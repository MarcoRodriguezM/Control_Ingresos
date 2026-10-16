import { useState } from 'react'
import { Icon } from '../components/Icon'
import { showSuccessAlert } from '../utils/alerts'
import { accessStatusClass, formatDate, formatDateTime } from '../utils/formatters'

export function ApprovalsPage({ items, loading, onDecide, onDecideMany, onViewDetail }) {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('PENDIENTE')
  const [selectedIds, setSelectedIds] = useState([])
  const [decision, setDecision] = useState(null)
  const [comment, setComment] = useState('')
  const [saving, setSaving] = useState(false)
  const [decisionError, setDecisionError] = useState('')
  const [resultSummary, setResultSummary] = useState(null)

  const normalizedQuery = query.trim().toLowerCase()
  const filtered = items.filter((item) => {
    const matchesQuery = !normalizedQuery || [item.persona, item.numeroDocumento, item.numeroSolicitud, item.area, item.actividad, item.empresa]
      .some((value) => value?.toLowerCase().includes(normalizedQuery))
    return matchesQuery && (!status || item.codigoEstado === status)
  })
  const pendingRows = filtered.filter((item) => item.codigoEstado === 'PENDIENTE')
  const hasPending = pendingRows.length > 0
  const selectedItems = items.filter((item) => item.codigoEstado === 'PENDIENTE' && selectedIds.includes(item.idSolicitudPersonaArea))
  const allVisibleSelected = pendingRows.length > 0 && pendingRows.every((item) => selectedIds.includes(item.idSolicitudPersonaArea))

  function toggleSelection(idSolicitudPersonaArea) {
    setSelectedIds((current) => current.includes(idSolicitudPersonaArea)
      ? current.filter((id) => id !== idSolicitudPersonaArea)
      : [...current, idSolicitudPersonaArea])
  }

  function toggleVisibleSelection() {
    const visibleIds = pendingRows.map((item) => item.idSolicitudPersonaArea)
    setSelectedIds((current) => allVisibleSelected
      ? current.filter((id) => !visibleIds.includes(id))
      : [...new Set([...current, ...visibleIds])])
  }

  function beginDecision(decisionItems, codigoEstado) {
    if (!decisionItems.length) return
    setDecision({ items: decisionItems, codigoEstado })
    setComment('')
    setDecisionError('')
  }

  async function confirmDecision() {
    if (!decision) return
    const trimmedComment = comment.trim()
    if (decision.codigoEstado === 'RECHAZADA' && !trimmedComment) {
      setDecisionError('Debes indicar el motivo del rechazo.')
      return
    }

    setSaving(true)
    setDecisionError('')
    if (decision.items.length === 1) {
      const item = decision.items[0]
      const result = await onDecide(item.idSolicitudPersonaArea, decision.codigoEstado, trimmedComment)
      setSaving(false)
      if (!result?.success) {
        setDecisionError(result?.message || 'No se pudo guardar la decisión.')
        return
      }
      setDecision(null)
      setComment('')
      showSuccessAlert(decision.codigoEstado === 'APROBADA' ? 'El acceso fue aprobado.' : 'El acceso fue rechazado.')
      return
    }

    const result = await onDecideMany(decision.items.map((item) => item.idSolicitudPersonaArea), decision.codigoEstado, trimmedComment)
    setSaving(false)
    const successIds = result.successIds ?? []
    const successIdSet = new Set(successIds)
    const successes = decision.items.filter((item) => successIdSet.has(item.idSolicitudPersonaArea))
    const failures = (result.failures ?? []).map((failure) => ({
      ...failure,
      item: decision.items.find((candidate) => candidate.idSolicitudPersonaArea === failure.idSolicitudPersonaArea),
    }))
    setSelectedIds((current) => current.filter((id) => !successIdSet.has(id)))
    setDecision(null)
    setComment('')
    setResultSummary({ codigoEstado: decision.codigoEstado, successes, failures })
  }

  return <>
    <div className="page-heading approvals-heading"><div><h1>Solicitudes de Ingreso por Aprobar</h1></div></div>

    {decision && <DecisionModal decision={decision} comment={comment} saving={saving} error={decisionError} onCommentChange={(value) => { setComment(value); setDecisionError('') }} onCancel={() => setDecision(null)} onConfirm={confirmDecision} />}
    {resultSummary && <BatchResultModal summary={resultSummary} onClose={() => setResultSummary(null)} />}

    <div className="filters">
      <div className="search-box"><Icon name="search" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar persona, solicitud o área" /></div>
      <select className="filter-select" value={status} onChange={(event) => setStatus(event.target.value)}><option value="">Todos los estados</option><option value="PENDIENTE">Pendientes</option><option value="APROBADA">Aprobadas</option><option value="RECHAZADA">Rechazadas</option></select>
    </div>

    <div className="bulk-actions">{selectedItems.length > 0 && <span>{selectedItems.length} acceso{selectedItems.length === 1 ? '' : 's'} seleccionado{selectedItems.length === 1 ? '' : 's'}</span>}<div><button type="button" className="approve-action" disabled={selectedItems.length === 0} onClick={() => beginDecision(selectedItems, 'APROBADA')}>Aprobar seleccionadas</button><button type="button" className="delete-action" disabled={selectedItems.length === 0} onClick={() => beginDecision(selectedItems, 'RECHAZADA')}>Rechazar seleccionadas</button></div></div>

    <article className="panel requests-panel">
      <div className="table-wrap"><table className="approvals-table"><thead><tr>{hasPending && <th className="selection-cell"><input type="checkbox" className="selection-checkbox" checked={allVisibleSelected} onChange={toggleVisibleSelection} aria-label="Seleccionar todos los accesos pendientes visibles" /></th>}<th>Detalle</th><th>Persona</th><th>Solicitud / actividad</th><th>Área</th><th>Vigencia</th><th>Estado</th>{hasPending && <th>Acciones</th>}</tr></thead>
        <tbody>
          {loading && <tr><td colSpan={hasPending ? 8 : 6} className="empty-table">Cargando aprobaciones…</td></tr>}
          {!loading && filtered.length === 0 && <tr><td colSpan={hasPending ? 8 : 6} className="empty-table">No hay aprobaciones para este filtro.</td></tr>}
          {filtered.map((item) => <tr key={item.idSolicitudPersonaArea}>
            {hasPending && <td className="selection-cell">{item.codigoEstado === 'PENDIENTE' && <input type="checkbox" className="selection-checkbox" checked={selectedIds.includes(item.idSolicitudPersonaArea)} onChange={() => toggleSelection(item.idSolicitudPersonaArea)} aria-label={`Seleccionar ${item.persona || 'acceso'}`} />}</td>}
            <td className="detail-cell"><button type="button" className="secondary-button detail-button" onClick={() => onViewDetail(item.idSolicitudPersonaArea)}><Icon name="file" />Ver detalle</button></td>
            <td><div className="approval-person"><span><strong>{item.persona || 'Sin nombre'}</strong><small>{item.empresa || item.numeroDocumento || 'Sin empresa'}</small></span></div></td>
            <td><strong>{item.numeroSolicitud || 'Sin número'}</strong><span className="cell-sub">{item.actividad || 'Sin actividad'}</span></td>
            <td>{item.area || '—'}<span className="cell-sub">{item.ubicacion || 'Sin ubicación'}</span></td>
            <td>{formatDate(item.fechaInicio)}<span className="cell-sub">hasta {formatDate(item.fechaFin)}</span></td>
            <td><span className={`access-status ${accessStatusClass(item.codigoEstado)}`}>{item.estado || 'Sin estado'}</span>{item.fechaDecision && <span className="cell-sub">{formatDateTime(item.fechaDecision)}</span>}</td>
            {hasPending && <td>{item.codigoEstado === 'PENDIENTE' && <div className="row-actions"><button type="button" className="approve-action" onClick={() => beginDecision([item], 'APROBADA')}>Aprobar</button><button type="button" className="delete-action" onClick={() => beginDecision([item], 'RECHAZADA')}>Rechazar</button></div>}</td>}
          </tr>)}
        </tbody>
      </table></div>
    </article>
  </>
}

function DecisionModal({ decision, comment, saving, error, onCommentChange, onCancel, onConfirm }) {
  const isApproval = decision.codigoEstado === 'APROBADA'
  return <div className="approval-modal-backdrop" role="presentation" onMouseDown={() => !saving && onCancel()}>
    <section className={`approval-modal ${isApproval ? 'approve' : 'reject'}`} role="dialog" aria-modal="true" aria-labelledby="approval-modal-title" onMouseDown={(event) => event.stopPropagation()}>
      <h2 id="approval-modal-title" className="approval-modal-title">{isApproval ? 'Aprobar acceso' : 'Rechazar acceso'}</h2>
      <div className={`decision-copy ${decision.items.length > 1 ? 'multiple' : ''}`}>{decision.items.map((item) => <div className="decision-person" key={item.idSolicitudPersonaArea}><h3>{item.persona || 'Sin nombre'}</h3><p>{item.area || 'Sin área'} · {item.numeroSolicitud || 'Sin solicitud'}</p></div>)}</div>
      <div className="decision-form"><label htmlFor="approval-comment">Comentario {!isApproval && <span className="required">*</span>}</label><textarea id="approval-comment" value={comment} onChange={(event) => onCommentChange(event.target.value)} maxLength="1000" placeholder={isApproval ? 'Comentario opcional' : 'Indica el motivo del rechazo'} autoFocus />{error && <p className="decision-error" role="alert">{error}</p>}<div className="action-row"><button type="button" className="secondary-button" disabled={saving} onClick={onCancel}>Cancelar</button><button type="button" className={`primary-button ${isApproval ? 'teal' : 'danger-button'}`} disabled={saving} onClick={onConfirm}>{saving ? 'Guardando…' : isApproval ? 'Confirmar aprobación' : 'Confirmar rechazo'}</button></div></div>
    </section>
  </div>
}

function BatchResultModal({ summary, onClose }) {
  const isApproval = summary.codigoEstado === 'APROBADA'
  const actionLabel = isApproval ? 'Aprobaciones realizadas' : 'Rechazos realizados'
  return <div className="approval-modal-backdrop" role="presentation" onMouseDown={onClose}>
    <section className={`approval-modal bulk-result-modal ${isApproval ? 'approve' : 'reject'}`} role="dialog" aria-modal="true" aria-labelledby="batch-result-title" onMouseDown={(event) => event.stopPropagation()}>
      <h2 id="batch-result-title" className="approval-modal-title">Resultado de {isApproval ? 'aprobación' : 'rechazo'}</h2>
      <div className="bulk-result-copy">{summary.successes.length > 0 && <ResultGroup label={actionLabel} items={summary.successes} />}{summary.failures.length > 0 && <ResultGroup label="No procesadas" items={summary.failures.map((failure) => failure.item ? { ...failure.item, message: failure.message } : { persona: 'Acceso', area: 'Sin información', message: failure.message })} failed />}</div>
      <div className="action-row bulk-result-actions"><button type="button" className="secondary-button" onClick={onClose}>Cerrar</button></div>
    </section>
  </div>
}

function ResultGroup({ label, items, failed }) {
  return <section className={`bulk-result-group ${failed ? 'failed' : 'successful'}`}><strong>{label} ({items.length})</strong><div className="decision-copy multiple bulk-result-list">{items.map((item, index) => <div className="decision-person" key={item.idSolicitudPersonaArea ?? index}><h3>{item.persona || 'Sin nombre'}</h3><p>{item.area || 'Sin área'}</p>{item.message && <small>{item.message}</small>}</div>)}</div></section>
}
