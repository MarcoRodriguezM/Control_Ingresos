using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize(Roles = "Aprobador,Administrador")]
[Route("api/aprobaciones")]
public sealed class AprobacionesController(ISolicitudesRepository repository) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<IReadOnlyCollection<AprobacionResumen>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<AprobacionResumen>>> Listar(CancellationToken cancellationToken)
    {
        var idUsuarioAprobador = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuarioAprobador)) return Unauthorized();

        return Ok(await repository.ListarAprobacionesAsync(idUsuarioAprobador, cancellationToken));
    }

    [HttpPut("{idSolicitudPersonaArea:long}/decision")]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IdCreadoResponse>> Decidir(
        long idSolicitudPersonaArea,
        DecidirAprobacionRequest request,
        CancellationToken cancellationToken)
    {
        var idUsuarioAprobador = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuarioAprobador)) return Unauthorized();

        var id = await repository.DecidirAprobacionAsync(idSolicitudPersonaArea, idUsuarioAprobador, request, cancellationToken);
        return Ok(new IdCreadoResponse(id));
    }
}
