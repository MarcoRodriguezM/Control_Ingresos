using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize]
[Route("api/solicitudes")]
public sealed class SolicitudesController(ISolicitudesRepository repository) : ControllerBase
{
    [HttpGet("formulario-datos")]
    [ProducesResponseType<SolicitudFormularioDatos>(StatusCodes.Status200OK)]
    public async Task<ActionResult<SolicitudFormularioDatos>> ObtenerDatosFormulario(
        CancellationToken cancellationToken) =>
        Ok(await repository.ObtenerDatosFormularioSolicitudAsync(cancellationToken));

    [HttpGet]
    [ProducesResponseType<IReadOnlyCollection<SolicitudResumen>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<SolicitudResumen>>> Listar(
        CancellationToken cancellationToken)
    {
        var usuario = CurrentUserId();
        if (usuario is null) return Unauthorized();
        var accesoTotal = User.IsInRole("Administrador") || User.IsInRole("Aprobador") || User.IsInRole("Seguridad") || User.IsInRole("Auditor");
        return Ok(await repository.ListarSolicitudesAsync(usuario, accesoTotal, cancellationToken));
    }

    [HttpGet("{id:long}")]
    [ProducesResponseType<SolicitudDetalle>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<SolicitudDetalle>> Obtener(
        long id,
        CancellationToken cancellationToken)
    {
        var solicitud = await repository.ObtenerSolicitudAsync(id, cancellationToken);

        return solicitud is null
            ? NotFound()
            : Ok(solicitud);
    }

    [HttpPost]
    [Authorize(Roles = "Solicitante,Administrador")]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<IdCreadoResponse>> Crear(
        CrearSolicitudRequest request,
        CancellationToken cancellationToken)
    {
        var idUsuario = CurrentUserId();
        if (idUsuario is null) return Unauthorized();
        request = request with { IdEstadoSolicitud = null, IdUsuarioSolicitante = idUsuario, Usuario = idUsuario };
        if (request.FechaInicio.HasValue &&
            request.FechaFin.HasValue &&
            request.FechaFin < request.FechaInicio)
        {
            ModelState.AddModelError(
                nameof(request.FechaFin),
                "La fecha final no puede ser anterior a la fecha inicial.");
        }

        if (!ModelState.IsValid)
            return ValidationProblem(ModelState);

        var creado = await repository.CrearSolicitudAsync(
            request,
            cancellationToken);

        return CreatedAtAction(
            nameof(Obtener),
            new { id = creado.Id },
            creado);
    }

    [HttpPost("completa")]
    [Authorize(Roles = "Solicitante,Administrador")]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<IdCreadoResponse>> CrearCompleta(
        CrearSolicitudCompletaRequest request,
        CancellationToken cancellationToken)
    {
        var idUsuario = CurrentUserId();
        if (idUsuario is null) return Unauthorized();
        if (request.Solicitud.FechaInicio.HasValue && request.Solicitud.FechaFin < request.Solicitud.FechaInicio)
        {
            ModelState.AddModelError("fechaFin", "La fecha final no puede ser anterior a la fecha inicial.");
            return ValidationProblem(ModelState);
        }

        var normalized = request with
        {
            Solicitud = request.Solicitud with { IdEstadoSolicitud = null, IdUsuarioSolicitante = idUsuario, Usuario = idUsuario },
            Personas = request.Personas?.Select(person => person with { Usuario = idUsuario }).ToArray()
        };
        var created = await repository.CrearSolicitudCompletaAsync(normalized, cancellationToken);
        return CreatedAtAction(nameof(Obtener), new { id = created.Id }, created);
    }

    [HttpPut("{id:long}")]
    [Authorize(Roles = "Solicitante,Administrador")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Actualizar(
        long id,
        CrearSolicitudRequest request,
        CancellationToken cancellationToken)
    {
        var idUsuario = CurrentUserId();
        if (idUsuario is null) return Unauthorized();
        var existing = await repository.ObtenerSolicitudAsync(id, cancellationToken);
        if (existing is null) return NotFound();
        if (!User.IsInRole("Administrador") && existing.IdUsuarioSolicitante != idUsuario) return Forbid();
        request = request with
        {
            IdEstadoSolicitud = existing.IdEstadoSolicitud,
            IdUsuarioSolicitante = existing.IdUsuarioSolicitante ?? idUsuario,
            Usuario = idUsuario
        };
        if (request.FechaInicio.HasValue &&
            request.FechaFin.HasValue &&
            request.FechaFin < request.FechaInicio)
        {
            ModelState.AddModelError(
                nameof(request.FechaFin),
                "La fecha final no puede ser anterior a la fecha inicial.");
        }

        if (!ModelState.IsValid)
            return ValidationProblem(ModelState);

        return await repository.ActualizarSolicitudAsync(
            id,
            request,
            cancellationToken)
            ? NoContent()
            : NotFound();
    }

    [HttpDelete("{id:long}")]
    [Authorize(Roles = "Solicitante,Administrador")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Eliminar(
        long id,
        CancellationToken cancellationToken)
    {
        var usuario = CurrentUserId();
        if (usuario is null) return Unauthorized();
        var existing = await repository.ObtenerSolicitudAsync(id, cancellationToken);
        if (existing is null) return NotFound();
        if (!User.IsInRole("Administrador") && existing.IdUsuarioSolicitante != usuario) return Forbid();

        return await repository.EliminarSolicitudAsync(
            id,
            usuario,
            cancellationToken)
            ? NoContent()
            : NotFound();
    }

    [HttpPost("{id:long}/personas")]
    [Authorize(Roles = "Solicitante,Administrador")]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<IdCreadoResponse>> AgregarPersona(
        long id,
        AgregarPersonaSolicitudRequest request,
        CancellationToken cancellationToken)
    {
        var usuario = CurrentUserId();
        if (usuario is null) return Unauthorized();
        var existing = await repository.ObtenerSolicitudAsync(id, cancellationToken);
        if (existing is null) return NotFound();
        if (!User.IsInRole("Administrador") && existing.IdUsuarioSolicitante != usuario) return Forbid();
        request = request with { Usuario = usuario };
        var idSolicitudPersona = await repository.AgregarPersonaAsync(
            id,
            request,
            cancellationToken);

        return CreatedAtAction(
            nameof(Obtener),
            new { id },
            new IdCreadoResponse(idSolicitudPersona));
    }

    [HttpPost("{id:long}/enviar")]
    [Authorize(Roles = "Solicitante,Administrador")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Enviar(long id, CancellationToken cancellationToken)
    {
        var usuario = CurrentUserId();
        if (usuario is null) return Unauthorized();
        var existing = await repository.ObtenerSolicitudAsync(id, cancellationToken);
        if (existing is null) return NotFound();
        if (!User.IsInRole("Administrador") && existing.IdUsuarioSolicitante != usuario) return Forbid();
        await repository.EnviarSolicitudAsync(id, usuario, cancellationToken);
        return NoContent();
    }

    [HttpPost("personas-areas/{idSolicitudPersonaArea:long}/reenviar-aprobacion")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> ReenviarAprobacion(long idSolicitudPersonaArea, CancellationToken cancellationToken)
    {
        var idUsuarioSolicitante = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuarioSolicitante)) return Unauthorized();

        await repository.ReenviarAprobacionAsync(idSolicitudPersonaArea, idUsuarioSolicitante, cancellationToken);
        return NoContent();
    }

    private string? CurrentUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier);
}
