using System.Security.Claims;
using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Control_Ingresos.Security;
using Control_Ingresos.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize]
[Route("api/usuarios")]
public sealed class UsuariosController(ISolicitudesRepository repository, ICredentialEmailSender emailSender) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<IReadOnlyCollection<UsuarioAdministracionResumen>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<UsuarioAdministracionResumen>>> Listar(CancellationToken cancellationToken) =>
        Ok(await repository.ListarUsuariosAsync(cancellationToken));

    [HttpGet("{idUsuario}")]
    [ProducesResponseType<UsuarioAdministracionDetalle>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UsuarioAdministracionDetalle>> Obtener(
        string idUsuario,
        CancellationToken cancellationToken)
    {
        var usuario = await repository.ObtenerUsuarioAsync(idUsuario, cancellationToken);
        return usuario is null ? NotFound() : Ok(usuario);
    }

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    public async Task<ActionResult<object>> Crear(CrearUsuarioRequest request, CancellationToken cancellationToken)
    {
        if ((request.PuedeSolicitar || request.EsAprobador) && request.IdArea is null or <= 0)
            return BadRequest(new ProblemDetails { Detail = "Selecciona un area principal para el solicitante o aprobador." });
        if (request.Permisos?.Any(permission => !AppPermissions.IsKnown(permission)) == true)
            return BadRequest("La lista de permisos contiene un valor no valido.");
        var idUsuarioActual = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuarioActual)) return Unauthorized();
        var idUsuario = await repository.CrearUsuarioAsync(request, idUsuarioActual, cancellationToken);
        var credencialesEnviadas = await emailSender.EnviarCredencialesUsuarioAsync(
            request.Correo, request.NombreCompleto, idUsuario, request.Contrasena, cancellationToken);
        return Created($"/api/usuarios/{Uri.EscapeDataString(idUsuario)}", new { idUsuario, credencialesEnviadas });
    }

    [HttpPut("{idUsuario}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Actualizar(
        string idUsuario,
        ActualizarUsuarioRequest request,
        CancellationToken cancellationToken)
    {
        if ((request.PuedeSolicitar || request.EsAprobador) && request.IdArea is null or <= 0)
            return BadRequest(new ProblemDetails { Detail = "Selecciona un area principal para el solicitante o aprobador." });
        if (request.Permisos?.Any(permission => !AppPermissions.IsKnown(permission)) == true)
            return BadRequest("La lista de permisos contiene un valor no valido.");
        var idUsuarioActual = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuarioActual)) return Unauthorized();

        var actualizado = await repository.ActualizarUsuarioAsync(
            idUsuario,
            request,
            idUsuarioActual,
            cancellationToken);

        return actualizado ? NoContent() : NotFound();
    }
}
