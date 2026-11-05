using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Data;

public static class IngresoTypeCatalogInstaller
{
    private static readonly string[] Scripts =
    [
        "Control_Ingresos.Sql.002_Tipo_Ingreso_Proveedor.sql",
        "Control_Ingresos.Sql.003_Matriz_Areas.sql",
        "Control_Ingresos.Sql.004_Matriz_Aprobaciones.sql",
        "Control_Ingresos.Sql.005_Matriz_Usuario_Actualizar.sql"
    ];

    public static async Task EnsureInstalledAsync(
        IConfiguration configuration, ILogger logger, CancellationToken cancellationToken)
    {
        var connectionString = configuration.GetConnectionString("ControlIngresos")
            ?? throw new InvalidOperationException("No se configuro ConnectionStrings:ControlIngresos.");
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        var assembly = typeof(IngresoTypeCatalogInstaller).Assembly;
        foreach (var scriptName in Scripts)
        {
            await using var stream = assembly.GetManifestResourceStream(scriptName)
                ?? throw new InvalidOperationException($"No se encontro el script {scriptName}.");
            using var reader = new StreamReader(stream);
            var script = await reader.ReadToEndAsync(cancellationToken);
            foreach (var batch in System.Text.RegularExpressions.Regex.Split(
                script, @"(?im)^\s*GO\s*$"))
            {
                if (string.IsNullOrWhiteSpace(batch)) continue;
                await using var command = new SqlCommand(batch, connection) { CommandTimeout = 60 };
                await command.ExecuteNonQueryAsync(cancellationToken);
            }
        }
        logger.LogInformation("Catalogo y matriz de acceso verificados.");
    }
}
