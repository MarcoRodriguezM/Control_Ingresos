using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Data;

public sealed class HtisExceptionHandler(
    IProblemDetailsService problemDetailsService,
    ILogger<HtisExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not HtisUnavailableException htisException) return false;

        logger.LogWarning(htisException, "No fue posible completar la consulta en HTIS.");
        httpContext.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;

        return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            ProblemDetails = new ProblemDetails
            {
                Status = StatusCodes.Status503ServiceUnavailable,
                Title = "HTIS no está disponible",
                Detail = htisException.Message
            },
            Exception = exception
        });
    }
}
