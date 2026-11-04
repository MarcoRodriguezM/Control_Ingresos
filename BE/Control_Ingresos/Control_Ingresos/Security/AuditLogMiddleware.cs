using System.Security.Claims;
using Control_Ingresos.Services;
using Microsoft.AspNetCore.Routing;

namespace Control_Ingresos.Security;

public static class AuditLogMiddleware
{
    public static async Task Invoke(HttpContext context, RequestDelegate next)
    {
        var path = context.Request.Path;
        var shouldLog = context.User.Identity?.IsAuthenticated == true
            && path.StartsWithSegments("/api", StringComparison.OrdinalIgnoreCase)
            && !path.StartsWithSegments("/api/auditoria", StringComparison.OrdinalIgnoreCase)
            && !path.StartsWithSegments("/api/publico", StringComparison.OrdinalIgnoreCase)
            && !path.StartsWithSegments("/api/catalogos", StringComparison.OrdinalIgnoreCase)
            && !path.Equals("/api/autenticacion/sesion", StringComparison.OrdinalIgnoreCase)
            && path.Value?.Contains("fotografia", StringComparison.OrdinalIgnoreCase) != true;

        if (!shouldLog)
        {
            await next(context);
            return;
        }

        var failed = false;
        try { await next(context); }
        catch { failed = true; throw; }
        finally
        {
            var route = (context.GetEndpoint() as RouteEndpoint)?.RoutePattern.RawText
                ?? (path.Value?.Contains("/qr/", StringComparison.OrdinalIgnoreCase) == true
                    ? "api/qr/{codigo}" : context.Request.Path.Value ?? string.Empty);
            var reference = context.Request.RouteValues
                .Where(item => item.Key is "id" or "idUsuario" or "idPersona" or "idSolicitud"
                    or "idActividad" or "codigoEmpleado" or "idSolicitudPersonaArea")
                .Select(item => $"{item.Key}: {item.Value}")
                .FirstOrDefault();
            var entry = new AuditEntry(Guid.NewGuid(), DateTimeOffset.UtcNow,
                context.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? string.Empty,
                context.User.FindFirstValue(ClaimTypes.Name) ?? string.Empty,
                context.Request.Method, route, reference,
                failed ? StatusCodes.Status500InternalServerError : context.Response.StatusCode);
            try
            {
                await context.RequestServices.GetRequiredService<AuditLogService>()
                    .AppendAsync(entry);
            }
            catch (Exception exception)
            {
                context.RequestServices.GetRequiredService<ILoggerFactory>()
                    .CreateLogger("AuditLog").LogError(exception, "No se pudo registrar la accion en auditoria.");
            }
        }
    }
}
