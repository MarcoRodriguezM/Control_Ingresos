using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize]
[Route("api/empleados")]
public sealed class EmpleadosController(IEmpleadosRepository repository) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<IReadOnlyCollection<Empleado>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<Empleado>>> Listar(
        CancellationToken cancellationToken)
    {
        return Ok(await repository.ListarAsync(cancellationToken));
    }

    [HttpGet("estados")]
    [ProducesResponseType<IReadOnlyCollection<EmpleadoStatus>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<EmpleadoStatus>>> ListarEstados(
        CancellationToken cancellationToken)
    {
        return Ok(await repository.ListarEstadosAsync(cancellationToken));
    }

    [HttpGet("{codigoEmpleado}/qr")]
    [ProducesResponseType<EmpleadoQrResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<EmpleadoQrResponse>> ObtenerQr(
        string codigoEmpleado,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(codigoEmpleado)) return NotFound();

        var codigoQr = await repository.ObtenerCodigoQrAsync(codigoEmpleado, cancellationToken);
        return string.IsNullOrWhiteSpace(codigoQr)
            ? NotFound()
            : Ok(new EmpleadoQrResponse(codigoQr));
    }

    [HttpGet("qr/{codigoQr}")]
    [ProducesResponseType<Empleado>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<Empleado>> ConsultarQr(
        string codigoQr,
        CancellationToken cancellationToken)
    {
        if (codigoQr.Length != 64 || codigoQr.Any(character => !Uri.IsHexDigit(character)))
            return NotFound();

        var empleado = await repository.ConsultarQrAsync(codigoQr, cancellationToken);
        return empleado is null ? NotFound() : Ok(empleado);
    }

    [HttpGet("{codigoEmpleado}/fotografia")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ObtenerFotografia(
        string codigoEmpleado,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(codigoEmpleado)) return BadRequest();

        var fotografia = await repository.ObtenerFotografiaAsync(codigoEmpleado, cancellationToken);
        if (fotografia is null || fotografia.Length == 0) return NotFound();

        return File(fotografia, DetectarTipoContenido(fotografia));
    }

    private static string DetectarTipoContenido(ReadOnlySpan<byte> contenido)
    {
        if (contenido.Length >= 3 && contenido[0] == 0xFF && contenido[1] == 0xD8 && contenido[2] == 0xFF)
            return "image/jpeg";
        if (contenido.Length >= 8 && contenido[0] == 0x89 && contenido[1] == 0x50 && contenido[2] == 0x4E && contenido[3] == 0x47)
            return "image/png";
        if (contenido.Length >= 6 && contenido[0] == 0x47 && contenido[1] == 0x49 && contenido[2] == 0x46)
            return "image/gif";
        if (contenido.Length >= 2 && contenido[0] == 0x42 && contenido[1] == 0x4D)
            return "image/bmp";
        if (contenido.Length >= 12
            && contenido[0] == 0x52 && contenido[1] == 0x49 && contenido[2] == 0x46 && contenido[3] == 0x46
            && contenido[8] == 0x57 && contenido[9] == 0x45 && contenido[10] == 0x42 && contenido[11] == 0x50)
            return "image/webp";

        return "application/octet-stream";
    }
}
