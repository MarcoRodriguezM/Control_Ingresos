using System.Data;
using Control_Ingresos.Models;
using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Data;

public sealed class ActivityWorkflowRepository(IConfiguration configuration) : IActivityWorkflowRepository
{
    private readonly string _connectionString = configuration.GetConnectionString("ControlIngresos")
        ?? throw new InvalidOperationException("No se configuro ConnectionStrings:ControlIngresos.");

    public async Task<ActividadFlujoConfiguracion> ObtenerAsync(CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
            SELECT a.IdArea, a.Codigo, a.Nombre
            FROM dbo.Cat_Area AS a
            LEFT JOIN dbo.Cat_Estado_General AS eg ON eg.IdEstadoGeneral = a.IdEstadoGeneral
            WHERE ISNULL(eg.EsActivo, 1) = 1
            ORDER BY a.Nombre, a.IdArea;

            SELECT cra.IdConfigReqArea,
                   cra.IdAreaAcceso,
                   r.IdRequerimiento,
                   r.Codigo,
                   r.Nombre,
                   cra.IdAreaResponsable,
                   responsable.Nombre,
                   CONVERT(BIT, ISNULL(cra.RequiereTicketExterno, ISNULL(r.RequiereTicketExterno, 0))),
                   r.Descripcion
            FROM dbo.Config_Requerimiento_Area AS cra
            INNER JOIN dbo.Cat_Requerimiento AS r ON r.IdRequerimiento = cra.IdRequerimiento
            INNER JOIN dbo.Cat_Area AS responsable ON responsable.IdArea = cra.IdAreaResponsable
            LEFT JOIN dbo.Cat_Estado_General AS egConfig ON egConfig.IdEstadoGeneral = cra.IdEstadoGeneral
            LEFT JOIN dbo.Cat_Estado_General AS egReq ON egReq.IdEstadoGeneral = r.IdEstadoGeneral
            WHERE ISNULL(egConfig.EsActivo, 1) = 1
              AND ISNULL(egReq.EsActivo, 1) = 1
            ORDER BY cra.IdAreaAcceso, cra.IdConfigReqArea;
            """;

        await using var command = new SqlCommand(sql, connection) { CommandType = CommandType.Text };
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var areas = new List<(int Id, string? Codigo, string? Nombre)>();
        while (await reader.ReadAsync(cancellationToken))
            areas.Add((reader.GetInt32(0), GetNullableString(reader, 1), GetNullableString(reader, 2)));

        var pasos = new Dictionary<int, List<ActividadFlujoPaso>>();
        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                var idArea = reader.GetInt32(1);
                if (!pasos.TryGetValue(idArea, out var lista))
                {
                    lista = [];
                    pasos[idArea] = lista;
                }

                lista.Add(new ActividadFlujoPaso(
                    reader.GetInt64(0),
                    lista.Count + 1,
                    reader.GetInt32(2),
                    GetNullableString(reader, 3),
                    GetNullableString(reader, 4),
                    reader.GetInt32(5),
                    GetNullableString(reader, 6),
                    reader.GetBoolean(7),
                    ObtenerVigenciaMeses(GetNullableString(reader, 8))));
            }
        }

        return new ActividadFlujoConfiguracion(areas
            .Select(area => new ActividadFlujoArea(
                area.Id,
                area.Codigo,
                area.Nombre,
                pasos.TryGetValue(area.Id, out var lista) ? lista : []))
            .ToArray());
    }

    public async Task GuardarAsync(
        int idAreaAcceso,
        GuardarActividadFlujoRequest request,
        string usuario,
        CancellationToken cancellationToken)
    {
        var pasos = request.Pasos
            .Select(paso => paso with { NombreActividad = paso.NombreActividad.Trim() })
            .ToArray();

        if (pasos.Any(paso => string.IsNullOrWhiteSpace(paso.NombreActividad)))
            throw new InvalidOperationException("Todas las actividades deben tener un nombre.");
        if (pasos.Any(paso => paso.IdAreaResponsable <= 0))
            throw new InvalidOperationException("Cada actividad debe tener un area responsable.");
        if (pasos.Any(paso => paso.VigenciaMeses is < 1 or > 1200))
            throw new InvalidOperationException("La vigencia de cada actividad debe estar entre 1 y 1200 meses.");
        if (pasos.GroupBy(paso => paso.NombreActividad, StringComparer.OrdinalIgnoreCase).Any(group => group.Count() > 1))
            throw new InvalidOperationException("Una actividad no puede repetirse dentro del mismo flujo.");

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);

        try
        {
            var ids = await ObtenerIdsCatalogoAsync(connection, transaction, cancellationToken);
            await ValidarAreasAsync(connection, transaction, idAreaAcceso, pasos, cancellationToken);

            const string deactivateSql = """
                UPDATE dbo.Config_Requerimiento_Area
                   SET IdEstadoGeneral = @IdEstadoInactivo,
                       FechaModificacion = SYSDATETIME(),
                       UsuarioModificacion = @Usuario
                 WHERE IdAreaAcceso = @IdAreaAcceso
                   AND ISNULL(IdEstadoGeneral, @IdEstadoActivo) = @IdEstadoActivo;
                """;
            await using (var deactivate = new SqlCommand(deactivateSql, connection, transaction))
            {
                deactivate.Parameters.Add("@IdEstadoInactivo", SqlDbType.SmallInt).Value = ids.Inactivo;
                deactivate.Parameters.Add("@IdEstadoActivo", SqlDbType.SmallInt).Value = ids.Activo;
                deactivate.Parameters.Add("@Usuario", SqlDbType.VarChar, 50).Value = usuario;
                deactivate.Parameters.Add("@IdAreaAcceso", SqlDbType.Int).Value = idAreaAcceso;
                await deactivate.ExecuteNonQueryAsync(cancellationToken);
            }

            var nextRequirementId = await ObtenerSiguienteIdAsync(connection, transaction, "Cat_Requerimiento", "IdRequerimiento", cancellationToken);
            var nextConfigId = await ObtenerSiguienteIdAsync(connection, transaction, "Config_Requerimiento_Area", "IdConfigReqArea", cancellationToken);

            foreach (var paso in pasos)
            {
                var idRequerimiento = await ObtenerOCrearRequerimientoAsync(
                    connection,
                    transaction,
                    paso,
                    idAreaAcceso,
                    ids.Activo,
                    usuario,
                    nextRequirementId,
                    cancellationToken);
                if (idRequerimiento == nextRequirementId) nextRequirementId++;

                const string insertConfigSql = """
                    INSERT dbo.Config_Requerimiento_Area
                    (
                        IdConfigReqArea, IdRequerimiento, IdAreaAcceso, IdAreaResponsable,
                        IdTipoAplicacion, RequiereTicketExterno, IdEstadoGeneral,
                        FechaCreacion, UsuarioCreacion
                    )
                    VALUES
                    (
                        @IdConfigReqArea, @IdRequerimiento, @IdAreaAcceso, @IdAreaResponsable,
                        @IdTipoAplicacion, @RequiereTicketExterno, @IdEstadoActivo,
                        SYSDATETIME(), @Usuario
                    );
                    """;
                await using var insertConfig = new SqlCommand(insertConfigSql, connection, transaction);
                insertConfig.Parameters.Add("@IdConfigReqArea", SqlDbType.BigInt).Value = nextConfigId++;
                insertConfig.Parameters.Add("@IdRequerimiento", SqlDbType.Int).Value = idRequerimiento;
                insertConfig.Parameters.Add("@IdAreaAcceso", SqlDbType.Int).Value = idAreaAcceso;
                insertConfig.Parameters.Add("@IdAreaResponsable", SqlDbType.Int).Value = paso.IdAreaResponsable;
                insertConfig.Parameters.Add("@IdTipoAplicacion", SqlDbType.SmallInt).Value = ids.TipoAplicacion is null ? DBNull.Value : ids.TipoAplicacion.Value;
                insertConfig.Parameters.Add("@RequiereTicketExterno", SqlDbType.Bit).Value = paso.RequiereTicketExterno;
                insertConfig.Parameters.Add("@IdEstadoActivo", SqlDbType.SmallInt).Value = ids.Activo;
                insertConfig.Parameters.Add("@Usuario", SqlDbType.VarChar, 50).Value = usuario;
                await insertConfig.ExecuteNonQueryAsync(cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    public async Task SincronizarActividadesAsync(
        long idSolicitud,
        long idSolicitudPersona,
        IReadOnlyCollection<int> areas,
        string usuario,
        CancellationToken cancellationToken)
    {
        if (areas.Count == 0) return;

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);

        try
        {
            const string query = """
                SELECT cra.IdConfigReqArea,
                       cra.IdRequerimiento,
                       cra.IdAreaResponsable,
                       cra.IdTipoAplicacion,
                       CONVERT(BIT, ISNULL(cra.RequiereTicketExterno, ISNULL(r.RequiereTicketExterno, 0))),
                       r.Nombre,
                       r.Descripcion,
                       responsable.IdUsuarioAprobador,
                       s.FechaFin
                FROM dbo.Config_Requerimiento_Area AS cra
                INNER JOIN dbo.Cat_Requerimiento AS r ON r.IdRequerimiento = cra.IdRequerimiento
                INNER JOIN dbo.Solicitud_Persona_Requerimiento AS seleccion
                    ON seleccion.IdSolicitudPersona = @IdSolicitudPersona
                   AND seleccion.IdRequerimiento = cra.IdRequerimiento
                   AND ISNULL(seleccion.Seleccionado, 1) = 1
                INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = @IdSolicitud
                OUTER APPLY
                (
                    SELECT TOP (1) ca.IdUsuarioAprobador
                    FROM dbo.Config_Aprobador_Area AS ca
                    LEFT JOIN dbo.Cat_Estado_General AS estado ON estado.IdEstadoGeneral = ca.IdEstadoGeneral
                    WHERE ca.IdArea = cra.IdAreaResponsable
                      AND ISNULL(estado.EsActivo, 1) = 1
                      AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                      AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
                    ORDER BY ISNULL(ca.EsPrincipal, 0) DESC, ca.IdConfigAprobador
                ) AS responsable
                LEFT JOIN dbo.Cat_Estado_General AS estadoConfig ON estadoConfig.IdEstadoGeneral = cra.IdEstadoGeneral
                LEFT JOIN dbo.Cat_Estado_General AS estadoReq ON estadoReq.IdEstadoGeneral = r.IdEstadoGeneral
                WHERE cra.IdAreaAcceso IN (SELECT TRY_CONVERT(INT, value) FROM STRING_SPLIT(@Areas, ','))
                  AND ISNULL(estadoConfig.EsActivo, 1) = 1
                  AND ISNULL(estadoReq.EsActivo, 1) = 1
                ORDER BY cra.IdAreaAcceso, cra.IdConfigReqArea;
                """;
            var configuredSteps = new List<ConfiguredStep>();
            await using (var command = new SqlCommand(query, connection, transaction))
            {
                command.Parameters.Add("@IdSolicitud", SqlDbType.BigInt).Value = idSolicitud;
                command.Parameters.Add("@IdSolicitudPersona", SqlDbType.BigInt).Value = idSolicitudPersona;
                command.Parameters.Add("@Areas", SqlDbType.VarChar, -1).Value = string.Join(',', areas.Distinct());
                await using var reader = await command.ExecuteReaderAsync(cancellationToken);
                while (await reader.ReadAsync(cancellationToken))
                {
                    configuredSteps.Add(new ConfiguredStep(
                        reader.GetInt64(0),
                        reader.GetInt32(1),
                        reader.GetInt32(2),
                        reader.IsDBNull(3) ? null : reader.GetInt16(3),
                        reader.GetBoolean(4),
                        GetNullableString(reader, 5) ?? "Actividad requerida",
                        GetNullableString(reader, 7),
                        reader.IsDBNull(8) ? null : reader.GetDateTime(8),
                        ObtenerVigenciaMeses(GetNullableString(reader, 6))));
                }
            }

            var missingResponsible = configuredSteps.FirstOrDefault(step => string.IsNullOrWhiteSpace(step.IdUsuarioResponsable));
            if (missingResponsible is not null)
                throw new InvalidOperationException($"El area responsable de '{missingResponsible.Nombre}' no tiene un aprobador principal activo para asignar la actividad.");

            if (configuredSteps.Count == 0)
            {
                await transaction.CommitAsync(cancellationToken);
                return;
            }

            var pendingState = await ObtenerEstadoActividadPendienteAsync(connection, transaction, cancellationToken);
            var approvedState = await ObtenerEstadoActividadAprobadaAsync(connection, transaction, cancellationToken);
            var nextRequirementDetailId = await ObtenerSiguienteIdAsync(connection, transaction, "Solicitud_Persona_Requerimiento", "IdSolicitudPersonaReq", cancellationToken);
            var nextActivityId = await ObtenerSiguienteIdAsync(connection, transaction, "Actividad", "IdActividad", cancellationToken);

            foreach (var step in configuredSteps)
            {
                var aprobacionVigente = await ObtenerAprobacionVigenteAsync(
                    connection,
                    transaction,
                    idSolicitudPersona,
                    step.IdRequerimiento,
                    step.VigenciaMeses,
                    cancellationToken);
                var detailId = await ObtenerOCrearDetalleRequerimientoAsync(
                    connection, transaction, idSolicitudPersona, step, usuario,
                    nextRequirementDetailId, cancellationToken);
                if (detailId == nextRequirementDetailId) nextRequirementDetailId++;

                const string existsSql = "SELECT COUNT(*) FROM dbo.Actividad WHERE IdSolicitudPersonaReq = @IdSolicitudPersonaReq;";
                await using var exists = new SqlCommand(existsSql, connection, transaction);
                exists.Parameters.Add("@IdSolicitudPersonaReq", SqlDbType.BigInt).Value = detailId;
                if (Convert.ToInt32(await exists.ExecuteScalarAsync(cancellationToken)) > 0) continue;

                const string insertSql = """
                    INSERT dbo.Actividad
                    (
                        IdActividad, IdSolicitud, IdSolicitudPersona, IdSolicitudPersonaReq,
                        IdRequerimiento, IdAreaResponsable, IdUsuarioResponsable, IdEstadoActividad,
                        NombreActividad, FechaLimite, FechaInicio, FechaFinalizacion,
                        RequiereTicketExterno, FechaDecision, ComentarioDecision,
                        FechaCreacion, UsuarioCreacion
                    )
                    VALUES
                    (
                        @IdActividad, @IdSolicitud, @IdSolicitudPersona, @IdSolicitudPersonaReq,
                        @IdRequerimiento, @IdAreaResponsable, @IdUsuarioResponsable, @IdEstadoActividad,
                        @NombreActividad, @FechaLimite, @FechaInicio, @FechaFinalizacion,
                        @RequiereTicketExterno, @FechaDecision, @ComentarioDecision,
                        SYSDATETIME(), @Usuario
                    );
                    """;
                await using var insert = new SqlCommand(insertSql, connection, transaction);
                insert.Parameters.Add("@IdActividad", SqlDbType.BigInt).Value = nextActivityId++;
                insert.Parameters.Add("@IdSolicitud", SqlDbType.BigInt).Value = idSolicitud;
                insert.Parameters.Add("@IdSolicitudPersona", SqlDbType.BigInt).Value = idSolicitudPersona;
                insert.Parameters.Add("@IdSolicitudPersonaReq", SqlDbType.BigInt).Value = detailId;
                insert.Parameters.Add("@IdRequerimiento", SqlDbType.Int).Value = step.IdRequerimiento;
                insert.Parameters.Add("@IdAreaResponsable", SqlDbType.Int).Value = step.IdAreaResponsable;
                insert.Parameters.Add("@IdUsuarioResponsable", SqlDbType.VarChar, 50).Value = step.IdUsuarioResponsable!;
                insert.Parameters.Add("@IdEstadoActividad", SqlDbType.SmallInt).Value = aprobacionVigente is null ? pendingState : approvedState;
                insert.Parameters.Add("@NombreActividad", SqlDbType.NVarChar, 200).Value = step.Nombre;
                insert.Parameters.Add("@FechaLimite", SqlDbType.DateTime2).Value = step.FechaLimite is null ? DBNull.Value : step.FechaLimite.Value;
                insert.Parameters.Add("@FechaInicio", SqlDbType.DateTime2).Value = aprobacionVigente is null ? DBNull.Value : aprobacionVigente.Value.FechaFinalizacion;
                insert.Parameters.Add("@FechaFinalizacion", SqlDbType.DateTime2).Value = aprobacionVigente is null ? DBNull.Value : aprobacionVigente.Value.FechaFinalizacion;
                insert.Parameters.Add("@RequiereTicketExterno", SqlDbType.Bit).Value = step.RequiereTicketExterno;
                insert.Parameters.Add("@FechaDecision", SqlDbType.DateTime2).Value = aprobacionVigente is null ? DBNull.Value : DateTime.Now;
                insert.Parameters.Add("@ComentarioDecision", SqlDbType.NVarChar, 1000).Value = aprobacionVigente is null
                    ? DBNull.Value
                    : $"Aprobada automaticamente. La actividad realizada el {aprobacionVigente.Value.FechaFinalizacion:dd/MM/yyyy} tiene vigencia hasta el {aprobacionVigente.Value.VigenteHasta:dd/MM/yyyy}.";
                insert.Parameters.Add("@Usuario", SqlDbType.VarChar, 50).Value = usuario;
                await insert.ExecuteNonQueryAsync(cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    public async Task ValidarActividadDesbloqueadaAsync(
        long idActividad,
        string idUsuarioResponsable,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        const string sql = """
            SELECT COUNT(*)
            FROM dbo.Actividad AS actual
            INNER JOIN dbo.Config_Requerimiento_Area AS configActual
                ON configActual.IdRequerimiento = actual.IdRequerimiento
               AND configActual.IdAreaResponsable = actual.IdAreaResponsable
            INNER JOIN dbo.Config_Requerimiento_Area AS previa
                ON previa.IdAreaAcceso = configActual.IdAreaAcceso
               AND previa.IdConfigReqArea < configActual.IdConfigReqArea
            INNER JOIN dbo.Solicitud_Persona_Requerimiento AS seleccionPrevia
                ON seleccionPrevia.IdSolicitudPersona = actual.IdSolicitudPersona
               AND seleccionPrevia.IdRequerimiento = previa.IdRequerimiento
               AND ISNULL(seleccionPrevia.Seleccionado, 1) = 1
            LEFT JOIN dbo.Actividad AS actividadPrevia
                ON actividadPrevia.IdSolicitudPersona = actual.IdSolicitudPersona
               AND actividadPrevia.IdRequerimiento = previa.IdRequerimiento
            LEFT JOIN dbo.Cat_Estado_Actividad AS estadoPrevia
                ON estadoPrevia.IdEstadoActividad = actividadPrevia.IdEstadoActividad
            LEFT JOIN dbo.Cat_Estado_General AS estadoConfig ON estadoConfig.IdEstadoGeneral = configActual.IdEstadoGeneral
            LEFT JOIN dbo.Cat_Estado_General AS estadoPreviaConfig ON estadoPreviaConfig.IdEstadoGeneral = previa.IdEstadoGeneral
            WHERE actual.IdActividad = @IdActividad
              AND actual.IdUsuarioResponsable = @IdUsuarioResponsable
              AND ISNULL(estadoConfig.EsActivo, 1) = 1
              AND ISNULL(estadoPreviaConfig.EsActivo, 1) = 1
              AND ISNULL(estadoPrevia.Codigo, '') <> 'APROBADA';
            """;
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@IdActividad", SqlDbType.BigInt).Value = idActividad;
        command.Parameters.Add("@IdUsuarioResponsable", SqlDbType.VarChar, 50).Value = idUsuarioResponsable;
        var pending = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));
        if (pending > 0)
            throw new InvalidOperationException($"Esta actividad esta bloqueada. Primero deben aprobarse {pending} actividad(es) anterior(es) del flujo.");
    }

    public async Task<IReadOnlySet<long>> ObtenerAccesosBloqueadosAsync(
        IReadOnlyCollection<long> idsSolicitudPersonaArea,
        CancellationToken cancellationToken)
    {
        if (idsSolicitudPersonaArea.Count == 0) return new HashSet<long>();
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        const string sql = """
            SELECT DISTINCT spa.IdSolicitudPersonaArea
            FROM dbo.Solicitud_Persona_Area AS spa
            INNER JOIN dbo.Solicitud_Persona_Requerimiento AS seleccion
                ON seleccion.IdSolicitudPersona = spa.IdSolicitudPersona
               AND ISNULL(seleccion.Seleccionado, 1) = 1
            INNER JOIN dbo.Config_Requerimiento_Area AS cra
                ON cra.IdAreaAcceso = spa.IdArea
               AND cra.IdRequerimiento = seleccion.IdRequerimiento
            LEFT JOIN dbo.Cat_Estado_General AS estadoConfig ON estadoConfig.IdEstadoGeneral = cra.IdEstadoGeneral
            WHERE spa.IdSolicitudPersonaArea IN (SELECT TRY_CONVERT(BIGINT, value) FROM STRING_SPLIT(@Ids, ','))
              AND ISNULL(estadoConfig.EsActivo, 1) = 1
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM dbo.Actividad AS actividad
                  INNER JOIN dbo.Cat_Estado_Actividad AS estado ON estado.IdEstadoActividad = actividad.IdEstadoActividad
                  WHERE actividad.IdSolicitudPersona = spa.IdSolicitudPersona
                    AND actividad.IdRequerimiento = cra.IdRequerimiento
                    AND estado.Codigo = 'APROBADA'
              );
            """;
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@Ids", SqlDbType.VarChar, -1).Value = string.Join(',', idsSolicitudPersonaArea);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var blocked = new HashSet<long>();
        while (await reader.ReadAsync(cancellationToken)) blocked.Add(reader.GetInt64(0));
        return blocked;
    }

    public async Task<IReadOnlySet<string>> ObtenerAreasQrBloqueadasAsync(long idPersona, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        const string sql = """
            SELECT DISTINCT spa.IdArea, s.NumeroSolicitud
            FROM dbo.Solicitud_Persona_Area AS spa
            INNER JOIN dbo.Solicitud_Persona AS sp ON sp.IdSolicitudPersona = spa.IdSolicitudPersona
            INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = sp.IdSolicitud
            INNER JOIN dbo.Solicitud_Persona_Requerimiento AS seleccion
                ON seleccion.IdSolicitudPersona = sp.IdSolicitudPersona
               AND ISNULL(seleccion.Seleccionado, 1) = 1
            INNER JOIN dbo.Config_Requerimiento_Area AS cra
                ON cra.IdAreaAcceso = spa.IdArea
               AND cra.IdRequerimiento = seleccion.IdRequerimiento
            LEFT JOIN dbo.Cat_Estado_General AS estadoConfig ON estadoConfig.IdEstadoGeneral = cra.IdEstadoGeneral
            WHERE sp.IdPersona = @IdPersona
              AND ISNULL(estadoConfig.EsActivo, 1) = 1
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM dbo.Actividad AS actividad
                  INNER JOIN dbo.Cat_Estado_Actividad AS estado ON estado.IdEstadoActividad = actividad.IdEstadoActividad
                  WHERE actividad.IdSolicitudPersona = sp.IdSolicitudPersona
                    AND actividad.IdRequerimiento = cra.IdRequerimiento
                    AND estado.Codigo = 'APROBADA'
              );
            """;
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@IdPersona", SqlDbType.BigInt).Value = idPersona;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var blocked = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        while (await reader.ReadAsync(cancellationToken))
            blocked.Add(AreaKey(reader.GetInt32(0), GetNullableString(reader, 1)));
        return blocked;
    }

    public static string AreaKey(int idArea, string? numeroSolicitud) => $"{idArea}|{numeroSolicitud?.Trim()}";

    private static async Task<(short Activo, short Inactivo, short? TipoAplicacion)> ObtenerIdsCatalogoAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'ACTIVO';
            SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'INACTIVO';
            SELECT TOP (1) IdTipoAplicacion FROM dbo.Cat_Tipo_Aplicacion_Requerimiento
             WHERE Codigo IN ('OBLIGATORIO', 'REQUERIDO') ORDER BY CASE WHEN Codigo = 'OBLIGATORIO' THEN 0 ELSE 1 END;
            """;
        await using var command = new SqlCommand(sql, connection, transaction);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) throw new InvalidOperationException("No existe el estado general ACTIVO.");
        var activo = reader.GetInt16(0);
        if (!await reader.NextResultAsync(cancellationToken) || !await reader.ReadAsync(cancellationToken)) throw new InvalidOperationException("No existe el estado general INACTIVO.");
        var inactivo = reader.GetInt16(0);
        short? tipo = null;
        if (await reader.NextResultAsync(cancellationToken) && await reader.ReadAsync(cancellationToken)) tipo = reader.GetInt16(0);
        return (activo, inactivo, tipo);
    }

    private static async Task ValidarAreasAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int idAreaAcceso,
        IReadOnlyCollection<GuardarActividadFlujoPasoRequest> pasos,
        CancellationToken cancellationToken)
    {
        var ids = pasos.Select(paso => paso.IdAreaResponsable).Append(idAreaAcceso).Distinct().ToArray();
        const string sql = "SELECT COUNT(*) FROM dbo.Cat_Area WHERE IdArea IN (SELECT TRY_CONVERT(INT, value) FROM STRING_SPLIT(@Ids, ','));";
        await using var command = new SqlCommand(sql, connection, transaction);
        command.Parameters.Add("@Ids", SqlDbType.VarChar, -1).Value = string.Join(',', ids);
        var count = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));
        if (count != ids.Length) throw new InvalidOperationException("Una de las areas seleccionadas no existe.");
    }

    private static async Task<int> ObtenerOCrearRequerimientoAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        GuardarActividadFlujoPasoRequest paso,
        int idAreaAcceso,
        short idEstadoActivo,
        string usuario,
        int nuevoId,
        CancellationToken cancellationToken)
    {
        const string findSql = """
            SELECT TOP (1) r.IdRequerimiento
            FROM dbo.Cat_Requerimiento AS r
            INNER JOIN dbo.Config_Requerimiento_Area AS cra
                ON cra.IdRequerimiento = r.IdRequerimiento
               AND cra.IdAreaAcceso = @IdAreaAcceso
            WHERE UPPER(LTRIM(RTRIM(r.Nombre))) = UPPER(LTRIM(RTRIM(@Nombre)))
            ORDER BY CASE WHEN r.IdEstadoGeneral = @IdEstadoActivo THEN 0 ELSE 1 END,
                     cra.IdConfigReqArea DESC;
            """;
        await using (var find = new SqlCommand(findSql, connection, transaction))
        {
            find.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = paso.NombreActividad;
            find.Parameters.Add("@IdAreaAcceso", SqlDbType.Int).Value = idAreaAcceso;
            find.Parameters.Add("@IdEstadoActivo", SqlDbType.SmallInt).Value = idEstadoActivo;
            var existing = await find.ExecuteScalarAsync(cancellationToken);
            if (existing is not null and not DBNull)
            {
                var id = Convert.ToInt32(existing);
                const string activateSql = """
                    UPDATE dbo.Cat_Requerimiento
                       SET IdEstadoGeneral = @IdEstadoActivo,
                           RequiereTicketExterno = @RequiereTicketExterno,
                           Descripcion = @Descripcion,
                           FechaModificacion = SYSDATETIME(),
                           UsuarioModificacion = @Usuario
                     WHERE IdRequerimiento = @IdRequerimiento;
                    """;
                await using var activate = new SqlCommand(activateSql, connection, transaction);
                activate.Parameters.Add("@IdEstadoActivo", SqlDbType.SmallInt).Value = idEstadoActivo;
                activate.Parameters.Add("@RequiereTicketExterno", SqlDbType.Bit).Value = paso.RequiereTicketExterno;
                activate.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 500).Value = CrearDescripcionVigencia(paso.VigenciaMeses);
                activate.Parameters.Add("@Usuario", SqlDbType.VarChar, 50).Value = usuario;
                activate.Parameters.Add("@IdRequerimiento", SqlDbType.Int).Value = id;
                await activate.ExecuteNonQueryAsync(cancellationToken);
                return id;
            }
        }

        const string insertSql = """
            INSERT dbo.Cat_Requerimiento
            (
                IdRequerimiento, Codigo, Nombre, Descripcion, IdCategoriaRequerimiento,
                RequiereTicketExterno, IdEstadoGeneral, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdRequerimiento, @Codigo, @Nombre, @Descripcion, NULL,
                @RequiereTicketExterno, @IdEstadoActivo, SYSDATETIME(), @Usuario
            );
            """;
        await using var insert = new SqlCommand(insertSql, connection, transaction);
        insert.Parameters.Add("@IdRequerimiento", SqlDbType.Int).Value = nuevoId;
        insert.Parameters.Add("@Codigo", SqlDbType.VarChar, 40).Value = $"ACT_{nuevoId:000000}";
        insert.Parameters.Add("@Nombre", SqlDbType.NVarChar, 150).Value = paso.NombreActividad;
        insert.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 500).Value = CrearDescripcionVigencia(paso.VigenciaMeses);
        insert.Parameters.Add("@RequiereTicketExterno", SqlDbType.Bit).Value = paso.RequiereTicketExterno;
        insert.Parameters.Add("@IdEstadoActivo", SqlDbType.SmallInt).Value = idEstadoActivo;
        insert.Parameters.Add("@Usuario", SqlDbType.VarChar, 50).Value = usuario;
        await insert.ExecuteNonQueryAsync(cancellationToken);
        return nuevoId;
    }

    private static async Task<int> ObtenerSiguienteIdAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        string table,
        string column,
        CancellationToken cancellationToken)
    {
        var sql = $"SELECT ISNULL(MAX({column}), 0) + 1 FROM dbo.{table} WITH (UPDLOCK, HOLDLOCK);";
        await using var command = new SqlCommand(sql, connection, transaction);
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));
    }

    private static async Task<short> ObtenerEstadoActividadPendienteAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        CancellationToken cancellationToken)
    {
        const string sql = "SELECT TOP (1) IdEstadoActividad FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'PENDIENTE';";
        await using var command = new SqlCommand(sql, connection, transaction);
        var result = await command.ExecuteScalarAsync(cancellationToken);
        return result is null or DBNull
            ? throw new InvalidOperationException("No existe el estado PENDIENTE para las actividades.")
            : Convert.ToInt16(result);
    }

    private static async Task<short> ObtenerEstadoActividadAprobadaAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        CancellationToken cancellationToken)
    {
        const string sql = "SELECT TOP (1) IdEstadoActividad FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'APROBADA';";
        await using var command = new SqlCommand(sql, connection, transaction);
        var result = await command.ExecuteScalarAsync(cancellationToken);
        return result is null or DBNull
            ? throw new InvalidOperationException("No existe el estado APROBADA para las actividades.")
            : Convert.ToInt16(result);
    }

    private static async Task<AprobacionVigente?> ObtenerAprobacionVigenteAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long idSolicitudPersona,
        int idRequerimiento,
        int vigenciaMeses,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT TOP (1)
                   actividad.FechaFinalizacion,
                   DATEADD(MONTH, @VigenciaMeses, actividad.FechaFinalizacion)
            FROM dbo.Solicitud_Persona AS actual
            INNER JOIN dbo.Solicitud_Persona AS anterior
                ON anterior.IdSolicitudPersona <> actual.IdSolicitudPersona
               AND
               (
                   (actual.IdPersona IS NOT NULL AND anterior.IdPersona = actual.IdPersona)
                   OR
                   (NULLIF(LTRIM(RTRIM(actual.CodigoEmpleadoHtis)), '') IS NOT NULL
                    AND anterior.CodigoEmpleadoHtis = actual.CodigoEmpleadoHtis)
               )
            INNER JOIN dbo.Actividad AS actividad
                ON actividad.IdSolicitudPersona = anterior.IdSolicitudPersona
               AND actividad.IdRequerimiento = @IdRequerimiento
            INNER JOIN dbo.Cat_Estado_Actividad AS estado
                ON estado.IdEstadoActividad = actividad.IdEstadoActividad
               AND estado.Codigo = 'APROBADA'
            WHERE actual.IdSolicitudPersona = @IdSolicitudPersona
              AND actividad.FechaFinalizacion IS NOT NULL
              AND DATEADD(MONTH, @VigenciaMeses, actividad.FechaFinalizacion) >= CONVERT(DATE, SYSDATETIME())
            ORDER BY actividad.FechaFinalizacion DESC;
            """;
        await using var command = new SqlCommand(sql, connection, transaction);
        command.Parameters.Add("@IdSolicitudPersona", SqlDbType.BigInt).Value = idSolicitudPersona;
        command.Parameters.Add("@IdRequerimiento", SqlDbType.Int).Value = idRequerimiento;
        command.Parameters.Add("@VigenciaMeses", SqlDbType.Int).Value = vigenciaMeses;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new AprobacionVigente(reader.GetDateTime(0), reader.GetDateTime(1));
    }

    private static async Task<long> ObtenerOCrearDetalleRequerimientoAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long idSolicitudPersona,
        ConfiguredStep step,
        string usuario,
        int nuevoId,
        CancellationToken cancellationToken)
    {
        const string findSql = """
            SELECT TOP (1) IdSolicitudPersonaReq
            FROM dbo.Solicitud_Persona_Requerimiento
            WHERE IdSolicitudPersona = @IdSolicitudPersona
              AND IdRequerimiento = @IdRequerimiento;
            """;
        await using (var find = new SqlCommand(findSql, connection, transaction))
        {
            find.Parameters.Add("@IdSolicitudPersona", SqlDbType.BigInt).Value = idSolicitudPersona;
            find.Parameters.Add("@IdRequerimiento", SqlDbType.Int).Value = step.IdRequerimiento;
            var existing = await find.ExecuteScalarAsync(cancellationToken);
            if (existing is not null and not DBNull) return Convert.ToInt64(existing);
        }

        const string insertSql = """
            INSERT dbo.Solicitud_Persona_Requerimiento
            (
                IdSolicitudPersonaReq, IdSolicitudPersona, IdRequerimiento, IdTipoAplicacion,
                Seleccionado, ConfiguradoAutomatico, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdSolicitudPersonaReq, @IdSolicitudPersona, @IdRequerimiento, @IdTipoAplicacion,
                1, 1, SYSDATETIME(), @Usuario
            );
            """;
        await using var insert = new SqlCommand(insertSql, connection, transaction);
        insert.Parameters.Add("@IdSolicitudPersonaReq", SqlDbType.BigInt).Value = nuevoId;
        insert.Parameters.Add("@IdSolicitudPersona", SqlDbType.BigInt).Value = idSolicitudPersona;
        insert.Parameters.Add("@IdRequerimiento", SqlDbType.Int).Value = step.IdRequerimiento;
        insert.Parameters.Add("@IdTipoAplicacion", SqlDbType.SmallInt).Value = step.IdTipoAplicacion is null ? DBNull.Value : step.IdTipoAplicacion.Value;
        insert.Parameters.Add("@Usuario", SqlDbType.VarChar, 50).Value = usuario;
        await insert.ExecuteNonQueryAsync(cancellationToken);
        return nuevoId;
    }

    private static string? GetNullableString(SqlDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);

    private const string VigenciaPrefix = "VIGENCIA_MESES=";

    private static int ObtenerVigenciaMeses(string? descripcion)
    {
        if (string.IsNullOrWhiteSpace(descripcion)) return 24;
        var marker = descripcion.IndexOf(VigenciaPrefix, StringComparison.OrdinalIgnoreCase);
        if (marker < 0) return 24;
        var value = descripcion[(marker + VigenciaPrefix.Length)..]
            .Split([';', ' ', '\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
            .FirstOrDefault();
        return int.TryParse(value, out var meses) && meses is >= 1 and <= 1200 ? meses : 24;
    }

    private static string CrearDescripcionVigencia(int meses) => $"{VigenciaPrefix}{meses}";

    private sealed record ConfiguredStep(
        long IdConfig,
        int IdRequerimiento,
        int IdAreaResponsable,
        short? IdTipoAplicacion,
        bool RequiereTicketExterno,
        string Nombre,
        string? IdUsuarioResponsable,
        DateTime? FechaLimite,
        int VigenciaMeses);

    private readonly record struct AprobacionVigente(DateTime FechaFinalizacion, DateTime VigenteHasta);
}
