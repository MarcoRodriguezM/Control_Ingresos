using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Data;

public sealed class SingularExceptionHandler(
    IProblemDetailsService problemDetailsService,
    ILogger<SingularExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not SingularUnavailableException singularException) return false;

        logger.LogWarning(singularException, "No fue posible completar la consulta en Singular.");
        httpContext.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;

        return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            ProblemDetails = new ProblemDetails
            {
                Status = StatusCodes.Status503ServiceUnavailable,
                Title = "La información de autorizaciones no está disponible",
                Detail = singularException.Message
            },
            Exception = exception
        });
    }
}
