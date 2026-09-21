import { useState } from 'react'
import { Icon } from '../components/Icon'
import { formatDateTime } from '../utils/formatters'

const isOverdue = (item) => !item.esEstadoFinal && item.fechaLimite && new Date(item.fechaLimite) < new Date()

export function MyActivitiesPage({ items, loading, onRequest, onComplete }) {
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState('pendientes')
  const pending = items.filter((item) => !item.esEstadoFinal).length
  const overdue = items.filter(isOverdue).length
  const completed = items.filter((item) => item.esEstadoFinal).length
  const search = query.trim().toLocaleLowerCase('es')
  const filtered = items.filter((item) => {
    const matchesFilter = filter === 'todas' || (filter === 'pendientes' && !item.esEstadoFinal) || (filter === 'vencidas' && isOverdue(item)) || (filter === 'finalizadas' && item.esEstadoFinal)
    const matchesSearch = !search || [item.nombreActividad, item.numeroSolicitud, item.areaResponsable, item.estado]
      .some((value) => value?.toLocaleLowerCase('es').includes(search))
    return matchesFilter && matchesSearch
  })

  return <div className="activities-page">
    <div className="page-heading"><div><p className="eyebrow">Bandeja de trabajo</p><h1>Mis actividades</h1><p>Actividades asignadas a tu usuario y sus fechas de seguimiento.</p></div></div>

    <div className="activity-summary" aria-label="Resumen de actividades">
      <ActivitySummary label="Asignadas" value={items.length} loading={loading} tone="all" />
      <ActivitySummary label="Pendientes" value={pending} loading={loading} tone="pending" />
      <ActivitySummary label="Vencidas" value={overdue} loading={loading} tone="overdue" />
      <ActivitySummary label="Finalizadas" value={completed} loading={loading} tone="done" />
    </div>

    <div className="filters activity-filters">
      <div className="search-box"><Icon name="search" /><input aria-label="Buscar actividades" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar actividad, solicitud o área" /></div>
      <select className="filter-select" aria-label="Filtrar actividades" value={filter} onChange={(event) => setFilter(event.target.value)}>
        <option value="pendientes">Pendientes</option><option value="vencidas">Vencidas</option><option value="finalizadas">Finalizadas</option><option value="todas">Todas</option>
      </select>
    </div>

    <section className="panel activity-list" aria-label="Listado de mis actividades">
      {loading ? <p className="activity-empty">Cargando actividades…</p> : filtered.length === 0 ?
        <p className="activity-empty">{items.length === 0 ? 'No tienes actividades asignadas por ahora.' : 'No hay actividades para este filtro.'}</p> :
        filtered.map((item) => <article className="activity-row" key={item.idActividad}>
          <div className="activity-row-icon"><Icon name="tasks" /></div>
          <div className="activity-row-main">
            <div className="activity-title"><h2>{item.nombreActividad || `Actividad #${item.idActividad}`}</h2><span className={`access-status ${isOverdue(item) ? 'rejected' : item.esEstadoFinal ? 'approved' : 'pending'}`}>{isOverdue(item) ? 'Vencida' : item.estado || (item.esEstadoFinal ? 'Finalizada' : 'Pendiente')}</span></div>
            <p>{item.areaResponsable || 'Área no indicada'}{item.numeroSolicitud ? ` · ${item.numeroSolicitud}` : ''}</p>
            <div className="activity-meta"><span><strong>Fecha límite</strong>{formatDateTime(item.fechaLimite)}</span><span><strong>Inicio</strong>{formatDateTime(item.fechaInicio)}</span><span><strong>Finalización</strong>{formatDateTime(item.fechaFinalizacion)}</span>{item.requiereTicketExterno && <span className="activity-ticket">Requiere ticket externo</span>}</div>
            {item.comentarios && <p className="activity-comment">{item.comentarios}</p>}
          </div>
          <div className="activity-row-actions">
            {!item.esEstadoFinal && item.codigoEstado !== 'PENDIENTE_APROBACION' && <button type="button" className="primary-button teal activity-complete" onClick={() => onComplete(item.idActividad)}>Marcar completada</button>}
            {item.codigoEstado === 'PENDIENTE_APROBACION' && <span className="activity-waiting">Esperando aprobación</span>}
            {item.idSolicitud && <button type="button" className="secondary-button activity-open" onClick={() => onRequest(item.idSolicitud)}>Abrir solicitud <Icon name="arrow" /></button>}
          </div>
        </article>)}
    </section>
  </div>
}

function ActivitySummary({ label, value, loading, tone }) {
  return <div className={`panel activity-summary-card ${tone}`}><span>{label}</span><strong>{loading ? '—' : value}</strong></div>
}
