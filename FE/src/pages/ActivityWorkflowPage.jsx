import { useEffect, useMemo, useState } from 'react'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { ACTIVITY_ENTRY_TYPES } from '../utils/activityTypes'

const newKey = () => `step-${Date.now()}-${Math.random().toString(16).slice(2)}`

const emptyStep = (areaId = '') => ({
  key: newKey(),
  idRequerimiento: null,
  nombreActividad: '',
  idAreaResponsable: areaId ? String(areaId) : '',
  requiereTicketExterno: false,
  vigenciaMeses: 24,
  fechaInicio: '',
  fechaFin: '',
  dependencias: [],
  dependenciasExternas: [],
})

const emptyFlow = (areaId = '') => ({
  idActividadFlujo: null,
  idActividadFlujoVersion: null,
  nombre: '',
  codigo: '',
  descripcion: '',
  tiposIngreso: [],
  tiposIngresoAutomaticos: [],
  pasos: [emptyStep(areaId)],
})

export function ActivityWorkflowPage({ onError }) {
  const [areas, setAreas] = useState([])
  const [selectedAreaId, setSelectedAreaId] = useState('')
  const [flow, setFlow] = useState(emptyFlow())
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)

  useEffect(() => {
    let active = true
    controlIngresosApi.obtenerFlujosActividades()
      .then((result) => {
        if (!active) return
        const loadedAreas = result.areas ?? []
        setAreas(loadedAreas)
        if (loadedAreas.length) selectLoadedArea(loadedAreas[0], setSelectedAreaId, setFlow)
      })
      .catch((error) => active && onError(error.message))
      .finally(() => active && setLoading(false))
    return () => { active = false }
  }, [onError])

  const selectedArea = useMemo(
    () => areas.find((area) => String(area.idArea) === selectedAreaId) ?? null,
    [areas, selectedAreaId],
  )

  function selectArea(area) {
    selectLoadedArea(area, setSelectedAreaId, setFlow)
    setSaved(false)
  }

  function selectFlow(id) {
    if (!selectedArea) return
    const selected = selectedArea.flujos?.find((item) => item.esVersionActual !== false && String(item.idActividadFlujo) === id)
    setFlow(selected ? mapFlow(selected) : emptyFlow(selectedArea.idArea))
    setSaved(false)
  }

  function addStep() {
    setFlow((current) => ({ ...current, pasos: [...current.pasos, emptyStep(selectedAreaId)] }))
    setSaved(false)
  }

  function updateFlow(field, value) {
    setFlow((current) => ({ ...current, [field]: value }))
    setSaved(false)
  }

  function updateStep(index, field, value) {
    setFlow((current) => ({
      ...current,
      pasos: current.pasos.map((step, stepIndex) => stepIndex === index ? { ...step, [field]: value } : step),
    }))
    setSaved(false)
  }

  function toggleDependency(index, dependency) {
    setFlow((current) => ({
      ...current,
      pasos: current.pasos.map((step, stepIndex) => {
        if (stepIndex !== index) return step
        if (dependency.kind === 'external') {
          const dependencies = step.dependenciasExternas ?? []
          const selected = dependencies.some((item) => Number(item.idActividadFlujo) === dependency.idActividadFlujo && item.clavePaso === dependency.clavePaso)
          return {
            ...step,
            dependenciasExternas: selected
              ? dependencies.filter((item) => Number(item.idActividadFlujo) !== dependency.idActividadFlujo || item.clavePaso !== dependency.clavePaso)
              : [...dependencies, { idActividadFlujo: dependency.idActividadFlujo, clavePaso: dependency.clavePaso }],
          }
        }
        const dependencies = step.dependencias ?? []
        return {
          ...step,
          dependencias: dependencies.includes(dependency.clavePaso)
            ? dependencies.filter((key) => key !== dependency.clavePaso)
            : [...dependencies, dependency.clavePaso],
        }
      }),
    }))
    setSaved(false)
  }

  function clearDependencies(index) {
    setFlow((current) => ({
      ...current,
      pasos: current.pasos.map((step, stepIndex) => stepIndex === index
        ? { ...step, dependencias: [], dependenciasExternas: [] }
        : step),
    }))
    setSaved(false)
  }

  function toggleEntryType(code) {
    const current = flow.tiposIngreso ?? []
    const removing = current.includes(code)
    setFlow((value) => ({
      ...value,
      tiposIngreso: removing ? current.filter((item) => item !== code) : [...current, code],
      tiposIngresoAutomaticos: removing
        ? (value.tiposIngresoAutomaticos ?? []).filter((item) => item !== code)
        : value.tiposIngresoAutomaticos ?? [],
    }))
    setSaved(false)
  }

  function toggleAutomaticEntryType(code) {
    const current = flow.tiposIngresoAutomaticos ?? []
    updateFlow('tiposIngresoAutomaticos', current.includes(code)
      ? current.filter((item) => item !== code)
      : [...current, code])
  }

  function removeStep(index) {
    const removedKey = flow.pasos[index].key
    setFlow((current) => ({
      ...current,
      pasos: current.pasos
        .filter((_, stepIndex) => stepIndex !== index)
        .map((step) => ({ ...step, dependencias: (step.dependencias ?? []).filter((key) => key !== removedKey) })),
    }))
    setSaved(false)
  }

  async function save() {
    if (!selectedArea) return
    const invalid = !flow.nombre.trim() || flow.pasos.some((step) => !step.nombreActividad.trim()
      || !Number(step.idAreaResponsable)
      || Number(step.vigenciaMeses) < 1
      || (step.fechaInicio && step.fechaFin && step.fechaFin < step.fechaInicio))
    if (invalid) {
      onError('Indica el nombre del flujo y completa correctamente sus actividades.')
      return
    }

    setSaving(true)
    setSaved(false)
    try {
      const payload = {
        nombre: flow.nombre.trim(),
        codigo: flow.codigo.trim() || null,
        descripcion: flow.descripcion.trim() || null,
        tiposIngreso: flow.tiposIngreso,
        tiposIngresoAutomaticos: flow.tiposIngresoAutomaticos,
        pasos: flow.pasos.map((step) => ({
          clavePaso: step.key,
          idRequerimiento: step.idRequerimiento,
          nombreActividad: step.nombreActividad.trim(),
          idAreaResponsable: Number(step.idAreaResponsable),
          requiereTicketExterno: Boolean(step.requiereTicketExterno),
          vigenciaMeses: Number(step.vigenciaMeses),
          fechaInicio: step.fechaInicio || null,
          fechaFin: step.fechaFin || null,
          dependencias: step.dependencias,
          dependenciasExternas: step.dependenciasExternas,
        })),
      }
      const savedFlow = await controlIngresosApi.guardarFlujoActividades(selectedArea.idArea, flow.idActividadFlujo, payload)
      const result = await controlIngresosApi.obtenerFlujosActividades()
      const refreshedAreas = result.areas ?? []
      const refreshedArea = refreshedAreas.find((area) => area.idArea === selectedArea.idArea)
      const refreshedFlow = refreshedArea?.flujos?.find((item) => item.idActividadFlujo === savedFlow.idActividadFlujo)
      setAreas(refreshedAreas)
      setFlow(refreshedFlow ? mapFlow(refreshedFlow) : emptyFlow(selectedArea.idArea))
      setSaved(true)
    } catch (error) {
      onError(error.message)
    } finally {
      setSaving(false)
    }
  }

  const configuredAreas = areas.filter((area) => area.flujos?.some((item) => item.esVersionActual !== false)).length

  return <div className="workflow-page">
    <div className="page-heading workflow-heading">
      <div><p className="eyebrow">Configuracion administrativa</p><h1>Flujos de actividades</h1><p>Cada area puede tener varios flujos. Las dependencias entre actividades son configurables y no tienen que ser lineales.</p></div>
      <div className="workflow-total"><strong>{configuredAreas}</strong><span>areas configuradas</span></div>
    </div>

    {loading ? <section className="panel workflow-loading">Cargando configuracion…</section> : areas.length === 0
      ? <section className="panel workflow-loading">No hay areas disponibles para configurar.</section>
      : <div className="workflow-layout">
        <aside className="panel workflow-areas">
          <div className="workflow-panel-heading"><span>Areas de acceso</span><small>Selecciona un area para administrar sus flujos</small></div>
          <div className="workflow-area-list">{areas.map((area) => <button type="button" key={area.idArea} className={String(area.idArea) === selectedAreaId ? 'active' : ''} onClick={() => selectArea(area)}>
            <span className="workflow-area-icon"><Icon name="shield" /></span>
            <span><strong>{area.nombre || area.codigo}</strong><small>{area.flujos?.some((item) => item.esVersionActual !== false) ? `${area.flujos.filter((item) => item.esVersionActual !== false).length} flujo(s)` : 'Sin configurar'}</small></span>
            <Icon name="arrow" />
          </button>)}</div>
        </aside>

        <section className="panel workflow-editor">
          <div className="workflow-editor-heading">
            <div><p className="eyebrow">Area de acceso</p><h2>{selectedArea?.nombre || 'Area'}</h2><p>Una persona puede recibir uno o varios flujos de esta area, pero cada flujo solo una vez.</p></div>
            <button type="button" className="secondary-button" onClick={() => selectFlow('')}>Crear flujo</button>
          </div>

          <div className="workflow-flow-header">
            <label><span>Flujo configurado</span><select value={flow.idActividadFlujo ?? ''} onChange={(event) => selectFlow(event.target.value)}><option value="">Nuevo flujo</option>{(selectedArea?.flujos ?? []).filter((item) => item.esVersionActual !== false).map((item) => <option key={item.idActividadFlujo} value={item.idActividadFlujo}>{item.nombre}</option>)}</select></label>
            <label><span>Nombre del flujo</span><input value={flow.nombre} maxLength="150" onChange={(event) => updateFlow('nombre', event.target.value)} placeholder="Ej. Acceso a red WiFi" /></label>
            <label><span>Codigo</span><input value={flow.codigo} maxLength="40" onChange={(event) => updateFlow('codigo', event.target.value)} placeholder="Se genera si se deja vacio" /></label>
            <label className="workflow-flow-description"><span>Descripcion</span><input value={flow.descripcion} maxLength="500" onChange={(event) => updateFlow('descripcion', event.target.value)} /></label>
            <fieldset className="workflow-entry-types"><legend>Tipos de ingreso a los que aplica el flujo</legend><label><input type="checkbox" checked={flow.tiposIngreso.length === 0} onChange={() => updateFlow('tiposIngreso', [])} />Todos</label>{ACTIVITY_ENTRY_TYPES.map((type) => <label key={type.code}><input type="checkbox" checked={flow.tiposIngreso.includes(type.code)} onChange={() => toggleEntryType(type.code)} />{type.label}</label>)}<small>Sin filtros significa que tambien aplicara a tipos de ingreso futuros.</small></fieldset>
            <fieldset className="workflow-entry-types workflow-entry-types-auto"><legend>Asignacion automatica</legend>{ACTIVITY_ENTRY_TYPES.map((type) => {
              const enabled = flow.tiposIngreso.length === 0 || flow.tiposIngreso.includes(type.code)
              return <label key={type.code}><input type="checkbox" checked={(flow.tiposIngresoAutomaticos ?? []).includes(type.code)} disabled={!enabled} onChange={() => toggleAutomaticEntryType(type.code)} />{type.label}</label>
            })}<small>Los flujos marcados se asignaran automaticamente; los demas seguiran disponibles para seleccion manual.</small></fieldset>
          </div>

          <div className="workflow-section-heading"><strong>Actividades del flujo</strong><button type="button" className="secondary-button" onClick={addStep}>Agregar actividad</button></div>
          {flow.pasos.length === 0 ? <div className="workflow-empty"><Icon name="tasks" /><strong>Flujo sin actividades</strong><span>Este flujo puede guardarse sin actividades y completarse luego.</span><button type="button" className="primary-button" onClick={addStep}>Agregar actividad</button></div>
            : <div className="workflow-steps">{flow.pasos.map((step, index) => <article className="workflow-step" key={step.key}>
              <div className="workflow-step-order"><span>{index + 1}</span><small>Actividad</small></div>
              <div className="workflow-step-fields">
                <label><span>Actividad</span><input value={step.nombreActividad} maxLength="150" onChange={(event) => updateStep(index, 'nombreActividad', event.target.value)} /></label>
                <label><span>Area responsable</span><select value={step.idAreaResponsable} onChange={(event) => updateStep(index, 'idAreaResponsable', event.target.value)}><option value="">Selecciona un area</option>{areas.map((area) => <option key={area.idArea} value={area.idArea}>{area.nombre || area.codigo}</option>)}</select></label>
                <label><span>Vigencia (meses)</span><input type="number" min="1" max="1200" value={step.vigenciaMeses} onChange={(event) => updateStep(index, 'vigenciaMeses', event.target.value)} /></label>
                <label><span>Disponible desde</span><input type="date" value={step.fechaInicio} onChange={(event) => updateStep(index, 'fechaInicio', event.target.value)} /></label>
                <label><span>Disponible hasta</span><input type="date" min={step.fechaInicio || undefined} value={step.fechaFin} onChange={(event) => updateStep(index, 'fechaFin', event.target.value)} /></label>
                <div className="workflow-dependencies">
                  <div className="workflow-dependencies-heading"><span>Depende de</span>{dependencyCount(step) > 0 && <button type="button" onClick={() => clearDependencies(index)}>Quitar todas</button>}</div>
                  <div className="workflow-dependency-list">
                    {dependencyCandidates(areas, flow, step).length === 0
                      ? <span className="workflow-dependency-empty">No hay otras actividades disponibles.</span>
                      : dependencyCandidates(areas, flow, step).map((candidate) => {
                        const selected = dependencyIsSelected(step, candidate)
                        const createsCycle = candidate.kind === 'local' && !selected && wouldCreateDependencyCycle(flow.pasos, step.key, candidate.clavePaso)
                        return <label className={`workflow-dependency-option ${selected ? 'selected' : ''} ${createsCycle ? 'disabled' : ''}`} key={candidate.key}>
                          <input type="checkbox" checked={selected} disabled={createsCycle} onChange={() => toggleDependency(index, candidate)} />
                          <span><strong>{candidate.nombre}</strong><small>{createsCycle ? 'No disponible: crearia una dependencia circular' : candidate.contexto}</small></span>
                        </label>
                      })}
                  </div>
                  <small className="workflow-dependency-help">{dependencyCount(step) === 0 ? 'Esta actividad puede comenzar sin esperar otra.' : `${dependencyCount(step)} dependencia(s) seleccionada(s). Los flujos requeridos se seleccionaran automaticamente para la persona.`}</small>
                </div>
                <label className="workflow-ticket"><input type="checkbox" checked={Boolean(step.requiereTicketExterno)} onChange={(event) => updateStep(index, 'requiereTicketExterno', event.target.checked)} /><span>Requiere comprobante o ticket externo</span></label>
              </div>
              <div className="workflow-step-actions"><button type="button" className="remove" onClick={() => removeStep(index)} aria-label="Eliminar actividad">×</button></div>
            </article>)}</div>}

          <div className="workflow-footer"><span className={saved ? 'saved' : ''}>{saved ? 'Nueva version publicada correctamente.' : `${flow.pasos.length} actividad(es) en este flujo`}</span><button type="button" className="primary-button" onClick={save} disabled={saving}>{saving ? 'Guardando…' : 'Guardar nueva version'}</button></div>
        </section>
      </div>}
  </div>
}

function selectLoadedArea(area, setSelectedAreaId, setFlow) {
  setSelectedAreaId(String(area.idArea))
  const currentFlow = area.flujos?.find((item) => item.esVersionActual !== false)
  setFlow(currentFlow ? mapFlow(currentFlow) : emptyFlow(area.idArea))
}

function mapFlow(flow) {
  const keyById = new Map((flow.pasos ?? []).map((step) => [step.idActividadFlujoPaso, step.clavePaso || `saved-${step.idActividadFlujoPaso}`]))
  return {
    ...flow,
    nombre: flow.nombre ?? '',
    codigo: flow.codigo ?? '',
    descripcion: flow.descripcion ?? '',
    tiposIngreso: flow.tiposIngreso ?? [],
    tiposIngresoAutomaticos: flow.tiposIngresoAutomaticos ?? [],
    pasos: (flow.pasos ?? []).map((step) => ({
      ...step,
      key: keyById.get(step.idActividadFlujoPaso),
      nombreActividad: step.nombreActividad ?? '',
      idAreaResponsable: String(step.idAreaResponsable ?? ''),
      vigenciaMeses: Number(step.vigenciaMeses) || 24,
      fechaInicio: step.fechaInicio ?? '',
      fechaFin: step.fechaFin ?? '',
      dependencias: (step.dependencias ?? []).map((id) => keyById.get(id)).filter(Boolean),
      dependenciasExternas: step.dependenciasExternas ?? [],
    })),
  }
}

function dependencyCandidates(areas, flow, step) {
  const local = (flow.pasos ?? [])
    .filter((candidate) => candidate.key !== step.key)
    .map((candidate) => {
      const candidateIndex = flow.pasos.indexOf(candidate)
      return {
        kind: 'local',
        key: `local:${candidate.key}`,
        clavePaso: candidate.key,
        nombre: candidate.nombreActividad || `Actividad ${candidateIndex + 1}`,
        contexto: `Este flujo · Actividad ${candidateIndex + 1}`,
      }
    })

  const currentFlowId = Number(flow.idActividadFlujo) || null
  const external = areas.flatMap((area) => (area.flujos ?? [])
    .filter((candidateFlow) => candidateFlow.esVersionActual !== false && Number(candidateFlow.idActividadFlujo) !== currentFlowId)
    .flatMap((candidateFlow) => (candidateFlow.pasos ?? []).map((candidateStep, candidateIndex) => ({
      kind: 'external',
      key: `external:${candidateFlow.idActividadFlujo}:${candidateStep.clavePaso}`,
      idActividadFlujo: Number(candidateFlow.idActividadFlujo),
      clavePaso: candidateStep.clavePaso,
      nombre: candidateStep.nombreActividad || `Actividad ${candidateIndex + 1}`,
      contexto: `${area.nombre || area.codigo} · ${candidateFlow.nombre} · Actividad ${candidateIndex + 1}`,
    }))))

  return [...local, ...external]
}

function dependencyIsSelected(step, candidate) {
  if (candidate.kind === 'local') return (step.dependencias ?? []).includes(candidate.clavePaso)
  return (step.dependenciasExternas ?? []).some((item) => Number(item.idActividadFlujo) === candidate.idActividadFlujo && item.clavePaso === candidate.clavePaso)
}

function dependencyCount(step) {
  return (step.dependencias?.length ?? 0) + (step.dependenciasExternas?.length ?? 0)
}

function wouldCreateDependencyCycle(steps, stepKey, dependencyKey) {
  const dependenciesByStep = new Map(steps.map((step) => [step.key, step.dependencias ?? []]))
  const pending = [dependencyKey]
  const visited = new Set()
  while (pending.length > 0) {
    const current = pending.pop()
    if (current === stepKey) return true
    if (visited.has(current)) continue
    visited.add(current)
    pending.push(...(dependenciesByStep.get(current) ?? []))
  }
  return false
}
