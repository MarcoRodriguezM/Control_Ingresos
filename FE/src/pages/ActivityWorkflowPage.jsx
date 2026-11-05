import { useEffect, useMemo, useState } from 'react'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { confirmDeleteFlow, showSuccessAlert } from '../utils/alerts'
import { ACTIVITY_ENTRY_TYPES } from '../utils/activityTypes'

const newKey = () => `step-${Date.now()}-${Math.random().toString(16).slice(2)}`

const FRESHSERVICE_LOOKUP_ORIGINS = [
  { value: 'FRESHSERVICE_LOCATIONS', label: 'Localidades de Freshservice' },
  { value: 'FRESHSERVICE_DEPARTMENTS', label: 'Departamentos de Freshservice' },
  { value: 'FRESHSERVICE_REQUESTERS', label: 'Solicitantes de Freshservice' },
  { value: 'FRESHSERVICE_AGENT_GROUPS', label: 'Grupos de agentes de Freshservice' },
  { value: 'FRESHSERVICE_ASSETS', label: 'Activos de Freshservice' },
]

const SINGULAR_TRAININGS = [
  'ANALISIS DE ACCIDENTES',
  'ANIMALES PONZOÑOSOS',
  'CODIGO DE ETICA',
  'CONCEPTOS BASICOS DE SEGURIDAD',
  'EQUIPO DE PROTECION PERSONAL',
  'GERENCIAMIENTO DE CAMBIO',
  'IPERC',
  'MANEJO DE RESIDUOS',
  'MANEJO DEFENSIVO',
  'POLITICAS DE ALCOHOL Y DROGAS',
  'REGLAS QUE SALVAN VIDAS',
  'RESPUESTA DE EMERGENCIA',
  'USO DE CIANURO',
  'USO DE EXTINTORES',
]

const emptyStep = (areaId = '') => ({
  key: newKey(),
  idRequerimiento: null,
  nombreActividad: '',
  idAreaResponsable: areaId ? String(areaId) : '',
  requiereTicketExterno: false,
  freshserviceWorkspaceId: '',
  freshserviceServicioDisplayId: '',
  freshserviceUrlFormularioRespaldo: '',
  freshserviceLookups: [],
  requiereConsultaSingular: false,
  singularCapacitacionNombre: '',
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
  const [deleting, setDeleting] = useState(false)
  const [saved, setSaved] = useState(false)
  const [freshserviceWorkspaces, setFreshserviceWorkspaces] = useState([])
  const [freshserviceCatalogs, setFreshserviceCatalogs] = useState({})
  const [freshserviceLookupLoading, setFreshserviceLookupLoading] = useState('')

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

  useEffect(() => {
    let active = true
    controlIngresosApi.listarWorkspacesFreshservice()
      .then((result) => active && setFreshserviceWorkspaces(result ?? []))
      .catch((error) => active && onError(`No se pudieron consultar los workspaces de Freshservice. ${error.message}`))
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

  function updateStepFields(index, changes) {
    setFlow((current) => ({
      ...current,
      pasos: current.pasos.map((step, stepIndex) => stepIndex === index ? { ...step, ...changes } : step),
    }))
    setSaved(false)
  }

  async function ensureFreshserviceCatalog(workspaceId) {
    const key = String(workspaceId || '')
    if (!key) return []
    const current = freshserviceCatalogs[key]
    if (current?.loaded) return current.items

    setFreshserviceCatalogs((catalogs) => ({ ...catalogs, [key]: { items: current?.items ?? [], loading: true, loaded: false } }))
    try {
      const items = []
      let page = 1
      let hasNextPage = true
      while (hasNextPage && page <= 20) {
        const result = await controlIngresosApi.listarCatalogoFreshservice({ page, perPage: 30, workspaceId: key })
        items.push(...(result.items ?? []))
        hasNextPage = Boolean(result.hasNextPage)
        page += 1
      }
      setFreshserviceCatalogs((catalogs) => ({ ...catalogs, [key]: { items, loading: false, loaded: true } }))
      return items
    } catch (error) {
      setFreshserviceCatalogs((catalogs) => ({ ...catalogs, [key]: { items: [], loading: false, loaded: false } }))
      onError(`No se pudo consultar el catálogo del workspace seleccionado. ${error.message}`)
      return []
    }
  }

  async function changeFreshserviceWorkspace(index, workspaceId) {
    updateStepFields(index, {
      freshserviceWorkspaceId: workspaceId,
      freshserviceServicioDisplayId: '',
      freshserviceLookups: [],
    })
    if (workspaceId) await ensureFreshserviceCatalog(workspaceId)
  }

  async function detectFreshserviceLookups(index, workspaceId, displayId) {
    if (!workspaceId || !displayId) return
    const loadingKey = `${index}:${displayId}`
    setFreshserviceLookupLoading(loadingKey)
    try {
      const service = await controlIngresosApi.obtenerServicioFreshservice(displayId, workspaceId)
      setFlow((current) => ({
        ...current,
        pasos: current.pasos.map((step, stepIndex) => {
          if (stepIndex !== index) return step
          const configured = new Map((step.freshserviceLookups ?? []).map((lookup) => [lookup.campoApi, lookup.origen]))
          const lookups = (service.fields ?? [])
            .filter((field) => String(field.rawType ?? '').toLowerCase().includes('lookup'))
            .filter((field) => field.apiName)
            .map((field) => ({
              campoApi: field.apiName,
              etiqueta: field.label || field.apiName,
              tipo: field.rawType,
              origen: configured.get(field.apiName) ?? '',
            }))
          return { ...step, freshserviceLookups: lookups }
        }),
      }))
      setSaved(false)
    } catch (error) {
      onError(`No se pudieron detectar los campos lookup del servicio. ${error.message}`)
    } finally {
      setFreshserviceLookupLoading('')
    }
  }

  async function changeFreshserviceService(index, workspaceId, displayId) {
    updateStepFields(index, { freshserviceServicioDisplayId: displayId, freshserviceLookups: [] })
    if (displayId) await detectFreshserviceLookups(index, workspaceId, displayId)
  }

  function updateFreshserviceLookup(index, campoApi, origen) {
    setFlow((current) => ({
      ...current,
      pasos: current.pasos.map((step, stepIndex) => stepIndex === index
        ? { ...step, freshserviceLookups: (step.freshserviceLookups ?? []).map((lookup) => lookup.campoApi === campoApi ? { ...lookup, origen } : lookup) }
        : step),
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
      || (step.fechaInicio && step.fechaFin && step.fechaFin < step.fechaInicio)
      || (step.requiereTicketExterno && (!Number(step.freshserviceWorkspaceId)
        || !Number(step.freshserviceServicioDisplayId)
        || !step.freshserviceUrlFormularioRespaldo?.trim()
        || (step.freshserviceLookups ?? []).some((lookup) => !lookup.origen)))
      || (step.requiereConsultaSingular && !step.singularCapacitacionNombre?.trim()))
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
          freshserviceWorkspaceId: step.requiereTicketExterno ? Number(step.freshserviceWorkspaceId) : null,
          freshserviceServicioDisplayId: step.requiereTicketExterno ? Number(step.freshserviceServicioDisplayId) : null,
          freshserviceUrlFormularioRespaldo: step.requiereTicketExterno ? step.freshserviceUrlFormularioRespaldo.trim() : null,
          freshserviceLookups: step.requiereTicketExterno
            ? (step.freshserviceLookups ?? []).map((lookup) => ({ campoApi: lookup.campoApi, origen: lookup.origen }))
            : [],
          requiereConsultaSingular: Boolean(step.requiereConsultaSingular),
          singularCapacitacionNombre: step.requiereConsultaSingular ? step.singularCapacitacionNombre.trim() : null,
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

  async function deleteFlow() {
    if (!selectedArea || !flow.idActividadFlujo || deleting) return
    const current = selectedArea.flujos?.find((item) => item.idActividadFlujo === flow.idActividadFlujo && item.esVersionActual !== false)
    if (!await confirmDeleteFlow(current?.nombre || flow.nombre)) return

    setDeleting(true)
    try {
      await controlIngresosApi.eliminarFlujoActividades(selectedArea.idArea, flow.idActividadFlujo)
      const result = await controlIngresosApi.obtenerFlujosActividades()
      const refreshedAreas = result.areas ?? []
      const refreshedArea = refreshedAreas.find((area) => area.idArea === selectedArea.idArea)
      const nextFlow = refreshedArea?.flujos?.find((item) => item.esVersionActual !== false)
      setAreas(refreshedAreas)
      setFlow(nextFlow ? mapFlow(nextFlow) : emptyFlow(selectedArea.idArea))
      setSaved(false)
      showSuccessAlert('Flujo eliminado correctamente.')
    } catch (error) {
      onError(error.message)
    } finally {
      setDeleting(false)
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
            <div className="workflow-editor-actions">
              {flow.idActividadFlujo && <button type="button" className="secondary-button workflow-delete-button" onClick={deleteFlow} disabled={deleting || saving}>{deleting ? 'Eliminando...' : 'Eliminar flujo'}</button>}
              <button type="button" className="secondary-button" onClick={() => selectFlow('')}>Crear flujo</button>
            </div>
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
                <WorkflowDependencyPicker
                  key={`${flow.idActividadFlujoVersion ?? 'new'}:${step.key}`}
                  areas={areas}
                  flow={flow}
                  step={step}
                  onToggle={(candidate) => toggleDependency(index, candidate)}
                  onClear={() => clearDependencies(index)}
                />
                <label className="workflow-ticket"><input type="checkbox" checked={Boolean(step.requiereTicketExterno)} onChange={(event) => updateStep(index, 'requiereTicketExterno', event.target.checked)} /><span>Requiere comprobante o ticket externo</span></label>
                {step.requiereTicketExterno && <FreshserviceActivityConfiguration
                  step={step}
                  index={index}
                  workspaces={freshserviceWorkspaces}
                  catalog={freshserviceCatalogs[String(step.freshserviceWorkspaceId || '')]}
                  lookupLoading={freshserviceLookupLoading === `${index}:${step.freshserviceServicioDisplayId}`}
                  onWorkspaceChange={changeFreshserviceWorkspace}
                  onCatalogLoad={ensureFreshserviceCatalog}
                  onServiceChange={changeFreshserviceService}
                  onUrlChange={(value) => updateStep(index, 'freshserviceUrlFormularioRespaldo', value)}
                  onLookupDetect={detectFreshserviceLookups}
                  onLookupChange={updateFreshserviceLookup}
                />}
                <label className="workflow-ticket"><input type="checkbox" checked={Boolean(step.requiereConsultaSingular)} onChange={(event) => updateStepFields(index, { requiereConsultaSingular: event.target.checked, singularCapacitacionNombre: event.target.checked ? step.singularCapacitacionNombre : '' })} /><span>Consultar capacitación en Singular</span></label>
                {step.requiereConsultaSingular && <SingularActivityConfiguration
                  value={step.singularCapacitacionNombre}
                  onChange={(value) => updateStep(index, 'singularCapacitacionNombre', value)}
                />}
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
      freshserviceWorkspaceId: step.freshserviceWorkspaceId ? String(step.freshserviceWorkspaceId) : '',
      freshserviceServicioDisplayId: step.freshserviceServicioDisplayId ? String(step.freshserviceServicioDisplayId) : '',
      freshserviceUrlFormularioRespaldo: step.freshserviceUrlFormularioRespaldo ?? '',
      freshserviceLookups: step.freshserviceLookups ?? [],
      requiereConsultaSingular: Boolean(step.requiereConsultaSingular),
      singularCapacitacionNombre: step.singularCapacitacionNombre ?? '',
    })),
  }
}

function SingularActivityConfiguration({ value, onChange }) {
  const trainingKnown = !value || SINGULAR_TRAININGS.includes(value)
  return <section className="workflow-singular" aria-label="Configuración Singular de la actividad">
    <div><strong>Capacitación requerida en Singular</strong><small>Por ahora la asociación se realiza por el nombre exacto devuelto en el campo Entrenamiento.</small></div>
    <label><span>Capacitación</span><select value={value ?? ''} onChange={(event) => onChange(event.target.value)}>
      <option value="">Selecciona una capacitación</option>
      {!trainingKnown && <option value={value}>{value} · Configurada anteriormente</option>}
      {SINGULAR_TRAININGS.map((training) => <option key={training} value={training}>{training}</option>)}
    </select></label>
    <p>La consulta real y la validación de vigencia se habilitarán cuando sea posible probar la conexión con Singular.</p>
  </section>
}

function FreshserviceActivityConfiguration({
  step,
  index,
  workspaces,
  catalog,
  lookupLoading,
  onWorkspaceChange,
  onCatalogLoad,
  onServiceChange,
  onUrlChange,
  onLookupDetect,
  onLookupChange,
}) {
  const workspaceId = String(step.freshserviceWorkspaceId || '')
  const serviceId = String(step.freshserviceServicioDisplayId || '')
  const services = catalog?.items ?? []
  const [serviceFilter, setServiceFilter] = useState({ workspaceId: '', value: '' })
  const serviceSearch = serviceFilter.workspaceId === workspaceId ? serviceFilter.value : ''
  const normalizedSearch = normalizeSearch(serviceSearch)
  const visibleServices = services.filter((item) => {
    if (!normalizedSearch || String(item.displayId) === serviceId) return true
    return normalizeSearch(`${item.name ?? ''} ${item.displayId ?? ''}`).includes(normalizedSearch)
  })
  const workspaceKnown = workspaces.some((item) => String(item.id) === workspaceId)
  const serviceKnown = services.some((item) => String(item.displayId) === serviceId)

  return <section className="workflow-freshservice" aria-label="Configuración Freshservice de la actividad">
    <div className="workflow-freshservice-heading">
      <div><strong>Servicio requerido de Freshservice</strong><small>La actividad quedará vinculada a un servicio exacto del catálogo.</small></div>
      <span>Solo configuración</span>
    </div>
    <div className="workflow-freshservice-grid">
      <label><span>Workspace</span><select value={workspaceId} onChange={(event) => onWorkspaceChange(index, event.target.value)}>
        <option value="">Selecciona un workspace</option>
        {!workspaceKnown && workspaceId && <option value={workspaceId}>Workspace #{workspaceId} configurado</option>}
        {workspaces.filter((item) => item.state?.toLowerCase() !== 'inactive').map((item) => <option key={item.id} value={item.id}>{item.name || `Workspace #${item.id}`}{item.primary ? ' · Principal' : ''}</option>)}
      </select></label>
      <label className="workflow-freshservice-service"><span>Servicio del catálogo</span><input type="search" value={serviceSearch} disabled={!workspaceId || catalog?.loading} onFocus={() => workspaceId && onCatalogLoad(workspaceId)} onChange={(event) => setServiceFilter({ workspaceId, value: event.target.value })} placeholder="Buscar por nombre o ID" aria-label="Buscar servicio del catálogo" /><select value={serviceId} disabled={!workspaceId || catalog?.loading} onFocus={() => workspaceId && onCatalogLoad(workspaceId)} onChange={(event) => onServiceChange(index, workspaceId, event.target.value)}>
        <option value="">{catalog?.loading ? 'Consultando servicios…' : visibleServices.length === 0 && serviceSearch ? 'No se encontraron servicios' : 'Selecciona un servicio'}</option>
        {!serviceKnown && serviceId && <option value={serviceId}>Servicio #{serviceId} configurado</option>}
        {visibleServices.map((item) => <option key={item.displayId} value={item.displayId}>{item.name || `Servicio #${item.displayId}`}</option>)}
      </select></label>
      <label className="workflow-freshservice-url"><span>URL del formulario de respaldo</span><input type="url" maxLength="500" value={step.freshserviceUrlFormularioRespaldo ?? ''} onChange={(event) => onUrlChange(event.target.value)} placeholder="https://empresa.freshservice.com/support/catalog/items/..." /></label>
    </div>
    <div className="workflow-lookup-heading"><div><strong>Campos lookup</strong><small>Detecta los lookups del servicio y define de qué catálogo se alimenta cada uno.</small></div><button type="button" className="secondary-button" disabled={!workspaceId || !serviceId || lookupLoading} onClick={() => onLookupDetect(index, workspaceId, serviceId)}>{lookupLoading ? 'Detectando…' : 'Detectar lookups'}</button></div>
    {(step.freshserviceLookups ?? []).length === 0
      ? <p className="workflow-lookup-empty">No hay lookups detectados o todavía no se ha inspeccionado el servicio.</p>
      : <div className="workflow-lookup-list">{step.freshserviceLookups.map((lookup) => <label key={lookup.campoApi}><span><strong>{lookup.etiqueta || lookup.campoApi}</strong><small>{lookup.campoApi}{lookup.tipo ? ` · ${lookup.tipo}` : ''}</small></span><select value={lookup.origen ?? ''} onChange={(event) => onLookupChange(index, lookup.campoApi, event.target.value)}><option value="">Selecciona el origen</option>{FRESHSERVICE_LOOKUP_ORIGINS.map((origin) => <option key={origin.value} value={origin.value}>{origin.label}</option>)}</select></label>)}</div>}
  </section>
}

function normalizeSearch(value) {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
}

function WorkflowDependencyPicker({ areas, flow, step, onToggle, onClear }) {
  const [areaId, setAreaId] = useState('')
  const candidates = dependencyCandidates(areas, flow, step)
  const selected = candidates.filter((candidate) => dependencyIsSelected(step, candidate))
  const available = candidates.filter((candidate) => String(candidate.idArea) === areaId)

  return <div className="workflow-dependencies">
    <div className="workflow-dependencies-heading"><span>Depende de</span>{dependencyCount(step) > 0 && <button type="button" onClick={onClear}>Quitar todas</button>}</div>
    <label className="workflow-dependency-area"><span>Primero selecciona el area</span><select value={areaId} onChange={(event) => setAreaId(event.target.value)}><option value="">Selecciona un area</option>{areas.map((area) => <option key={area.idArea} value={area.idArea}>{area.nombre || area.codigo}</option>)}</select></label>
    {selected.length > 0 && <div className="workflow-dependency-selected"><span>Dependencias elegidas</span><div>{selected.map((candidate) => <button type="button" key={candidate.key} onClick={() => onToggle(candidate)} aria-label={`Quitar ${candidate.nombre}`}><strong>{candidate.nombre}</strong><small>{areas.find((area) => Number(area.idArea) === candidate.idArea)?.nombre || candidate.contexto}</small><span aria-hidden="true">×</span></button>)}</div></div>}
    {areaId && <div className="workflow-dependency-list">
      {available.length === 0
        ? <span className="workflow-dependency-empty">No hay otras actividades en esta area.</span>
        : available.map((candidate) => {
          const isSelected = dependencyIsSelected(step, candidate)
          const createsCycle = candidate.kind === 'local' && !isSelected && wouldCreateDependencyCycle(flow.pasos, step.key, candidate.clavePaso)
          return <label className={`workflow-dependency-option ${isSelected ? 'selected' : ''} ${createsCycle ? 'disabled' : ''}`} key={candidate.key}>
            <input type="checkbox" checked={isSelected} disabled={createsCycle} onChange={() => onToggle(candidate)} />
            <span><strong>{candidate.nombre}</strong><small>{createsCycle ? 'No disponible: crearia una dependencia circular' : candidate.contexto}</small></span>
          </label>
        })}
    </div>}
    <small className="workflow-dependency-help">{dependencyCount(step) === 0 ? 'Esta actividad puede comenzar sin esperar otra.' : `${dependencyCount(step)} dependencia(s) seleccionada(s). Los flujos requeridos se seleccionaran automaticamente para la persona.`}</small>
  </div>
}

function dependencyCandidates(areas, flow, step) {
  const local = (flow.pasos ?? [])
    .filter((candidate) => candidate.key !== step.key)
    .map((candidate) => {
      const candidateIndex = flow.pasos.indexOf(candidate)
      return {
        kind: 'local',
        key: `local:${candidate.key}`,
        idArea: Number(candidate.idAreaResponsable),
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
      idArea: Number(candidateStep.idAreaResponsable || area.idArea),
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
