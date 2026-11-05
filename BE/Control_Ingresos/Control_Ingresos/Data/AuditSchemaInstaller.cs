using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Data;

public static class AuditSchemaInstaller
{
    private const string ScriptName = "Control_Ingresos.Sql.001_Auditoria_Registro.sql";

    public static async Task EnsureInstalledAsync(
        IConfiguration configuration, ILogger logger, CancellationToken cancellationToken)
    {
        var connectionString = configuration.GetConnectionString("ControlIngresos")
            ?? throw new InvalidOperationException("No se configuro ConnectionStrings:ControlIngresos.");
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        var assembly = typeof(AuditSchemaInstaller).Assembly;
        await using var scriptStream = assembly.GetManifestResourceStream(ScriptName)
            ?? throw new InvalidOperationException($"No se encontro el script {ScriptName}.");
        using var reader = new StreamReader(scriptStream);
        var script = await reader.ReadToEndAsync(cancellationToken);

        await using var command = new SqlCommand(script, connection)
        {
            CommandTimeout = 60
        };
        await command.ExecuteNonQueryAsync(cancellationToken);
        logger.LogInformation("Tabla dbo.Auditoria_Registro verificada.");
    }
}
