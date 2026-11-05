using System.Data;
using System.Text.Json;
using Control_Ingresos.Models;
using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Data;

public sealed class ActivityWorkflowRepository(IConfiguration configuration) : IActivityWorkflowRepository
{
    private static readonly HashSet<string> OrigenesLookupFreshservice = new(StringComparer.OrdinalIgnoreCase)
    {
        "FRESHSERVICE_LOCATIONS",
        "FRESHSERVICE_DEPARTMENTS",
        "FRESHSERVICE_REQUESTERS",
        "FRESHSERVICE_AGENT_GROUPS",
        "FRESHSERVICE_ASSETS"
    };

    private readonly string _connectionString = configuration.GetConnectionString("ControlIngresos")
        ?? throw new InvalidOperationException("No se configuro ConnectionStrings:ControlIngresos.");

    public async Task<ActividadFlujoConfiguracion> ObtenerAsync(CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Actividad_Flujo_Obtener");
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var areas = new List<(int Id, string? Codigo, string? Nombre)>();
        while (await reader.ReadAsync(cancellationToken))
            areas.Add((reader.GetInt32(0), GetNullableString(reader, 1), GetNullableString(reader, 2)));

        var flujos = new Dictionary<long, FlujoBuilder>();
        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                var idVersion = GetInt64Value(reader, 1);
                flujos[idVersion] = new FlujoBuilder(
                    GetInt64Value(reader, 0), idVersion, reader.GetInt32(2), reader.GetInt32(3),
                    GetNullableString(reader, 4), GetNullableString(reader, 5), GetNullableString(reader, 6),
                    true, SplitStrings(GetNullableString(reader, 7)), [], []);
            }
        }

        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                var idVersion = GetInt64Value(reader, 1);
                if (!flujos.TryGetValue(idVersion, out var flujo)) continue;
                flujo.Pasos.Add(new ActividadFlujoPaso(
                    GetInt64Value(reader, 0), GetNullableString(reader, 3), reader.GetInt32(4), reader.GetInt32(2),
                    GetNullableString(reader, 5), reader.GetInt32(6), GetNullableString(reader, 7), reader.GetBoolean(8),
                    GetNullableInt32(reader, 9), GetNullableInt64(reader, 10), GetNullableString(reader, 11),
                    ParseFreshserviceLookups(GetNullableString(reader, 12)), reader.GetBoolean(13),
                    GetNullableString(reader, 14), reader.GetInt32(15),
                    GetNullableDateOnly(reader, 16), GetNullableDateOnly(reader, 17),
                    SplitLongs(GetNullableString(reader, 18)), []));
            }
        }

        await reader.DisposeAsync();

        await using (var historicalCommand = StoredProcedure(connection, "dbo.usp_Actividad_Flujo_Historicos_Obtener"))
        await using (var historicalReader = await historicalCommand.ExecuteReaderAsync(cancellationToken))
        {
            while (await historicalReader.ReadAsync(cancellationToken))
            {
                var idVersion = GetInt64Value(historicalReader, 1);
                flujos[idVersion] = new FlujoBuilder(
                    GetInt64Value(historicalReader, 0), idVersion, historicalReader.GetInt32(2), historicalReader.GetInt32(3),
                    GetNullableString(historicalReader, 4), GetNullableString(historicalReader, 5), GetNullableString(historicalReader, 6),
                    false, SplitStrings(GetNullableString(historicalReader, 7)), [], []);
            }

            if (await historicalReader.NextResultAsync(cancellationToken))
            {
                while (await historicalReader.ReadAsync(cancellationToken))
                {
                    var idVersion = GetInt64Value(historicalReader, 1);
                    if (!flujos.TryGetValue(idVersion, out var flujo)) continue;
                    flujo.Pasos.Add(new ActividadFlujoPaso(
                        GetInt64Value(historicalReader, 0), GetNullableString(historicalReader, 3), historicalReader.GetInt32(4), historicalReader.GetInt32(2),
                        GetNullableString(historicalReader, 5), historicalReader.GetInt32(6), GetNullableString(historicalReader, 7), historicalReader.GetBoolean(8),
                        GetNullableInt32(historicalReader, 9), GetNullableInt64(historicalReader, 10), GetNullableString(historicalReader, 11),
                        ParseFreshserviceLookups(GetNullableString(historicalReader, 12)), historicalReader.GetBoolean(13),
                        GetNullableString(historicalReader, 14), historicalReader.GetInt32(15),
                        GetNullableDateOnly(historicalReader, 16), GetNullableDateOnly(historicalReader, 17),
                        SplitLongs(GetNullableString(historicalReader, 18)), []));
                }
            }
        }

        var pasosPorId = flujos.Values
            .SelectMany(flujo => flujo.Pasos.Select((paso, index) => (paso.IdActividadFlujoPaso, flujo, index)))
            .ToDictionary(item => item.IdActividadFlujoPaso);
        await using (var externalCommand = StoredProcedure(connection, "dbo.usp_Actividad_Flujo_Dependencias_Externas_Listar"))
        await using (var externalReader = await externalCommand.ExecuteReaderAsync(cancellationToken))
        {
            while (await externalReader.ReadAsync(cancellationToken))
            {
                if (!pasosPorId.TryGetValue(GetInt64Value(externalReader, 0), out var ubicacion)) continue;
                var paso = ubicacion.flujo.Pasos[ubicacion.index];
                ubicacion.flujo.Pasos[ubicacion.index] = paso with
                {
                    DependenciasExternas =
                    [
                        .. paso.DependenciasExternas,
                        new ActividadFlujoDependenciaExterna(GetInt64Value(externalReader, 1), externalReader.GetString(2)),
                    ],
                };
            }
        }

        await using (var automaticCommand = StoredProcedure(connection, "dbo.usp_Actividad_Flujo_Automaticos_Listar"))
        await using (var automaticReader = await automaticCommand.ExecuteReaderAsync(cancellationToken))
        {
            while (await automaticReader.ReadAsync(cancellationToken))
            {
                if (flujos.TryGetValue(GetInt64Value(automaticReader, 0), out var flujo))
                    flujo.TiposIngresoAutomaticos.Add(automaticReader.GetString(1));
            }
        }

        return new ActividadFlujoConfiguracion(areas.Select(area => new ActividadFlujoArea(
            area.Id,
            area.Codigo,
            area.Nombre,
            flujos.Values
                .Where(flujo => flujo.IdArea == area.Id)
                .Select(flujo => new ActividadFlujo(
                    flujo.IdFlujo, flujo.IdVersion, flujo.NumeroVersion, flujo.Codigo, flujo.Nombre,
                    flujo.Descripcion, flujo.EsVersionActual, flujo.TiposIngreso,
                    flujo.TiposIngresoAutomaticos, flujo.Pasos))
                .ToArray()))
            .ToArray());
    }

    public async Task<ActividadFlujoGuardadoResponse> GuardarAsync(
        int idAreaAcceso,
        long? idActividadFlujo,
        GuardarActividadFlujoRequest request,
        string usuario,
        CancellationToken cancellationToken)
    {
        ValidarFlujo(request);
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);
        try
        {
            var flujoJson = JsonSerializer.Serialize(request);
            ActividadFlujoGuardadoResponse result;
            await using (var command = StoredProcedure(connection, "dbo.usp_Actividad_Flujo_Guardar"))
            {
                command.Transaction = transaction;
                Add(command, "@IdAreaAcceso", SqlDbType.Int, idAreaAcceso);
                Add(command, "@IdActividadFlujo", SqlDbType.BigInt, idActividadFlujo);
                Add(command, "@FlujoJson", SqlDbType.NVarChar, flujoJson, -1);
                Add(command, "@Usuario", SqlDbType.VarChar, usuario, 50);
                await using var reader = await command.ExecuteReaderAsync(cancellationToken);
                if (!await reader.ReadAsync(cancellationToken))
                    throw new InvalidOperationException("El procedimiento no devolvio la version guardada del flujo.");
                result = new(GetInt64Value(reader, 0), GetInt64Value(reader, 1));
            }

            await using (var externalCommand = StoredProcedure(connection, "dbo.usp_Actividad_Flujo_Dependencias_Externas_Guardar"))
            {
                externalCommand.Transaction = transaction;
                Add(externalCommand, "@IdActividadFlujoVersion", SqlDbType.BigInt, result.IdActividadFlujoVersion);
                Add(externalCommand, "@FlujoJson", SqlDbType.NVarChar, flujoJson, -1);
                Add(externalCommand, "@Usuario", SqlDbType.VarChar, usuario, 50);
                await externalCommand.ExecuteNonQueryAsync(cancellationToken);
            }

            await using (var automaticCommand = StoredProcedure(connection, "dbo.usp_Actividad_Flujo_Automaticos_Guardar"))
            {
                automaticCommand.Transaction = transaction;
                Add(automaticCommand, "@IdActividadFlujoVersion", SqlDbType.BigInt, result.IdActividadFlujoVersion);
                Add(automaticCommand, "@TiposJson", SqlDbType.NVarChar,
                    JsonSerializer.Serialize(request.TiposIngresoAutomaticos ?? []), -1);
                Add(automaticCommand, "@Usuario", SqlDbType.VarChar, usuario, 50);
                await automaticCommand.ExecuteNonQueryAsync(cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
            return result;
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    public async Task<bool> EliminarAsync(int idAreaAcceso, long idActividadFlujo, string usuario, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
        try
        {
            await using var command = new SqlCommand("""
            DECLARE @Inactivo SMALLINT =
                (SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'INACTIVO');
            DECLARE @Resultado TINYINT;

            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.Actividad_Flujo AS flujo WITH (UPDLOCK, HOLDLOCK)
                LEFT JOIN dbo.Cat_Estado_General AS estado ON estado.IdEstadoGeneral = flujo.IdEstadoGeneral
                WHERE flujo.IdActividadFlujo = @IdActividadFlujo
                  AND flujo.IdAreaAcceso = @IdAreaAcceso
                  AND ISNULL(estado.EsActivo, 1) = 1
            ) SET @Resultado = 0;
            ELSE IF EXISTS
            (
                SELECT 1
                FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
                LEFT JOIN dbo.Actividad_Flujo_Version AS version
                    ON version.IdActividadFlujoVersion = asignacion.IdActividadFlujoVersion
                WHERE asignacion.IdActividadFlujo = @IdActividadFlujo
                   OR version.IdActividadFlujo = @IdActividadFlujo
            ) SET @Resultado = 2;
            ELSE IF EXISTS
            (
                SELECT 1
                FROM dbo.Actividad_Flujo_Paso_Dependencia_Externa AS dependencia
                INNER JOIN dbo.Actividad_Flujo_Paso AS paso
                    ON paso.IdActividadFlujoPaso = dependencia.IdActividadFlujoPaso
                INNER JOIN dbo.Actividad_Flujo AS origen
                    ON origen.IdActividadFlujoVersionActual = paso.IdActividadFlujoVersion
                LEFT JOIN dbo.Cat_Estado_General AS estadoOrigen
                    ON estadoOrigen.IdEstadoGeneral = origen.IdEstadoGeneral
                LEFT JOIN dbo.Cat_Estado_General AS estadoDependencia
                    ON estadoDependencia.IdEstadoGeneral = dependencia.IdEstadoGeneral
                WHERE dependencia.IdActividadFlujoRequerido = @IdActividadFlujo
                  AND origen.IdActividadFlujo <> @IdActividadFlujo
                  AND ISNULL(estadoOrigen.EsActivo, 1) = 1
                  AND ISNULL(estadoDependencia.EsActivo, 1) = 1
            ) SET @Resultado = 3;
            ELSE IF @Inactivo IS NULL SET @Resultado = 4;
            ELSE
            BEGIN
                UPDATE dbo.Actividad_Flujo
                   SET IdEstadoGeneral = @Inactivo,
                       IdActividadFlujoVersionActual = NULL,
                       FechaModificacion = SYSDATETIME(),
                       UsuarioModificacion = @Usuario
                 WHERE IdActividadFlujo = @IdActividadFlujo
                   AND IdAreaAcceso = @IdAreaAcceso;
                SET @Resultado = 1;
            END;

            SELECT @Resultado;
            """, connection, transaction);
            Add(command, "@IdAreaAcceso", SqlDbType.Int, idAreaAcceso);
            Add(command, "@IdActividadFlujo", SqlDbType.BigInt, idActividadFlujo);
            Add(command, "@Usuario", SqlDbType.VarChar, usuario, 50);

            var result = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));
            await transaction.CommitAsync(cancellationToken);
            return result switch
            {
                0 => false,
                1 => true,
                2 => throw new InvalidOperationException("No se puede eliminar el flujo porque ya esta asignado a una solicitud."),
                3 => throw new InvalidOperationException("No se puede eliminar el flujo porque otra actividad depende de el."),
                _ => throw new InvalidOperationException("No existe el estado general INACTIVO para eliminar el flujo."),
            };
        }
        catch
        {
            if (transaction.Connection is not null) await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    public async Task SincronizarActividadesAsync(
        long idSolicitud,
        long idSolicitudPersona,
        IReadOnlyCollection<long> flujos,
        string usuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        var seleccion = flujos.Distinct().ToList();
        await using (var automaticCommand = StoredProcedure(connection, "dbo.usp_Actividad_Flujo_Automaticos_Resolver"))
        {
            Add(automaticCommand, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
            Add(automaticCommand, "@IdSolicitudPersona", SqlDbType.BigInt, idSolicitudPersona);
            Add(automaticCommand, "@FlujosJson", SqlDbType.NVarChar, JsonSerializer.Serialize(seleccion), -1);
            await using var automaticReader = await automaticCommand.ExecuteReaderAsync(cancellationToken);
            while (await automaticReader.ReadAsync(cancellationToken))
                seleccion.Add(GetInt64Value(automaticReader, 0));
        }
        await using (var dependencyCommand = StoredProcedure(connection, "dbo.usp_Actividad_Flujo_Dependencias_Resolver"))
        {
            Add(dependencyCommand, "@FlujosJson", SqlDbType.NVarChar, JsonSerializer.Serialize(seleccion.Distinct()), -1);
            await using var dependencyReader = await dependencyCommand.ExecuteReaderAsync(cancellationToken);
            while (await dependencyReader.ReadAsync(cancellationToken))
                seleccion.Add(GetInt64Value(dependencyReader, 0));
        }
        await using var command = StoredProcedure(connection, "dbo.usp_Actividad_Flujo_Asignar_Generar");
        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        Add(command, "@IdSolicitudPersona", SqlDbType.BigInt, idSolicitudPersona);
        Add(command, "@FlujosJson", SqlDbType.NVarChar, JsonSerializer.Serialize(seleccion.Distinct()), -1);
        Add(command, "@Usuario", SqlDbType.VarChar, usuario, 50);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task ValidarActividadDesbloqueadaAsync(long idActividad, string idUsuarioResponsable, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Actividad_Validar_Desbloqueada");
        Add(command, "@IdActividad", SqlDbType.BigInt, idActividad);
        Add(command, "@IdUsuarioResponsable", SqlDbType.VarChar, idUsuarioResponsable, 50);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<IReadOnlySet<long>> ObtenerAccesosBloqueadosAsync(IReadOnlyCollection<long> idsSolicitudPersonaArea, CancellationToken cancellationToken)
    {
        if (idsSolicitudPersonaArea.Count == 0) return new HashSet<long>();
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Actividad_Accesos_Bloqueados");
        Add(command, "@IdsJson", SqlDbType.NVarChar, JsonSerializer.Serialize(idsSolicitudPersonaArea.Distinct()), -1);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var bloqueados = new HashSet<long>();
        while (await reader.ReadAsync(cancellationToken)) bloqueados.Add(GetInt64Value(reader, 0));
        return bloqueados;
    }

    public async Task<IReadOnlySet<string>> ObtenerAreasQrBloqueadasAsync(long idPersona, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Actividad_Areas_Qr_Bloqueadas");
        Add(command, "@IdPersona", SqlDbType.BigInt, idPersona);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var bloqueadas = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        while (await reader.ReadAsync(cancellationToken))
            bloqueadas.Add(AreaKey(reader.GetInt32(0), GetNullableString(reader, 1)));
        return bloqueadas;
    }

    public static string AreaKey(int idArea, string? numeroSolicitud) => $"{idArea}|{numeroSolicitud?.Trim()}";

    private async Task<SqlConnection> OpenConnectionAsync(CancellationToken cancellationToken)
    {
        var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }

    private static SqlCommand StoredProcedure(SqlConnection connection, string name) =>
        new(name, connection) { CommandType = CommandType.StoredProcedure };

    private static void Add(SqlCommand command, string name, SqlDbType type, object? value, int? size = null)
    {
        var parameter = size.HasValue ? command.Parameters.Add(name, type, size.Value) : command.Parameters.Add(name, type);
        parameter.Value = value ?? DBNull.Value;
    }

    private static void ValidarFlujo(GuardarActividadFlujoRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Nombre))
            throw new InvalidOperationException("El nombre del flujo es obligatorio.");
        if (request.Pasos.Any(paso => string.IsNullOrWhiteSpace(paso.ClavePaso) || string.IsNullOrWhiteSpace(paso.NombreActividad)))
            throw new InvalidOperationException("Todas las actividades requieren una clave y un nombre.");
        if (request.Pasos.GroupBy(paso => paso.ClavePaso.Trim(), StringComparer.OrdinalIgnoreCase).Any(grupo => grupo.Count() > 1))
            throw new InvalidOperationException("Las claves de las actividades no pueden repetirse dentro del flujo.");
        if (request.Pasos.Any(paso => paso.IdAreaResponsable <= 0 || paso.VigenciaMeses is < 1 or > 1200))
            throw new InvalidOperationException("Cada actividad requiere un area responsable y una vigencia valida.");
        if (request.Pasos.Any(paso => paso.FechaInicio.HasValue && paso.FechaFin.HasValue && paso.FechaFin < paso.FechaInicio))
            throw new InvalidOperationException("La fecha final de una actividad no puede ser anterior a la inicial.");
        foreach (var paso in request.Pasos)
        {
            if (paso.RequiereTicketExterno)
            {
                if (paso.FreshserviceWorkspaceId is not > 0 || paso.FreshserviceServicioDisplayId is not > 0)
                    throw new InvalidOperationException("Cada actividad que requiere ticket debe indicar el workspace y el servicio de Freshservice.");
                if (!Uri.TryCreate(paso.FreshserviceUrlFormularioRespaldo, UriKind.Absolute, out var fallbackUri)
                    || fallbackUri.Scheme != Uri.UriSchemeHttps
                    || !fallbackUri.Host.EndsWith(".freshservice.com", StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("Cada actividad que requiere ticket debe indicar una URL HTTPS de respaldo de Freshservice.");
                var lookups = paso.FreshserviceLookups ?? [];
                if (lookups.Any(item => string.IsNullOrWhiteSpace(item.CampoApi)
                    || !OrigenesLookupFreshservice.Contains(item.Origen)))
                    throw new InvalidOperationException("La configuracion de lookups de Freshservice contiene un campo u origen no permitido.");
                if (lookups.GroupBy(item => item.CampoApi.Trim(), StringComparer.OrdinalIgnoreCase).Any(group => group.Count() > 1))
                    throw new InvalidOperationException("Un campo lookup de Freshservice no puede configurarse mas de una vez.");
            }
            if (paso.RequiereConsultaSingular && string.IsNullOrWhiteSpace(paso.SingularCapacitacionNombre))
                throw new InvalidOperationException("Cada actividad que consulta Singular debe indicar la capacitacion requerida.");
        }
        var tipos = (request.TiposIngreso ?? []).ToHashSet(StringComparer.OrdinalIgnoreCase);
        if (tipos.Count > 0 && (request.TiposIngresoAutomaticos ?? []).Any(tipo => !tipos.Contains(tipo)))
            throw new InvalidOperationException("Un tipo de ingreso automatico tambien debe estar habilitado para el flujo.");

        var claves = request.Pasos.Select(paso => paso.ClavePaso.Trim()).ToHashSet(StringComparer.OrdinalIgnoreCase);
        if (request.Pasos.Any(paso => (paso.Dependencias ?? []).Any(dependencia =>
            !claves.Contains(dependencia.Trim()) || dependencia.Trim().Equals(paso.ClavePaso.Trim(), StringComparison.OrdinalIgnoreCase))))
            throw new InvalidOperationException("Una dependencia no existe o apunta a la misma actividad.");
        if (request.Pasos.Any(paso => (paso.DependenciasExternas ?? []).Any(dependencia =>
            dependencia.IdActividadFlujo <= 0 || string.IsNullOrWhiteSpace(dependencia.ClavePaso))))
            throw new InvalidOperationException("Una dependencia externa no identifica un flujo y una actividad validos.");
    }

    private static string? GetNullableString(SqlDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);

    private static int? GetNullableInt32(SqlDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? null : reader.GetInt32(ordinal);

    private static long GetInt64Value(SqlDataReader reader, int ordinal) =>
        Convert.ToInt64(reader.GetValue(ordinal));

    private static long? GetNullableInt64(SqlDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? null : Convert.ToInt64(reader.GetValue(ordinal));

    private static DateOnly? GetNullableDateOnly(SqlDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? null : DateOnly.FromDateTime(reader.GetDateTime(ordinal));

    private static IReadOnlyCollection<string> SplitStrings(string? value) =>
        string.IsNullOrWhiteSpace(value) ? [] : value.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    private static IReadOnlyCollection<long> SplitLongs(string? value) =>
        SplitStrings(value).Select(item => long.TryParse(item, out var id) ? id : 0).Where(id => id > 0).ToArray();

    private static IReadOnlyCollection<ActividadFreshserviceLookupConfiguracion> ParseFreshserviceLookups(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return [];
        try
        {
            return JsonSerializer.Deserialize<IReadOnlyCollection<ActividadFreshserviceLookupConfiguracion>>(
                value,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }

    private sealed record FlujoBuilder(
        long IdFlujo,
        long IdVersion,
        int NumeroVersion,
        int IdArea,
        string? Codigo,
        string? Nombre,
        string? Descripcion,
        bool EsVersionActual,
        IReadOnlyCollection<string> TiposIngreso,
        List<string> TiposIngresoAutomaticos,
        List<ActividadFlujoPaso> Pasos);
}
