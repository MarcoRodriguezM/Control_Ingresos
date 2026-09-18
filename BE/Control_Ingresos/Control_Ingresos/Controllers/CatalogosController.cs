using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize]
[Route("api/catalogos")]
public sealed class CatalogosController(ISolicitudesRepository repository) : ControllerBase
{
    private static readonly HashSet<string> Permitidos = new(StringComparer.OrdinalIgnoreCase)
    {
        "estados-generales",
        "tipos-ingreso",
        "estados-solicitud",
        "estados-persona",
        "tipos-documento",
        "tipos-aplicacion",
        "areas",
        "ubicaciones",
        "categorias-requerimiento",
        "requerimientos"
    };

    [HttpGet("{catalogo}")]
    [ProducesResponseType<IReadOnlyCollection<CatalogoItem>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<CatalogoItem>>> Listar(
        string catalogo,
        CancellationToken cancellationToken)
    {
        if (!Permitidos.Contains(catalogo))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Catálogo no válido",
                Detail = $"El catálogo '{catalogo}' no está permitido."
            });
        }

        return Ok(await repository.ListarCatalogoAsync(catalogo, cancellationToken));
    }
}