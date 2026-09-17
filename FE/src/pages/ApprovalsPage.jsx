import { useMemo, useState } from 'react'
import { Icon } from '../components/Icon'
import { accessStatusClass, formatDate, formatDateTime, initials } from '../utils/formatters'

export function ApprovalsPage({ items, loading, saving, onDecide }) {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('PENDIENTE')
  const [decision, setDecision] = useState(null)
  const [comment, setComment] = useState('')

  const counts = useMemo(() => ({
    pending: items.filter((item) => item.codigoEstado === 'PENDIENTE').length,
    approved: items.filter((item) => item.codigoEstado === 'APROBADA').length,
    rejected: items.filter((item) => item.codigoEstado === 'RECHAZADA').length,
  }), [items])

  const normalizedQuery = query.trim().toLowerCase()
  const filtered = items.filter((item) => {
    const matchesQuery = !normalizedQuery || [item.persona, item.numeroDocumento, item.numeroSolicitud, item.area, item.actividad, item.empresa]
      .some((value) => value?.toLowerCase().includes(normalizedQuery))
    return matchesQuery && (!status || item.codigoEstado === status)
  })

  function beginDecision(item, code) {
    setDecision({ item, code })
    setComment('')
  }

  async function confirmDecision() {
    if (!decision || (decision.code === 'RECHAZADA' && !comment.trim())) return
    const completed = await onDecide(decision.item.idSolicitudPersonaArea, decision.code, comment)
    if (completed) {
      setDecision(null)
      setComment('')
    }
  }

  return <>
    <div className="page-heading approvals-heading">
      <div><p className="eyebrow">Bandeja de trabajo</p><h1>Mis aprobaciones</h1><p>Revisa y decide los accesos a las áreas que tienes asignadas.</p></div>
      <span className="approver-chip"><Icon name="shield" />Usuario: aprobador</span>
    </div>

    <div className="approval-summary">
      <SummaryCard label="Pendientes" value={counts.pending} tone="pending" />
      <SummaryCard label="Aprobadas" value={counts.approved} tone="approved" />
      <SummaryCard label="Rechazadas" value={counts.rejected} tone="rejected" />
    </div>

    {decision && <section className={`panel decision-panel ${decision.code === 'RECHAZADA' ? 'reject' : 'approve'}`}>
      <div className="decision-copy">
        <span className="person-avatar">{initials(decision.item.persona)}</span>
        <div><span className="decision-label">{decision.code === 'APROBADA' ? 'Aprobar acceso' : 'Rechazar acceso'}</span><h2>{decision.item.persona}</h2><p>{decision.item.area} · {decision.item.numeroSolicitud}</p></div>
      </div>
      <div className="decision-form">
        <label htmlFor="approval-comment">Comentario {decision.code === 'RECHAZADA' && <span className="required">*</span>}</label>
        <textarea id="approval-comment" value={comment} onChange={(event) => setComment(event.target.value)} maxLength="1000" placeholder={decision.code === 'RECHAZADA' ? 'Indica el motivo del rechazo' : 'Comentario opcional'} />
        <div className="action-row"><button type="button" className="secondary-button" onClick={() => setDecision(null)}>Cancelar</button><button type="button" className={`primary-button ${decision.code === 'APROBADA' ? 'teal' : 'danger-button'}`} disabled={saving || (decision.code === 'RECHAZADA' && !comment.trim())} onClick={confirmDecision}>{saving ? 'Guardando…' : 'Confirmar decisión'}</button></div>
      </div>
    </section>}

    <div className="filters">
      <div className="search-box"><Icon name="search" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar persona, solicitud o área" /></div>
      <select className="filter-select" value={status} onChange={(event) => setStatus(event.target.value)}><option value="">Todos los estados</option><option value="PENDIENTE">Pendientes</option><option value="APROBADA">Aprobadas</option><option value="RECHAZADA">Rechazadas</option></select>
    </div>

    <article className="panel requests-panel">
      <div className="table-wrap"><table className="approvals-table"><thead><tr><th>Persona</th><th>Solicitud / actividad</th><th>Área</th><th>Vigencia</th><th>Estado</th><th>Acciones</th></tr></thead>
        <tbody>
          {loading && <tr><td colSpan="6" className="empty-table">Cargando aprobaciones…</td></tr>}
          {!loading && filtered.length === 0 && <tr><td colSpan="6" className="empty-table">No hay aprobaciones para este filtro.</td></tr>}
          {filtered.map((item) => <tr key={item.idSolicitudPersonaArea}>
            <td><div className="approval-person"><span className="person-avatar compact">{initials(item.persona)}</span><span><strong>{item.persona || 'Sin nombre'}</strong><small>{item.empresa || item.numeroDocumento || 'Sin empresa'}</small></span></div></td>
            <td><strong>{item.numeroSolicitud || 'Sin número'}</strong><span className="cell-sub">{item.actividad || 'Sin actividad'}</span></td>
            <td>{item.area || '—'}<span className="cell-sub">{item.ubicacion || 'Sin ubicación'}</span></td>
            <td>{formatDate(item.fechaInicio)}<span className="cell-sub">hasta {formatDate(item.fechaFin)}</span></td>
            <td><span className={`access-status ${accessStatusClass(item.estado)}`}>{item.estado || 'Pendiente'}</span>{item.fechaDecision && <span className="cell-sub">{formatDateTime(item.fechaDecision)}</span>}</td>
            <td>{item.codigoEstado === 'PENDIENTE' ? <div className="row-actions"><button type="button" className="approve-action" onClick={() => beginDecision(item, 'APROBADA')}>Aprobar</button><button type="button" className="delete-action" onClick={() => beginDecision(item, 'RECHAZADA')}>Rechazar</button></div> : <span className="decision-complete">Decidida</span>}</td>
          </tr>)}
        </tbody>
      </table></div>
    </article>
  </>
}

function SummaryCard({ label, value, tone }) {
  return <article className={`panel approval-summary-card ${tone}`}><span>{label}</span><strong>{value}</strong></article>
}
