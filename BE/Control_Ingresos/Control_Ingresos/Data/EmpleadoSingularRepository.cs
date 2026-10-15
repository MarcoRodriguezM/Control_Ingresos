using System.Data;
using System.Data.Common;
using System.Globalization;
using Control_Ingresos.Models;
using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Data;

public sealed class EmpleadoSingularRepository(IConfiguration configuration) : IEmpleadoSingularRepository
{
    private const int ConnectionTimeoutSeconds = 5;
    private const int CommandTimeoutSeconds = 15;
    private const string ProcedimientoConsulta = "dbo.OBTENER_CONSULTA_AUTORIZACIONES_EMPLEADO";

    private readonly string _controlIngresosConnectionString = configuration.GetConnectionString("ControlIngresos")
        ?? throw new InvalidOperationException("No se configuró ConnectionStrings:ControlIngresos.");

    private readonly string _singularConnectionString = configuration.GetConnectionString("ConsultaEmpleadosSingular")
        ?? throw new InvalidOperationException("No se configuró ConnectionStrings:ConsultaEmpleadosSingular.");

    public async Task<EmpleadoInformacionSingular> ObtenerAsync(
        string codigoEmpleado,
        CancellationToken cancellationToken)
    {
        if (!int.TryParse(codigoEmpleado.Trim(), NumberStyles.None, CultureInfo.InvariantCulture, out var codigo))
            return new EmpleadoInformacionSingular(null, Array.Empty<EmpleadoEntrenamientoSingular>());

        try
        {
            var consultaSql = await ObtenerConsultaSqlAsync(cancellationToken);

            await using var connection = CrearConexionSingular();
            await connection.OpenAsync(cancellationToken);

            await using var command = new SqlCommand(consultaSql, connection)
            {
                CommandType = CommandType.Text,
                CommandTimeout = CommandTimeoutSeconds
            };
            command.Parameters.Add("@CodigoEmpleado", SqlDbType.Int).Value = codigo;

            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            EmpleadoAutorizacionSingular? autorizacion = null;
            if (await reader.ReadAsync(cancellationToken))
            {
                autorizacion = new EmpleadoAutorizacionSingular(
                    GetNullableInt32(reader, "CARNET"),
                    GetNullableString(reader, "NOMBRE"),
                    GetNullableString(reader, "CONTRATO"),
                    GetNullableString(reader, "EMPRESA"),
                    GetNullableString(reader, "CARGO"),
                    GetNullableString(reader, "CATEGORIA_LICENCIA"),
                    GetNullableDateTime(reader, "VALIDEZ_LICENCIA"),
                    GetNullableString(reader, "NUMERO_LICENCIA"),
                    GetNullableString(reader, "ESTADO"),
                    GetNullableDateTime(reader, "VALIDEZ_ASO"),
                    GetNullableString(reader, "AREA"),
                    GetNullableString(reader, "GERENCIA"),
                    GetNullableString(reader, "TIPO_SANGRE"));
            }

            var entrenamientos = new List<EmpleadoEntrenamientoSingular>();
            if (await reader.NextResultAsync(cancellationToken))
            {
                while (await reader.ReadAsync(cancellationToken))
                {
                    entrenamientos.Add(new EmpleadoEntrenamientoSingular(
                        GetNullableString(reader, "ENTRENAMIENTO"),
                        GetNullableString(reader, "VALIDEZ"),
                        GetNullableString(reader, "FECHA_ENTRENAMIENTO"),
                        GetNullableString(reader, "CARGA_HORARIA"),
                        GetNullableString(reader, "TIPO")));
                }
            }

            return new EmpleadoInformacionSingular(autorizacion, entrenamientos);
        }
        catch (SqlException exception)
        {
            throw;
        }
        catch (TimeoutException exception)
        {
            throw new SingularUnavailableException(
                "La consulta de autorizaciones y entrenamientos tardó demasiado. Intenta nuevamente.",
                exception);
        }
        catch (InvalidOperationException exception)
        {
            throw new SingularUnavailableException(
                "La configuración o la respuesta de Singular no tiene el formato esperado. Revisa los registros del backend.",
                exception);
        }
    }

    private async Task<string> ObtenerConsultaSqlAsync(CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_controlIngresosConnectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(ProcedimientoConsulta, connection)
        {
            CommandType = CommandType.StoredProcedure
        };

        var result = await command.ExecuteScalarAsync(cancellationToken);
        var consultaSql = result is null or DBNull
            ? null
            : Convert.ToString(result, CultureInfo.InvariantCulture);

        if (string.IsNullOrWhiteSpace(consultaSql))
            throw new InvalidOperationException($"El procedimiento {ProcedimientoConsulta} no devolvió una consulta SQL.");

        return consultaSql;
    }

    private SqlConnection CrearConexionSingular()
    {
        var builder = new SqlConnectionStringBuilder(_singularConnectionString)
        {
            ConnectTimeout = ConnectionTimeoutSeconds
        };
        return new SqlConnection(builder.ConnectionString);
    }

    private static string DescribirErrorSql(SqlException exception) =>
        exception.Number switch
        {
            -2 => "La conexión o consulta a Singular superó el tiempo de espera configurado.",
            2 or 20 or 53 or 64 or 121 or 233 or 258 or 10054 or 10060 or 10061 or 11001 =>
                "El servidor de Singular no está disponible o no puede alcanzarse desde el servidor de la aplicación.",
            18452 or 18456 or 18470 or 18486 =>
                "Singular rechazó las credenciales configuradas para la conexión.",
            4060 => "La base de datos configurada para Singular no está disponible o no permite el acceso.",
            229 => "El usuario configurado no tiene permisos suficientes para consultar Singular.",
            207 or 208 => "La consulta de Singular no coincide con la estructura actual de su base de datos.",
            2812 => "No se encontró el procedimiento local que prepara la consulta de Singular.",
            _ => $"Singular devolvió un error de SQL Server (código {exception.Number}). Revisa los registros del backend."
        };

    private static string? GetNullableString(DbDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal)
            ? null
            : Convert.ToString(reader.GetValue(ordinal), CultureInfo.InvariantCulture)?.Trim();
    }

    private static int? GetNullableInt32(DbDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal)
            ? null
            : Convert.ToInt32(reader.GetValue(ordinal), CultureInfo.InvariantCulture);
    }

    private static DateTime? GetNullableDateTime(DbDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal)
            ? null
            : Convert.ToDateTime(reader.GetValue(ordinal), CultureInfo.InvariantCulture);
    }
}
