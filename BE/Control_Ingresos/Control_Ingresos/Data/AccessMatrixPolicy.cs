namespace Control_Ingresos.Data;

public static class AccessMatrixPolicy
{
    public static readonly HashSet<string> AreaCodes = new(StringComparer.OrdinalIgnoreCase)
    {
        "CENTRO_INTEGRACION", "TAJO", "BOTADEROS", "MIRADORES", "TALLER_EDI",
        "PAD_POZAS_1_6", "PLANTA_ADR_LABORATORIO", "METALURGIA", "AGLOMERADOR",
        "TRITURACION_PRIMARIA", "TRITURACION_SECUNDARIA", "SUBESTACION",
        "TALLER_MANTENIMIENTO", "ALMACEN", "ASERRADERO", "INCINERADOR",
        "CENTRO_ACOPIO", "VIVERO", "POLVORIN", "REFINERIA"
    };

    public static bool Allows(string? typeCode, string? areaCode)
    {
        if (typeCode is null || areaCode is null || !AreaCodes.Contains(areaCode)) return false;
        return typeCode.ToUpperInvariant() switch
        {
            "VISITA" or "PRACTICANTE" or "SERV_PROF" => areaCode.Equals("CENTRO_INTEGRACION", StringComparison.OrdinalIgnoreCase),
            "PROVEEDOR" => !areaCode.Equals("REFINERIA", StringComparison.OrdinalIgnoreCase),
            "EMPLEADO" or "NUEVO_EMPLEADO" => true,
            _ => false
        };
    }
}
