using System.Data;
using System.Text.Json;
using Control_Ingresos.Models;
using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Data;

public sealed class SolicitudesRepository(
    IConfiguration configuration,
    IActivityWorkflowRepository activityWorkflows) : ISolicitudesRepository
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
            reader.GetBoolean(7),
            (GetNullableString(reader, 8) ?? string.Empty)
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
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

    public async Task<IReadOnlyCollection<UsuarioAdministracionResumen>> ListarUsuariosAsync(CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Usuario_Administracion_Listar");
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var items = new List<UsuarioAdministracionResumen>();
        while (await reader.ReadAsync(cancellationToken))
            items.Add(new(
                reader.GetString(0),
                GetNullableString(reader, 1),
                GetNullableString(reader, 2),
                GetNullableString(reader, 3),
                GetNullableString(reader, 4),
                GetNullable<int>(reader, 5),
                GetNullableString(reader, 6),
                reader.GetBoolean(7),
                reader.GetBoolean(8),
                reader.GetBoolean(9),
                GetNullable<DateTime>(reader, 10),
                GetNullableString(reader, 11)));
        return items;
    }

    public async Task<UsuarioAdministracionDetalle?> ObtenerUsuarioAsync(
        string idUsuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Usuario_Administracion_Obtener");
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken)) return null;

        var usuario = new UsuarioAdministracionDetalle(
            reader.GetString(0),
            GetNullableString(reader, 1),
            GetNullableString(reader, 2),
            GetNullableString(reader, 3),
            GetNullableString(reader, 4),
            GetNullableString(reader, 5),
            reader.GetBoolean(6),
            GetNullable<DateTime>(reader, 7),
            GetNullableString(reader, 8),
            GetNullable<DateTime>(reader, 9),
            GetNullableString(reader, 10),
            GetNullableString(reader, 11),
            []);

        var areas = new List<AreaUsuarioAdministracion>();
        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                areas.Add(new(
                    reader.GetInt32(0),
                    GetNullableString(reader, 1),
                    GetNullableString(reader, 2),
                    reader.GetBoolean(3),
                    reader.GetBoolean(4),
                    reader.GetBoolean(5),
                    reader.GetBoolean(6),
                    GetNullableDateOnly(reader, 7),
                    GetNullableDateOnly(reader, 8),
                    reader.GetBoolean(9)));
            }
        }

        return usuario with { Areas = areas };
    }

    public async Task<string> CrearUsuarioAsync(CrearUsuarioRequest request, string usuarioCreacion, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Usuario_Crear", transaction);
        Add(command, "@IdUsuario", SqlDbType.VarChar, request.IdUsuario, 50);
        Add(command, "@NombreCompleto", SqlDbType.NVarChar, request.NombreCompleto, 200);
        Add(command, "@Correo", SqlDbType.VarChar, request.Correo, 254);
        Add(command, "@Telefono", SqlDbType.VarChar, request.Telefono, 30);
        Add(command, "@Puesto", SqlDbType.NVarChar, request.Puesto, 150);
        Add(command, "@Contrasena", SqlDbType.VarChar, request.Contrasena, 200);
        Add(command, "@IdArea", SqlDbType.Int, request.IdArea);
        Add(command, "@PuedeSolicitar", SqlDbType.Bit, request.PuedeSolicitar);
        Add(command, "@EsAprobador", SqlDbType.Bit, request.EsAprobador);
        Add(command, "@Activo", SqlDbType.Bit, request.Activo);
        Add(command, "@UsuarioCreacion", SqlDbType.VarChar, usuarioCreacion, 50);
        try
        {
            var idUsuario = Convert.ToString(await command.ExecuteScalarAsync(cancellationToken))
                ?? throw new InvalidOperationException("No se recibió el identificador del usuario creado.");
            if (request.EsSeguridad)
            {
                await using var roleCommand = StoredProcedure(connection, "dbo.usp_Usuario_Rol_Asignar", transaction);
                Add(roleCommand, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
                Add(roleCommand, "@CodigoRol", SqlDbType.VarChar, "SEGURIDAD", 30);
                Add(roleCommand, "@UsuarioAsignacion", SqlDbType.VarChar, usuarioCreacion, 50);
                await roleCommand.ExecuteNonQueryAsync(cancellationToken);
            }

            if (request.EsGuardia)
            {
                await using var roleCommand = StoredProcedure(connection, "dbo.usp_Usuario_Rol_Asignar", transaction);
                Add(roleCommand, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
                Add(roleCommand, "@CodigoRol", SqlDbType.VarChar, "GUARDIA", 30);
                Add(roleCommand, "@UsuarioAsignacion", SqlDbType.VarChar, usuarioCreacion, 50);
                await roleCommand.ExecuteNonQueryAsync(cancellationToken);
            }

            if (request.EsProveedor)
            {
                await using var roleCommand = StoredProcedure(connection, "dbo.usp_Usuario_Rol_Asignar", transaction);
                Add(roleCommand, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
                Add(roleCommand, "@CodigoRol", SqlDbType.VarChar, "PROVEEDOR", 30);
                Add(roleCommand, "@UsuarioAsignacion", SqlDbType.VarChar, usuarioCreacion, 50);
                await roleCommand.ExecuteNonQueryAsync(cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
            return idUsuario;
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    public async Task<bool> ActualizarUsuarioAsync(
        string idUsuario,
        ActualizarUsuarioRequest request,
        string usuarioModificacion,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Usuario_Actualizar");
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
        Add(command, "@NombreCompleto", SqlDbType.NVarChar, request.NombreCompleto, 200);
        Add(command, "@Correo", SqlDbType.VarChar, request.Correo, 254);
        Add(command, "@Telefono", SqlDbType.VarChar, request.Telefono, 30);
        Add(command, "@Puesto", SqlDbType.NVarChar, request.Puesto, 150);
        Add(command, "@IdArea", SqlDbType.Int, request.IdArea);
        Add(command, "@PuedeSolicitar", SqlDbType.Bit, request.PuedeSolicitar);
        Add(command, "@EsAprobador", SqlDbType.Bit, request.EsAprobador);
        Add(command, "@EsSeguridad", SqlDbType.Bit, request.EsSeguridad);
        Add(command, "@EsGuardia", SqlDbType.Bit, request.EsGuardia);
        Add(command, "@EsProveedor", SqlDbType.Bit, request.EsProveedor);
        Add(command, "@Activo", SqlDbType.Bit, request.Activo);
        Add(command, "@UsuarioModificacion", SqlDbType.VarChar, usuarioModificacion, 50);
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken)) > 0;
    }

    public async Task<ProveedorUsuario?> ObtenerProveedorUsuarioAsync(
        string idUsuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Proveedor_Usuario_Obtener");
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken)
            ? new(reader.GetInt64(0), GetNullableString(reader, 1), GetNullableString(reader, 2))
            : null;
    }

    public async Task<IReadOnlyCollection<SolicitudProveedorResumen>> ListarSolicitudesProveedorAsync(
        string idUsuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Proveedor_Solicitud_Listar");
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var items = new List<SolicitudProveedorResumen>();
        while (await reader.ReadAsync(cancellationToken))
            items.Add(new(
                reader.GetInt64(0), GetNullableString(reader, 1), GetNullableString(reader, 2),
                GetNullableString(reader, 3), GetNullableString(reader, 4), GetNullableDateOnly(reader, 5),
                GetNullableDateOnly(reader, 6), GetNullableString(reader, 7), GetNullableString(reader, 8),
                GetNullableString(reader, 9), reader.GetInt32(10), reader.GetInt32(11)));
        return items;
    }

    public async Task<SolicitudProveedorDetalle?> ObtenerSolicitudProveedorAsync(
        long idSolicitud,
        string idUsuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Proveedor_Solicitud_Obtener");
        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;

        var detail = new SolicitudProveedorDetalle(
            reader.GetInt64(0), GetNullableString(reader, 1), GetNullableString(reader, 2),
            GetNullableString(reader, 3), GetNullableString(reader, 4), GetNullableDateOnly(reader, 5),
            GetNullableDateOnly(reader, 6), GetNullableString(reader, 7), GetNullableString(reader, 8),
            GetNullableString(reader, 9), GetNullableString(reader, 10), GetNullableString(reader, 11),
            GetNullableString(reader, 12), GetNullableString(reader, 13), reader.GetInt32(14),
            reader.GetInt32(15), GetNullableString(reader, 16), []);

        var people = new List<PersonaSolicitudDetalle>();
        if (await reader.NextResultAsync(cancellationToken))
            while (await reader.ReadAsync(cancellationToken))
                people.Add(new(
                    reader.GetInt64(0), GetNullable<long>(reader, 1), GetNullableString(reader, 2),
                    GetNullableString(reader, 3), GetNullable<short>(reader, 4), GetNullable<bool>(reader, 5),
                    GetNullableString(reader, 6), GetNullableString(reader, 7), reader.GetInt32(8),
                    reader.GetInt32(9), reader.GetInt32(10), GetNullableString(reader, 11),
                    null, ParseIntList(GetNullableString(reader, 12))));
        return detail with { Personas = people };
    }

    public async Task<IReadOnlyCollection<PersonaResumen>> ListarPersonasProveedorAsync(
        string idUsuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Proveedor_Persona_Listar");
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var items = new List<PersonaResumen>();
        while (await reader.ReadAsync(cancellationToken))
            items.Add(new(
                reader.GetInt64(0), GetNullableString(reader, 1), GetNullableString(reader, 2),
                GetNullableString(reader, 3), GetNullableString(reader, 4), GetNullableString(reader, 5),
                reader.GetInt32(6)));
        return items;
    }

    public async Task<long> AgregarPersonaProveedorAsync(
        long idSolicitud,
        string idUsuario,
        AgregarPersonaSolicitudRequest request,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Proveedor_Solicitud_Persona_Agregar");
        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
        Add(command, "@IdPersona", SqlDbType.BigInt, request.IdPersona);
        Add(command, "@IdEstadoPersonaSolicitud", SqlDbType.SmallInt, request.IdEstadoPersonaSolicitud);
        Add(command, "@DatosCompletos", SqlDbType.Bit, request.DatosCompletos);
        Add(command, "@ObservacionesRevision", SqlDbType.NVarChar, request.ObservacionesRevision, 1000);
        Add(command, "@AreasJson", SqlDbType.NVarChar, request.Areas is null ? null : JsonSerializer.Serialize(request.Areas), -1);
        Add(command, "@RequerimientosJson", SqlDbType.NVarChar, request.Requerimientos is null ? null : JsonSerializer.Serialize(request.Requerimientos), -1);
        var idSolicitudPersona = Convert.ToInt64(await command.ExecuteScalarAsync(cancellationToken));
        await activityWorkflows.SincronizarActividadesAsync(
            idSolicitud,
            idSolicitudPersona,
            request.Flujos ?? [],
            idUsuario,
            cancellationToken);
        await SyncTicketStateAsync(idSolicitud, idUsuario, cancellationToken);
        return idSolicitudPersona;
    }

    public async Task<bool> EliminarPersonaProveedorAsync(
        long idSolicitud,
        long idSolicitudPersona,
        string idUsuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Proveedor_Solicitud_Persona_Eliminar");
        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        Add(command, "@IdSolicitudPersona", SqlDbType.BigInt, idSolicitudPersona);
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken)) > 0;
    }

    public async Task EnviarSolicitudProveedorAsync(
        long idSolicitud,
        string idUsuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Proveedor_Solicitud_Enviar");
        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task AsignarAreasPersonaAsync(
        long idSolicitud,
        long idSolicitudPersona,
        IReadOnlyCollection<int> areas,
        IReadOnlyCollection<RequerimientoSolicitudRequest>? requerimientos,
        IReadOnlyCollection<long>? flujos,
        string usuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Persona_Areas_Asignar");
        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        Add(command, "@IdSolicitudPersona", SqlDbType.BigInt, idSolicitudPersona);
        Add(command, "@AreasJson", SqlDbType.NVarChar, JsonSerializer.Serialize(areas), -1);
        Add(command, "@RequerimientosJson", SqlDbType.NVarChar,
            JsonSerializer.Serialize(requerimientos ?? []), -1);
        Add(command, "@Usuario", SqlDbType.VarChar, usuario, 50);
        await command.ExecuteNonQueryAsync(cancellationToken);

        await activityWorkflows.SincronizarActividadesAsync(
            idSolicitud,
            idSolicitudPersona,
            flujos ?? [],
            usuario,
            cancellationToken);
        await SyncTicketStateAsync(idSolicitud, usuario, cancellationToken);
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
        var proveedores = new List<ProveedorFormularioOpcion>();
        while (await reader.ReadAsync(cancellationToken))
            proveedores.Add(new(
                reader.GetInt64(0),
                GetNullableString(reader, 1),
                GetNullableString(reader, 2),
                GetNullableString(reader, 3),
                GetNullableString(reader, 4)));

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

    public async Task<ProveedorUsuarioCreado> CrearProveedorAsync(
        CrearProveedorRequest request,
        string contrasenaTemporal,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Proveedor_Usuario_Crear");

        Add(command, "@Codigo", SqlDbType.VarChar, request.Codigo, 30);
        Add(command, "@NombreLegal", SqlDbType.NVarChar, request.NombreLegal, 200);
        Add(command, "@NombreComercial", SqlDbType.NVarChar, request.NombreComercial, 200);
        Add(command, "@RTN", SqlDbType.VarChar, request.Rtn, 30);
        Add(command, "@ContactoPrincipal", SqlDbType.NVarChar, request.ContactoPrincipal, 200);
        Add(command, "@CorreoPrincipal", SqlDbType.VarChar, request.CorreoPrincipal, 254);
        Add(command, "@TelefonoPrincipal", SqlDbType.VarChar, request.TelefonoPrincipal, 30);
        Add(command, "@IdEstadoGeneral", SqlDbType.SmallInt, request.IdEstadoGeneral);
        Add(command, "@ContrasenaTemporal", SqlDbType.VarChar, contrasenaTemporal, 200);
        Add(command, "@UsuarioCreacion", SqlDbType.VarChar, request.Usuario, 50);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
            throw new InvalidOperationException("No se recibió la cuenta creada para el proveedor.");

        return new ProveedorUsuarioCreado(reader.GetInt64(0), reader.GetString(1));
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

    public async Task<bool> ActualizarFotografiaPersonaAsync(
        long idPersona,
        string fotografiaUrl,
        string usuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Persona_Fotografia_Actualizar");
        Add(command, "@IdPersona", SqlDbType.BigInt, idPersona);
        Add(command, "@FotografiaUrl", SqlDbType.NVarChar, fotografiaUrl, 500);
        Add(command, "@Usuario", SqlDbType.VarChar, usuario, 50);
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken)) > 0;
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

    public async Task<IReadOnlyCollection<PersonaResumen>> ListarPersonasConAccesosAsync(
        string idUsuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Persona_Accesos_Listar");
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
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
        string idUsuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Persona_Accesos_Obtener");

        Add(command, "@IdPersona", SqlDbType.BigInt, idPersona);
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);

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

        var bloqueados = await activityWorkflows.ObtenerAccesosBloqueadosAsync(
            accesos.Select(acceso => acceso.IdSolicitudPersonaArea).ToArray(),
            cancellationToken);

        var accesosActualizados = accesos
            .Select(acceso => bloqueados.Contains(acceso.IdSolicitudPersonaArea)
                ? acceso with
                {
                    EstadoAcceso = "Actividades pendientes",
                    CodigoEstadoAcceso = "ACTIVIDADES_PENDIENTES"
                }
                : acceso)
            .ToArray();

        return persona with { Accesos = accesosActualizados };
    }

    public async Task<string?> ObtenerCodigoQrPersonaAsync(
        long idPersona,
        string idUsuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Persona_Qr_Obtener");

        Add(command, "@IdPersona", SqlDbType.BigInt, idPersona);
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);

        var result = await command.ExecuteScalarAsync(cancellationToken);
        return result is null or DBNull ? null : Convert.ToString(result);
    }

    public async Task<PersonaQrDetalle?> ConsultarPersonaQrAsync(
        string codigoQr,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Persona_Qr_Consultar");
        Add(command, "@CodigoQr", SqlDbType.VarChar, codigoQr.Trim().ToLowerInvariant(), 64);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;

        var persona = new PersonaQrDetalle(
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

        var areas = new List<AreaAccesoQr>();
        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                areas.Add(new(
                    reader.GetInt32(0),
                    GetNullableString(reader, 1),
                    GetNullableString(reader, 2),
                    GetNullableString(reader, 3),
                    GetNullableString(reader, 4),
                    reader.GetBoolean(5),
                    GetNullableString(reader, 6),
                    GetNullableString(reader, 7),
                    GetNullableString(reader, 8),
                    GetNullableDateOnly(reader, 9),
                    GetNullableDateOnly(reader, 10),
                    GetNullableString(reader, 11)));
            }
        }

        var bloqueadas = await activityWorkflows.ObtenerAreasQrBloqueadasAsync(persona.IdPersona, cancellationToken);
        var areasActualizadas = areas
            .Select(area => bloqueadas.Contains(ActivityWorkflowRepository.AreaKey(area.IdArea, area.NumeroSolicitud))
                ? area with
                {
                    CodigoAcceso = "ACTIVIDADES_PENDIENTES",
                    EstadoAcceso = "Actividades pendientes",
                    TieneAcceso = false
                }
                : area)
            .ToArray();

        return persona with { Areas = areasActualizadas };
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
                GetNullableString(reader, 18),
                GetNullableString(reader, 19),
                false));
        }

        await reader.DisposeAsync();

        var pendingTicketRequests = (await ListarSolicitudesAsync(idUsuarioAprobador, true, cancellationToken))
            .Where(item => item.TicketsPendientes > 0)
            .Select(item => item.IdSolicitud)
            .ToHashSet();
        var visibleItems = items.Where(item => item.CodigoEstado != "PENDIENTE"
            || !item.IdSolicitud.HasValue
            || !pendingTicketRequests.Contains(item.IdSolicitud.Value)).ToArray();
        var bloqueados = await activityWorkflows.ObtenerAccesosBloqueadosAsync(
            visibleItems.Where(item => string.Equals(item.CodigoEstado, "PENDIENTE", StringComparison.OrdinalIgnoreCase))
                .Select(item => item.IdSolicitudPersonaArea)
                .ToArray(),
            cancellationToken);
        return visibleItems.Select(item => bloqueados.Contains(item.IdSolicitudPersonaArea)
            ? item with { ActividadesPendientes = true }
            : item).ToArray();
    }

    public async Task<long> DecidirAprobacionAsync(long idSolicitudPersonaArea, string idUsuarioAprobador, DecidirAprobacionRequest request, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using (var ticketLookup = StoredProcedure(connection, "dbo.usp_Solicitud_Persona_Area_Solicitud_Obtener"))
        {
            Add(ticketLookup, "@IdSolicitudPersonaArea", SqlDbType.BigInt, idSolicitudPersonaArea);
            Add(ticketLookup, "@UsuarioSolicitante", SqlDbType.VarChar, null, 50);
            var ticketRequestId = await ticketLookup.ExecuteScalarAsync(cancellationToken);
            if (ticketRequestId is not null)
            {
                var hasPendingTickets = (await ListarSolicitudesAsync(idUsuarioAprobador, true, cancellationToken))
                    .Any(item => item.IdSolicitud == Convert.ToInt64(ticketRequestId) && item.TicketsPendientes > 0);
                if (hasPendingTickets)
                    throw new InvalidOperationException("Primero se deben crear los tickets pendientes de la solicitud.");
            }
        }
        if (string.Equals(request.CodigoEstado, "APROBADA", StringComparison.OrdinalIgnoreCase))
        {
            var bloqueados = await activityWorkflows.ObtenerAccesosBloqueadosAsync(
                [idSolicitudPersonaArea],
                cancellationToken);
            if (bloqueados.Contains(idSolicitudPersonaArea))
                throw new InvalidOperationException("No se puede aprobar el acceso al area porque la persona todavia tiene actividades pendientes.");
        }

        await using var command = StoredProcedure(connection, "dbo.usp_Aprobacion_Area_Decidir");

        Add(command, "@IdSolicitudPersonaArea", SqlDbType.BigInt, idSolicitudPersonaArea);
        Add(command, "@IdUsuarioAprobador", SqlDbType.VarChar, idUsuarioAprobador, 50);
        Add(command, "@CodigoEstado", SqlDbType.VarChar, request.CodigoEstado, 30);
        Add(command, "@ComentarioDecision", SqlDbType.NVarChar, request.ComentarioDecision, 1000);

        var idAprobacion = Convert.ToInt64(
            await command.ExecuteScalarAsync(cancellationToken));

        await using var recalculate = StoredProcedure(connection, "dbo.usp_Solicitud_Estado_Recalcular");
        Add(recalculate, "@IdSolicitudPersonaArea", SqlDbType.BigInt, idSolicitudPersonaArea);
        Add(recalculate, "@IdUsuario", SqlDbType.VarChar, idUsuarioAprobador, 50);
        await recalculate.ExecuteNonQueryAsync(cancellationToken);
        await using var lookup = StoredProcedure(connection, "dbo.usp_Solicitud_Persona_Area_Solicitud_Obtener");
        Add(lookup, "@IdSolicitudPersonaArea", SqlDbType.BigInt, idSolicitudPersonaArea);
        Add(lookup, "@UsuarioSolicitante", SqlDbType.VarChar, null, 50);
        var requestId = await lookup.ExecuteScalarAsync(cancellationToken);
        if (requestId is not null) await SyncTicketStateAsync(Convert.ToInt64(requestId), idUsuarioAprobador, cancellationToken);
        return idAprobacion;
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

    public async Task<IdCreadoResponse> CrearSolicitudCompletaAsync(
        CrearSolicitudCompletaRequest request,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);

        try
        {
            var solicitud = request.Solicitud;
            await using var createCommand = StoredProcedure(connection, "dbo.usp_Solicitud_Ingreso_Crear", transaction);
            AddSolicitudParameters(createCommand, solicitud);

            IdCreadoResponse created;
            await using (var reader = await createCommand.ExecuteReaderAsync(cancellationToken))
            {
                await reader.ReadAsync(cancellationToken);
                created = new(reader.GetInt64(0), reader.GetString(1));
            }

            var integrantesCreados = new List<(long IdSolicitudPersona, AgregarPersonaSolicitudRequest Persona)>();
            foreach (var person in request.Personas ?? [])
            {
                await using var personCommand = StoredProcedure(connection, "dbo.usp_Solicitud_Integrante_Agregar", transaction);
                AddPersonaSolicitudParameters(personCommand, created.Id, person);
                var idSolicitudPersona = Convert.ToInt64(await personCommand.ExecuteScalarAsync(cancellationToken));
                integrantesCreados.Add((idSolicitudPersona, person));
            }

            await transaction.CommitAsync(cancellationToken);

            foreach (var integrante in integrantesCreados)
            {
                await activityWorkflows.SincronizarActividadesAsync(
                    created.Id,
                    integrante.IdSolicitudPersona,
                    integrante.Persona.Flujos ?? [],
                    integrante.Persona.Usuario,
                    cancellationToken);
            }

            return created;
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
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
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Integrante_Agregar");

        AddPersonaSolicitudParameters(command, idSolicitud, request);

        var idSolicitudPersona = Convert.ToInt64(
            await command.ExecuteScalarAsync(cancellationToken));

        await activityWorkflows.SincronizarActividadesAsync(
            idSolicitud,
            idSolicitudPersona,
            request.Flujos ?? [],
            request.Usuario,
            cancellationToken);
        await SyncTicketStateAsync(idSolicitud, request.Usuario, cancellationToken);

        return idSolicitudPersona;
    }

    public async Task<long> AgregarEmpleadoAsync(
        long idSolicitud,
        Empleado empleado,
        AgregarEmpleadoSolicitudRequest request,
        string usuario,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Empleado_Agregar");

        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        Add(command, "@CodigoEmpleado", SqlDbType.VarChar, request.CodigoEmpleado.Trim(), 50);
        Add(command, "@NombreCompleto", SqlDbType.NVarChar, empleado.NombreCompleto, 200);
        Add(command, "@Correo", SqlDbType.VarChar, empleado.Correo, 254);
        Add(command, "@CargoFuncion", SqlDbType.NVarChar, empleado.CargoNivel, 150);
        Add(command, "@AreasJson", SqlDbType.NVarChar, JsonSerializer.Serialize(request.Areas), -1);
        Add(command, "@Usuario", SqlDbType.VarChar, usuario, 50);

        var idSolicitudPersona = Convert.ToInt64(await command.ExecuteScalarAsync(cancellationToken));
        await activityWorkflows.SincronizarActividadesAsync(
            idSolicitud,
            idSolicitudPersona,
            request.Flujos ?? [],
            usuario,
            cancellationToken);
        await SyncTicketStateAsync(idSolicitud, usuario, cancellationToken);
        return idSolicitudPersona;
    }

    public async Task<IReadOnlyCollection<EmpleadoAccesoActual>> ListarAccesosEmpleadoAsync(
        string codigoEmpleado,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Empleado_Accesos_Listar");
        Add(command, "@CodigoEmpleado", SqlDbType.VarChar, codigoEmpleado.Trim(), 50);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var items = new List<EmpleadoAccesoActual>();
        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new EmpleadoAccesoActual(
                reader.GetInt32(0),
                GetNullableString(reader, 1),
                GetNullableString(reader, 2),
                GetNullableDateOnly(reader, 3),
                GetNullableDateOnly(reader, 4)));
        }

        return items;
    }

    public async Task ReenviarAprobacionAsync(long idSolicitudPersonaArea, string idUsuarioSolicitante, string justificacion, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);
        long idSolicitud;
        try
        {
            long idPersona;
            await using (var lookup = StoredProcedure(connection, "dbo.usp_Solicitud_Persona_Area_Solicitud_Obtener", transaction))
            {
                Add(lookup, "@IdSolicitudPersonaArea", SqlDbType.BigInt, idSolicitudPersonaArea);
                Add(lookup, "@UsuarioSolicitante", SqlDbType.VarChar, idUsuarioSolicitante, 50);
                await using var reader = await lookup.ExecuteReaderAsync(cancellationToken);
                if (!await reader.ReadAsync(cancellationToken))
                    throw new InvalidOperationException("La aprobacion no pertenece a tu solicitud.");
                idSolicitud = reader.GetInt64(0);
                idPersona = reader.GetInt64(1);
            }
            await using (var command = StoredProcedure(connection, "dbo.usp_Solicitud_Persona_Area_ReenviarAprobacion", transaction))
            {
                Add(command, "@IdSolicitudPersonaArea", SqlDbType.BigInt, idSolicitudPersonaArea);
                Add(command, "@IdUsuarioSolicitante", SqlDbType.VarChar, idUsuarioSolicitante, 50);
                await command.ExecuteNonQueryAsync(cancellationToken);
            }
            await using (var history = StoredProcedure(connection, "dbo.usp_Historial_Solicitud_Reenvio_Agregar", transaction))
            {
                Add(history, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
                Add(history, "@IdSolicitudPersona", SqlDbType.BigInt, idPersona);
                Add(history, "@IdSolicitudPersonaArea", SqlDbType.BigInt, idSolicitudPersonaArea);
                Add(history, "@Justificacion", SqlDbType.NVarChar, justificacion, 1000);
                Add(history, "@Usuario", SqlDbType.VarChar, idUsuarioSolicitante, 50);
                await history.ExecuteNonQueryAsync(cancellationToken);
            }
            await transaction.CommitAsync(cancellationToken);
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
        await SyncTicketStateAsync(idSolicitud, idUsuarioSolicitante, cancellationToken);
    }

    public async Task EnviarSolicitudAsync(long idSolicitud, string idUsuario, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Enviar");
        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
        await command.ExecuteNonQueryAsync(cancellationToken);
        await SyncTicketStateAsync(idSolicitud, idUsuario, cancellationToken);
    }

    public async Task<IReadOnlyCollection<RegistroIngresoResumen>> ListarRegistrosIngresoAsync(CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Registro_Ingreso_Listar");
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var items = new List<RegistroIngresoResumen>();
        while (await reader.ReadAsync(cancellationToken))
            items.Add(new(
                reader.GetInt64(0), reader.GetInt64(1), GetNullableString(reader, 2),
                GetNullableString(reader, 3), reader.GetInt64(4), GetNullableString(reader, 5),
                GetNullableString(reader, 6), reader.GetString(7), reader.GetDateTime(8),
                GetNullableString(reader, 9), GetNullableString(reader, 10), GetNullableString(reader, 11)));
        return items;
    }

    public async Task<long> RegistrarIngresoAsync(RegistrarIngresoRequest request, string idUsuarioSeguridad, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Registro_Ingreso_Registrar");
        Add(command, "@IdPersona", SqlDbType.BigInt, request.IdPersona);
        Add(command, "@TipoMovimiento", SqlDbType.VarChar, request.TipoMovimiento, 10);
        Add(command, "@IdUsuarioSeguridad", SqlDbType.VarChar, idUsuarioSeguridad, 50);
        Add(command, "@Observaciones", SqlDbType.NVarChar, request.Observaciones, 500);
        return Convert.ToInt64(await command.ExecuteScalarAsync(cancellationToken));
    }

    public async Task<IReadOnlyCollection<SolicitudResumen>> ListarSolicitudesAsync(string idUsuario, bool accesoTotal, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Ingreso_Listar");
        Add(command, "@IdUsuario", SqlDbType.VarChar, idUsuario, 50);
        Add(command, "@AccesoTotal", SqlDbType.Bit, accesoTotal);
        var items = new List<SolicitudResumen>();
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
        {
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
        }
        if (items.Count == 0) return items;
        await using var stateCommand = StoredProcedure(connection, "dbo.usp_Solicitud_Listado_Estados_Obtener");
        Add(stateCommand, "@Usuario", SqlDbType.VarChar, idUsuario, 50);
        Add(stateCommand, "@Ids", SqlDbType.VarChar, string.Join(',', items.Select(item => item.IdSolicitud)), -1);
        var states = new Dictionary<long, (bool Own, int Pending, string? Code, bool Rejected, bool PendingApproval, bool HasConfiguration)>();
        await using (var reader = await stateCommand.ExecuteReaderAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
                states[reader.GetInt64(0)] = (reader.GetBoolean(1), reader.GetInt32(2),
                    GetNullableString(reader, 3), reader.GetBoolean(4), reader.GetBoolean(5), reader.GetBoolean(6));
        }
        return items.Select(item =>
        {
            if (!states.TryGetValue(item.IdSolicitud, out var state)) return item;
            var pending = state.Code is "BORRADOR" or "PENDIENTE_PROVEEDOR" or "FINALIZADA" or "CANCELADA"
                ? 0 : state.Pending;
            var effective = EffectiveRequestStatus(state.Code, item.Estado, pending, state.Rejected, state.PendingApproval, state.HasConfiguration);
            return item with { EsPropia = state.Own, TicketsPendientes = pending, Estado = effective.Name };
        }).ToArray();
    }

    private static (string Code, string Name) EffectiveRequestStatus(
        string? code, string? name, int pendingTickets, bool rejected, bool pendingApproval, bool hasConfiguration)
    {
        if (code is "BORRADOR" or "PENDIENTE_PROVEEDOR" or "FINALIZADA" or "CANCELADA")
            return (code, name ?? code);
        if (!hasConfiguration) return ("CONFIGURACION_ACCESOS", "Pendiente de asignar areas o flujos");
        if (pendingTickets > 0) return ("PENDIENTE_CREACION_TICKET", "Pendiente de creacion de ticket");
        if (rejected) return ("EN_REVISION", "En revision");
        if (pendingApproval) return ("PENDIENTE_APROBACIONES", "Pendiente de aprobaciones de area");
        if (code is "PENDIENTE_CREACION_TICKET" or "PENDIENTE_APROBACIONES" or "EN_REVISION")
            return ("LISTA_INGRESO", "Listo para ingresar");
        return (code ?? "", name ?? "Sin estado");
    }

    private async Task SyncTicketStateAsync(long idSolicitud, string usuario, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
        try
        {
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Estado_Ticket_Sincronizar", transaction);
            Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
            Add(command, "@Usuario", SqlDbType.VarChar, usuario, 50);
            await command.ExecuteNonQueryAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    public async Task<SeguimientoSolicitud?> ObtenerSeguimientoSolicitudAsync(
        long idSolicitud, string idUsuario, bool accesoTotal, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        var solicitud = await ObtenerSolicitudAsync(idSolicitud, cancellationToken);
        if (solicitud is null) return null;
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Seguimiento_Obtener");
        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        Add(command, "@Usuario", SqlDbType.VarChar, idUsuario, 50);
        Add(command, "@AccesoTotal", SqlDbType.Bit, accesoTotal);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken) || !reader.GetBoolean(0)) return null;
        if (!await reader.NextResultAsync(cancellationToken)) return null;
        var areas = new List<SeguimientoArea>();
        while (await reader.ReadAsync(cancellationToken))
            areas.Add(new(reader.GetInt64(0), reader.GetInt64(1), GetNullableString(reader, 2),
                GetNullableString(reader, 3), GetNullableString(reader, 4), GetNullableString(reader, 5),
                GetNullableString(reader, 6), GetNullableString(reader, 7), GetNullable<DateTime>(reader, 8),
                GetNullableString(reader, 9)));
        var actividades = new List<SeguimientoActividad>();
        if (await reader.NextResultAsync(cancellationToken))
            while (await reader.ReadAsync(cancellationToken))
                actividades.Add(new(reader.GetInt64(0), GetNullable<long>(reader, 1), GetNullableString(reader, 2),
                    GetNullableString(reader, 3), GetNullableString(reader, 4), GetNullableString(reader, 5),
                    GetNullableString(reader, 6), reader.GetBoolean(7), GetNullableString(reader, 8),
                    GetNullable<DateTime>(reader, 9), GetNullableString(reader, 10),
                    GetNullableString(reader, 11), GetNullable<DateTime>(reader, 12), reader.GetBoolean(13),
                    reader.GetBoolean(14)));
        var decisiones = new List<SeguimientoDecision>();
        if (await reader.NextResultAsync(cancellationToken))
            while (await reader.ReadAsync(cancellationToken))
                decisiones.Add(new(reader.GetInt64(0), GetNullableString(reader, 1), GetNullableString(reader, 2),
                    GetNullableString(reader, 3), GetNullableString(reader, 4), GetNullable<DateTime>(reader, 5),
                    GetNullableString(reader, 6)));
        var reenvios = new List<SeguimientoReenvio>();
        if (await reader.NextResultAsync(cancellationToken))
            while (await reader.ReadAsync(cancellationToken))
                reenvios.Add(new(reader.GetInt64(0), GetNullableString(reader, 1), GetNullableString(reader, 2),
                    GetNullable<DateTime>(reader, 3)));

        await reader.DisposeAsync();
        var summary = (await ListarSolicitudesAsync(idUsuario, accesoTotal, cancellationToken))
            .FirstOrDefault(item => item.IdSolicitud == idSolicitud);
        var storedCode = await ObtenerCodigoEstadoSolicitudAsync(connection, idSolicitud, cancellationToken);
        var current = EffectiveRequestStatus(storedCode, summary?.Estado,
            summary?.TicketsPendientes ?? 0,
            areas.Any(area => area.CodigoEstado == "RECHAZADA"),
            areas.Any(area => area.CodigoEstado is not ("APROBADA" or "RECHAZADA")), areas.Count > 0);
        return new SeguimientoSolicitud(solicitud, current.Name, current.Code,
            summary?.TicketsPendientes ?? 0, areas, actividades, decisiones, reenvios);
    }

    private static async Task<string?> ObtenerCodigoEstadoSolicitudAsync(SqlConnection connection, long idSolicitud, CancellationToken cancellationToken)
    {
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Estado_Codigo_Obtener");
        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        return await command.ExecuteScalarAsync(cancellationToken) as string;
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
                reader.GetBoolean(12),
                reader.IsDBNull(18) ? null : new ActividadTicketResumen(
                    reader.GetInt64(18), GetNullableString(reader, 19), GetNullableString(reader, 20),
                    GetNullableString(reader, 21), GetNullable<DateTime>(reader, 22)),
                GetNullable<long>(reader, 13),
                GetNullableString(reader, 14),
                GetNullableString(reader, 15),
                GetNullable<int>(reader, 16),
                GetNullableString(reader, 17)));
        return items;
    }

    public async Task<IReadOnlyCollection<ActividadAdministracionResumen>> ListarActividadesAsync(CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Actividad_Administracion_Listar");
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var items = new List<ActividadAdministracionResumen>();
        while (await reader.ReadAsync(cancellationToken))
            items.Add(new(
                reader.GetInt64(0),
                GetNullable<long>(reader, 1),
                GetNullableString(reader, 2),
                GetNullableString(reader, 3),
                GetNullable<int>(reader, 4),
                GetNullableString(reader, 5),
                GetNullableString(reader, 6),
                GetNullableString(reader, 7),
                GetNullable<short>(reader, 8),
                GetNullableString(reader, 9),
                GetNullableString(reader, 10),
                reader.GetBoolean(11),
                GetNullable<DateTime>(reader, 12),
                GetNullable<DateTime>(reader, 13),
                GetNullable<DateTime>(reader, 14),
                GetNullableString(reader, 15),
                reader.GetBoolean(16),
                GetNullableString(reader, 17),
                GetNullable<DateTime>(reader, 18),
                GetNullableString(reader, 19),
                GetNullable<long>(reader, 20),
                GetNullableString(reader, 21),
                GetNullableString(reader, 22),
                GetNullable<int>(reader, 23),
                GetNullableString(reader, 24),
                reader.IsDBNull(25) ? null : new ActividadTicketResumen(reader.GetInt64(25),
                    GetNullableString(reader, 26), GetNullableString(reader, 27),
                    GetNullableString(reader, 28), GetNullable<DateTime>(reader, 29))));
        return items;
    }

    public async Task<long> CrearActividadAsync(CrearActividadRequest request, string usuario, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Actividad_Crear");
        Add(command, "@IdSolicitud", SqlDbType.BigInt, request.IdSolicitud);
        Add(command, "@IdAreaResponsable", SqlDbType.Int, request.IdAreaResponsable);
        Add(command, "@IdUsuarioResponsable", SqlDbType.VarChar, request.IdUsuarioResponsable, 50);
        Add(command, "@NombreActividad", SqlDbType.NVarChar, request.NombreActividad, 200);
        Add(command, "@FechaLimite", SqlDbType.DateTime2, request.FechaLimite);
        Add(command, "@Comentarios", SqlDbType.NVarChar, request.Comentarios, 1000);
        Add(command, "@RequiereTicketExterno", SqlDbType.Bit, request.RequiereTicketExterno);
        Add(command, "@Usuario", SqlDbType.VarChar, usuario, 50);
        return Convert.ToInt64(await command.ExecuteScalarAsync(cancellationToken));
    }

    public async Task<long> CompletarActividadAsync(long idActividad, string idUsuarioResponsable, CompletarActividadRequest request, CancellationToken cancellationToken)
    {
        await activityWorkflows.ValidarActividadDesbloqueadaAsync(
            idActividad,
            idUsuarioResponsable,
            cancellationToken);

        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Actividad_Completar");
        Add(command, "@IdActividad", SqlDbType.BigInt, idActividad);
        Add(command, "@IdUsuarioResponsable", SqlDbType.VarChar, idUsuarioResponsable, 50);
        Add(command, "@Comentarios", SqlDbType.NVarChar, request.Comentarios, 1000);
        return Convert.ToInt64(await command.ExecuteScalarAsync(cancellationToken));
    }

    public async Task<ActividadTicketResumen> CrearTicketActividadAsync(long idActividad, string idUsuarioSolicitante, CrearActividadTicketRequest request, CancellationToken cancellationToken)
    {
        var plataforma = request.Plataforma?.Trim();
        var numero = request.NumeroTicket?.Trim();
        var url = request.UrlTicket?.Trim();
        if (request.IdTicketExterno is null && (string.IsNullOrWhiteSpace(plataforma) || string.IsNullOrWhiteSpace(numero)))
            throw new InvalidOperationException("Indica la plataforma y el numero del ticket.");
        if (!string.IsNullOrEmpty(url) && (!Uri.TryCreate(url, UriKind.Absolute, out var parsed) || parsed.Scheme != Uri.UriSchemeHttps))
            throw new InvalidOperationException("El enlace del ticket debe ser una direccion HTTPS valida.");

        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
        ActividadTicketResumen ticket;
        long requestId;
        try
        {
            await using var command = StoredProcedure(connection, "dbo.usp_Actividad_Ticket_Guardar", transaction);
            Add(command, "@IdActividadPrincipal", SqlDbType.BigInt, idActividad);
            Add(command, "@IdTicketExterno", SqlDbType.BigInt, request.IdTicketExterno);
            Add(command, "@IdsActividadJson", SqlDbType.NVarChar, JsonSerializer.Serialize(request.IdsActividad ?? []), -1);
            Add(command, "@Usuario", SqlDbType.VarChar, idUsuarioSolicitante, 50);
            Add(command, "@Plataforma", SqlDbType.NVarChar, plataforma, 100);
            Add(command, "@NumeroTicket", SqlDbType.VarChar, numero, 80);
            Add(command, "@UrlTicket", SqlDbType.NVarChar, string.IsNullOrEmpty(url) ? null : url, 500);
            await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
            {
                if (!await reader.ReadAsync(cancellationToken)) throw new InvalidOperationException("No se pudo registrar el ticket.");
                ticket = new ActividadTicketResumen(reader.GetInt64(0), GetNullableString(reader, 1),
                    GetNullableString(reader, 2), GetNullableString(reader, 3), GetNullable<DateTime>(reader, 4));
                requestId = reader.GetInt64(5);
            }
            await transaction.CommitAsync(cancellationToken);
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
        await SyncTicketStateAsync(requestId, idUsuarioSolicitante, cancellationToken);
        return ticket;
    }

    public async Task<IReadOnlyCollection<TicketSolicitudResumen>> ListarTicketsSolicitudAsync(
        long idSolicitud, string idUsuarioSolicitante, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Solicitud_Tickets_Listar");
        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        Add(command, "@Usuario", SqlDbType.VarChar, idUsuarioSolicitante, 50);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var baseItems = new List<(long IdActividad, long IdSolicitud, DateTime? FechaFin,
            string? NumeroSolicitud, string? NombreActividad, string? Persona,
            string? AreaResponsable, bool EsEstadoFinal, long? IdSolicitudPersona)>();
        while (await reader.ReadAsync(cancellationToken))
            baseItems.Add((reader.GetInt64(0), reader.GetInt64(1),
                GetNullable<DateTime>(reader, 2), GetNullableString(reader, 3), GetNullableString(reader, 4),
                GetNullableString(reader, 5), GetNullableString(reader, 6), reader.GetBoolean(7),
                GetNullable<long>(reader, 8)));

        var tickets = new Dictionary<long, List<ActividadTicketResumen>>();
        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                var idActividad = reader.GetInt64(0);
                if (!tickets.TryGetValue(idActividad, out var activityTickets))
                {
                    activityTickets = [];
                    tickets[idActividad] = activityTickets;
                }
                activityTickets.Add(new ActividadTicketResumen(reader.GetInt64(1),
                    GetNullableString(reader, 2), GetNullableString(reader, 3),
                    GetNullableString(reader, 4), GetNullable<DateTime>(reader, 5)));
            }
        }

        return baseItems.Select(item =>
        {
            var activityTickets = tickets.TryGetValue(item.IdActividad, out var values)
                ? (IReadOnlyCollection<ActividadTicketResumen>)values
                : [];
            return new TicketSolicitudResumen(item.IdActividad, item.IdSolicitud, item.FechaFin,
                item.NumeroSolicitud, item.NombreActividad, item.Persona, item.AreaResponsable,
                item.EsEstadoFinal, activityTickets.LastOrDefault(), activityTickets,
                item.IdSolicitudPersona);
        }).ToArray();
    }

    public async Task<long> DecidirActividadAsync(long idActividad, string idUsuarioAprobador, DecidirActividadRequest request, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = StoredProcedure(connection, "dbo.usp_Actividad_Decidir");
        Add(command, "@IdActividad", SqlDbType.BigInt, idActividad);
        Add(command, "@IdUsuarioAprobador", SqlDbType.VarChar, idUsuarioAprobador, 50);
        Add(command, "@CodigoEstado", SqlDbType.VarChar, request.CodigoEstado, 30);
        Add(command, "@ComentarioDecision", SqlDbType.NVarChar, request.ComentarioDecision, 1000);
        return Convert.ToInt64(await command.ExecuteScalarAsync(cancellationToken));
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
                    GetNullable<bool>(reader, 5),
                    GetNullableString(reader, 6),
                    GetNullableString(reader, 7),
                    reader.GetInt32(8),
                    reader.GetInt32(9),
                    reader.GetInt32(10),
                    GetNullableString(reader, 11),
                    GetNullableString(reader, 12),
                    ParseIntList(GetNullableString(reader, 13)),
                    ParseIntList(GetNullableString(reader, 14))));

            }
        }

        await reader.CloseAsync();
        await using var flowCommand = StoredProcedure(connection, "dbo.usp_Solicitud_Flujos_Asignados_Listar");
        Add(flowCommand, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        await using var flowReader = await flowCommand.ExecuteReaderAsync(cancellationToken);
        var flujosPorPersona = new Dictionary<long, List<long>>();
        while (await flowReader.ReadAsync(cancellationToken))
        {
            var idSolicitudPersona = flowReader.GetInt64(0);
            if (!flujosPorPersona.TryGetValue(idSolicitudPersona, out var flujos))
            {
                flujos = [];
                flujosPorPersona[idSolicitudPersona] = flujos;
            }
            flujos.Add(flowReader.GetInt64(1));
        }

        return solicitud with
        {
            Personas = personas.Select(persona => persona with
            {
                Flujos = flujosPorPersona.TryGetValue(persona.IdSolicitudPersona, out var flujos) ? flujos : []
            }).ToArray()
        };
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
        string name,
        SqlTransaction? transaction = null) =>
        new(name, connection)
        {
            CommandType = CommandType.StoredProcedure,
            Transaction = transaction
        };

    private static void AddPersonaSolicitudParameters(SqlCommand command, long idSolicitud, AgregarPersonaSolicitudRequest request)
    {
        Add(command, "@IdSolicitud", SqlDbType.BigInt, idSolicitud);
        Add(command, "@IdPersona", SqlDbType.BigInt, request.IdPersona);
        Add(command, "@CodigoEmpleadoHtis", SqlDbType.VarChar, request.CodigoEmpleadoHtis, 50);
        Add(command, "@IdEstadoPersonaSolicitud", SqlDbType.SmallInt, request.IdEstadoPersonaSolicitud);
        Add(command, "@DatosCompletos", SqlDbType.Bit, request.DatosCompletos);
        Add(command, "@ObservacionesRevision", SqlDbType.NVarChar, request.ObservacionesRevision, 1000);
        Add(command, "@AreasJson", SqlDbType.NVarChar, request.Areas is null ? null : JsonSerializer.Serialize(request.Areas), -1);
        Add(command, "@RequerimientosJson", SqlDbType.NVarChar, request.Requerimientos is null ? null : JsonSerializer.Serialize(request.Requerimientos), -1);
        Add(command, "@Usuario", SqlDbType.VarChar, request.Usuario, 50);
    }

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

    private static IReadOnlyCollection<int> ParseIntList(string? value) =>
        string.IsNullOrWhiteSpace(value)
            ? []
            : value.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(item => int.TryParse(item, out var id) ? id : 0)
                .Where(id => id > 0)
                .Distinct()
                .ToArray();

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
