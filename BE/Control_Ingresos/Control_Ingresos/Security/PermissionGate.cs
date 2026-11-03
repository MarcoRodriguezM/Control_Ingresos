using Microsoft.AspNetCore.Mvc;

namespace Control_Ingresos.Security;

public static class PermissionGate
{
    public static async Task Invoke(HttpContext context, RequestDelegate next)
    {
        if (context.User.Identity?.IsAuthenticated != true ||
            !context.Request.Path.StartsWithSegments("/api", StringComparison.OrdinalIgnoreCase))
        {
            await next(context);
            return;
        }

        var required = Required(context.Request);
        if (required.Length == 0 || required.Any(permission => AppPermissions.Has(context.User, permission)))
        {
            await next(context);
            return;
        }

        context.Response.StatusCode = StatusCodes.Status403Forbidden;
        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Title = "Permiso requerido",
            Detail = "Tu cuenta no tiene permiso para realizar esta accion.",
            Status = StatusCodes.Status403Forbidden
        });
    }

    private static string[] Required(HttpRequest request)
    {
        var segments = (request.Path.Value ?? "").Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (segments.Length < 2 || !segments[0].Equals("api", StringComparison.OrdinalIgnoreCase)) return [];

        var resource = segments[1].ToLowerInvariant();
        var action = segments.Length > 2 ? segments[2].ToLowerInvariant() : "";
        var method = request.Method;

        if (resource is "autenticacion" or "publico" or "catalogos") return [];
        if (resource == "usuarios") return ["GESTIONAR_USUARIOS"];
        if (resource == "freshservice") return ["VER_FRESHSERVICE"];
        if (resource == "control-accesos") return ["REGISTRAR_INGRESOS"];
        if (resource == "actividad-flujos")
            return HttpMethods.IsGet(method)
                ? ["CREAR_SOLICITUDES", "EDITAR_SOLICITUDES", "GESTIONAR_FLUJOS"]
                : ["GESTIONAR_FLUJOS"];
        if (resource == "aprobaciones")
            return HttpMethods.IsGet(method) ? ["APROBAR_ACCESOS"] : ["APROBAR_ACCESOS"];
        if (resource == "actividades")
        {
            if (HttpMethods.IsGet(method)) return action == "mias" ? ["VER_ACTIVIDADES"] : ["APROBAR_ACTIVIDADES"];
            if (segments.Length > 3 && segments[3].Equals("ticket", StringComparison.OrdinalIgnoreCase)) return ["CREAR_TICKETS"];
            if (segments.Length > 3 && segments[3].Equals("decision", StringComparison.OrdinalIgnoreCase)) return ["APROBAR_ACTIVIDADES"];
            if (segments.Length > 3 && segments[3].Equals("completar", StringComparison.OrdinalIgnoreCase)) return ["COMPLETAR_ACTIVIDADES"];
            return ["GESTIONAR_ACTIVIDADES"];
        }
        if (resource == "empleados")
            return action == "qr" ? ["ESCANEAR_QR"]
                : segments.Last().Equals("fotografia", StringComparison.OrdinalIgnoreCase)
                    ? ["VER_EMPLEADOS", "ESCANEAR_QR"] : ["VER_EMPLEADOS"];
        if (resource == "personas")
        {
            if (HttpMethods.IsGet(method)) return (action == "qr" && segments.Length == 4)
                || segments.Last().Equals("fotografia-contenido", StringComparison.OrdinalIgnoreCase)
                ? ["VER_PERSONAS", "ESCANEAR_QR"] : ["VER_PERSONAS"];
            return action == "fotografia" || segments.Length == 2
                ? ["CREAR_PERSONAS", "REGISTRAR_PERSONAS_PROVEEDOR"] : ["EDITAR_PERSONAS"];
        }
        if (resource == "proveedores")
        {
            if (segments.Length == 2) return ["CREAR_PROVEEDORES"];
            if (HttpMethods.IsGet(method)) return ["VER_PORTAL_PROVEEDOR"];
            return ["REGISTRAR_PERSONAS_PROVEEDOR"];
        }
        if (resource == "solicitudes")
        {
            if (HttpMethods.IsGet(method))
                return action == "formulario-datos" ? ["VER_SOLICITUDES", "CREAR_SOLICITUDES", "EDITAR_SOLICITUDES", "APROBAR_ACCESOS", "GESTIONAR_USUARIOS", "CREAR_PERSONAS"]
                    : segments.Last().Equals("tickets", StringComparison.OrdinalIgnoreCase) ? ["CREAR_TICKETS"]
                    : segments.Length == 2 ? ["VER_SOLICITUDES"]
                    : ["VER_SOLICITUDES", "APROBAR_ACCESOS"];
            if (HttpMethods.IsDelete(method)) return ["ELIMINAR_SOLICITUDES"];
            if (action == "completa" || (segments.Length == 2 && HttpMethods.IsPost(method))) return ["CREAR_SOLICITUDES"];
            if (segments.Last().Equals("enviar", StringComparison.OrdinalIgnoreCase)) return ["ENVIAR_SOLICITUDES"];
            if (segments.Last().Equals("tickets", StringComparison.OrdinalIgnoreCase)) return ["CREAR_TICKETS"];
            return ["EDITAR_SOLICITUDES"];
        }

        return ["GESTIONAR_USUARIOS"];
    }
}
