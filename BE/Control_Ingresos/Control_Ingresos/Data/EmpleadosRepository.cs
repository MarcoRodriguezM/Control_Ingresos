using System.Data;
using System.Data.Common;
using System.Data.SqlTypes;
using System.Globalization;
using Control_Ingresos.Models;
using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Data;

public sealed class EmpleadosRepository(IConfiguration configuration) : IEmpleadosRepository
{
    private const int HtisConnectionTimeoutSeconds = 5;
    private const int HtisCommandTimeoutSeconds = 15;
    private const string ProcedimientoConsulta = "dbo.OBTENER_CONSULTA_EMPLEADOS";
    private const string ProcedimientoConsultaFotografia = "dbo.OBTENER_FOTO_EMPLEADO";
    private const string ProcedimientoEstados = "dbo.usp_Empleado_Status_Listar";
    private const string ProcedimientoQrObtener = "dbo.usp_Empleado_Qr_Obtener";
    private const string ProcedimientoQrConsultar = "dbo.usp_Empleado_Qr_Consultar";

    private readonly string _controlIngresosConnectionString = configuration.GetConnectionString("ControlIngresos")
        ?? throw new InvalidOperationException("No se configuró ConnectionStrings:ControlIngresos.");

    private readonly string _empleadosConnectionString =
        configuration.GetConnectionString("ConsultaEmpleadosHtis")
        ?? throw new InvalidOperationException("No se configuró ConnectionStrings:ConsultaEmpleadosHtis.");

    public async Task<IReadOnlyCollection<Empleado>> ListarAsync(CancellationToken cancellationToken)
    {
        var consultaSql = await ObtenerConsultaSqlAsync(ProcedimientoConsulta, cancellationToken);
        try
        {
            await using var connection = CrearConexionHtis();
            await connection.OpenAsync(cancellationToken);

            await using var command = new SqlCommand(consultaSql, connection)
            {
                CommandType = CommandType.Text,
                CommandTimeout = HtisCommandTimeoutSeconds
            };

            var empleados = new List<Empleado>();
            await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
            {
                while (await reader.ReadAsync(cancellationToken))
                {
                    empleados.Add(new Empleado(
                        GetNullableString(reader, "COD_EMPLEADO"),
                        GetNullableString(reader, "NOMBRE"),
                        GetNullableString(reader, "NOMBRE1"),
                        GetNullableString(reader, "NOMBRE2"),
                        GetNullableString(reader, "APELLIDO1"),
                        GetNullableString(reader, "APELLIDO2"),
                        GetNullableString(reader, "TIPO_SANGRE"),
                        GetNullableString(reader, "NIT"),
                        GetNullableString(reader, "COD_NACIONALIDAD"),
                        GetNullableDateTime(reader, "FECHA_NACIMIENTO"),
                        GetNullableString(reader, "LUGAR_NACIMIENTO"),
                        GetNullableString(reader, "COD_STATUS"),
                        null,
                        GetNullableString(reader, "EDO_CIVIL"),
                        GetNullableString(reader, "SEXO"),
                        GetNullableDateTime(reader, "FECHA_INGRESO"),
                        GetNullableDateTime(reader, "FECHA_EGRESO"),
                        GetNullableString(reader, "CORREO"),
                        GetNullableString(reader, "TIPO_LICENCIA"),
                        GetNullableString(reader, "DEPARTAMENTO"),
                        GetNullableString(reader, "CARGO_NIVEL")));
                }
            }

            return empleados;
        }
        catch (SqlException exception)
        {
            throw new HtisUnavailableException(
                "No fue posible consultar los empleados en HTIS. Intenta nuevamente en unos minutos.",
                exception);
        }
        catch (TimeoutException exception)
        {
            throw new HtisUnavailableException(
                "La consulta de empleados en HTIS tardó demasiado. Intenta nuevamente.",
                exception);
        }
    }

    public async Task<IReadOnlyCollection<Empleado>> ListarActivosAsync(
        CancellationToken cancellationToken)
    {
        var empleados = await ListarAsync(cancellationToken);
        var estados = await ListarEstadosAsync(cancellationToken);
        var estadosActivos = estados
            .Where(estado => string.Equals(estado.Descripcion?.Trim(), "ACTIVO", StringComparison.OrdinalIgnoreCase))
            .Select(estado => estado.StatusId.ToString(CultureInfo.InvariantCulture))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        if (estadosActivos.Count == 0)
            throw new HtisUnavailableException(
                "No se encontró el estado Activo en el catálogo de estados de empleados de Control Ingresos.");

        return empleados
            .Where(empleado => !string.IsNullOrWhiteSpace(empleado.CodigoEmpleado)
                && empleado.CodigoStatus is not null
                && estadosActivos.Contains(empleado.CodigoStatus.Trim()))
            .GroupBy(empleado => empleado.CodigoEmpleado!.Trim(), StringComparer.OrdinalIgnoreCase)
            .Select(grupo => grupo.First())
            .ToArray();
    }

    public async Task<IReadOnlyDictionary<string, Empleado>> ObtenerPorCodigosAsync(
        IEnumerable<string> codigosEmpleado,
        bool soloActivos,
        CancellationToken cancellationToken)
    {
        var codigos = codigosEmpleado
            .Where(codigo => !string.IsNullOrWhiteSpace(codigo))
            .Select(codigo => codigo.Trim())
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        if (codigos.Count == 0)
            return new Dictionary<string, Empleado>(StringComparer.OrdinalIgnoreCase);

        var empleados = soloActivos
            ? await ListarActivosAsync(cancellationToken)
            : await ListarAsync(cancellationToken);

        return empleados
            .Where(empleado => empleado.CodigoEmpleado is not null
                && codigos.Contains(empleado.CodigoEmpleado.Trim()))
            .GroupBy(empleado => empleado.CodigoEmpleado!.Trim(), StringComparer.OrdinalIgnoreCase)
            .ToDictionary(grupo => grupo.Key, grupo => grupo.First(), StringComparer.OrdinalIgnoreCase);
    }

    public async Task<byte[]?> ObtenerFotografiaAsync(
        string codigoEmpleado,
        CancellationToken cancellationToken)
    {
        var consultaSql = await ObtenerConsultaSqlAsync(ProcedimientoConsultaFotografia, cancellationToken);
        try
        {
            await using var connection = CrearConexionHtis();
            await connection.OpenAsync(cancellationToken);

            await using var command = new SqlCommand(consultaSql, connection)
            {
                CommandType = CommandType.Text,
                CommandTimeout = HtisCommandTimeoutSeconds
            };
            command.Parameters.Add("@COD_EMPLEADO", SqlDbType.VarChar, 50).Value = codigoEmpleado.Trim();

            await using var reader = await command.ExecuteReaderAsync(
                CommandBehavior.SequentialAccess | CommandBehavior.SingleRow,
                cancellationToken);

            if (!await reader.ReadAsync(cancellationToken)) return null;

            var ordinal = reader.GetOrdinal("FOTOGRAFIA");
            if (reader.IsDBNull(ordinal)) return null;

            return ConvertirFotografia(reader.GetValue(ordinal));
        }
        catch (SqlException exception)
        {
            throw new HtisUnavailableException(
                "No fue posible consultar la fotografía del empleado en HTIS.",
                exception);
        }
        catch (TimeoutException exception)
        {
            throw new HtisUnavailableException(
                "La consulta de la fotografía en HTIS tardó demasiado.",
                exception);
        }
    }

    private async Task<string> ObtenerConsultaSqlAsync(
        string procedimiento,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_controlIngresosConnectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(procedimiento, connection)
        {
            CommandType = CommandType.StoredProcedure
        };

        var result = await command.ExecuteScalarAsync(cancellationToken);
        var consultaSql = result is null or DBNull ? null : Convert.ToString(result, CultureInfo.InvariantCulture);

        if (string.IsNullOrWhiteSpace(consultaSql))
            throw new InvalidOperationException($"El procedimiento {procedimiento} no devolvió una consulta SQL.");

        return consultaSql;
    }

    public async Task<IReadOnlyCollection<EmpleadoStatus>> ListarEstadosAsync(
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_controlIngresosConnectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(ProcedimientoEstados, connection)
        {
            CommandType = CommandType.StoredProcedure
        };

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var estados = new List<EmpleadoStatus>();

        while (await reader.ReadAsync(cancellationToken))
        {
            estados.Add(new EmpleadoStatus(
                reader.GetInt32(reader.GetOrdinal("STATUS_ID")),
                GetNullableString(reader, "DESCRIPCION")));
        }

        return estados;
    }

    public async Task<string?> ObtenerCodigoQrAsync(
        string codigoEmpleado,
        CancellationToken cancellationToken)
    {
        var codigoNormalizado = codigoEmpleado.Trim();
        var empleado = (await ListarAsync(cancellationToken)).FirstOrDefault(item =>
            string.Equals(item.CodigoEmpleado?.Trim(), codigoNormalizado, StringComparison.OrdinalIgnoreCase));
        if (empleado is null) return null;

        await using var connection = new SqlConnection(_controlIngresosConnectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(ProcedimientoQrObtener, connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.Add("@CodigoEmpleado", SqlDbType.VarChar, 50).Value = codigoNormalizado;

        var result = await command.ExecuteScalarAsync(cancellationToken);
        return result is null or DBNull ? null : Convert.ToString(result, CultureInfo.InvariantCulture);
    }

    public async Task<Empleado?> ConsultarQrAsync(
        string codigoQr,
        CancellationToken cancellationToken)
    {
        var codigoEmpleado = await ResolverCodigoEmpleadoQrAsync(codigoQr, cancellationToken);
        if (string.IsNullOrWhiteSpace(codigoEmpleado)) return null;

        return await ConsultarPorCodigoAsync(codigoEmpleado, cancellationToken);
    }

    public async Task<Empleado?> ConsultarPorCodigoAsync(
        string codigoEmpleado,
        CancellationToken cancellationToken)
    {
        var codigoNormalizado = codigoEmpleado.Trim();

        var empleado = (await ListarAsync(cancellationToken)).FirstOrDefault(item =>
            string.Equals(item.CodigoEmpleado?.Trim(), codigoNormalizado, StringComparison.OrdinalIgnoreCase));
        if (empleado is null) return null;

        var estados = await ListarEstadosAsync(cancellationToken);
        var descripcionEstado = estados.FirstOrDefault(estado =>
            string.Equals(
                estado.StatusId.ToString(CultureInfo.InvariantCulture),
                empleado.CodigoStatus?.Trim(),
                StringComparison.OrdinalIgnoreCase))?.Descripcion;

        return empleado with { DescripcionStatus = descripcionEstado };
    }

    public async Task<string?> ResolverCodigoEmpleadoQrAsync(
        string codigoQr,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_controlIngresosConnectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(ProcedimientoQrConsultar, connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.Add("@CodigoQr", SqlDbType.VarChar, 64).Value = codigoQr.Trim().ToLowerInvariant();

        var result = await command.ExecuteScalarAsync(cancellationToken);
        var codigoEmpleado = result is null or DBNull
            ? null
            : Convert.ToString(result, CultureInfo.InvariantCulture)?.Trim();
        return string.IsNullOrWhiteSpace(codigoEmpleado) ? null : codigoEmpleado;
    }

    private static byte[] ConvertirFotografia(object value)
    {
        return value switch
        {
            byte[] bytes => bytes,
            SqlBinary sqlBinary => sqlBinary.Value,
            SqlBytes sqlBytes => sqlBytes.Value,
            string base64 => Convert.FromBase64String(base64),
            _ => throw new InvalidOperationException(
                $"El formato de fotografía '{value.GetType().Name}' no es compatible.")
        };
    }

    private SqlConnection CrearConexionHtis()
    {
        var builder = new SqlConnectionStringBuilder(_empleadosConnectionString)
        {
            ConnectTimeout = HtisConnectionTimeoutSeconds
        };
        return new SqlConnection(builder.ConnectionString);
    }

    private static string? GetNullableString(DbDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal)
            ? null
            : Convert.ToString(reader.GetValue(ordinal), CultureInfo.InvariantCulture);
    }

    private static DateTime? GetNullableDateTime(DbDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        if (reader.IsDBNull(ordinal)) return null;

        var value = reader.GetValue(ordinal);
        return value switch
        {
            DateTime dateTime => dateTime,
            DateOnly dateOnly => dateOnly.ToDateTime(TimeOnly.MinValue),
            _ => Convert.ToDateTime(value, CultureInfo.InvariantCulture)
        };
    }
}
