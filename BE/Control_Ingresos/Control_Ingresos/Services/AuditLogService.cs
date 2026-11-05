using System.Data;
using System.Text.Json;
using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Services;

public sealed record AuditEntry(
    Guid Id,
    DateTimeOffset Fecha,
    string Usuario,
    string NombreUsuario,
    string Metodo,
    string Recurso,
    string? Referencia,
    int Estado);

public sealed record AuditPage(IReadOnlyList<AuditEntry> Registros, int Total, int Pagina, int TamanoPagina);

public sealed class AuditLogService(IConfiguration configuration, IWebHostEnvironment environment)
{
    private readonly string _connectionString = configuration.GetConnectionString("ControlIngresos")
        ?? throw new InvalidOperationException("No se configuro ConnectionStrings:ControlIngresos.");
    private readonly string _legacyDirectory = ResolveLegacyDirectory(environment, configuration);
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public static bool IsActionMethod(string method) =>
        HttpMethods.IsPost(method) || HttpMethods.IsPut(method)
        || HttpMethods.IsPatch(method) || HttpMethods.IsDelete(method);

    public async Task AppendAsync(AuditEntry entry, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = InsertCommand(connection, entry, ignoreDuplicates: false);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<AuditPage> SearchAsync(
        DateTimeOffset from, DateTimeOffset until, string? person, int page, int pageSize,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        const string sql = """
            SELECT COUNT(1)
            FROM dbo.Auditoria_Registro
            WHERE Fecha >= @Desde AND Fecha < @Hasta
              AND Metodo IN ('POST', 'PUT', 'PATCH', 'DELETE', 'VIEW')
              AND (@Persona IS NULL
                   OR CHARINDEX(@Persona, Usuario COLLATE Latin1_General_CI_AI) > 0
                   OR CHARINDEX(@Persona, NombreUsuario COLLATE Latin1_General_CI_AI) > 0
                   OR CHARINDEX(@Persona, Referencia COLLATE Latin1_General_CI_AI) > 0);

            SELECT Id, Fecha, Usuario, NombreUsuario, Metodo, Recurso, Referencia, Estado
            FROM dbo.Auditoria_Registro
            WHERE Fecha >= @Desde AND Fecha < @Hasta
              AND Metodo IN ('POST', 'PUT', 'PATCH', 'DELETE', 'VIEW')
              AND (@Persona IS NULL
                   OR CHARINDEX(@Persona, Usuario COLLATE Latin1_General_CI_AI) > 0
                   OR CHARINDEX(@Persona, NombreUsuario COLLATE Latin1_General_CI_AI) > 0
                   OR CHARINDEX(@Persona, Referencia COLLATE Latin1_General_CI_AI) > 0)
            ORDER BY Fecha DESC, Id DESC
            OFFSET @Saltar ROWS FETCH NEXT @Tomar ROWS ONLY;
            """;
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@Desde", SqlDbType.DateTimeOffset).Value = from;
        command.Parameters.Add("@Hasta", SqlDbType.DateTimeOffset).Value = until;
        command.Parameters.Add("@Persona", SqlDbType.NVarChar, 100).Value =
            string.IsNullOrWhiteSpace(person) ? DBNull.Value : person;
        command.Parameters.Add("@Saltar", SqlDbType.Int).Value = (page - 1) * pageSize;
        command.Parameters.Add("@Tomar", SqlDbType.Int).Value = pageSize;

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var total = await reader.ReadAsync(cancellationToken) ? reader.GetInt32(0) : 0;
        var entries = new List<AuditEntry>();
        if (await reader.NextResultAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
                entries.Add(new AuditEntry(
                    reader.GetGuid(0), reader.GetFieldValue<DateTimeOffset>(1),
                    reader.GetString(2), reader.GetString(3), reader.GetString(4),
                    reader.GetString(5), reader.IsDBNull(6) ? null : reader.GetString(6),
                    reader.GetInt16(7)));
        }
        return new AuditPage(entries, total, page, pageSize);
    }

    public async Task<int> ImportLegacyFilesAsync(CancellationToken cancellationToken)
    {
        if (!Directory.Exists(_legacyDirectory)) return 0;

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        var imported = 0;
        foreach (var path in Directory.EnumerateFiles(_legacyDirectory, "*.jsonl"))
        {
            using var reader = new StreamReader(path);
            while (await reader.ReadLineAsync(cancellationToken) is { } line)
            {
                AuditEntry? entry;
                try { entry = JsonSerializer.Deserialize<AuditEntry>(line, JsonOptions); }
                catch (JsonException) { continue; }
                if (entry is null || !IsActionMethod(entry.Metodo)) continue;
                await using var command = InsertCommand(connection, entry, ignoreDuplicates: true);
                imported += await command.ExecuteNonQueryAsync(cancellationToken);
            }
        }
        return imported;
    }

    private static SqlCommand InsertCommand(SqlConnection connection, AuditEntry entry, bool ignoreDuplicates)
    {
        var sql = """
            INSERT INTO dbo.Auditoria_Registro
                (Id, Fecha, Usuario, NombreUsuario, Metodo, Recurso, Referencia, Estado)
            """ + (ignoreDuplicates ? """
            SELECT @Id, @Fecha, @Usuario, @NombreUsuario, @Metodo, @Recurso, @Referencia, @Estado
            WHERE NOT EXISTS (SELECT 1 FROM dbo.Auditoria_Registro WHERE Id = @Id);
            """ : """
            VALUES (@Id, @Fecha, @Usuario, @NombreUsuario, @Metodo, @Recurso, @Referencia, @Estado);
            """);
        var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@Id", SqlDbType.UniqueIdentifier).Value = entry.Id;
        command.Parameters.Add("@Fecha", SqlDbType.DateTimeOffset).Value = entry.Fecha;
        command.Parameters.Add("@Usuario", SqlDbType.NVarChar, 254).Value = Truncate(entry.Usuario, 254);
        command.Parameters.Add("@NombreUsuario", SqlDbType.NVarChar, 200).Value = Truncate(entry.NombreUsuario, 200);
        command.Parameters.Add("@Metodo", SqlDbType.VarChar, 10).Value = Truncate(entry.Metodo, 10);
        command.Parameters.Add("@Recurso", SqlDbType.NVarChar, 300).Value = Truncate(entry.Recurso, 300);
        command.Parameters.Add("@Referencia", SqlDbType.NVarChar, 200).Value = entry.Referencia is null
            ? DBNull.Value : Truncate(entry.Referencia, 200);
        command.Parameters.Add("@Estado", SqlDbType.SmallInt).Value = entry.Estado;
        return command;
    }

    private static string Truncate(string value, int limit) => value.Length > limit ? value[..limit] : value;

    private static string ResolveLegacyDirectory(IWebHostEnvironment environment, IConfiguration configuration)
    {
        var configured = configuration["Audit:Directory"];
        return Path.GetFullPath(Path.IsPathRooted(configured ?? string.Empty)
            ? configured!
            : Path.Combine(environment.ContentRootPath, configured ?? "App_Data/audit"));
    }
}
