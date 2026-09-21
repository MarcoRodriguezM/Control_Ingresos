using System.Security.Claims;
using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize(Roles = "Administrador")]
[Route("api/usuarios")]
public sealed class UsuariosController(ISolicitudesRepository repository) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<IReadOnlyCollection<UsuarioAdministracionResumen>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<UsuarioAdministracionResumen>>> Listar(CancellationToken cancellationToken) =>
        Ok(await repository.ListarUsuariosAsync(cancellationToken));

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    public async Task<ActionResult<object>> Crear(CrearUsuarioRequest request, CancellationToken cancellationToken)
    {
        var idUsuarioActual = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuarioActual)) return Unauthorized();
        var idUsuario = await repository.CrearUsuarioAsync(request, idUsuarioActual, cancellationToken);
        return Created($"/api/usuarios/{Uri.EscapeDataString(idUsuario)}", new { idUsuario });
    }
}
