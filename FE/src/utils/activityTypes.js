export const ACTIVITY_ENTRY_TYPES = [
  { code: 'EMPLEADO', label: 'Empleados' },
  { code: 'VISITA', label: 'Visitas' },
  { code: 'PRACTICANTE', label: 'Practicantes' },
  { code: 'SERV_PROF', label: 'Servicios profesionales' },
]

export function activityAppliesToType(activity, typeCode) {
  const allowed = activity.tiposIngreso ?? []
  const normalized = typeCode === 'NUEVO_EMPLEADO' ? 'EMPLEADO' : typeCode
  return allowed.length === 0 || allowed.includes(normalized)
}
