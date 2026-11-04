using Control_Ingresos.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize(Roles = "Administrador")]
[Route("api/auditoria")]
public sealed class AuditoriaController(AuditLogService auditLog) : ControllerBase
{
    [HttpGet]
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
}
