import { useState } from 'react'
import { Icon } from '../components/Icon'
import { activityStatusLabel, formatDateTime } from '../utils/formatters'

const isOverdue = (item) => {
  if (item.esEstadoFinal || !item.fechaLimite) return false
  const limit = new Date(item.fechaLimite)
  limit.setHours(23, 59, 59, 999)
  return limit < new Date()
}

export function MyActivitiesPage({ items, loading, onRequest, onComplete }) {
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState('pendientes')
  const [completion, setCompletion] = useState(null)
  const [completionComment, setCompletionComment] = useState('')
  const [completionSaving, setCompletionSaving] = useState(false)
  const pending = items.filter((item) => !item.esEstadoFinal).length
  const overdue = items.filter(isOverdue).length
  const completed = items.filter((item) => item.esEstadoFinal).length
  const search = query.trim().toLocaleLowerCase('es')
  const filtered = items.filter((item) => {
    const matchesFilter = filter === 'todas' || (filter === 'pendientes' && !item.esEstadoFinal) || (filter === 'vencidas' && isOverdue(item)) || (filter === 'finalizadas' && item.esEstadoFinal)
    const matchesSearch = !search || [item.nombreActividad, item.numeroSolicitud, item.areaAcceso, item.areaResponsable, item.estado]
      .some((value) => value?.toLocaleLowerCase('es').includes(search))
    return matchesFilter && matchesSearch
  })

  function beginCompletion(item) {
    setCompletion(item)
    setCompletionComment('')
  }

  async function confirmCompletion() {
    if (!completion) return
    setCompletionSaving(true)
    const result = await onComplete(completion.idActividad, completionComment)
    setCompletionSaving(false)
    if (!result?.success) return
    setCompletion(null)
    setCompletionComment('')
  }

  return <div className="activities-page">
    <div className="page-heading"><div><p className="eyebrow">Bandeja de trabajo</p><h1>Mis actividades</h1><p>Actividades asignadas a tu usuario y sus fechas de seguimiento.</p></div></div>

    <div className="activity-summary" aria-label="Resumen de actividades">
      <ActivitySummary label="Asignadas" value={items.length} loading={loading} tone="all" />
      <ActivitySummary label="Pendientes" value={pending} loading={loading} tone="pending" />
      <ActivitySummary label="Vencidas" value={overdue} loading={loading} tone="overdue" />
      <ActivitySummary label="Finalizadas" value={completed} loading={loading} tone="done" />
    </div>

    <div className="activity-worklist-heading">
      <div><p className="eyebrow">Seguimiento personal</p><h2>Actividades asignadas</h2><p>Registra las actividades realizadas y consulta su estado actual.</p></div>
      <span>{filtered.length} resultado(s)</span>
    </div>

    <div className="filters activity-filters">
      <div className="search-box"><Icon name="search" /><input aria-label="Buscar actividades" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar actividad, solicitud o area" /></div>
      <select className="filter-select" aria-label="Filtrar actividades" value={filter} onChange={(event) => setFilter(event.target.value)}>
        <option value="pendientes">Pendientes</option><option value="vencidas">Vencidas</option><option value="finalizadas">Finalizadas</option><option value="todas">Todas</option>
      </select>
    </div>

    <section className="panel activity-list" aria-label="Listado de mis actividades">
      {loading ? <p className="activity-empty">Cargando actividades…</p> : filtered.length === 0 ?
        <p className="activity-empty">{items.length === 0 ? 'No tienes actividades asignadas por ahora.' : 'No hay actividades para este filtro.'}</p> :
        filtered.map((item) => <article className={`activity-row ${isOverdue(item) ? 'is-overdue' : ''}`} key={item.idActividad}>
          <div className="activity-row-icon"><Icon name="tasks" /></div>
          <div className="activity-row-main">
            <div className="activity-title"><h2>{item.nombreActividad || `Actividad #${item.idActividad}`}</h2><span className={`access-status ${isOverdue(item) ? 'rejected' : item.esEstadoFinal ? 'approved' : 'pending'}`}>{isOverdue(item) ? 'Vencida' : activityStatusLabel(item.codigoEstado, item.esEstadoFinal ? 'Finalizada' : 'Pendiente')}</span></div>
            <p>{item.areaResponsable || 'Area no indicada'}{item.numeroSolicitud ? ` · ${item.numeroSolicitud}` : ''}</p>
            <div className="activity-meta"><span><strong>Fecha limite</strong>{formatDateTime(item.fechaLimite)}</span><span><strong>Inicio</strong>{formatDateTime(item.fechaInicio)}</span><span><strong>Finalizacion</strong>{formatDateTime(item.fechaFinalizacion)}</span>{item.requiereTicketExterno && <span className="activity-ticket">{item.ticket ? `Ticket ${item.ticket.numeroTicket}` : 'Ticket requerido'}</span>}</div>
            {item.ticket ? <p className="activity-ticket-detail">{item.ticket.plataforma}: <strong>{item.ticket.numeroTicket}</strong>{item.ticket.urlTicket?.startsWith('https://') && <> · <a href={item.ticket.urlTicket} target="_blank" rel="noopener noreferrer">Abrir ticket</a></>}</p> : item.requiereTicketExterno && <p className="activity-ticket-detail">El solicitante debe registrar el ticket en su solicitud.</p>}
            {item.comentarios && <p className="activity-comment">{item.comentarios}</p>}
          </div>
          <div className="activity-row-actions">
            {!item.esEstadoFinal && <button type="button" className="primary-button teal activity-complete" disabled={item.requiereTicketExterno && !item.ticket} onClick={() => beginCompletion(item)}>{item.codigoEstado === 'PENDIENTE_APROBACION' ? 'Finalizar actividad' : 'Registrar como realizada'}</button>}
            {item.idSolicitud && <button type="button" className="secondary-button activity-open" onClick={() => onRequest(item.idSolicitud, item.idSolicitudPersona)}>Abrir solicitud <Icon name="arrow" /></button>}
          </div>
        </article>)}
    </section>

    {completion && <div className="approval-modal-backdrop" role="presentation" onMouseDown={() => !completionSaving && setCompletion(null)}>
      <section className="approval-modal approve activity-completion-modal" role="dialog" aria-modal="true" aria-labelledby="activity-completion-title" onMouseDown={(event) => event.stopPropagation()}>
        <h2 id="activity-completion-title" className="approval-modal-title">Registrar actividad realizada</h2>
        <div className="decision-copy"><div><h3>{completion.nombreActividad || `Actividad #${completion.idActividad}`}</h3><p>{completion.areaResponsable || 'Area no indicada'}{completion.numeroSolicitud ? ` · ${completion.numeroSolicitud}` : ''}</p></div></div>
        <div className="decision-form"><label htmlFor="activity-completion-comment">Comentario</label><textarea id="activity-completion-comment" value={completionComment} onChange={(event) => setCompletionComment(event.target.value)} maxLength="1000" placeholder="Comentario de finalizacion (opcional)" autoFocus /><div className="action-row"><button type="button" className="secondary-button" disabled={completionSaving} onClick={() => setCompletion(null)}>Cancelar</button><button type="button" className="primary-button teal" disabled={completionSaving} onClick={confirmCompletion}>{completionSaving ? 'Guardando…' : 'Confirmar actividad'}</button></div></div>
      </section>
    </div>}

  </div>
}

function ActivitySummary({ label, value, loading, tone }) {
  return <div className={`panel activity-summary-card ${tone}`}><span>{label}</span><strong>{loading ? '—' : value}</strong></div>
}
