using System.Security.Claims;
using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize]
[Route("api/actividades")]
public sealed class ActividadesController(ISolicitudesRepository repository) : ControllerBase
{
    [HttpGet("mias")]
    [ProducesResponseType<IReadOnlyCollection<ActividadResumen>>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyCollection<ActividadResumen>>> ListarMias(CancellationToken cancellationToken)
    {
        var idUsuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuario)) return Unauthorized();
        return Ok(await repository.ListarMisActividadesAsync(idUsuario, cancellationToken));
    }
}
