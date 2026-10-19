using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Controllers;

[ApiController]
[AllowAnonymous]
[Route("api/publico/personas")]
public sealed class PersonasPublicasController(
    ISolicitudesRepository repository,
    IWebHostEnvironment environment) : ControllerBase
{
    [HttpGet("qr/{codigoQr}")]
    [ProducesResponseType<PersonaQrDetalle>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PersonaQrDetalle>> ConsultarQr(
        string codigoQr,
        CancellationToken cancellationToken)
    {
        if (!EsCodigoQrValido(codigoQr)) return NotFound();

        var persona = await repository.ConsultarPersonaQrAsync(codigoQr, cancellationToken);
        return persona is null ? NotFound() : Ok(persona);
    }

    [HttpGet("qr/{codigoQr}/fotografia")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ObtenerFotografia(
        string codigoQr,
        CancellationToken cancellationToken)
    {
        if (!EsCodigoQrValido(codigoQr)) return NotFound();

        var persona = await repository.ConsultarPersonaQrAsync(codigoQr, cancellationToken);
        if (persona is null || string.IsNullOrWhiteSpace(persona.FotografiaUrl)) return NotFound();

        var rutaUrl = Uri.TryCreate(persona.FotografiaUrl, UriKind.Absolute, out var uri)
            ? uri.AbsolutePath
            : persona.FotografiaUrl;
        var nombreArchivo = Path.GetFileName(rutaUrl);
        if (string.IsNullOrWhiteSpace(nombreArchivo)) return NotFound();

        var carpeta = Path.GetFullPath(Path.Combine(environment.ContentRootPath, "wwwroot", "uploads", "personas"));
        var rutaArchivo = Path.GetFullPath(Path.Combine(carpeta, nombreArchivo));
        if (!rutaArchivo.StartsWith(carpeta + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)
            || !System.IO.File.Exists(rutaArchivo))
            return NotFound();

        var tipoContenido = Path.GetExtension(rutaArchivo).ToLowerInvariant() switch
        {
            ".jpg" or ".jpeg" => "image/jpeg",
            ".png" => "image/png",
            ".webp" => "image/webp",
            _ => null
        };
        if (tipoContenido is null) return NotFound();

        var contenido = await System.IO.File.ReadAllBytesAsync(rutaArchivo, cancellationToken);
        return File(contenido, tipoContenido);
    }

    private static bool EsCodigoQrValido(string codigoQr) =>
        codigoQr.Length == 64 && codigoQr.All(Uri.IsHexDigit);
}
