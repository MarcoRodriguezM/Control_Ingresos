import { useCallback, useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { formatDate, formatDateTime } from '../utils/formatters'

const stages = [
  { code: 'BORRADOR', label: 'Solicitud creada' },
  { code: 'CONFIGURACION_ACCESOS', label: 'Personas y areas' },
  { code: 'PENDIENTE_CREACION_TICKET', label: 'Creacion de tickets' },
  { code: 'PENDIENTE_APROBACIONES', label: 'Aprobaciones de area' },
  { code: 'LISTA_INGRESO', label: 'Listo para ingresar' },
]

function Status({ code, children }) {
  const tone = ['APROBADA', 'APROBADO', 'FINALIZADA', 'COMPLETADA', 'VALIDADA'].includes(code) ? 'approved'
    : code === 'RECHAZADA' || code === 'RECHAZADO' ? 'rejected' : 'pending'
  return <span className={`access-status ${tone}`}>{children || 'Pendiente'}</span>
}

export function RequestTrackingPage({ session, options, onBack, onTickets, onChanged }) {
  const { id } = useParams()
  const [tracking, setTracking] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [selectedArea, setSelectedArea] = useState(null)
  const [justification, setJustification] = useState('')
  const [saving, setSaving] = useState(false)

  const refresh = useCallback(async () => {
    const result = await controlIngresosApi.obtenerSeguimientoSolicitud(id)
    setTracking(result)
  }, [id])

  useEffect(() => {
    let active = true
    function loadCurrent() {
      controlIngresosApi.obtenerSeguimientoSolicitud(id)
        .then((result) => { if (active) { setTracking(result); setError('') } })
        .catch((requestError) => { if (active) { setTracking(null); setError(requestError.message) } })
        .finally(() => { if (active) setLoading(false) })
    }
    function onVisible() { if (!document.hidden) loadCurrent() }
    loadCurrent()
    window.addEventListener('focus', loadCurrent)
    document.addEventListener('visibilitychange', onVisible)
    return () => { active = false; window.removeEventListener('focus', loadCurrent); document.removeEventListener('visibilitychange', onVisible) }
  }, [id])

  async function resend(event) {
    event.preventDefault()
    if (!selectedArea || !justification.trim()) return
    setSaving(true)
    setError('')
    try {
      await controlIngresosApi.reenviarAprobacionArea(selectedArea.idSolicitudPersonaArea, justification.trim())
      await refresh()
      await onChanged?.()
      setSelectedArea(null)
      setJustification('')
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setSaving(false)
    }
  }

  if (loading || (tracking && String(tracking.solicitud?.idSolicitud) !== String(id))) return <div className="panel empty-state">Cargando seguimiento de la solicitud...</div>
  if (!tracking) return <div className="panel empty-state" role="alert">{error || 'No se encontro la solicitud.'}<div><button type="button" className="secondary-button" onClick={onBack}>Volver</button></div></div>

  const { solicitud, areas, actividades, decisiones, reenvios } = tracking
  const own = solicitud.idUsuarioSolicitante === session?.idUsuario
  const stageIndex = stages.findIndex((stage) => stage.code === tracking.codigoEstado)
  const currentStage = tracking.codigoEstado === 'EN_REVISION' ? 3
    : tracking.codigoEstado === 'PENDIENTE_PROVEEDOR' ? 1
      : tracking.codigoEstado === 'FINALIZADA' ? 4 : stageIndex
  const people = solicitud.personas?.length ? solicitud.personas : [...new Map(areas.map((area) => [area.idSolicitudPersona, { idSolicitudPersona: area.idSolicitudPersona, nombreCompleto: area.persona, numeroDocumento: area.numeroDocumento }])).values()]
  const option = (items, value) => items?.find((item) => String(item.id) === String(value))?.nombre

  return <div className="request-tracking-page">
    <div className="page-heading tracking-heading"><div><p className="eyebrow">Seguimiento de solicitud</p><h1>{solicitud.numeroSolicitud || `Solicitud #${id}`}</h1><p>Consulta los accesos, actividades y decisiones de cada persona.</p></div><button type="button" className="secondary-button" onClick={onBack}><Icon name="back" />Volver</button></div>
    {error && <p className="activity-ticket-error" role="alert">{error}</p>}
    <section className="panel tracking-overview">
      <div className="tracking-overview-top"><div><span className="tracking-overline">Estado actual</span><h2>{tracking.estado}</h2><p>{solicitud.nombreActividad || 'Solicitud de ingreso'}</p></div>{own && tracking.ticketsPendientes > 0 && <button type="button" className="primary-button" onClick={() => onTickets(id)}>Crear tickets ({tracking.ticketsPendientes})</button>}</div>
      <ol className="tracking-steps" aria-label="Flujo de la solicitud">{stages.map((stage, index) => <li key={stage.code} className={index < currentStage ? 'done' : index === currentStage ? 'current' : ''}><span>{index + 1}</span>{stage.label}</li>)}</ol>
      {tracking.codigoEstado === 'EN_REVISION' && <p className="tracking-review-note">Hay accesos rechazados. Revisa el motivo y solicita una nueva aprobacion si corresponde.</p>}
    </section>

    <section className="panel tracking-summary"><h2>Datos de la solicitud</h2><div className="tracking-facts">
      <div><span>Tipo de ingreso</span><strong>{option(options?.tiposIngreso, solicitud.idTipoIngreso) || '—'}</strong></div>
      <div><span>Vigencia</span><strong>{formatDate(solicitud.fechaInicio)} - {formatDate(solicitud.fechaFin)}</strong></div>
      <div><span>Area solicitante</span><strong>{option(options?.areas, solicitud.idAreaSolicitante) || '—'}</strong></div>
      <div><span>Ubicacion</span><strong>{option(options?.ubicaciones, solicitud.idUbicacion) || '—'}</strong></div>
      <div><span>Solicitante</span><strong>{option(options?.usuarios, solicitud.idUsuarioSolicitante) || solicitud.idUsuarioSolicitante || '—'}</strong></div>
      <div><span>Personas</span><strong>{people.length}</strong></div>
      {solicitud.idProveedor && <div><span>Proveedor</span><strong>{option(options?.proveedores, solicitud.idProveedor) || `#${solicitud.idProveedor}`}</strong></div>}
      {solicitud.numeroContrato && <div><span>Contrato</span><strong>{solicitud.numeroContrato}</strong></div>}
      {solicitud.contactoProveedor && <div><span>Contacto</span><strong>{solicitud.contactoProveedor}</strong></div>}
      {solicitud.correoProveedor && <div><span>Correo</span><strong>{solicitud.correoProveedor}</strong></div>}
      {solicitud.cantidadEstimada != null && <div><span>Cantidad estimada</span><strong>{solicitud.cantidadEstimada}</strong></div>}
    </div>{solicitud.descripcionActividad && <p className="tracking-description">{solicitud.descripcionActividad}</p>}{solicitud.observaciones && <p className="tracking-description"><strong>Observaciones:</strong> {solicitud.observaciones}</p>}</section>

    <section className="tracking-people"><div className="tracking-section-title"><h2>Personas, areas y actividades</h2><p>Las actividades se muestran con el area responsable. Cada acceso requiere su propia decision.</p></div>
      {people.length === 0 && <div className="panel empty-state">Aun no hay personas asignadas.</div>}
      {people.map((person) => {
        const personAreas = areas.filter((area) => area.idSolicitudPersona === person.idSolicitudPersona)
        const personActivities = actividades.filter((activity) => activity.idSolicitudPersona === person.idSolicitudPersona)
        const personNeedsTicket = own && tracking.ticketsPendientes > 0 && personActivities.some((activity) => activity.ticketPendiente)
        return <article className="panel tracking-person" key={person.idSolicitudPersona}><header><div><h3>{person.nombreCompleto || personAreas[0]?.persona || person.codigoEmpleadoHtis || 'Persona sin nombre'}</h3><p>{person.numeroDocumento || person.codigoEmpleadoHtis || 'Sin documento'}</p></div><div className="tracking-person-actions"><span>{personAreas.length} area(s)</span>{personNeedsTicket && <button type="button" className="secondary-button" onClick={() => onTickets(id, person.idSolicitudPersona)}>Crear ticket</button>}</div></header>
          <div className="tracking-person-body"><div><h4>Accesos por area</h4>{personAreas.length === 0 && <p className="tracking-muted">Sin areas asignadas.</p>}{personAreas.map((area) => {
            const history = decisiones.filter((decision) => decision.idSolicitudPersonaArea === area.idSolicitudPersonaArea)
            const resendHistory = reenvios.filter((resend) => resend.idSolicitudPersonaArea === area.idSolicitudPersonaArea)
            return <div className="tracking-area" key={area.idSolicitudPersonaArea}><div className="tracking-area-head"><strong>{area.area || 'Area sin nombre'}</strong><Status code={area.codigoEstado}>{area.estado}</Status></div>
              {area.fechaDecision && <small>Decision: {formatDateTime(area.fechaDecision)}{area.usuarioDecision ? ` · ${area.usuarioDecision}` : ''}</small>}
              {area.comentarioDecision && <p className="tracking-reason">Motivo: {area.comentarioDecision}</p>}
              {(history.length > 1 || (history.length > 0 && area.codigoEstado === 'PENDIENTE')) && <details><summary>Ver historial de decisiones ({history.length})</summary><ul>{history.map((decision, index) => <li key={`${decision.fecha}-${index}`}>{decision.codigoEstado} · {formatDateTime(decision.fecha)}{decision.usuarioDecision ? ` · ${decision.usuarioDecision}` : ''}{decision.comentario ? ` — ${decision.comentario}` : ''}</li>)}</ul></details>}
              {resendHistory.length > 0 && <details><summary>Ver solicitudes de nueva aprobacion ({resendHistory.length})</summary><ul>{resendHistory.map((resend, index) => <li key={`${resend.fecha}-${index}`}>{formatDateTime(resend.fecha)} · {resend.usuario}: {resend.justificacion}</li>)}</ul></details>}
              {own && area.codigoEstado === 'RECHAZADA' && <button type="button" className="secondary-button tracking-resend" onClick={() => { setError(''); setJustification(''); setSelectedArea(area) }}>Solicitar nueva aprobacion</button>}
            </div>
          })}</div><div><h4>Actividades</h4>{personActivities.length === 0 && <p className="tracking-muted">Sin actividades asignadas.</p>}{personActivities.map((activity) => <div className="tracking-activity" key={activity.idActividad}><div><strong>{activity.nombreActividad || 'Actividad'}</strong><small>{activity.areaResponsable || 'Area responsable sin indicar'}</small>{activity.fechaDecision && <small>Decision: {formatDateTime(activity.fechaDecision)}{activity.usuarioDecision ? ` · ${activity.usuarioDecision}` : ''}</small>}</div><Status code={activity.codigoEstado}>{activity.estado}</Status>{activity.requiereTicket && <p>{activity.numeroTicket ? `Ticket: ${activity.numeroTicket}` : 'Ticket pendiente'}</p>}{activity.comentarioDecision && <p className="tracking-reason">{activity.comentarioDecision}</p>}</div>)}</div></div>
        </article>
      })}
    </section>

    {selectedArea && <div className="approval-modal-backdrop" role="presentation" onMouseDown={() => !saving && setSelectedArea(null)}><section className="approval-modal approve" role="dialog" aria-modal="true" aria-labelledby="tracking-resend-title" onMouseDown={(event) => event.stopPropagation()}><h2 id="tracking-resend-title" className="approval-modal-title">Solicitar nueva aprobacion</h2><div className="decision-copy"><div><h3>{selectedArea.area}</h3><p>{selectedArea.persona} · {solicitud.numeroSolicitud}</p></div></div><form className="decision-form" onSubmit={resend}><label htmlFor="tracking-justification">Justificacion <span className="required">*</span></label><textarea id="tracking-justification" required maxLength="1000" value={justification} onChange={(event) => setJustification(event.target.value)} placeholder="Explica por que se necesita el acceso a esta area" autoFocus />{error && <p className="decision-error" role="alert">{error}</p>}<div className="action-row"><button type="button" className="secondary-button" disabled={saving} onClick={() => setSelectedArea(null)}>Cancelar</button><button type="submit" className="primary-button" disabled={saving || !justification.trim()}>{saving ? 'Enviando...' : 'Reenviar para aprobacion'}</button></div></form></section></div>}
  </div>
}
