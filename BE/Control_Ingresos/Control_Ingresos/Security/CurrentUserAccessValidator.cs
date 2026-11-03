using System.Security.Claims;
using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Security;

public sealed class CurrentUserAccessValidator(IConfiguration configuration)
{
    private readonly string _connectionString = configuration.GetConnectionString("ControlIngresos")
        ?? throw new InvalidOperationException("No se configuro ConnectionStrings:ControlIngresos.");

    public async Task<bool> IsCurrentAsync(ClaimsPrincipal principal, CancellationToken cancellationToken)
    {
        var idUsuario = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuario)) return false;

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new SqlCommand("""
            SELECT ISNULL(eg.EsActivo, 1)
            FROM dbo.Usuario AS u
            LEFT JOIN dbo.Cat_Estado_General AS eg ON eg.IdEstadoGeneral = u.IdEstadoGeneral
            WHERE u.IdUsuario = @IdUsuario;

            SELECT r.Nombre
            FROM dbo.Usuario_Rol AS ur
            INNER JOIN dbo.Rol AS r ON r.IdRol = ur.IdRol
            WHERE ur.IdUsuario = @IdUsuario AND r.Activo = 1;
            """, connection);
        command.Parameters.Add("@IdUsuario", System.Data.SqlDbType.VarChar, 50).Value = idUsuario;

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken) || !reader.GetBoolean(0)) return false;

        var currentRoles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (await reader.NextResultAsync(cancellationToken))
            while (await reader.ReadAsync(cancellationToken))
                currentRoles.Add(reader.GetString(0).Trim());

        var cookieRoles = principal.FindAll(ClaimTypes.Role)
            .Select(claim => claim.Value)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        return currentRoles.SetEquals(cookieRoles);
    }
}
