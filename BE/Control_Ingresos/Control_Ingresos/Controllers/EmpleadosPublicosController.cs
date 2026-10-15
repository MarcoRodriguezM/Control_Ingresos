using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Controllers;

[ApiController]
[AllowAnonymous]
[Route("api/publico/empleados")]
public sealed class EmpleadosPublicosController(
    IEmpleadosRepository empleadosRepository,
    IEmpleadoSingularRepository singularRepository,
    ILogger<EmpleadosPublicosController> logger) : ControllerBase
{
    [HttpGet("qr/{codigoQr}")]
    [ProducesResponseType<EmpleadoCredencialPublica>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<EmpleadoCredencialPublica>> ConsultarQr(
        string codigoQr,
        CancellationToken cancellationToken)
    {
        if (!EsCodigoQrValido(codigoQr)) return NotFound();

        var codigoEmpleado = await empleadosRepository.ResolverCodigoEmpleadoQrAsync(codigoQr, cancellationToken);
        if (string.IsNullOrWhiteSpace(codigoEmpleado)) return NotFound();

        var consultaHtis = ConsultarHtisAsync(codigoEmpleado, cancellationToken);
        var consultaSingular = ConsultarSingularAsync(codigoEmpleado, cancellationToken);
        await Task.WhenAll(consultaHtis, consultaSingular);

        var resultadoHtis = await consultaHtis;
        var resultadoSingular = await consultaSingular;
        var empleado = resultadoHtis.Empleado;
        var singular = resultadoSingular.Informacion;
        var avisos = new[] { resultadoHtis.Aviso, resultadoSingular.Aviso }
            .Where(aviso => !string.IsNullOrWhiteSpace(aviso));

        var autorizacion = singular?.Autorizacion;
        return Ok(new EmpleadoCredencialPublica(
            codigoEmpleado,
            autorizacion?.Nombre ?? empleado?.NombreCompleto,
            autorizacion?.Empresa,
            autorizacion?.Area ?? empleado?.Departamento,
            autorizacion?.Cargo ?? empleado?.CargoNivel,
            autorizacion?.TipoSangre ?? empleado?.TipoSangre,
            autorizacion?.NumeroLicencia,
            autorizacion?.CategoriaLicencia,
            autorizacion?.ValidezLicencia,
            autorizacion?.ValidezAso,
            null,
            empleado?.DescripcionStatus ?? empleado?.CodigoStatus ?? autorizacion?.Estado,
            singular?.Entrenamientos ?? Array.Empty<EmpleadoEntrenamientoSingular>(),
            resultadoHtis.Disponible,
            resultadoSingular.Disponible,
            string.Join(" ", avisos)));
    }

    [HttpGet("qr/{codigoQr}/fotografia")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ObtenerFotografia(
        string codigoQr,
        CancellationToken cancellationToken)
    {
        if (!EsCodigoQrValido(codigoQr)) return NotFound();

        var codigoEmpleado = await empleadosRepository.ResolverCodigoEmpleadoQrAsync(codigoQr, cancellationToken);
        if (string.IsNullOrWhiteSpace(codigoEmpleado)) return NotFound();

        var fotografia = await empleadosRepository.ObtenerFotografiaAsync(codigoEmpleado, cancellationToken);
        if (fotografia is null || fotografia.Length == 0) return NotFound();

        return File(fotografia, DetectarTipoContenido(fotografia));
    }

    private async Task<(Empleado? Empleado, bool Disponible, string? Aviso)> ConsultarHtisAsync(
        string codigoEmpleado,
        CancellationToken cancellationToken)
    {
        try
        {
            var empleado = await empleadosRepository.ConsultarPorCodigoAsync(codigoEmpleado, cancellationToken);
            return (empleado, true, null);
        }
        catch (HtisUnavailableException exception)
        {
            logger.LogWarning(exception, "La credencial pública se entregará sin los datos de HTIS.");
            return (null, false, "La información laboral y la fotografía de HTIS no están disponibles temporalmente.");
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogError(exception, "Ocurrió un error inesperado al consultar HTIS para la credencial pública.");
            return (null, false, "La información laboral y la fotografía de HTIS no están disponibles temporalmente.");
        }
    }

    private async Task<(EmpleadoInformacionSingular? Informacion, bool Disponible, string? Aviso)> ConsultarSingularAsync(
        string codigoEmpleado,
        CancellationToken cancellationToken)
    {
        try
        {
            var informacion = await singularRepository.ObtenerAsync(codigoEmpleado, cancellationToken);
            return (informacion, true, null);
        }
        catch (SingularUnavailableException exception)
        {
            logger.LogWarning(exception, "La credencial pública se entregará sin los datos de Singular.");
            return (null, false, "Las autorizaciones y los entrenamientos de Singular no están disponibles temporalmente.");
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogError(exception, "Ocurrió un error inesperado al consultar Singular para la credencial pública.");
            return (null, false, "Las autorizaciones y los entrenamientos de Singular no están disponibles temporalmente.");
        }
    }

    private static bool EsCodigoQrValido(string codigoQr) =>
        codigoQr.Length == 64 && codigoQr.All(Uri.IsHexDigit);

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
