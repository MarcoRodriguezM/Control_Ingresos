using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Control_Ingresos.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Security.Cryptography;
using System.Security.Claims;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize]
[Route("api/proveedores")]
public sealed class ProveedoresController(
    ISolicitudesRepository repository,
    ICredentialEmailSender credentialEmailSender) : ControllerBase
{
    [HttpGet("mi-empresa")]
    [Authorize(Roles = "Proveedor")]
    [ProducesResponseType<ProveedorUsuario>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ProveedorUsuario>> ObtenerMiEmpresa(CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        var proveedor = await repository.ObtenerProveedorUsuarioAsync(usuario, cancellationToken);
        return proveedor is null ? NotFound() : Ok(proveedor);
    }

    [HttpGet("solicitudes")]
    [Authorize(Roles = "Proveedor")]
    public async Task<ActionResult<IReadOnlyCollection<SolicitudProveedorResumen>>> ListarSolicitudes(CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        return Ok(await repository.ListarSolicitudesProveedorAsync(usuario, cancellationToken));
    }

    [HttpGet("solicitudes/{id:long}")]
    [Authorize(Roles = "Proveedor")]
    public async Task<ActionResult<SolicitudProveedorDetalle>> ObtenerSolicitud(long id, CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        var solicitud = await repository.ObtenerSolicitudProveedorAsync(id, usuario, cancellationToken);
        return solicitud is null ? NotFound() : Ok(solicitud);
    }

    [HttpGet("personas")]
    [Authorize(Roles = "Proveedor")]
    public async Task<ActionResult<IReadOnlyCollection<PersonaResumen>>> ListarPersonas(CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        return Ok(await repository.ListarPersonasProveedorAsync(usuario, cancellationToken));
    }

    [HttpPost("solicitudes/{id:long}/personas")]
    [Authorize(Roles = "Proveedor")]
    public async Task<ActionResult<IdCreadoResponse>> AgregarPersona(
        long id,
        AgregarPersonaSolicitudRequest request,
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        var idSolicitudPersona = await repository.AgregarPersonaProveedorAsync(
            id,
            usuario,
            request with { Usuario = usuario },
            cancellationToken);
        return Created($"/api/proveedores/solicitudes/{id}", new IdCreadoResponse(idSolicitudPersona));
    }

    [HttpDelete("solicitudes/{id:long}/personas/{idSolicitudPersona:long}")]
    [Authorize(Roles = "Proveedor")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> EliminarPersona(
        long id,
        long idSolicitudPersona,
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        return await repository.EliminarPersonaProveedorAsync(
            id, idSolicitudPersona, usuario, cancellationToken)
            ? NoContent()
            : NotFound();
    }

    [HttpPost("solicitudes/{id:long}/enviar")]
    [Authorize(Roles = "Proveedor")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> EnviarSolicitud(long id, CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        await repository.EnviarSolicitudProveedorAsync(id, usuario, cancellationToken);
        return NoContent();
    }

    [HttpPost]
    [ProducesResponseType<ProveedorCreadoResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<ProveedorCreadoResponse>> Crear(
        CrearProveedorRequest request,
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        request = request with { Usuario = usuario, IdEstadoGeneral = null };
        var contrasenaTemporal = GenerarContrasenaTemporal();
        var creado = await repository.CrearProveedorAsync(request, contrasenaTemporal, cancellationToken);
        var credencialesEnviadas = await credentialEmailSender.EnviarCredencialesProveedorAsync(
            request.CorreoPrincipal,
            request.NombreComercial ?? request.NombreLegal,
            creado.IdUsuario,
            contrasenaTemporal,
            cancellationToken);

        return Created(
            $"/api/proveedores/{creado.IdProveedor}",
            new ProveedorCreadoResponse(
                creado.IdProveedor,
                creado.IdUsuario,
                credencialesEnviadas,
                credencialesEnviadas ? null : contrasenaTemporal));
    }

    private static string GenerarContrasenaTemporal() =>
        $"Ci-{Convert.ToHexString(RandomNumberGenerator.GetBytes(8))}!a";
}
