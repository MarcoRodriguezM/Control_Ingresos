using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize]
[Route("api/aprobaciones")]
public sealed class AprobacionesController(ISolicitudesRepository repository) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<IReadOnlyCollection<AprobacionResumen>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<AprobacionResumen>>> Listar(
        [FromQuery] string usuario,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(usuario))
            return BadRequest(new ProblemDetails { Title = "Usuario requerido", Detail = "Debe indicar el usuario aprobador." });

        return Ok(await repository.ListarAprobacionesAsync(usuario, cancellationToken));
    }

    [HttpPut("{idSolicitudPersonaArea:long}/decision")]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IdCreadoResponse>> Decidir(
        long idSolicitudPersonaArea,
        DecidirAprobacionRequest request,
        CancellationToken cancellationToken)
    {
        var id = await repository.DecidirAprobacionAsync(idSolicitudPersonaArea, request, cancellationToken);
        return Ok(new IdCreadoResponse(id));
    }
}
