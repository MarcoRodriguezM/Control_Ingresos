using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize]
[Route("api/personas")]
public sealed class PersonasController(
    ISolicitudesRepository repository,
    IWebHostEnvironment environment) : ControllerBase
{
    private const long MaximoFotografiaBytes = 5 * 1024 * 1024;

    [HttpGet]
    [ProducesResponseType<IReadOnlyCollection<PersonaResumen>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<PersonaResumen>>> Listar(
        CancellationToken cancellationToken) =>
        Ok(await repository.ListarPersonasAsync(cancellationToken));

    [HttpGet("accesos")]
    [ProducesResponseType<IReadOnlyCollection<PersonaResumen>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<PersonaResumen>>> ListarConAccesos(
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        return Ok(await repository.ListarPersonasConAccesosAsync(usuario, cancellationToken));
    }

    [HttpGet("{id:long}/accesos")]
    [ProducesResponseType<PersonaConAccesos>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PersonaConAccesos>> ObtenerAccesos(
        long id,
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        var persona = await repository.ObtenerPersonaAccesosAsync(id, usuario, cancellationToken);

        return persona is null
            ? NotFound()
            : Ok(persona);
    }

    [HttpGet("{id:long}/qr")]
    [ProducesResponseType<PersonaQrResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PersonaQrResponse>> ObtenerQr(
        long id,
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();

        var codigo = await repository.ObtenerCodigoQrPersonaAsync(id, usuario, cancellationToken);
        return string.IsNullOrWhiteSpace(codigo)
            ? NotFound()
            : Ok(new PersonaQrResponse(codigo));
    }

    [HttpGet("{id:long}/fotografia-contenido")]
    [ProducesResponseType<FotografiaContenidoResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<FotografiaContenidoResponse>> ObtenerFotografiaContenido(
        long id,
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();

        var persona = await repository.ObtenerPersonaAccesosAsync(id, usuario, cancellationToken);
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
        var dataUrl = $"data:{tipoContenido};base64,{Convert.ToBase64String(contenido)}";
        return Ok(new FotografiaContenidoResponse(dataUrl));
    }

    [HttpGet("qr/{codigoQr}")]
    [ProducesResponseType<PersonaQrDetalle>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PersonaQrDetalle>> ConsultarQr(
        string codigoQr,
        CancellationToken cancellationToken)
    {
        if (codigoQr.Length != 64 || codigoQr.Any(character => !Uri.IsHexDigit(character)))
            return NotFound();

        var persona = await repository.ConsultarPersonaQrAsync(codigoQr, cancellationToken);
        return persona is null ? NotFound() : Ok(persona);
    }

    [HttpPost]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<IdCreadoResponse>> Crear(
        CrearPersonaRequest request,
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();
        request = request with { Usuario = usuario };
        var id = await repository.CrearPersonaAsync(request, cancellationToken);

        return Created(
            $"/api/personas/{id}",
            new IdCreadoResponse(id));
    }

    [HttpPost("fotografia")]
    [RequestSizeLimit(6 * 1024 * 1024)]
    [RequestFormLimits(MultipartBodyLengthLimit = 6 * 1024 * 1024)]
    [ProducesResponseType<FotografiaSubidaResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<FotografiaSubidaResponse>> SubirFotografia(
        [FromForm] IFormFile? archivo,
        CancellationToken cancellationToken)
    {
        try
        {
            var fotografia = await GuardarFotografiaAsync(archivo, cancellationToken);
            return Created(fotografia.RutaPublica, new FotografiaSubidaResponse(fotografia.Url));
        }
        catch (InvalidDataException exception)
        {
            return Problem(
                statusCode: StatusCodes.Status400BadRequest,
                title: "Fotografía no válida",
                detail: exception.Message);
        }
    }

    [HttpPost("{id:long}/fotografia")]
    [RequestSizeLimit(6 * 1024 * 1024)]
    [RequestFormLimits(MultipartBodyLengthLimit = 6 * 1024 * 1024)]
    [ProducesResponseType<FotografiaSubidaResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<FotografiaSubidaResponse>> ActualizarFotografia(
        long id,
        [FromForm] IFormFile? archivo,
        CancellationToken cancellationToken)
    {
        var usuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(usuario)) return Unauthorized();

        FotografiaGuardada fotografia;
        try
        {
            fotografia = await GuardarFotografiaAsync(archivo, cancellationToken);
        }
        catch (InvalidDataException exception)
        {
            return Problem(
                statusCode: StatusCodes.Status400BadRequest,
                title: "Fotografía no válida",
                detail: exception.Message);
        }

        try
        {
            var actualizada = await repository.ActualizarFotografiaPersonaAsync(
                id,
                fotografia.Url,
                usuario,
                cancellationToken);

            if (!actualizada)
            {
                System.IO.File.Delete(fotografia.RutaArchivo);
                return NotFound();
            }

            return Ok(new FotografiaSubidaResponse(fotografia.Url));
        }
        catch
        {
            if (System.IO.File.Exists(fotografia.RutaArchivo))
                System.IO.File.Delete(fotografia.RutaArchivo);
            throw;
        }
    }

    private async Task<FotografiaGuardada> GuardarFotografiaAsync(
        IFormFile? archivo,
        CancellationToken cancellationToken)
    {
        if (archivo is null || archivo.Length == 0)
            throw new InvalidDataException("Selecciona una fotografía para continuar.");

        if (archivo.Length > MaximoFotografiaBytes)
            throw new InvalidDataException("La fotografía no puede superar los 5 MB.");

        await using var origen = archivo.OpenReadStream();
        var extension = await DetectarExtensionImagenAsync(origen, cancellationToken);
        if (extension is null)
            throw new InvalidDataException("La fotografía debe estar en formato JPG, PNG o WebP.");

        origen.Position = 0;

        var nombreArchivo = $"{Guid.NewGuid():N}{extension}";
        var carpeta = Path.Combine(environment.ContentRootPath, "wwwroot", "uploads", "personas");
        Directory.CreateDirectory(carpeta);

        var rutaArchivo = Path.Combine(carpeta, nombreArchivo);
        try
        {
            await using var destino = new FileStream(
                rutaArchivo,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                bufferSize: 81920,
                useAsync: true);

            await origen.CopyToAsync(destino, cancellationToken);
        }
        catch
        {
            if (System.IO.File.Exists(rutaArchivo))
            {
                System.IO.File.Delete(rutaArchivo);
            }

            throw;
        }

        var rutaPublica = $"/uploads/personas/{nombreArchivo}";
        var url = $"{Request.Scheme}://{Request.Host}{Request.PathBase}{rutaPublica}";
        return new FotografiaGuardada(url, rutaPublica, rutaArchivo);
    }

    private sealed record FotografiaGuardada(string Url, string RutaPublica, string RutaArchivo);

    private static async Task<string?> DetectarExtensionImagenAsync(
        Stream stream,
        CancellationToken cancellationToken)
    {
        var encabezado = new byte[12];
        var leidos = await stream.ReadAsync(encabezado.AsMemory(), cancellationToken);

        if (leidos >= 3
            && encabezado[0] == 0xFF
            && encabezado[1] == 0xD8
            && encabezado[2] == 0xFF)
        {
            return ".jpg";
        }

        if (leidos >= 8
            && encabezado[0] == 0x89
            && encabezado[1] == 0x50
            && encabezado[2] == 0x4E
            && encabezado[3] == 0x47
            && encabezado[4] == 0x0D
            && encabezado[5] == 0x0A
            && encabezado[6] == 0x1A
            && encabezado[7] == 0x0A)
        {
            return ".png";
        }

        if (leidos >= 12
            && encabezado[0] == 0x52
            && encabezado[1] == 0x49
            && encabezado[2] == 0x46
            && encabezado[3] == 0x46
            && encabezado[8] == 0x57
            && encabezado[9] == 0x45
            && encabezado[10] == 0x42
            && encabezado[11] == 0x50)
        {
            return ".webp";
        }

        return null;
    }
}
