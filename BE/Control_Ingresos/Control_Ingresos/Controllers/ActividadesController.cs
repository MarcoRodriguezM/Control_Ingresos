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
    [Authorize(Roles = "Aprobador,Administrador")]
    [HttpGet]
    [ProducesResponseType<IReadOnlyCollection<ActividadAdministracionResumen>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<ActividadAdministracionResumen>>> Listar(CancellationToken cancellationToken) =>
        Ok(await repository.ListarActividadesAsync(cancellationToken));

    [HttpGet("mias")]
    [ProducesResponseType<IReadOnlyCollection<ActividadResumen>>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyCollection<ActividadResumen>>> ListarMias(CancellationToken cancellationToken)
    {
        var idUsuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuario)) return Unauthorized();
        return Ok(await repository.ListarMisActividadesAsync(idUsuario, cancellationToken));
    }

    [Authorize(Roles = "Aprobador,Administrador")]
    [HttpPost]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<IdCreadoResponse>> Crear(CrearActividadRequest request, CancellationToken cancellationToken)
    {
        var idUsuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuario)) return Unauthorized();
        var id = await repository.CrearActividadAsync(request, idUsuario, cancellationToken);
        return Created($"/api/actividades/{id}", new IdCreadoResponse(id));
    }

    [HttpPut("{idActividad:long}/completar")]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IdCreadoResponse>> Completar(long idActividad, CompletarActividadRequest request, CancellationToken cancellationToken)
    {
        var idUsuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuario)) return Unauthorized();
        var id = await repository.CompletarActividadAsync(idActividad, idUsuario, request, cancellationToken);
        return Ok(new IdCreadoResponse(id));
    }

    [Authorize(Roles = "Aprobador,Administrador")]
    [HttpPut("{idActividad:long}/decision")]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IdCreadoResponse>> Decidir(long idActividad, DecidirActividadRequest request, CancellationToken cancellationToken)
    {
        var idUsuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuario)) return Unauthorized();
        var id = await repository.DecidirActividadAsync(idActividad, idUsuario, request, cancellationToken);
        return Ok(new IdCreadoResponse(id));
    }
}
