using System.Security.Claims;
using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize(Roles = "Seguridad,Administrador")]
[Route("api/control-accesos")]
public sealed class ControlAccesosController(ISolicitudesRepository repository) : ControllerBase
{
    [HttpGet("movimientos")]
    public async Task<ActionResult<IReadOnlyCollection<RegistroIngresoResumen>>> Listar(CancellationToken cancellationToken) =>
        Ok(await repository.ListarRegistrosIngresoAsync(cancellationToken));

    [HttpPost("movimientos")]
    public async Task<ActionResult<IdCreadoResponse>> Registrar(
        RegistrarIngresoRequest request,
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        var id = await repository.RegistrarIngresoAsync(request, usuario, cancellationToken);
        return Ok(new IdCreadoResponse(id));
    }
}
