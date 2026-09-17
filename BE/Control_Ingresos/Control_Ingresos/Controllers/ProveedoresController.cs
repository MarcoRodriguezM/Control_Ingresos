using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Controllers;

[ApiController]
[Route("api/proveedores")]
public sealed class ProveedoresController(ISolicitudesRepository repository) : ControllerBase
{
    [HttpPost]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<IdCreadoResponse>> Crear(CrearProveedorRequest request, CancellationToken cancellationToken)
    {
        var id = await repository.CrearProveedorAsync(request, cancellationToken);
        return Created($"/api/proveedores/{id}", new IdCreadoResponse(id));
    }
}
