using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize]
[Route("api/proveedores")]
public sealed class ProveedoresController(ISolicitudesRepository repository) : ControllerBase
{
    [HttpPost]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<IdCreadoResponse>> Crear(
        CrearProveedorRequest request,
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        request = request with { Usuario = usuario };
        var id = await repository.CrearProveedorAsync(request, cancellationToken);

        return Created(
            $"/api/proveedores/{id}",
            new IdCreadoResponse(id));
    }
}
