export const MATRIX_AREA_CODES = [
  'CENTRO_INTEGRACION', 'TAJO', 'BOTADEROS', 'MIRADORES', 'TALLER_EDI',
  'PAD_POZAS_1_6', 'PLANTA_ADR_LABORATORIO', 'METALURGIA', 'AGLOMERADOR',
  'TRITURACION_PRIMARIA', 'TRITURACION_SECUNDARIA', 'SUBESTACION',
  'TALLER_MANTENIMIENTO', 'ALMACEN', 'ASERRADERO', 'INCINERADOR',
  'CENTRO_ACOPIO', 'VIVERO', 'POLVORIN', 'REFINERIA',
]

export function areaAvailableForEntry(typeCode, areaCode) {
  const code = String(areaCode ?? '').trim().toUpperCase()
  if (!MATRIX_AREA_CODES.includes(code)) return false
  if (typeCode === 'VISITA' || typeCode === 'PRACTICANTE' || typeCode === 'SERV_PROF') {
    return code === 'CENTRO_INTEGRACION'
  }
  if (typeCode === 'PROVEEDOR') return code !== 'REFINERIA'
  return typeCode === 'EMPLEADO' || typeCode === 'NUEVO_EMPLEADO'
}

export function availableAreasForEntry(typeCode, areas) {
  return areas.filter((area) => areaAvailableForEntry(typeCode, area.codigo))
}

export function areaRequiresApproval(typeCode, areaCode) {
  if (!areaAvailableForEntry(typeCode, areaCode)) return false
  if (typeCode === 'EMPLEADO' || typeCode === 'NUEVO_EMPLEADO') {
    return areaCode === 'POLVORIN' || areaCode === 'REFINERIA'
  }
  return true
}
