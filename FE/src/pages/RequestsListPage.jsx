import { useState } from 'react'
import { Icon } from '../components/Icon'
import { formatDate } from '../utils/formatters'

export function RequestsListPage({ items, loading, onNew, onEdit, onDelete }) {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('')
  const activeItems = items.filter((item) => item.estado?.toLowerCase() !== 'cancelada')
  const statuses = [...new Set(activeItems.map((item) => item.estado).filter(Boolean))]
  const normalizedQuery = query.trim().toLowerCase()
  const filtered = activeItems.filter((item) => {
    const matchesQuery = !normalizedQuery || [item.numeroSolicitud, item.nombreActividad, item.tipoIngreso, item.usuarioSolicitante]
      .some((value) => value?.toLowerCase().includes(normalizedQuery))
    return matchesQuery && (!status || item.estado === status)
  })

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
          {filtered.map((item) => <tr key={item.idSolicitud}><td><strong>{item.numeroSolicitud}</strong><span className="cell-sub">{item.nombreActividad}</span></td><td>{item.tipoIngreso ?? '—'}</td><td>{formatDate(item.fechaInicio)}</td><td>{formatDate(item.fechaFin)}</td><td>{item.cantidadPersonas}</td><td><span className="status-badge">{item.estado ?? 'Sin estado'}</span></td><td><div className="row-actions"><button type="button" onClick={() => onEdit(item.idSolicitud)}>Editar</button><button type="button" className="delete-action" onClick={() => onDelete(item.idSolicitud, item.numeroSolicitud)}>Eliminar</button></div></td></tr>)}
        </tbody>
      </table></div>
    </article>
  </>
}
