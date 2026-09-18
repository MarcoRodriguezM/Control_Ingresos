using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

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
        CancellationToken cancellationToken) =>
        Ok(await repository.ListarSolicitudesAsync(cancellationToken));

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
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<IdCreadoResponse>> Crear(
        CrearSolicitudRequest request,
        CancellationToken cancellationToken)
    {
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

    [HttpPut("{id:long}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Actualizar(
        long id,
        CrearSolicitudRequest request,
        CancellationToken cancellationToken)
    {
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
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Eliminar(
        long id,
        [FromQuery] string usuario,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(usuario))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Usuario requerido",
                Detail = "Debe indicar el usuario que elimina la solicitud."
            });
        }

        return await repository.EliminarSolicitudAsync(
            id,
            usuario,
            cancellationToken)
            ? NoContent()
            : NotFound();
    }

    [HttpPost("{id:long}/personas")]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<IdCreadoResponse>> AgregarPersona(
        long id,
        AgregarPersonaSolicitudRequest request,
        CancellationToken cancellationToken)
    {
        var idSolicitudPersona = await repository.AgregarPersonaAsync(
            id,
            request,
            cancellationToken);

        return CreatedAtAction(
            nameof(Obtener),
            new { id },
            new IdCreadoResponse(idSolicitudPersona));
    }
}