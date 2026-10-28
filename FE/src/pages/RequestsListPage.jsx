import { useState } from 'react'
import { Icon } from '../components/Icon'
import { formatDate } from '../utils/formatters'

export function RequestsListPage({ items, loading, canOpenAll, onNew, onOpen, onEdit, onTickets, onDelete }) {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('')
  const [deletion, setDeletion] = useState(null)
  const [deleting, setDeleting] = useState(false)
  const activeItems = items.filter((item) => item.estado?.toLowerCase() !== 'cancelada')
  const statuses = [...new Set(activeItems.map((item) => item.estado).filter(Boolean))]
  const normalizedQuery = query.trim().toLowerCase()
  const filtered = activeItems.filter((item) => {
    const matchesQuery = !normalizedQuery || [item.numeroSolicitud, item.nombreActividad, item.tipoIngreso, item.usuarioSolicitante]
      .some((value) => value?.toLowerCase().includes(normalizedQuery))
    return matchesQuery && (!status || item.estado === status)
  })

  async function confirmDelete() {
    if (!deletion) return
    setDeleting(true)
    await onDelete(deletion.idSolicitud, deletion.numeroSolicitud)
    setDeleting(false)
    setDeletion(null)
  }

  return <>
    <div className="page-heading requests-heading">
      <div><p className="eyebrow">Gestión</p><h1>Listado Solicitudes</h1><p>Crea, consulta y da seguimiento a las solicitudes de ingreso.</p></div>
      <button type="button" className="primary-button" onClick={onNew}><span className="plus-sign">+</span>Nueva solicitud</button>
    </div>
    <div className="filters">
      <div className="search-box"><Icon name="search" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar por número, actividad o solicitante" /></div>
      <select className="filter-select" value={status} onChange={(event) => setStatus(event.target.value)}><option value="">Estado: Todos</option>{statuses.map((item) => <option key={item}>{item}</option>)}</select>
    </div>
    <article className="panel requests-panel">
      <div className="table-wrap"><table><thead><tr><th>Solicitud</th><th>Tipo</th><th>Inicio</th><th>Fin</th><th>Personas</th><th>Estado</th><th>Acciones</th></tr></thead>
        <tbody>
          {loading && <tr><td colSpan="7" className="empty-table">Cargando solicitudes…</td></tr>}
          {!loading && filtered.length === 0 && <tr><td colSpan="7" className="empty-table">No se encontraron solicitudes.</td></tr>}
          {filtered.map((item) => <tr key={item.idSolicitud}><td>{item.esPropia || canOpenAll ? <button type="button" className="request-number-link" onClick={() => onOpen(item.idSolicitud)}>{item.numeroSolicitud}</button> : <strong>{item.numeroSolicitud}</strong>}<span className="cell-sub">{item.nombreActividad}</span></td><td>{item.tipoIngreso ?? '—'}</td><td>{formatDate(item.fechaInicio)}</td><td>{formatDate(item.fechaFin)}</td><td>{item.cantidadPersonas}</td><td><span className="status-badge">{item.estado ?? 'Sin estado'}</span></td><td><div className="row-actions">{(item.esPropia || canOpenAll) && <button type="button" onClick={() => onOpen(item.idSolicitud)}>Ver detalle</button>}{item.esPropia && <button type="button" onClick={() => onEdit(item.idSolicitud)}>Editar</button>}{item.esPropia && item.ticketsPendientes > 0 && <button type="button" onClick={() => onTickets(item.idSolicitud)}>Tickets ({item.ticketsPendientes})</button>}<button type="button" className="delete-action" onClick={() => setDeletion(item)}>Eliminar</button></div></td></tr>)}
        </tbody>
      </table></div>
    </article>

    {deletion && <div className="approval-modal-backdrop" role="presentation" onMouseDown={() => !deleting && setDeletion(null)}>
      <section className="approval-modal reject request-delete-modal" role="alertdialog" aria-modal="true" aria-labelledby="request-delete-title" onMouseDown={(event) => event.stopPropagation()}>
        <header className="request-delete-header"><span><Icon name="warning" /></span><div><h2 id="request-delete-title">Eliminar solicitud</h2><p>Confirma que deseas eliminar este registro.</p></div></header>
        <div className="request-delete-body">
          <div className="request-delete-target"><span>Solicitud seleccionada</span><strong>{deletion.numeroSolicitud || `Solicitud #${deletion.idSolicitud}`}</strong><small>{deletion.nombreActividad || 'Solicitud de ingreso'}</small></div>
          <p className="delete-confirmation-message"><strong>Esta acción no se puede deshacer.</strong> La solicitud dejará de aparecer en el listado y se cancelará su proceso actual.</p>
        </div>
        <footer className="request-delete-actions"><button type="button" className="secondary-button" disabled={deleting} onClick={() => setDeletion(null)}>Cancelar</button><button type="button" className="primary-button danger-button" disabled={deleting} onClick={confirmDelete}>{deleting ? 'Eliminando…' : 'Sí, eliminar solicitud'}</button></footer>
      </section>
    </div>}
  </>
}
