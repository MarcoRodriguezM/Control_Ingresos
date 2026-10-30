using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Integrations.Freshservice;

public sealed class FreshserviceExceptionHandler(
    IProblemDetailsService problemDetailsService,
    ILogger<FreshserviceExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not FreshserviceIntegrationException freshserviceException) return false;

        logger.LogWarning(
            freshserviceException,
            "No fue posible completar la consulta de solo lectura a Freshservice.");
        httpContext.Response.StatusCode = freshserviceException.StatusCode;

        return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            ProblemDetails = new ProblemDetails
            {
                Status = freshserviceException.StatusCode,
                Title = freshserviceException.Title,
                Detail = freshserviceException.Message
            },
            Exception = exception
        });
    }
}

