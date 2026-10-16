using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Control_Ingresos.Data;

public sealed class SqlExceptionHandler(
    IProblemDetailsService problemDetailsService,
    ILogger<SqlExceptionHandler> logger,
    IHostEnvironment environment) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        if (exception is not SqlException sqlException) return false;

        var esReglaNegocio = sqlException.Number is >= 50000 and <= 50999;
        logger.LogError(sqlException, "Error de SQL Server {SqlErrorNumber}", sqlException.Number);
        httpContext.Response.StatusCode = esReglaNegocio
            ? StatusCodes.Status400BadRequest
            : StatusCodes.Status503ServiceUnavailable;

        return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            ProblemDetails = new ProblemDetails
            {
                Status = httpContext.Response.StatusCode,
                Title = esReglaNegocio ? "No se pudo guardar la información" : "Base de datos no disponible",
                Detail = esReglaNegocio || environment.IsDevelopment()
                    ? sqlException.Message
                    : "No fue posible completar la operación en SQL Server."
            },
            Exception = exception
        });
    }
}
