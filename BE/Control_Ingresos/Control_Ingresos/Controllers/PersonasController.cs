using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Controllers;

[ApiController]
[Route("api/personas")]
public sealed class PersonasController(ISolicitudesRepository repository) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<IReadOnlyCollection<PersonaResumen>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<PersonaResumen>>> Listar(CancellationToken cancellationToken) =>
        Ok(await repository.ListarPersonasAsync(cancellationToken));

    [HttpGet("{id:long}/accesos")]
    [ProducesResponseType<PersonaConAccesos>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PersonaConAccesos>> ObtenerAccesos(long id, CancellationToken cancellationToken)
    {
        var persona = await repository.ObtenerPersonaAccesosAsync(id, cancellationToken);
        return persona is null ? NotFound() : Ok(persona);
    }

    [HttpPost]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<IdCreadoResponse>> Crear(CrearPersonaRequest request, CancellationToken cancellationToken)
    {
        var id = await repository.CrearPersonaAsync(request, cancellationToken);
        return Created($"/api/personas/{id}", new IdCreadoResponse(id));
    }
}
