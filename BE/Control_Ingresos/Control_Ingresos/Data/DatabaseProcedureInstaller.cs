using System.Data;
using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Data;

public static partial class DatabaseProcedureInstaller
{
    private const string ResourceSuffix = "Database.StoredProcedures.sql";

    public static async Task EnsureInstalledAsync(
        IConfiguration configuration,
        ILogger logger,
        CancellationToken cancellationToken = default)
    {
        if (!configuration.GetValue("Database:InstallMissingStoredProceduresOnStartup", true))
        {
            logger.LogInformation("La instalación automática de procedimientos almacenados está desactivada.");
            return;
        }

        var connectionString = configuration.GetConnectionString("ControlIngresos")
            ?? throw new InvalidOperationException("No se configuró ConnectionStrings:ControlIngresos.");

        var script = await ReadEmbeddedScriptAsync(cancellationToken);
        var procedureBatches = ParseProcedureBatches(script);
        if (procedureBatches.Count == 0)
            throw new InvalidOperationException("StoredProcedures.sql no contiene procedimientos almacenados.");

        await using var connection = await OpenWithRetryAsync(
            connectionString,
            logger,
            cancellationToken);

        logger.LogInformation(
            "Sincronizando {ProcedureCount} procedimientos almacenados con la versión del backend.",
            procedureBatches.Count);

        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);
        try
        {
            await using (var sessionCommand = new SqlCommand(
                "SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET XACT_ABORT ON;",
                connection,
                transaction))
            {
                await sessionCommand.ExecuteNonQueryAsync(cancellationToken);
            }

            foreach (var (procedureName, procedureBatch) in procedureBatches.OrderBy(
                         item => item.Key,
                         StringComparer.OrdinalIgnoreCase))
            {
                await using var command = new SqlCommand(
                    procedureBatch,
                    connection,
                    transaction)
                {
                    CommandType = CommandType.Text,
                    CommandTimeout = 120
                };

                try
                {
                    await command.ExecuteNonQueryAsync(cancellationToken);
                }
                catch (SqlException exception)
                {
                    throw new InvalidOperationException(
                        $"No fue posible sincronizar el procedimiento dbo.{procedureName}.",
                        exception);
                }

                logger.LogDebug("Procedimiento dbo.{ProcedureName} sincronizado.", procedureName);
            }

            await transaction.CommitAsync(cancellationToken);
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }

        var remaining = await ReadExistingProceduresAsync(connection, cancellationToken);
        var notInstalled = procedureBatches.Keys
            .Where(name => !remaining.Contains(name))
            .ToArray();

        if (notInstalled.Length > 0)
            throw new InvalidOperationException(
                $"No fue posible instalar: {string.Join(", ", notInstalled.Select(name => $"dbo.{name}"))}.");

        logger.LogInformation(
            "Sincronización automática completada: {TotalCount} procedimientos verificados y actualizados.",
            procedureBatches.Count);
    }

    private static async Task<string> ReadEmbeddedScriptAsync(CancellationToken cancellationToken)
    {
        var assembly = typeof(DatabaseProcedureInstaller).Assembly;
        var resourceName = assembly.GetManifestResourceNames()
            .SingleOrDefault(name => name.EndsWith(ResourceSuffix, StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidOperationException(
                $"No se encontró el recurso embebido {ResourceSuffix}.");

        await using var stream = assembly.GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException($"No se pudo abrir el recurso {resourceName}.");
        using var reader = new StreamReader(stream);
        return await reader.ReadToEndAsync(cancellationToken);
    }

    private static Dictionary<string, string> ParseProcedureBatches(string script)
    {
        var batches = GoBatchRegex().Split(script);
        var procedures = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        foreach (var batch in batches)
        {
            if (string.IsNullOrWhiteSpace(batch)) continue;
            var match = ProcedureRegex().Match(batch);
            if (!match.Success) continue;
            procedures[match.Groups["name"].Value] = batch.Trim();
        }

        return procedures;
    }

    private static async Task<HashSet<string>> ReadExistingProceduresAsync(
        SqlConnection connection,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT p.name
            FROM sys.procedures AS p
            INNER JOIN sys.schemas AS s ON s.schema_id = p.schema_id
            WHERE s.name = 'dbo' AND p.is_ms_shipped = 0;
            """;

        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        while (await reader.ReadAsync(cancellationToken)) names.Add(reader.GetString(0));
        return names;
    }

    private static async Task<SqlConnection> OpenWithRetryAsync(
        string connectionString,
        ILogger logger,
        CancellationToken cancellationToken)
    {
        const int attempts = 3;
        for (var attempt = 1; attempt <= attempts; attempt++)
        {
            var connection = new SqlConnection(connectionString);
            try
            {
                await connection.OpenAsync(cancellationToken);
                return connection;
            }
            catch when (attempt < attempts)
            {
                await connection.DisposeAsync();
                logger.LogWarning(
                    "SQL Server todavía no está disponible. Reintento {Attempt} de {Attempts}.",
                    attempt + 1,
                    attempts);
                await Task.Delay(TimeSpan.FromSeconds(2), cancellationToken);
            }
            catch
            {
                await connection.DisposeAsync();
                throw;
            }
        }

        throw new InvalidOperationException("No fue posible abrir la conexión con SQL Server.");
    }

    [GeneratedRegex(@"^\s*GO\s*(?:--.*)?$", RegexOptions.IgnoreCase | RegexOptions.Multiline)]
    private static partial Regex GoBatchRegex();

    [GeneratedRegex(@"\bCREATE\s+(?:OR\s+ALTER\s+)?PROCEDURE\s+(?:\[?dbo\]?\.)?\[?(?<name>[A-Za-z0-9_]+)\]?", RegexOptions.IgnoreCase)]
    private static partial Regex ProcedureRegex();
}
