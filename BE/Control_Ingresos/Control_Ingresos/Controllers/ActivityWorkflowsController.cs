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
    [Authorize]
    [ProducesResponseType<ActividadFlujoConfiguracion>(StatusCodes.Status200OK)]
    public async Task<ActionResult<ActividadFlujoConfiguracion>> Obtener(CancellationToken cancellationToken) =>
        Ok(await repository.ObtenerAsync(cancellationToken));

    [HttpPost("{idAreaAcceso:int}")]
    [Authorize]
    [ProducesResponseType<ActividadFlujoGuardadoResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<ActividadFlujoGuardadoResponse>> Crear(
        int idAreaAcceso,
        GuardarActividadFlujoRequest request,
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        var resultado = await repository.GuardarAsync(idAreaAcceso, null, request, usuario, cancellationToken);
        return CreatedAtAction(nameof(Obtener), resultado);
    }

    [HttpPut("{idAreaAcceso:int}/{idActividadFlujo:long}")]
    [Authorize]
    [ProducesResponseType<ActividadFlujoGuardadoResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<ActividadFlujoGuardadoResponse>> Actualizar(
        int idAreaAcceso,
        long idActividadFlujo,
        GuardarActividadFlujoRequest request,
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        return Ok(await repository.GuardarAsync(idAreaAcceso, idActividadFlujo, request, usuario, cancellationToken));
    }

    [HttpDelete("{idAreaAcceso:int}/{idActividadFlujo:long}")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Eliminar(int idAreaAcceso, long idActividadFlujo, CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        try
        {
            return await repository.EliminarAsync(idAreaAcceso, idActividadFlujo, usuario, cancellationToken)
                ? NoContent()
                : NotFound();
        }
        catch (InvalidOperationException error)
        {
            return Conflict(new ProblemDetails { Status = StatusCodes.Status409Conflict, Detail = error.Message });
        }
    }
}
