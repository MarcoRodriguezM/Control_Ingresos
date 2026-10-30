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

export function activityIsAutomaticForType(activity, typeCode) {
  const normalized = typeCode === 'NUEVO_EMPLEADO' ? 'EMPLEADO' : typeCode
  return (activity.tiposIngresoAutomaticos ?? []).includes(normalized)
}

export function includeRequiredFlowVersions(selectedVersionIds, activityAreas) {
  const flows = activityAreas.flatMap((area) => area.flujos ?? [])
  const byVersion = new Map(flows.map((flow) => [Number(flow.idActividadFlujoVersion), flow]))
  const currentByFlow = new Map(flows
    .filter((flow) => flow.esVersionActual !== false)
    .map((flow) => [Number(flow.idActividadFlujo), flow]))
  const selected = new Set((selectedVersionIds ?? []).map(Number))
  const pending = [...selected]
  while (pending.length > 0) {
    const flow = byVersion.get(pending.pop())
    if (!flow) continue
    for (const dependency of (flow.pasos ?? []).flatMap((step) => step.dependenciasExternas ?? [])) {
      const requiredFlow = currentByFlow.get(Number(dependency.idActividadFlujo))
      const requiredVersion = Number(requiredFlow?.idActividadFlujoVersion)
      if (!requiredVersion || selected.has(requiredVersion)) continue
      selected.add(requiredVersion)
      pending.push(requiredVersion)
    }
  }
  return [...selected]
}

export function flowIsRequiredBySelection(idActividadFlujoVersion, selectedVersionIds, activityAreas) {
  const target = Number(idActividadFlujoVersion)
  const withoutTarget = (selectedVersionIds ?? []).map(Number).filter((id) => id !== target)
  return includeRequiredFlowVersions(withoutTarget, activityAreas).includes(target)
}
