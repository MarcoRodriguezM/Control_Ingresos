using Control_Ingresos.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize]
[Route("api/auditoria")]
public sealed class AuditoriaController(AuditLogService auditLog) : ControllerBase
{
    [HttpGet]
    [Authorize(Roles = "Administrador")]
    public async Task<ActionResult<AuditPage>> Listar(
        [FromQuery] DateOnly? desde,
        [FromQuery] DateOnly? hasta,
        [FromQuery] string? persona,
        [FromQuery] int pagina = 1,
        [FromQuery] int tamanoPagina = 50,
        [FromQuery] int offsetMinutos = 0,
        CancellationToken cancellationToken = default)
    {
        var start = desde ?? DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-6));
        var end = hasta ?? DateOnly.FromDateTime(DateTime.UtcNow);
        if (end < start || end.DayNumber - start.DayNumber > 90
            || pagina is < 1 or > 100000 || tamanoPagina is < 1 or > 100
            || persona?.Length > 100
            || offsetMinutos is < -840 or > 840)
            return BadRequest(new ProblemDetails
            {
                Title = "Filtros invalidos",
                Detail = "Selecciona un rango de hasta 90 dias y una pagina valida."
            });

        var from = new DateTimeOffset(start.ToDateTime(TimeOnly.MinValue), TimeSpan.Zero)
            .AddMinutes(offsetMinutos);
        var until = new DateTimeOffset(end.AddDays(1).ToDateTime(TimeOnly.MinValue), TimeSpan.Zero)
            .AddMinutes(offsetMinutos);
        return Ok(await auditLog.SearchAsync(from, until, persona?.Trim(), pagina, tamanoPagina,
            cancellationToken));
    }

    [HttpPost("navegacion")]
    public async Task<IActionResult> RegistrarNavegacion(
        VisitaPantallaRequest request, CancellationToken cancellationToken)
    {
        var screen = ScreenName(request.Ruta);
        if (screen is null) return NoContent();
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(userId)) return Unauthorized();

        await auditLog.AppendAsync(new AuditEntry(
            Guid.NewGuid(), DateTimeOffset.UtcNow, userId,
            User.FindFirstValue(ClaimTypes.Name) ?? userId,
            "VIEW", "pantalla", screen, StatusCodes.Status200OK), cancellationToken);
        return NoContent();
    }

    private static string? ScreenName(string? route)
    {
        if (string.IsNullOrWhiteSpace(route) || route.Length > 200) return null;
        var segments = route.Trim('/').Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (segments.Length == 0) return null;
        return segments[0].ToLowerInvariant() switch
        {
            "dashboard" => "Dashboard",
            "solicitudes" when segments.Length == 1 => "Solicitudes",
            "solicitudes" when segments.Length > 1 && segments[1] == "nueva" => "Nueva solicitud",
            "solicitudes" when segments.Length > 2 && segments[2] == "editar" => "Editar solicitud",
            "solicitudes" when segments.Length > 2 && segments[2] == "tickets" => "Tickets de solicitud",
            "solicitudes" => "Seguimiento de solicitud",
            "aprobaciones" when segments.Length > 1 => "Detalle de aprobacion",
            "aprobaciones" => "Mis aprobaciones",
            "mis-actividades" when segments.Length > 1 => "Consulta de solicitud",
            "mis-actividades" => "Mis actividades",
            "personas" when segments.Length > 1 && segments[1] == "nueva" => "Nueva persona",
            "personas" when segments.Length > 2 && segments[2] == "qr" => "QR de persona",
            "personas" => "Personas y accesos",
            "empleados" when segments.Length > 2 && segments[2] == "qr" => "QR de empleado",
            "empleados" => "Empleados",
            "proveedores" => "Nuevo proveedor",
            "portal-proveedor" when segments.Length > 1 && segments[1] == "seguimiento" => "Seguimiento del proveedor",
            "portal-proveedor" when segments.Length > 3 && segments[3] == "personas" => "Registrar persona de solicitud",
            "portal-proveedor" when segments.Length > 1 && segments[1] == "solicitudes" => "Solicitudes del proveedor",
            "portal-proveedor" => "Portal del proveedor",
            "usuarios" when segments.Length == 1 => "Usuarios",
            "usuarios" when segments.Length > 1 && segments[1] == "nuevo" => "Nuevo usuario",
            "usuarios" when segments.Length > 2 && segments[2] == "editar" => "Editar usuario",
            "usuarios" => "Detalle de usuario",
            "configuracion" when segments.Length > 1 && segments[1] == "actividades" => "Flujos de acceso",
            "configuracion" when segments.Length > 1 && segments[1] == "freshservice" => "Pruebas Freshservice",
            "escanear-qr" => "Escanear QR",
            "perfil" => "Mi perfil",
            "auditoria" => "Auditoria",
            "credencial" when segments.Length > 1 && segments[1] == "empleado" => "Credencial del empleado",
            "credencial" when segments.Length > 1 && segments[1] == "persona" => "Credencial de la persona",
            _ => null
        };
    }
}

public sealed record VisitaPantallaRequest(string? Ruta);
