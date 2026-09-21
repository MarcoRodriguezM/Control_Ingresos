using System.Data;
using System.Text.Json;
using Control_Ingresos.Models;
using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Data;

public sealed class SolicitudesRepository(IConfiguration configuration) : ISolicitudesRepository
{
    private readonly string _connectionString = configuration.GetConnectionString("ControlIngresos")
        ?? throw new InvalidOperationException("No se configuró ConnectionStrings:ControlIngresos.");

    public async Task<SesionUsuario?> AutenticarAsync(
        LoginRequest request,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Usuario_Autenticar");

        Add(command, "@Usuario", SqlDbType.VarChar, request.Usuario.Trim(), 254);
        Add(command, "@Contrasena", SqlDbType.VarChar, request.Contrasena, 200);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
            return null;

        return new(
            reader.GetString(0),
            GetNullableString(reader, 1),
            GetNullableString(reader, 2),
            GetNullableString(reader, 3),
            GetNullable<int>(reader, 4),
            GetNullableString(reader, 5),
            reader.GetBoolean(6),
            reader.GetBoolean(7));
    }

    public async Task<PerfilUsuario?> ObtenerPerfilAsync(string idUsuario, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Usuario_Perfil_Obtener");
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;

        var perfil = new PerfilUsuario(
            reader.GetString(0),
            GetNullableString(reader, 1),
            GetNullableString(reader, 2),
            GetNullableString(reader, 3),
            GetNullableString(reader, 4),
            reader.GetBoolean(5),
            reader.GetBoolean(6),
            [],
            []);

        var areas = new List<AreaUsuarioPerfil>();
        if (await reader.NextResultAsync(cancellationToken))
            while (await reader.ReadAsync(cancellationToken))
                areas.Add(new(reader.GetInt32(0), GetNullableString(reader, 1), reader.GetBoolean(2), reader.GetBoolean(3), reader.GetBoolean(4), reader.GetBoolean(5)));

        var solicitudes = new List<SolicitudResumen>();
        if (await reader.NextResultAsync(cancellationToken))
            while (await reader.ReadAsync(cancellationToken))
                solicitudes.Add(new(reader.GetInt64(0), GetNullableString(reader, 1), GetNullableString(reader, 2), GetNullableString(reader, 3), GetNullableDateOnly(reader, 4), GetNullableDateOnly(reader, 5), GetNullableString(reader, 6), GetNullableString(reader, 7), reader.GetInt32(8)));

        return perfil with { Areas = areas, Solicitudes = solicitudes };
    }

    public async Task<IReadOnlyCollection<CatalogoItem>> ListarCatalogoAsync(
        string catalogo,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Catalogo_Listar");

        command.Parameters.Add("@Catalogo", SqlDbType.VarChar, 50).Value = catalogo;

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var items = new List<CatalogoItem>();

        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new(
                reader.GetInt32(0),
                GetNullableString(reader, 1),
                GetNullableString(reader, 2),
                GetNullableString(reader, 3)));
        }

        return items;
    }

    public async Task<SolicitudFormularioDatos> ObtenerDatosFormularioSolicitudAsync(
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Formulario_Datos");
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var tiposIngreso = await ReadOptionsAsync<short>(reader, cancellationToken);

        await reader.NextResultAsync(cancellationToken);
        var estadosSolicitud = await ReadOptionsAsync<short>(reader, cancellationToken);

        await reader.NextResultAsync(cancellationToken);
        var areas = await ReadOptionsAsync<int>(reader, cancellationToken);

        await reader.NextResultAsync(cancellationToken);
        var ubicaciones = await ReadOptionsAsync<int>(reader, cancellationToken);

        await reader.NextResultAsync(cancellationToken);
        var proveedores = await ReadOptionsAsync<long>(reader, cancellationToken);

        await reader.NextResultAsync(cancellationToken);
        var usuarios = await ReadOptionsAsync<string>(reader, cancellationToken);

        return new(
            tiposIngreso,
            estadosSolicitud,
            areas,
            ubicaciones,
            proveedores,
            usuarios);
    }

    public async Task<long> CrearProveedorAsync(
        CrearProveedorRequest request,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Proveedor_Crear");

        Add(command, "@Codigo", SqlDbType.VarChar, request.Codigo, 30);
        Add(command, "@NombreLegal", SqlDbType.NVarChar, request.NombreLegal, 200);
        Add(command, "@NombreComercial", SqlDbType.NVarChar, request.NombreComercial, 200);
        Add(command, "@RTN", SqlDbType.VarChar, request.Rtn, 30);
        Add(command, "@ContactoPrincipal", SqlDbType.NVarChar, request.ContactoPrincipal, 200);
        Add(command, "@CorreoPrincipal", SqlDbType.VarChar, request.CorreoPrincipal, 254);
        Add(command, "@TelefonoPrincipal", SqlDbType.VarChar, request.TelefonoPrincipal, 30);
        Add(command, "@IdEstadoGeneral", SqlDbType.SmallInt, request.IdEstadoGeneral);
        Add(command, "@Usuario", SqlDbType.VarChar, request.Usuario, 50);

        return Convert.ToInt64(
            await command.ExecuteScalarAsync(cancellationToken));
    }

    public async Task<long> CrearPersonaAsync(
        CrearPersonaRequest request,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Persona_Crear");

        Add(command, "@IdTipoDocumento", SqlDbType.SmallInt, request.IdTipoDocumento);
        Add(command, "@NumeroDocumento", SqlDbType.VarChar, request.NumeroDocumento, 60);
        Add(command, "@NombreCompleto", SqlDbType.NVarChar, request.NombreCompleto, 200);
        Add(command, "@FotografiaUrl", SqlDbType.NVarChar, request.FotografiaUrl, 500);
        Add(command, "@Telefono", SqlDbType.VarChar, request.Telefono, 30);
        Add(command, "@Correo", SqlDbType.VarChar, request.Correo, 254);
        Add(command, "@CargoFuncion", SqlDbType.NVarChar, request.CargoFuncion, 150);
        Add(command, "@IdProveedor", SqlDbType.BigInt, request.IdProveedor);
        Add(command, "@EmpresaTexto", SqlDbType.NVarChar, request.EmpresaTexto, 200);
        Add(command, "@InformacionAdicional", SqlDbType.NVarChar, request.InformacionAdicional, 1000);
        Add(command, "@IdEstadoGeneral", SqlDbType.SmallInt, request.IdEstadoGeneral);
        Add(command, "@Usuario", SqlDbType.VarChar, request.Usuario, 50);

        return Convert.ToInt64(
            await command.ExecuteScalarAsync(cancellationToken));
    }

    public async Task<IReadOnlyCollection<PersonaResumen>> ListarPersonasAsync(
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Persona_Listar");
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var items = new List<PersonaResumen>();

        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new(
                reader.GetInt64(0),
                GetNullableString(reader, 1),
                GetNullableString(reader, 2),
                GetNullableString(reader, 3),
                GetNullableString(reader, 4),
                GetNullableString(reader, 5),
                reader.GetInt32(6)));
        }

        return items;
    }

    public async Task<PersonaConAccesos?> ObtenerPersonaAccesosAsync(
        long idPersona,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Persona_Accesos_Obtener");

        Add(command, "@IdPersona", SqlDbType.BigInt, idPersona);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
            return null;

        var persona = new PersonaConAccesos(
            reader.GetInt64(0),
            GetNullableString(reader, 1),
            GetNullableString(reader, 2),
            GetNullableString(reader, 3),
            GetNullableString(reader, 4),
            GetNullableString(reader, 5),
            GetNullableString(reader, 6),
            GetNullableString(reader, 7),
            GetNullableString(reader, 8),
            []);

        var accesos = new List<PersonaAccesoDetalle>();

        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                accesos.Add(new(
                    reader.GetInt64(0),
                    GetNullable<long>(reader, 1),
                    GetNullableString(reader, 2),
                    GetNullableString(reader, 3),
                    GetNullable<int>(reader, 4),
                    GetNullableString(reader, 5),
                    GetNullableString(reader, 6),
                    GetNullableDateOnly(reader, 7),
                    GetNullableDateOnly(reader, 8),
                    GetNullable<bool>(reader, 9),
                    GetNullableString(reader, 10),
                    GetNullableString(reader, 11),
                    GetNullable<DateTime>(reader, 12),
                    GetNullableString(reader, 13)));
            }
        }

        return persona with { Accesos = accesos };
    }

    public async Task<IReadOnlyCollection<AprobacionResumen>> ListarAprobacionesAsync(
        string idUsuarioAprobador,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Aprobacion_Area_Listar");

        Add(command, "@IdUsuarioAprobador", SqlDbType.VarChar, idUsuarioAprobador, 50);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var items = new List<AprobacionResumen>();

        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new(
                reader.GetInt64(0),
                GetNullable<long>(reader, 1),
                GetNullableString(reader, 2),
                GetNullable<long>(reader, 3),
                GetNullableString(reader, 4),
                GetNullableString(reader, 5),
                GetNullableString(reader, 6),
                GetNullable<int>(reader, 7),
                GetNullableString(reader, 8),
                GetNullableString(reader, 9),
                GetNullableString(reader, 10),
                GetNullableDateOnly(reader, 11),
                GetNullableDateOnly(reader, 12),
                GetNullable<DateTime>(reader, 13),
                GetNullable<short>(reader, 14),
                GetNullableString(reader, 15),
                GetNullableString(reader, 16),
                GetNullable<DateTime>(reader, 17),
                GetNullableString(reader, 18)));
        }

        return items;
    }

    public async Task<long> DecidirAprobacionAsync(long idSolicitudPersonaArea, string idUsuarioAprobador, DecidirAprobacionRequest request, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Aprobacion_Area_Decidir");

        Add(command, "@IdSolicitudPersonaArea", SqlDbType.BigInt, idSolicitudPersonaArea);
        Add(command, "@IdUsuarioAprobador", SqlDbType.VarChar, idUsuarioAprobador, 50);
        Add(command, "@CodigoEstado", SqlDbType.VarChar, request.CodigoEstado, 30);
        Add(command, "@ComentarioDecision", SqlDbType.NVarChar, request.ComentarioDecision, 1000);

        return Convert.ToInt64(
            await command.ExecuteScalarAsync(cancellationToken));
    }

    public async Task<IdCreadoResponse> CrearSolicitudAsync(
        CrearSolicitudRequest request,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Ingreso_Crear");

        Add(command, "@IdTipoIngreso", SqlDbType.SmallInt, request.IdTipoIngreso);
        Add(command, "@IdEstadoSolicitud", SqlDbType.SmallInt, request.IdEstadoSolicitud);
        Add(command, "@FechaInicio", SqlDbType.Date, request.FechaInicio);
        Add(command, "@FechaFin", SqlDbType.Date, request.FechaFin);
        Add(command, "@NombreActividad", SqlDbType.NVarChar, request.NombreActividad, 200);
        Add(command, "@DescripcionActividad", SqlDbType.NVarChar, request.DescripcionActividad, 1000);
        Add(command, "@IdProveedor", SqlDbType.BigInt, request.IdProveedor);
        Add(command, "@NumeroContrato", SqlDbType.VarChar, request.NumeroContrato, 60);
        Add(command, "@ContactoProveedor", SqlDbType.NVarChar, request.ContactoProveedor, 200);
        Add(command, "@CorreoProveedor", SqlDbType.VarChar, request.CorreoProveedor, 254);
        Add(command, "@CantidadEstimada", SqlDbType.Int, request.CantidadEstimada);
        Add(command, "@IdAreaSolicitante", SqlDbType.Int, request.IdAreaSolicitante);
        Add(command, "@IdUsuarioSolicitante", SqlDbType.VarChar, request.IdUsuarioSolicitante, 50);
        Add(command, "@IdUbicacion", SqlDbType.Int, request.IdUbicacion);
        Add(command, "@Observaciones", SqlDbType.NVarChar, request.Observaciones, 1000);
        Add(command, "@Usuario", SqlDbType.VarChar, request.Usuario, 50);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        await reader.ReadAsync(cancellationToken);

        return new(
            reader.GetInt64(0),
            reader.GetString(1));
    }

    public async Task<bool> ActualizarSolicitudAsync(
        long idSolicitud,
        CrearSolicitudRequest request,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Ingreso_Actualizar");

        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        AddSolicitudParameters(command, request);

        return Convert.ToInt32(
            await command.ExecuteScalarAsync(cancellationToken)) > 0;
    }

    public async Task<bool> EliminarSolicitudAsync(
        long idSolicitud,
        string usuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Ingreso_Eliminar");

        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        Add(command, "@Usuario", SqlDbType.VarChar, usuario, 50);

        return Convert.ToInt32(
            await command.ExecuteScalarAsync(cancellationToken)) > 0;
    }

    public async Task<long> AgregarPersonaAsync(
        long idSolicitud,
        AgregarPersonaSolicitudRequest request,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Persona_Agregar");

        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        Add(command, "@IdPersona", SqlDbType.BigInt, request.IdPersona);
        Add(command, "@IdEstadoPersonaSolicitud", SqlDbType.SmallInt, request.IdEstadoPersonaSolicitud);
        Add(command, "@DatosCompletos", SqlDbType.Bit, request.DatosCompletos);
        Add(command, "@ObservacionesRevision", SqlDbType.NVarChar, request.ObservacionesRevision, 1000);

        Add(
            command,
            "@AreasJson",
            SqlDbType.NVarChar,
            request.Areas is null ? null : JsonSerializer.Serialize(request.Areas),
            -1);

        Add(
            command,
            "@RequerimientosJson",
            SqlDbType.NVarChar,
            request.Requerimientos is null ? null : JsonSerializer.Serialize(request.Requerimientos),
            -1);

        Add(command, "@Usuario", SqlDbType.VarChar, request.Usuario, 50);

        return Convert.ToInt64(
            await command.ExecuteScalarAsync(cancellationToken));
    }

    public async Task ReenviarAprobacionAsync(long idSolicitudPersonaArea, string idUsuarioSolicitante, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Persona_Area_ReenviarAprobacion");
        Add(command, "@IdSolicitudPersonaArea", SqlDbType.BigInt, idSolicitudPersonaArea);
        Add(command, "@IdUsuarioSolicitante", SqlDbType.VarChar, idUsuarioSolicitante, 50);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<IReadOnlyCollection<SolicitudResumen>> ListarSolicitudesAsync(CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Ingreso_Listar");
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var items = new List<SolicitudResumen>();

        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new(
                reader.GetInt64(0),
                GetNullableString(reader, 1),
                GetNullableString(reader, 2),
                GetNullableString(reader, 3),
                GetNullableDateOnly(reader, 4),
                GetNullableDateOnly(reader, 5),
                GetNullableString(reader, 6),
                GetNullableString(reader, 7),
                reader.GetInt32(8)));
        }

        return items;
    }

    public async Task<IReadOnlyCollection<ActividadResumen>> ListarMisActividadesAsync(string idUsuarioResponsable, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Actividad_Mis_Listar");
        Add(command, "@IdUsuarioResponsable", SqlDbType.VarChar, idUsuarioResponsable, 50);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var items = new List<ActividadResumen>();
        while (await reader.ReadAsync(cancellationToken))
            items.Add(new(
                reader.GetInt64(0),
                GetNullable<long>(reader, 1),
                GetNullableString(reader, 2),
                GetNullableString(reader, 3),
                GetNullableString(reader, 4),
                GetNullableString(reader, 5),
                GetNullableString(reader, 6),
                reader.GetBoolean(7),
                GetNullable<DateTime>(reader, 8),
                GetNullable<DateTime>(reader, 9),
                GetNullable<DateTime>(reader, 10),
                GetNullableString(reader, 11),
                reader.GetBoolean(12)));
        return items;
    }

    public async Task<SolicitudDetalle?> ObtenerSolicitudAsync(
        long idSolicitud,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Ingreso_Obtener");

        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
            return null;

        var solicitud = new SolicitudDetalle(
            reader.GetInt64(0),
            GetNullableString(reader, 1),
            GetNullable<short>(reader, 2),
            GetNullable<short>(reader, 3),
            GetNullableDateOnly(reader, 4),
            GetNullableDateOnly(reader, 5),
            GetNullableString(reader, 6),
            GetNullableString(reader, 7),
            GetNullable<long>(reader, 8),
            GetNullableString(reader, 9),
            GetNullableString(reader, 10),
            GetNullableString(reader, 11),
            GetNullable<int>(reader, 12),
            GetNullable<int>(reader, 13),
            GetNullableString(reader, 14),
            GetNullable<int>(reader, 15),
            GetNullableString(reader, 16),
            GetNullable<DateTime>(reader, 17),
            []);

        var personas = new List<PersonaSolicitudDetalle>();

        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                personas.Add(new(
                    reader.GetInt64(0),
                    GetNullable<long>(reader, 1),
                    GetNullableString(reader, 2),
                    GetNullableString(reader, 3),
                    GetNullable<short>(reader, 4),
                    GetNullable<bool>(reader, 5)));
            }
        }

        return solicitud with { Personas = personas };
    }

    private async Task<SqlConnection> OpenConnectionAsync(
        CancellationToken cancellationToken)
    {
        var connection = new SqlConnection(_connectionString);

        await connection.OpenAsync(cancellationToken);

        return connection;
    }

    private static SqlCommand StoredProcedure(
        SqlConnection connection,
        string name) =>
        new(name, connection)
        {
            CommandType = CommandType.StoredProcedure
        };

    private static void AddSolicitudParameters(
        SqlCommand command,
        CrearSolicitudRequest request)
    {
        Add(command, "@IdTipoIngreso", SqlDbType.SmallInt, request.IdTipoIngreso);
        Add(command, "@IdEstadoSolicitud", SqlDbType.SmallInt, request.IdEstadoSolicitud);
        Add(command, "@FechaInicio", SqlDbType.Date, request.FechaInicio);
        Add(command, "@FechaFin", SqlDbType.Date, request.FechaFin);
        Add(command, "@NombreActividad", SqlDbType.NVarChar, request.NombreActividad, 200);
        Add(command, "@DescripcionActividad", SqlDbType.NVarChar, request.DescripcionActividad, 1000);
        Add(command, "@IdProveedor", SqlDbType.BigInt, request.IdProveedor);
        Add(command, "@NumeroContrato", SqlDbType.VarChar, request.NumeroContrato, 60);
        Add(command, "@ContactoProveedor", SqlDbType.NVarChar, request.ContactoProveedor, 200);
        Add(command, "@CorreoProveedor", SqlDbType.VarChar, request.CorreoProveedor, 254);
        Add(command, "@CantidadEstimada", SqlDbType.Int, request.CantidadEstimada);
        Add(command, "@IdAreaSolicitante", SqlDbType.Int, request.IdAreaSolicitante);
        Add(command, "@IdUsuarioSolicitante", SqlDbType.VarChar, request.IdUsuarioSolicitante, 50);
        Add(command, "@IdUbicacion", SqlDbType.Int, request.IdUbicacion);
        Add(command, "@Observaciones", SqlDbType.NVarChar, request.Observaciones, 1000);
        Add(command, "@Usuario", SqlDbType.VarChar, request.Usuario, 50);
    }

    private static void Add(
        SqlCommand command,
        string name,
        SqlDbType type,
        object? value,
        int? size = null)
    {
        var parameter = size.HasValue
            ? command.Parameters.Add(name, type, size.Value)
            : command.Parameters.Add(name, type);

        parameter.Value = value switch
        {
            null => DBNull.Value,
            DateOnly date => date.ToDateTime(TimeOnly.MinValue),
            _ => value
        };
    }

    private static string? GetNullableString(
        SqlDataReader reader,
        int ordinal) =>
        reader.IsDBNull(ordinal)
            ? null
            : reader.GetString(ordinal);

    private static T? GetNullable<T>(
        SqlDataReader reader,
        int ordinal) where T : struct =>
        reader.IsDBNull(ordinal)
            ? null
            : reader.GetFieldValue<T>(ordinal);

    private static DateOnly? GetNullableDateOnly(
        SqlDataReader reader,
        int ordinal) =>
        reader.IsDBNull(ordinal)
            ? null
            : DateOnly.FromDateTime(reader.GetDateTime(ordinal));

    private static async Task<IReadOnlyCollection<OpcionFormulario<T>>> ReadOptionsAsync<T>(
        SqlDataReader reader,
        CancellationToken cancellationToken)
    {
        var items = new List<OpcionFormulario<T>>();

        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new(
                reader.GetFieldValue<T>(0),
                GetNullableString(reader, 1),
                GetNullableString(reader, 2)));
        }

        return items;
    }
}
