import { useEffect, useMemo, useState } from 'react'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { ACTIVITY_ENTRY_TYPES } from '../utils/activityTypes'

const emptyStep = (areaId = '') => ({
  key: `${Date.now()}-${Math.random()}`,
  nombreActividad: '',
  idAreaResponsable: areaId ? String(areaId) : '',
  requiereTicketExterno: false,
  tiposIngreso: [],
  vigenciaMeses: 24,
})

export function ActivityWorkflowPage({ onError }) {
  const [areas, setAreas] = useState([])
  const [selectedAreaId, setSelectedAreaId] = useState('')
  const [steps, setSteps] = useState([])
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
        if (loadedAreas.length) {
          setSelectedAreaId(String(loadedAreas[0].idArea))
          setSteps(mapSteps(loadedAreas[0].pasos))
        }
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
    setSelectedAreaId(String(area.idArea))
    setSteps(mapSteps(area.pasos))
    setSaved(false)
  }

  function addStep() {
    setSaved(false)
    setSteps((current) => [...current, emptyStep(selectedAreaId)])
  }

  function updateStep(index, field, value) {
    setSaved(false)
    setSteps((current) => current.map((step, stepIndex) => stepIndex === index ? { ...step, [field]: value } : step))
  }

  function toggleEntryType(index, code) {
    const current = steps[index].tiposIngreso ?? []
    updateStep(index, 'tiposIngreso', current.includes(code) ? current.filter((item) => item !== code) : [...current, code])
  }

  function removeStep(index) {
    setSaved(false)
    setSteps((current) => current.filter((_, stepIndex) => stepIndex !== index))
  }

  function moveStep(index, direction) {
    const target = index + direction
    if (target < 0 || target >= steps.length) return
    setSaved(false)
    setSteps((current) => {
      const next = [...current]
      ;[next[index], next[target]] = [next[target], next[index]]
      return next
    })
  }

  async function save() {
    if (!selectedArea) return
    const invalid = steps.some((step) => !step.nombreActividad.trim() || !Number(step.idAreaResponsable) || Number(step.vigenciaMeses) < 1)
    if (invalid) {
      onError('Completa el nombre y el area responsable de todas las actividades.')
      return
    }

    setSaving(true)
    setSaved(false)
    try {
      await controlIngresosApi.guardarFlujoActividades(selectedArea.idArea, {
        pasos: steps.map((step) => ({
          nombreActividad: step.nombreActividad.trim(),
          idAreaResponsable: Number(step.idAreaResponsable),
          requiereTicketExterno: Boolean(step.requiereTicketExterno),
          vigenciaMeses: Number(step.vigenciaMeses),
          tiposIngreso: step.tiposIngreso,
        })),
      })
      const result = await controlIngresosApi.obtenerFlujosActividades()
      const refreshedAreas = result.areas ?? []
      setAreas(refreshedAreas)
      setSteps(mapSteps(refreshedAreas.find((area) => area.idArea === selectedArea.idArea)?.pasos))
      setSaved(true)
    } catch (error) {
      onError(error.message)
    } finally {
      setSaving(false)
    }
  }

  const configuredAreas = areas.filter((area) => area.pasos?.length).length

  return <div className="workflow-page">
    <div className="page-heading workflow-heading">
      <div><p className="eyebrow">Configuracion administrativa</p><h1>Flujos de actividades</h1><p>Define las actividades que una persona debe completar, en orden, antes de recibir acceso a cada area.</p></div>
      <div className="workflow-total"><strong>{configuredAreas}</strong><span>areas configuradas</span></div>
    </div>

    {loading ? <section className="panel workflow-loading">Cargando configuracion…</section> : areas.length === 0
      ? <section className="panel workflow-loading">No hay areas disponibles para configurar.</section>
      : <div className="workflow-layout">
        <aside className="panel workflow-areas">
          <div className="workflow-panel-heading"><span>Areas de acceso</span><small>Selecciona una para editar su flujo</small></div>
          <div className="workflow-area-list">{areas.map((area) => <button
            type="button"
            key={area.idArea}
            className={String(area.idArea) === selectedAreaId ? 'active' : ''}
            onClick={() => selectArea(area)}
          >
            <span className="workflow-area-icon"><Icon name="shield" /></span>
            <span><strong>{area.nombre || area.codigo}</strong><small>{area.pasos?.length ? `${area.pasos.length} actividad(es)` : 'Sin configurar'}</small></span>
            <Icon name="arrow" />
          </button>)}</div>
        </aside>

        <section className="panel workflow-editor">
          <div className="workflow-editor-heading">
            <div><p className="eyebrow">Acceso solicitado</p><h2>{selectedArea?.nombre || 'Area'}</h2><p>Las actividades se habilitaran de arriba hacia abajo. El area responsable puede ser distinta al area de acceso.</p></div>
            <button type="button" className="secondary-button" onClick={addStep}><span aria-hidden="true">＋</span>Agregar actividad</button>
          </div>

          {steps.length === 0 ? <div className="workflow-empty"><Icon name="tasks" /><strong>Flujo sin actividades</strong><span>Agrega la primera actividad requerida para ingresar a esta area.</span><button type="button" className="primary-button" onClick={addStep}>Agregar actividad</button></div>
            : <div className="workflow-steps">{steps.map((step, index) => <article className="workflow-step" key={step.key}>
              <div className="workflow-step-order"><span>{index + 1}</span><small>{index === steps.length - 1 ? 'Final' : 'Paso'}</small></div>
              <div className="workflow-step-fields">
                <label><span>Actividad</span><input value={step.nombreActividad} maxLength="150" onChange={(event) => updateStep(index, 'nombreActividad', event.target.value)} placeholder="Ej. Induccion de seguridad y manejo de EPP" /></label>
                <label><span>Area responsable</span><select value={step.idAreaResponsable} onChange={(event) => updateStep(index, 'idAreaResponsable', event.target.value)}><option value="">Selecciona un area</option>{areas.map((area) => <option key={area.idArea} value={area.idArea}>{area.nombre || area.codigo}</option>)}</select></label>
                <label><span>Vigencia (meses)</span><input type="number" min="1" max="1200" value={step.vigenciaMeses} onChange={(event) => updateStep(index, 'vigenciaMeses', event.target.value)} /><small>Durante este tiempo no tendra que repetirla.</small></label>
                <label className="workflow-ticket"><input type="checkbox" checked={Boolean(step.requiereTicketExterno)} onChange={(event) => updateStep(index, 'requiereTicketExterno', event.target.checked)} /><span>Requiere comprobante o ticket externo</span></label>
                <fieldset className="workflow-entry-types"><legend>Tipos de ingreso</legend><label><input type="checkbox" checked={step.tiposIngreso.length === 0} onChange={() => updateStep(index, 'tiposIngreso', [])} />Todos</label>{ACTIVITY_ENTRY_TYPES.map((type) => <label key={type.code}><input type="checkbox" checked={step.tiposIngreso.includes(type.code)} onChange={() => toggleEntryType(index, type.code)} />{type.label}</label>)}<small>Todos aplica tambien a futuros tipos de ingreso.</small></fieldset>
              </div>
              <div className="workflow-step-actions">
                <button type="button" onClick={() => moveStep(index, -1)} disabled={index === 0} aria-label="Mover actividad hacia arriba">↑</button>
                <button type="button" onClick={() => moveStep(index, 1)} disabled={index === steps.length - 1} aria-label="Mover actividad hacia abajo">↓</button>
                <button type="button" className="remove" onClick={() => removeStep(index)} aria-label="Eliminar actividad">×</button>
              </div>
            </article>)}</div>}

          <div className="workflow-footer"><span className={saved ? 'saved' : ''}>{saved ? 'Configuracion guardada correctamente.' : `${steps.length} actividad(es) en este flujo`}</span><button type="button" className="primary-button" onClick={save} disabled={saving}>{saving ? 'Guardando…' : 'Guardar flujo'}</button></div>
        </section>
      </div>}
  </div>
}

function mapSteps(steps) {
  return (steps ?? []).map((step) => ({
    ...step,
    key: `saved-${step.idConfigReqArea}`,
    nombreActividad: step.nombreActividad ?? '',
    idAreaResponsable: String(step.idAreaResponsable ?? ''),
    vigenciaMeses: Number(step.vigenciaMeses) || 24,
    tiposIngreso: step.tiposIngreso ?? [],
  }))
}
