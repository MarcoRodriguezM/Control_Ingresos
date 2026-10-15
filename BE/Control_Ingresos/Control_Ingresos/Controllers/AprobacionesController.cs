using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Control_Ingresos.Controllers;

[ApiController]
[Authorize(Roles = "Aprobador,Administrador")]
[Route("api/aprobaciones")]
public sealed class AprobacionesController(
    ISolicitudesRepository repository,
    IEmpleadosRepository empleadosRepository,
    ILogger<AprobacionesController> logger) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<IReadOnlyCollection<AprobacionResumen>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<AprobacionResumen>>> Listar(CancellationToken cancellationToken)
    {
        var idUsuarioAprobador = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuarioAprobador)) return Unauthorized();

        var aprobaciones = await repository.ListarAprobacionesAsync(idUsuarioAprobador, cancellationToken);
        var codigos = aprobaciones
            .Select(item => item.CodigoEmpleadoHtis)
            .Where(codigo => !string.IsNullOrWhiteSpace(codigo))
            .Select(codigo => codigo!)
            .ToArray();
        if (codigos.Length == 0) return Ok(aprobaciones);

        try
        {
            var empleados = await empleadosRepository.ObtenerPorCodigosAsync(
                codigos,
                soloActivos: false,
                cancellationToken: cancellationToken);
            return Ok(aprobaciones.Select(item =>
            {
                if (item.CodigoEmpleadoHtis is null
                    || !empleados.TryGetValue(item.CodigoEmpleadoHtis.Trim(), out var empleado))
                    return item;
                return item with
                {
                    Persona = empleado.NombreCompleto,
                    NumeroDocumento = empleado.Nit ?? empleado.CodigoEmpleado,
                    Empresa = empleado.Departamento
                };
            }).ToArray());
        }
        catch (HtisUnavailableException exception)
        {
            logger.LogWarning(exception,
                "Las aprobaciones se devolverán usando únicamente los códigos HTIS.");
            return Ok(aprobaciones);
        }
    }

    [HttpPut("{idSolicitudPersonaArea:long}/decision")]
    [ProducesResponseType<IdCreadoResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IdCreadoResponse>> Decidir(
        long idSolicitudPersonaArea,
        DecidirAprobacionRequest request,
        CancellationToken cancellationToken)
    {
        var idUsuarioAprobador = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuarioAprobador)) return Unauthorized();

        var id = await repository.DecidirAprobacionAsync(idSolicitudPersonaArea, idUsuarioAprobador, request, cancellationToken);
        return Ok(new IdCreadoResponse(id));
    }
}
