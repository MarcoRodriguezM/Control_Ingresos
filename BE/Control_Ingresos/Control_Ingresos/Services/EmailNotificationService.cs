using System.Data;
using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Services;

public sealed class EmailNotificationService(
    IConfiguration configuration,
    ICredentialEmailSender emailSender,
    ILogger<EmailNotificationService> logger)
{
    private string AppUrl =>
        (configuration["Frontend:BaseUrl"] ?? "http://localhost:5173").TrimEnd('/');

    public Task NotificarSolicitudEnviadaAsync(long idSolicitud) => ExecuteSafelyAsync(
        async (connection, token) =>
        {
            var solicitud = await ReadRequestAsync(connection, idSolicitud, token);
            if (solicitud is null) return;
            if (solicitud.Estado == "PENDIENTE_PROVEEDOR"
                && !string.IsNullOrWhiteSpace(solicitud.CorreoProveedor))
            {
                await emailSender.EnviarNotificacionAsync(
                    solicitud.CorreoProveedor,
                    $"Solicitud de ingreso {solicitud.Numero}",
                    $"""
                        Hola {solicitud.NombreProveedor ?? "proveedor"},

                        Se ha realizado una solicitud de ingreso para su empresa: {solicitud.Numero}

                        Solicitante: {solicitud.NombreSolicitante ?? "No indicado"}
                        Correo del solicitante: {solicitud.CorreoSolicitante ?? "No indicado"}
                        Actividad: {solicitud.Actividad}
                        Descripcion: {solicitud.Descripcion ?? "No indicada"}
                        Fecha ingreso: {solicitud.FechaInicio?.ToString("dd-MM-yyyy") ?? "No indicada"}
                        Personas a ingresar: {solicitud.CantidadEstimada?.ToString() ?? "No indicada"}

                        Ingrese al portal y registre las personas que participaran.
                        """,
                    token,
                    $"{AppUrl}/portal-proveedor/solicitudes/{idSolicitud}",
                    "Registrar personas");
            }
            else if (solicitud.Estado == "PENDIENTE_APROBACIONES")
            {
                await NotifyApproversAsync(connection, solicitud, null, token);
            }
        });

    public Task NotificarAreasAsignadasAsync(long idSolicitud) =>
        ExecuteSafelyAsync(async (connection, token) =>
        {
            var solicitud = await ReadRequestAsync(connection, idSolicitud, token);
            if (solicitud?.Estado == "PENDIENTE_APROBACIONES")
                await NotifyApproversAsync(connection, solicitud, null, token);
        });

    public Task NotificarAprobacionReenviadaAsync(long idSolicitudPersonaArea) =>
        ExecuteSafelyAsync(async (connection, token) =>
        {
            await using var lookup = new SqlCommand("""
                SELECT sp.IdSolicitud
                FROM dbo.Solicitud_Persona_Area AS spa
                INNER JOIN dbo.Solicitud_Persona AS sp
                    ON sp.IdSolicitudPersona = spa.IdSolicitudPersona
                WHERE spa.IdSolicitudPersonaArea = @IdAcceso;
                """, connection);
            lookup.Parameters.Add("@IdAcceso", SqlDbType.BigInt).Value = idSolicitudPersonaArea;
            var value = await lookup.ExecuteScalarAsync(token);
            if (value is null) return;
            var solicitud = await ReadRequestAsync(connection, Convert.ToInt64(value), token);
            if (solicitud?.Estado == "PENDIENTE_APROBACIONES")
                await NotifyApproversAsync(connection, solicitud, null, token, idSolicitudPersonaArea);
        });

    public Task NotificarTicketRegistradoAsync(long idActividad) => ExecuteSafelyAsync(
        async (connection, token) =>
        {
            await using var lookup = new SqlCommand("""
                SELECT IdSolicitud FROM dbo.Actividad WHERE IdActividad = @IdActividad;
                """, connection);
            lookup.Parameters.Add("@IdActividad", SqlDbType.BigInt).Value = idActividad;
            var value = await lookup.ExecuteScalarAsync(token);
            if (value is null) return;
            var solicitud = await ReadRequestAsync(connection, Convert.ToInt64(value), token);
            if (solicitud?.Estado == "PENDIENTE_APROBACIONES")
                await NotifyApproversAsync(connection, solicitud, null, token);
        });

    public Task NotificarProveedorFinalizoAsync(long idSolicitud) => ExecuteSafelyAsync(
        async (connection, token) =>
        {
            var solicitud = await ReadRequestAsync(connection, idSolicitud, token);
            if (solicitud?.Estado != "CONFIGURACION_ACCESOS"
                || string.IsNullOrWhiteSpace(solicitud.CorreoSolicitante)) return;

            await emailSender.EnviarNotificacionAsync(
                solicitud.CorreoSolicitante,
                $"Personas registradas - {solicitud.Numero}",
                $"""
                    Hola {solicitud.NombreSolicitante ?? "solicitante"},

                    El proveedor registro las personas de la solicitud {solicitud.Numero}.
                    Ya puedes asignarles areas y actividades para continuar el proceso.

                    """,
                token,
                $"{AppUrl}/solicitudes/{idSolicitud}",
                "Ver solicitud");
        });

    public Task NotificarDecisionAsync(long idSolicitudPersonaArea, string codigoEstado) =>
        ExecuteSafelyAsync(async (connection, token) =>
        {
            await using var lookup = new SqlCommand("""
                SELECT sp.IdSolicitud, area.Nombre,
                       COALESCE(persona.NombreCompleto, N'empleado'),
                       solicitante.Correo
                FROM dbo.Solicitud_Persona_Area AS spa
                INNER JOIN dbo.Solicitud_Persona AS sp ON sp.IdSolicitudPersona = spa.IdSolicitudPersona
                INNER JOIN dbo.Solicitud_Ingreso AS solicitud ON solicitud.IdSolicitud = sp.IdSolicitud
                INNER JOIN dbo.Cat_Area AS area ON area.IdArea = spa.IdArea
                LEFT JOIN dbo.Persona AS persona ON persona.IdPersona = sp.IdPersona
                LEFT JOIN dbo.Usuario AS solicitante ON solicitante.IdUsuario = solicitud.IdUsuarioSolicitante
                WHERE spa.IdSolicitudPersonaArea = @IdAcceso;
                """, connection);
            lookup.Parameters.Add("@IdAcceso", SqlDbType.BigInt).Value = idSolicitudPersonaArea;
            await using var reader = await lookup.ExecuteReaderAsync(token);
            if (!await reader.ReadAsync(token)) return;
            var idSolicitud = reader.GetInt64(0);
            var area = reader.IsDBNull(1) ? "area" : reader.GetString(1);
            var persona = reader.IsDBNull(2) ? "la persona" : reader.GetString(2);
            var destinatario = reader.IsDBNull(3) ? null : reader.GetString(3);
            await reader.CloseAsync();
            if (string.IsNullOrWhiteSpace(destinatario)) return;
            var solicitud = await ReadRequestAsync(connection, idSolicitud, token);
            var decision = codigoEstado == "APROBADA" ? "aprobado" : "rechazado";
            await emailSender.EnviarNotificacionAsync(destinatario,
                $"Acceso {decision} - {solicitud?.Numero ?? idSolicitud.ToString()}",
                $"""
                    El acceso de {persona} al area {area} fue {decision}.

                    Consulta el seguimiento de la solicitud.
                    """,
                token,
                $"{AppUrl}/solicitudes/{idSolicitud}",
                "Ver seguimiento");
        });

    private async Task NotifyApproversAsync(
        SqlConnection connection, RequestInfo solicitud,
        long? idSolicitudPersona, CancellationToken token,
        long? idSolicitudPersonaArea = null)
    {
        await using var command = new SqlCommand("""
            SELECT DISTINCT usuario.IdUsuario, usuario.Correo, usuario.NombreCompleto, area.Nombre
            FROM dbo.Solicitud_Persona AS persona
            INNER JOIN dbo.Solicitud_Persona_Area AS acceso
                ON acceso.IdSolicitudPersona = persona.IdSolicitudPersona
            INNER JOIN dbo.Cat_Estado_Aprobacion_Area AS estado
                ON estado.IdEstadoAprobacion = acceso.IdEstadoAprobacion AND estado.Codigo = 'PENDIENTE'
            INNER JOIN dbo.Cat_Area AS area ON area.IdArea = acceso.IdArea
            INNER JOIN dbo.Config_Aprobador_Area AS asignacion
                ON asignacion.IdArea = area.IdArea
                AND ISNULL(asignacion.IdEstadoGeneral, 1) = 1
                AND (asignacion.FechaInicio IS NULL OR asignacion.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                AND (asignacion.FechaFin IS NULL OR asignacion.FechaFin >= CONVERT(DATE, SYSDATETIME()))
            INNER JOIN dbo.Usuario AS usuario
                ON usuario.IdUsuario = asignacion.IdUsuarioAprobador
                AND ISNULL(usuario.IdEstadoGeneral, 1) = 1
            WHERE persona.IdSolicitud = @IdSolicitud
              AND acceso.RequiereAprobacion = 1
              AND (@IdSolicitudPersona IS NULL OR persona.IdSolicitudPersona = @IdSolicitudPersona)
              AND (@IdAcceso IS NULL OR acceso.IdSolicitudPersonaArea = @IdAcceso)
              AND NULLIF(LTRIM(RTRIM(usuario.Correo)), '') IS NOT NULL;
            """, connection);
        command.Parameters.Add("@IdSolicitud", SqlDbType.BigInt).Value = solicitud.Id;
        command.Parameters.Add("@IdSolicitudPersona", SqlDbType.BigInt).Value =
            (object?)idSolicitudPersona ?? DBNull.Value;
        command.Parameters.Add("@IdAcceso", SqlDbType.BigInt).Value =
            (object?)idSolicitudPersonaArea ?? DBNull.Value;

        var recipients = new Dictionary<string, ApprovalRecipient>(StringComparer.OrdinalIgnoreCase);
        await using (var reader = await command.ExecuteReaderAsync(token))
        {
            while (await reader.ReadAsync(token))
            {
                var idUsuario = reader.GetString(0);
                if (!recipients.TryGetValue(idUsuario, out var recipient))
                {
                    recipient = new ApprovalRecipient(reader.GetString(1),
                        reader.IsDBNull(2) ? idUsuario : reader.GetString(2));
                    recipients.Add(idUsuario, recipient);
                }
                recipient.Areas.Add(reader.GetString(3));
            }
        }

        foreach (var recipient in recipients.Values)
        {
            var areas = string.Join(", ", recipient.Areas.OrderBy(area => area));
            await emailSender.EnviarNotificacionAsync(recipient.Email,
                $"Aprobacion de acceso pendiente - {solicitud.Numero}",
                $"""
                    Hola {recipient.Nombre},

                    Tienes una solicitud de acceso asignada: {solicitud.Numero}.
                    Actividad: {solicitud.Actividad}.
                    Areas por revisar: {areas}.

                    """,
                token,
                $"{AppUrl}/aprobaciones",
                "Revisar aprobaciones");
        }
    }

    private static async Task<RequestInfo?> ReadRequestAsync(
        SqlConnection connection, long idSolicitud, CancellationToken token)
    {
        await using var command = new SqlCommand("""
            SELECT solicitud.IdSolicitud, solicitud.NumeroSolicitud, solicitud.NombreActividad,
                   estado.Codigo,
                   COALESCE(NULLIF(proveedor.CorreoPrincipal, ''), NULLIF(solicitud.CorreoProveedor, '')),
                   proveedor.NombreLegal,
                   solicitante.Correo, solicitante.NombreCompleto,
                   solicitud.DescripcionActividad, solicitud.FechaInicio, solicitud.CantidadEstimada
            FROM dbo.Solicitud_Ingreso AS solicitud
            LEFT JOIN dbo.Cat_Estado_Solicitud AS estado
                ON estado.IdEstadoSolicitud = solicitud.IdEstadoSolicitud
            LEFT JOIN dbo.Proveedor AS proveedor ON proveedor.IdProveedor = solicitud.IdProveedor
            LEFT JOIN dbo.Usuario AS solicitante ON solicitante.IdUsuario = solicitud.IdUsuarioSolicitante
            WHERE solicitud.IdSolicitud = @IdSolicitud;
            """, connection);
        command.Parameters.Add("@IdSolicitud", SqlDbType.BigInt).Value = idSolicitud;
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return null;
        return new RequestInfo(reader.GetInt64(0),
            reader.IsDBNull(1) ? $"Solicitud #{idSolicitud}" : reader.GetString(1),
            reader.IsDBNull(2) ? "Sin actividad" : reader.GetString(2),
            reader.IsDBNull(3) ? "" : reader.GetString(3),
            reader.IsDBNull(4) ? null : reader.GetString(4),
            reader.IsDBNull(5) ? null : reader.GetString(5),
            reader.IsDBNull(6) ? null : reader.GetString(6),
            reader.IsDBNull(7) ? null : reader.GetString(7),
            reader.IsDBNull(8) ? null : reader.GetString(8),
            reader.IsDBNull(9) ? null : DateOnly.FromDateTime(reader.GetDateTime(9)),
            reader.IsDBNull(10) ? null : reader.GetInt32(10));
    }

    private async Task ExecuteSafelyAsync(Func<SqlConnection, CancellationToken, Task> action)
    {
        if (configuration.GetValue<bool?>("Email:Enabled") == false) return;
        var connectionString = configuration.GetConnectionString("ControlIngresos");
        if (string.IsNullOrWhiteSpace(connectionString)) return;
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(30));
        try
        {
            await using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync(timeout.Token);
            await action(connection, timeout.Token);
        }
        catch (Exception exception)
        {
            logger.LogWarning(exception, "No se pudo completar una notificacion por correo.");
        }
    }

    private sealed record RequestInfo(
        long Id, string Numero, string Actividad, string Estado,
        string? CorreoProveedor, string? NombreProveedor,
        string? CorreoSolicitante, string? NombreSolicitante,
        string? Descripcion, DateOnly? FechaInicio, int? CantidadEstimada);

    private sealed class ApprovalRecipient(string email, string nombre)
    {
        public string Email { get; } = email;
        public string Nombre { get; } = nombre;
        public HashSet<string> Areas { get; } = new(StringComparer.OrdinalIgnoreCase);
    }
}
