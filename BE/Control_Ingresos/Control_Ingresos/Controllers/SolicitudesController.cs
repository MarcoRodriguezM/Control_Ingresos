using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize]
[Route("api/solicitudes")]
public sealed class SolicitudesController(
    ISolicitudesRepository repository,
    IEmpleadosRepository empleadosRepository,
    ILogger<SolicitudesController> logger) : ControllerBase

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

        if (solicitud is null) return NotFound();

        return Ok(await CompletarEmpleadosHtisAsync(solicitud, cancellationToken));
    }

    [HttpGet("{id:long}/tickets")]
    [Authorize(Roles = "Solicitante,Administrador")]
    [ProducesResponseType<IReadOnlyCollection<TicketSolicitudResumen>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<TicketSolicitudResumen>>> ListarTickets(long id, CancellationToken cancellationToken)
    {
        var usuario = CurrentUserId();
        if (usuario is null) return Unauthorized();
        var solicitud = await repository.ObtenerSolicitudAsync(id, cancellationToken);
        if (solicitud is null) return NotFound();
        if (solicitud.IdUsuarioSolicitante != usuario) return Forbid();
        return Ok(await repository.ListarTicketsSolicitudAsync(id, usuario, cancellationToken));
    }

    [HttpGet("{id:long}/seguimiento")]
    [ProducesResponseType<SeguimientoSolicitud>(StatusCodes.Status200OK)]
    public async Task<ActionResult<SeguimientoSolicitud>> ObtenerSeguimiento(long id, CancellationToken cancellationToken)
    {
        var usuario = CurrentUserId();
        if (usuario is null) return Unauthorized();
        var accesoTotal = User.IsInRole("Administrador") || User.IsInRole("Aprobador");
        var seguimiento = await repository.ObtenerSeguimientoSolicitudAsync(id, usuario, accesoTotal, cancellationToken);
        return seguimiento is null ? NotFound() : Ok(seguimiento with
        {
            Solicitud = await CompletarEmpleadosHtisAsync(seguimiento.Solicitud, cancellationToken)
        });
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
        request = await NormalizarYValidarSolicitudAsync(request, cancellationToken);
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
        var solicitudNormalizada = await NormalizarYValidarSolicitudAsync(
            request.Solicitud with { IdEstadoSolicitud = null, IdUsuarioSolicitante = idUsuario, Usuario = idUsuario },
            cancellationToken);
        await ValidarIntegrantesAsync(solicitudNormalizada.IdTipoIngreso, request.Personas, cancellationToken);

        if (!ModelState.IsValid)
            return ValidationProblem(ModelState);

        if (solicitudNormalizada.FechaInicio.HasValue && solicitudNormalizada.FechaFin < solicitudNormalizada.FechaInicio)
        {
            ModelState.AddModelError("fechaFin", "La fecha final no puede ser anterior a la fecha inicial.");
            return ValidationProblem(ModelState);
        }

        var normalized = request with
        {
            Solicitud = solicitudNormalizada,
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
        request = await NormalizarYValidarSolicitudAsync(request, cancellationToken);
        await ValidarCambioDeTipoAsync(request.IdTipoIngreso, existing.Personas, cancellationToken);
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
        await ValidarIntegrantesAsync(existing.IdTipoIngreso, [request], cancellationToken);
        if (!ModelState.IsValid) return ValidationProblem(ModelState);
        var idSolicitudPersona = await repository.AgregarPersonaAsync(
            id,
            request,
            cancellationToken);

        return CreatedAtAction(
            nameof(Obtener),
            new { id },
            new IdCreadoResponse(idSolicitudPersona));
    }

    [HttpPost("{id:long}/empleados")]
    [Authorize(Roles = "Solicitante,Administrador")]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IdCreadoResponse>> AgregarEmpleado(
        long id,
        AgregarEmpleadoSolicitudRequest request,
        CancellationToken cancellationToken)
    {
        var usuario = CurrentUserId();
        if (usuario is null) return Unauthorized();
        var existing = await repository.ObtenerSolicitudAsync(id, cancellationToken);
        if (existing is null) return NotFound();
        if (!User.IsInRole("Administrador") && existing.IdUsuarioSolicitante != usuario) return Forbid();

        var codigo = request.CodigoEmpleado.Trim();
        var empleado = (await empleadosRepository.ListarAsync(cancellationToken)).FirstOrDefault(item =>
            string.Equals(item.CodigoEmpleado?.Trim(), codigo, StringComparison.OrdinalIgnoreCase));
        if (empleado is null) return NotFound();

        var idSolicitudPersona = await repository.AgregarEmpleadoAsync(
            id,
            empleado,
            request with { CodigoEmpleado = codigo },
            usuario,
            cancellationToken);

        return CreatedAtAction(nameof(Obtener), new { id }, new IdCreadoResponse(idSolicitudPersona));
    }

    [HttpPut("{id:long}/personas/{idSolicitudPersona:long}/areas")]
    [Authorize(Roles = "Solicitante,Administrador")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> AsignarAreasPersona(
        long id,
        long idSolicitudPersona,
        AsignarAreasPersonaSolicitudRequest request,
        CancellationToken cancellationToken)
    {
        var usuario = CurrentUserId();
        if (usuario is null) return Unauthorized();
        var existing = await repository.ObtenerSolicitudAsync(id, cancellationToken);
        if (existing is null) return NotFound();
        if (!User.IsInRole("Administrador") && existing.IdUsuarioSolicitante != usuario) return Forbid();
        await repository.AsignarAreasPersonaAsync(
            id,
            idSolicitudPersona,
            request.Areas,
            request.Requerimientos,
            request.Flujos,
            usuario,
            cancellationToken);
        return NoContent();
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
        await ValidarEmpleadosAsociadosActivosAsync(existing, cancellationToken);
        if (!ModelState.IsValid) return ValidationProblem(ModelState);
        await repository.EnviarSolicitudAsync(id, usuario, cancellationToken);
        return NoContent();
    }

    [HttpPost("personas-areas/{idSolicitudPersonaArea:long}/reenviar-aprobacion")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> ReenviarAprobacion(long idSolicitudPersonaArea, ReenviarAprobacionRequest request, CancellationToken cancellationToken)
    {
        var idUsuarioSolicitante = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuarioSolicitante)) return Unauthorized();

        if (string.IsNullOrWhiteSpace(request.Justificacion))
            return BadRequest(new ProblemDetails { Detail = "La justificacion es obligatoria." });
        await repository.ReenviarAprobacionAsync(idSolicitudPersonaArea, idUsuarioSolicitante, request.Justificacion.Trim(), cancellationToken);
        return NoContent();
    }

    private string? CurrentUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier);

    private async Task<CrearSolicitudRequest> NormalizarYValidarSolicitudAsync(
        CrearSolicitudRequest request,
        CancellationToken cancellationToken)
    {
        var codigoTipo = await ObtenerCodigoTipoIngresoAsync(request.IdTipoIngreso, cancellationToken);
        var esEmpleado = EsTipo(codigoTipo, "EMPLEADO");
        var esNuevoEmpleado = EsTipo(codigoTipo, "NUEVO_EMPLEADO");

        if (esEmpleado || esNuevoEmpleado)
            request = request with { IdProveedor = null };

        if (esEmpleado)
            return request with { ContactoProveedor = null, CorreoProveedor = null };

        if (string.IsNullOrWhiteSpace(request.ContactoProveedor))
            ModelState.AddModelError(nameof(request.ContactoProveedor),
                esNuevoEmpleado ? "El nombre del nuevo empleado es obligatorio." : "El contacto del proveedor es obligatorio.");
        if (string.IsNullOrWhiteSpace(request.CorreoProveedor))
            ModelState.AddModelError(nameof(request.CorreoProveedor),
                esNuevoEmpleado ? "El correo del nuevo empleado es obligatorio." : "El correo del proveedor es obligatorio.");

        return request;
    }

    private async Task ValidarIntegrantesAsync(
        short? idTipoIngreso,
        IReadOnlyCollection<AgregarPersonaSolicitudRequest>? integrantes,
        CancellationToken cancellationToken)
    {
        var items = integrantes ?? [];
        var codigoTipo = await ObtenerCodigoTipoIngresoAsync(idTipoIngreso, cancellationToken);
        var esEmpleado = EsTipo(codigoTipo, "EMPLEADO");

        if (!esEmpleado)
        {
            if (items.Any(item => !item.IdPersona.HasValue || !string.IsNullOrWhiteSpace(item.CodigoEmpleadoHtis)))
                ModelState.AddModelError(nameof(integrantes),
                    "Este tipo de ingreso solamente permite personas registradas en Control Ingresos.");
            return;
        }

        if (items.Any(item => item.IdPersona.HasValue || string.IsNullOrWhiteSpace(item.CodigoEmpleadoHtis)))
        {
            ModelState.AddModelError(nameof(integrantes),
                "Las solicitudes de empleados solamente permiten empleados seleccionados desde HTIS.");
            return;
        }

        var codigos = items.Select(item => item.CodigoEmpleadoHtis!.Trim()).ToArray();
        if (codigos.Length != codigos.Distinct(StringComparer.OrdinalIgnoreCase).Count())
        {
            ModelState.AddModelError(nameof(integrantes), "No puedes agregar dos veces al mismo empleado.");
            return;
        }

        var empleadosActivos = await empleadosRepository.ObtenerPorCodigosAsync(
            codigos,
            soloActivos: true,
            cancellationToken: cancellationToken);
        var noDisponibles = codigos.Where(codigo => !empleadosActivos.ContainsKey(codigo)).ToArray();
        if (noDisponibles.Length > 0)
            ModelState.AddModelError(nameof(integrantes),
                $"Los siguientes empleados no existen o no están activos en HTIS: {string.Join(", ", noDisponibles)}.");
    }

    private async Task ValidarCambioDeTipoAsync(
        short? idTipoIngreso,
        IReadOnlyCollection<PersonaSolicitudDetalle> integrantes,
        CancellationToken cancellationToken)
    {
        var codigoTipo = await ObtenerCodigoTipoIngresoAsync(idTipoIngreso, cancellationToken);
        var esEmpleado = EsTipo(codigoTipo, "EMPLEADO");
        var contieneEmpleados = integrantes.Any(item => !string.IsNullOrWhiteSpace(item.CodigoEmpleadoHtis));
        var contienePersonas = integrantes.Any(item => item.IdPersona.HasValue);

        if ((esEmpleado && contienePersonas) || (!esEmpleado && contieneEmpleados))
            ModelState.AddModelError(nameof(idTipoIngreso),
                "No se puede cambiar el tipo de ingreso porque la solicitud ya contiene integrantes de otro origen.");
    }

    private async Task<string?> ObtenerCodigoTipoIngresoAsync(
        short? idTipoIngreso,
        CancellationToken cancellationToken)
    {
        if (!idTipoIngreso.HasValue) return null;
        var datos = await repository.ObtenerDatosFormularioSolicitudAsync(cancellationToken);
        return datos.TiposIngreso
            .FirstOrDefault(tipo => tipo.Id == idTipoIngreso.Value)?.Codigo;
    }

    private async Task<SolicitudDetalle> CompletarEmpleadosHtisAsync(
        SolicitudDetalle solicitud,
        CancellationToken cancellationToken)
    {
        var codigos = solicitud.Personas
            .Select(item => item.CodigoEmpleadoHtis)
            .Where(codigo => !string.IsNullOrWhiteSpace(codigo))
            .Select(codigo => codigo!)
            .ToArray();
        if (codigos.Length == 0) return solicitud;

        try
        {
            var empleados = await empleadosRepository.ObtenerPorCodigosAsync(
                codigos,
                soloActivos: false,
                cancellationToken: cancellationToken);
            return solicitud with
            {
                Personas = solicitud.Personas.Select(item =>
                {
                    if (item.CodigoEmpleadoHtis is null
                        || !empleados.TryGetValue(item.CodigoEmpleadoHtis.Trim(), out var empleado))
                        return item;
                    return item with
                    {
                        NombreCompleto = empleado.NombreCompleto,
                        NumeroDocumento = empleado.Nit ?? empleado.CodigoEmpleado
                    };
                }).ToArray()
            };
        }
        catch (HtisUnavailableException exception)
        {
            logger.LogWarning(exception,
                "La solicitud {IdSolicitud} se devolverá usando únicamente los códigos HTIS.",
                solicitud.IdSolicitud);
            return solicitud;
        }
    }

    private async Task ValidarEmpleadosAsociadosActivosAsync(
        SolicitudDetalle solicitud,
        CancellationToken cancellationToken)
    {
        var codigoTipo = await ObtenerCodigoTipoIngresoAsync(solicitud.IdTipoIngreso, cancellationToken);
        if (!EsTipo(codigoTipo, "EMPLEADO")) return;

        var codigos = solicitud.Personas
            .Select(item => item.CodigoEmpleadoHtis)
            .Where(codigo => !string.IsNullOrWhiteSpace(codigo))
            .Select(codigo => codigo!.Trim())
            .ToArray();
        if (codigos.Length == 0) return;

        var empleadosActivos = await empleadosRepository.ObtenerPorCodigosAsync(
            codigos,
            soloActivos: true,
            cancellationToken: cancellationToken);
        var inactivos = codigos.Where(codigo => !empleadosActivos.ContainsKey(codigo)).ToArray();
        if (inactivos.Length > 0)
            ModelState.AddModelError(nameof(solicitud.Personas),
                $"No se puede enviar la solicitud porque estos empleados ya no están activos en HTIS: {string.Join(", ", inactivos)}.");
    }

    private static bool EsTipo(string? codigoActual, string codigoEsperado) =>
        string.Equals(codigoActual?.Trim(), codigoEsperado, StringComparison.OrdinalIgnoreCase);
}
