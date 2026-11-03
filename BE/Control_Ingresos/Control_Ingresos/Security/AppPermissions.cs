using System.Security.Claims;

namespace Control_Ingresos.Security;

public static class AppPermissions
{
    public const string Configured = "PERM_CONFIGURADO";

    public static readonly IReadOnlyList<string> All =
    [
        "VER_SOLICITUDES", "CREAR_SOLICITUDES", "EDITAR_SOLICITUDES",
        "ELIMINAR_SOLICITUDES", "ENVIAR_SOLICITUDES", "APROBAR_ACCESOS",
        "VER_PERSONAS", "CREAR_PERSONAS", "EDITAR_PERSONAS", "VER_EMPLEADOS",
        "VER_ACTIVIDADES", "GESTIONAR_ACTIVIDADES", "COMPLETAR_ACTIVIDADES",
        "APROBAR_ACTIVIDADES", "CREAR_TICKETS", "GESTIONAR_FLUJOS",
        "CREAR_PROVEEDORES", "VER_PORTAL_PROVEEDOR", "REGISTRAR_PERSONAS_PROVEEDOR",
        "ESCANEAR_QR", "REGISTRAR_INGRESOS", "GESTIONAR_USUARIOS", "VER_FRESHSERVICE"
    ];

    private static readonly HashSet<string> Allowed = new(All, StringComparer.OrdinalIgnoreCase);

    public static bool IsKnown(string permission) => Allowed.Contains(permission);

    public static bool Has(ClaimsPrincipal user, string permission)
    {
        if (user.IsInRole("Administrador")) return true;
        if (!IsKnown(permission)) return false;
        if (user.IsInRole(Configured)) return user.IsInRole(permission);

        return LegacyPermissions(user).Contains(permission);
    }

    public static HashSet<string> LegacyPermissions(ClaimsPrincipal user)
    {
        var permissions = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        void Grant(params string[] values) { foreach (var value in values) permissions.Add(value); }

        if (user.IsInRole("Proveedor"))
        {
            Grant("VER_PORTAL_PROVEEDOR", "REGISTRAR_PERSONAS_PROVEEDOR");
            return permissions;
        }
        if (user.IsInRole("Guardia"))
        {
            Grant("ESCANEAR_QR");
            return permissions;
        }

        if (user.IsInRole("Solicitante"))
            Grant("VER_SOLICITUDES", "CREAR_SOLICITUDES", "EDITAR_SOLICITUDES",
                "ELIMINAR_SOLICITUDES", "ENVIAR_SOLICITUDES", "VER_PERSONAS",
                "CREAR_PERSONAS", "EDITAR_PERSONAS", "VER_EMPLEADOS", "VER_ACTIVIDADES",
                "COMPLETAR_ACTIVIDADES", "CREAR_TICKETS", "CREAR_PROVEEDORES", "ESCANEAR_QR");
        if (user.IsInRole("Aprobador"))
            Grant("VER_SOLICITUDES", "APROBAR_ACCESOS", "VER_PERSONAS", "VER_EMPLEADOS",
                "VER_ACTIVIDADES", "GESTIONAR_ACTIVIDADES", "COMPLETAR_ACTIVIDADES",
                "APROBAR_ACTIVIDADES", "ESCANEAR_QR");
        if (user.IsInRole("Responsable"))
            Grant("VER_SOLICITUDES", "VER_ACTIVIDADES", "COMPLETAR_ACTIVIDADES", "ESCANEAR_QR");
        if (user.IsInRole("Seguridad"))
            Grant("VER_PERSONAS", "VER_EMPLEADOS", "ESCANEAR_QR", "REGISTRAR_INGRESOS");
        if (user.IsInRole("Auditor"))
            Grant("VER_SOLICITUDES", "VER_PERSONAS", "VER_EMPLEADOS", "VER_ACTIVIDADES");

        return permissions;
    }
}
