using System.Data;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Data;

public static partial class DatabaseInitializer
{
    public static async Task ApplyScriptsAsync(IConfiguration configuration, ILogger logger)
    {
        var connectionString = configuration.GetConnectionString("ControlIngresos")
            ?? throw new InvalidOperationException("No se configuró ConnectionStrings:ControlIngresos.");
        var scriptsDirectory = Path.Combine(AppContext.BaseDirectory, "Database");

        if (!Directory.Exists(scriptsDirectory))
            throw new DirectoryNotFoundException($"No se encontró el directorio de scripts: {scriptsDirectory}");

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();

        foreach (var scriptPath in Directory.GetFiles(scriptsDirectory, "*.sql").OrderBy(path => path))
        {
            var script = await File.ReadAllTextAsync(scriptPath);
            var batches = GoSeparator().Split(script).Where(batch => !string.IsNullOrWhiteSpace(batch));
            foreach (var batch in batches)
            {
                await using var command = new SqlCommand(batch, connection)
                {
                    CommandType = CommandType.Text,
                    CommandTimeout = 60
                };
                await command.ExecuteNonQueryAsync();
            }
            logger.LogInformation("Script de base de datos aplicado: {Script}", Path.GetFileName(scriptPath));
        }

        logger.LogInformation("Scripts de Control_Ingresos_DB instalados o actualizados correctamente.");
    }

    [GeneratedRegex(@"^\s*GO\s*;?\s*$", RegexOptions.Multiline | RegexOptions.IgnoreCase)]
    private static partial Regex GoSeparator();
}
