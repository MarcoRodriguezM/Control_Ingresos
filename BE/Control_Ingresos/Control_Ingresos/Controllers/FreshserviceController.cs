using Control_Ingresos.Integrations.Freshservice;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize(Roles = "Administrador")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
[Route("api/freshservice")]
public sealed class FreshserviceController(IFreshserviceReadOnlyClient client) : ControllerBase
{
    [HttpGet("catalogo")]
    [ProducesResponseType<FreshserviceCatalogPage>(StatusCodes.Status200OK)]
    public async Task<ActionResult<FreshserviceCatalogPage>> ListCatalog(
        [FromQuery] int page = 1,
        [FromQuery] int perPage = 30,
        [FromQuery] int? workspaceId = null,
        CancellationToken cancellationToken = default)
    {
        if (page < 1 || perPage is < 1 or > 30 || workspaceId is <= 0)
            return ValidationProblem("La página debe ser mayor que cero, perPage debe estar entre 1 y 30 y el workspace debe ser positivo.");

        return Ok(await client.ListCatalogAsync(page, perPage, workspaceId, cancellationToken));
    }

    [HttpGet("catalogo/{displayId:long}")]
    [ProducesResponseType<FreshserviceServiceItemForm>(StatusCodes.Status200OK)]
    public async Task<ActionResult<FreshserviceServiceItemForm>> GetServiceItem(
        long displayId,
        [FromQuery] int? workspaceId = null,
        CancellationToken cancellationToken = default)
    {
        if (displayId <= 0 || workspaceId is <= 0)
            return ValidationProblem("El display_id debe ser mayor que cero y el workspace debe ser positivo.");

        return Ok(await client.GetServiceItemAsync(displayId, workspaceId, cancellationToken));
    }
}

