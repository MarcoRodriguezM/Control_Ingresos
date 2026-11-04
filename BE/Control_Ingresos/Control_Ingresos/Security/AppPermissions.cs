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
        => Has(user.FindAll(ClaimTypes.Role).Select(claim => claim.Value), permission);

    public static bool Has(IEnumerable<string> roleNames, string permission)
    {
        if (!IsKnown(permission)) return false;
        var roles = roleNames
            .Select(role => role.Trim())
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        if (roles.Contains(Configured)) return roles.Contains(permission);
        if (roles.Contains("Administrador")) return true;

        return LegacyPermissions(roles).Contains(permission);
    }

    public static HashSet<string> LegacyPermissions(IReadOnlySet<string> roles)
    {
        var permissions = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        void Grant(params string[] values) { foreach (var value in values) permissions.Add(value); }

        if (roles.Contains("Proveedor"))
        {
            Grant("VER_PORTAL_PROVEEDOR", "REGISTRAR_PERSONAS_PROVEEDOR");
            return permissions;
        }
        if (roles.Contains("Guardia"))
        {
            Grant("ESCANEAR_QR");
            return permissions;
        }

        if (roles.Contains("Solicitante"))
            Grant("VER_SOLICITUDES", "CREAR_SOLICITUDES", "EDITAR_SOLICITUDES",
                "ELIMINAR_SOLICITUDES", "ENVIAR_SOLICITUDES", "VER_PERSONAS",
                "CREAR_PERSONAS", "EDITAR_PERSONAS", "VER_EMPLEADOS", "VER_ACTIVIDADES",
                "COMPLETAR_ACTIVIDADES", "CREAR_TICKETS", "CREAR_PROVEEDORES", "ESCANEAR_QR");
        if (roles.Contains("Aprobador"))
            Grant("VER_SOLICITUDES", "APROBAR_ACCESOS", "VER_PERSONAS", "VER_EMPLEADOS",
                "VER_ACTIVIDADES", "GESTIONAR_ACTIVIDADES", "COMPLETAR_ACTIVIDADES",
                "APROBAR_ACTIVIDADES", "ESCANEAR_QR");
        if (roles.Contains("Responsable"))
            Grant("VER_SOLICITUDES", "VER_ACTIVIDADES", "COMPLETAR_ACTIVIDADES", "ESCANEAR_QR");
        if (roles.Contains("Seguridad"))
            Grant("VER_PERSONAS", "VER_EMPLEADOS", "ESCANEAR_QR", "REGISTRAR_INGRESOS");
        if (roles.Contains("Auditor"))
            Grant("VER_SOLICITUDES", "VER_PERSONAS", "VER_EMPLEADOS", "VER_ACTIVIDADES");

        return permissions;
    }
}
