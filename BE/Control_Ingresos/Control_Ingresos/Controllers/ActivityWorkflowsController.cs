using System.Security.Claims;
using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize]
[Route("api/actividad-flujos")]
public sealed class ActivityWorkflowsController(IActivityWorkflowRepository repository) : ControllerBase
{
    [HttpGet]
    [Authorize(Roles = "Solicitante,Administrador")]
    [ProducesResponseType<ActividadFlujoConfiguracion>(StatusCodes.Status200OK)]
    public async Task<ActionResult<ActividadFlujoConfiguracion>> Obtener(CancellationToken cancellationToken) =>
        Ok(await repository.ObtenerAsync(cancellationToken));

    [HttpPut("{idAreaAcceso:int}")]
    [Authorize(Roles = "Administrador")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Guardar(
        int idAreaAcceso,
        GuardarActividadFlujoRequest request,
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        await repository.GuardarAsync(idAreaAcceso, request, usuario, cancellationToken);
        return NoContent();
    }
}
