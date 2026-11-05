using System.Data;
using System.Text.Json;
using System.Security.Claims;
using Control_Ingresos.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize(Roles = "Administrador")]
[Route("api/matriz-accesos")]
public sealed class MatrizAccesosController(IConfiguration configuration) : ControllerBase
{
    private readonly string _connectionString = configuration.GetConnectionString("ControlIngresos")
        ?? throw new InvalidOperationException("No se configuro ConnectionStrings:ControlIngresos.");

    [HttpGet]
    public async Task<IActionResult> Obtener(CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        const string sql = """
            SELECT IdArea, Codigo, Nombre FROM dbo.Cat_Area
            WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
            SELECT u.IdUsuario, u.NombreCompleto, u.Puesto
            FROM dbo.Usuario AS u
            WHERE ISNULL(u.IdEstadoGeneral, 1) = 1
              AND EXISTS (SELECT 1 FROM dbo.Usuario_Rol AS ur
                          INNER JOIN dbo.Rol AS r ON r.IdRol = ur.IdRol
                          WHERE ur.IdUsuario = u.IdUsuario
                            AND r.Codigo IN ('APROBADOR', 'ADMINISTRADOR'))
            ORDER BY u.NombreCompleto;
            SELECT ca.IdArea, ca.IdUsuarioAprobador FROM dbo.Config_Aprobador_Area AS ca
            INNER JOIN dbo.Usuario AS u ON u.IdUsuario = ca.IdUsuarioAprobador
                AND ISNULL(u.IdEstadoGeneral, 1) = 1
            WHERE ISNULL(ca.IdEstadoGeneral, 1) = 1
              AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
              AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()));
            """;
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var areas = new List<object>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var code = reader.IsDBNull(1) ? "" : reader.GetString(1);
            if (AccessMatrixPolicy.AreaCodes.Contains(code))
                areas.Add(new { id = reader.GetInt32(0), codigo = code,
                    nombre = reader.IsDBNull(2) ? code : reader.GetString(2) });
        }
        await reader.NextResultAsync(cancellationToken);
        var users = new List<object>();
        while (await reader.ReadAsync(cancellationToken))
            users.Add(new { idUsuario = reader.GetString(0),
                nombreCompleto = reader.IsDBNull(1) ? reader.GetString(0) : reader.GetString(1),
                puesto = reader.IsDBNull(2) ? "" : reader.GetString(2) });
        await reader.NextResultAsync(cancellationToken);
        var assignments = new List<object>();
        while (await reader.ReadAsync(cancellationToken))
            if (!reader.IsDBNull(1))
                assignments.Add(new { idArea = reader.GetInt32(0), idUsuario = reader.GetString(1) });
        return Ok(new { areas, usuarios = users, asignaciones = assignments });
    }

    public sealed record GuardarAprobadoresRequest(IReadOnlyCollection<string> Usuarios);

    [HttpPut("areas/{idArea:int}/aprobadores")]
    public async Task<IActionResult> Guardar(
        int idArea, GuardarAprobadoresRequest request, CancellationToken cancellationToken)
    {
        var selected = request.Usuarios?.Where(id => !string.IsNullOrWhiteSpace(id))
            .Select(id => id.Trim()).Distinct(StringComparer.OrdinalIgnoreCase).ToArray() ?? [];
        if (selected.Any(id => id.Length > 50))
            return BadRequest(new ProblemDetails { Detail = "Un identificador de usuario es demasiado largo." });
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);
        try
        {
            await using var validate = new SqlCommand("""
                SELECT Codigo FROM dbo.Cat_Area WHERE IdArea = @IdArea AND ISNULL(IdEstadoGeneral, 1) = 1;
                """, connection, transaction);
            validate.Parameters.Add("@IdArea", SqlDbType.Int).Value = idArea;
            var code = (string?)await validate.ExecuteScalarAsync(cancellationToken);
            if (code is null || !AccessMatrixPolicy.AreaCodes.Contains(code))
            {
                await transaction.RollbackAsync(cancellationToken);
                return BadRequest(new ProblemDetails { Detail = "El area no pertenece a la matriz de acceso." });
            }
            if (selected.Length == 0 || (code is "POLVORIN" or "REFINERIA" && selected.Length != 3))
            {
                await transaction.RollbackAsync(cancellationToken);
                return BadRequest(new ProblemDetails { Detail = code is "POLVORIN" or "REFINERIA"
                    ? "Asigna exactamente tres aprobadores a esta area."
                    : "Asigna al menos un aprobador al area." });
            }

            await using var save = new SqlCommand("""
                DECLARE @Usuarios TABLE (IdUsuario VARCHAR(50) PRIMARY KEY);
                INSERT @Usuarios SELECT DISTINCT CONVERT(VARCHAR(50), [value]) FROM OPENJSON(@IdsJson);
                IF (SELECT COUNT(*) FROM @Usuarios) <>
                (
                    SELECT COUNT(*) FROM @Usuarios AS elegido
                    INNER JOIN dbo.Usuario AS u ON u.IdUsuario = elegido.IdUsuario AND ISNULL(u.IdEstadoGeneral, 1) = 1
                    WHERE EXISTS (SELECT 1 FROM dbo.Usuario_Rol AS ur
                                  INNER JOIN dbo.Rol AS r ON r.IdRol = ur.IdRol
                                  WHERE ur.IdUsuario = u.IdUsuario AND r.Codigo IN ('APROBADOR', 'ADMINISTRADOR'))
                ) THROW 50730, 'Todos los usuarios seleccionados deben estar activos y tener rol aprobador.', 1;

                UPDATE dbo.Config_Aprobador_Area
                   SET IdEstadoGeneral = 2, FechaModificacion = SYSDATETIME(),
                       UsuarioModificacion = @Usuario
                 WHERE IdArea = @IdArea AND ISNULL(IdEstadoGeneral, 1) = 1;

                DECLARE @IdUsuario VARCHAR(50), @Id BIGINT;
                DECLARE usuarios_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT IdUsuario FROM @Usuarios;
                OPEN usuarios_cursor;
                FETCH NEXT FROM usuarios_cursor INTO @IdUsuario;
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    IF EXISTS (SELECT 1 FROM dbo.Config_Aprobador_Area
                               WHERE IdArea = @IdArea AND IdUsuarioAprobador = @IdUsuario)
                        UPDATE dbo.Config_Aprobador_Area
                           SET IdEstadoGeneral = 1, EsPrincipal = 0,
                               FechaInicio = NULL, FechaFin = NULL,
                               FechaModificacion = SYSDATETIME(), UsuarioModificacion = @Usuario
                         WHERE IdArea = @IdArea AND IdUsuarioAprobador = @IdUsuario;
                    ELSE
                    BEGIN
                        EXEC dbo.usp_ObtenerSiguienteId 'Config_Aprobador_Area', @Id OUTPUT;
                        INSERT dbo.Config_Aprobador_Area
                            (IdConfigAprobador, IdArea, IdUsuarioAprobador, EsPrincipal,
                             IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
                        VALUES (@Id, @IdArea, @IdUsuario, 0, 1, SYSDATETIME(), @Usuario);
                    END;
                    FETCH NEXT FROM usuarios_cursor INTO @IdUsuario;
                END;
                CLOSE usuarios_cursor;
                DEALLOCATE usuarios_cursor;
                """, connection, transaction);
            save.Parameters.Add("@IdArea", SqlDbType.Int).Value = idArea;
            save.Parameters.Add("@IdsJson", SqlDbType.NVarChar, -1).Value = JsonSerializer.Serialize(selected);
            save.Parameters.Add("@Usuario", SqlDbType.VarChar, 50).Value =
                User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "SYSTEM";
            await save.ExecuteNonQueryAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return NoContent();
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }
}

