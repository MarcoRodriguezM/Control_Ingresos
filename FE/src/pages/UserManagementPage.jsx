import { useState } from 'react'
import { Icon } from '../components/Icon'
import { formatDateTime, initials } from '../utils/formatters'

export function UserManagementPage({ items, loading, onNew, onSelect }) {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('activos')

  const normalizedQuery = query.trim().toLowerCase()
  const filtered = items.filter((item) => {
    const matchesQuery = !normalizedQuery || [item.idUsuario, item.nombreCompleto, item.correo, item.puesto, item.area]
      .some((value) => value?.toLowerCase().includes(normalizedQuery))
    const matchesStatus = status === 'todos'
      || (status === 'activos' && item.activo)
      || (status === 'inactivos' && !item.activo)
    return matchesQuery && matchesStatus
  })

  return <>
    <div className="page-heading requests-heading">
      <div><p className="eyebrow">Administración</p><h1>Listado de usuarios</h1><p>Consulta las cuentas, áreas, permisos y estado de los usuarios del sistema.</p></div>
      <button type="button" className="primary-button" onClick={onNew}><Icon name="users" />Nuevo usuario</button>
    </div>

    <div className="filters user-filters">
      <div className="search-box"><Icon name="search" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar usuario, correo, puesto o área" /></div>
      <select className="filter-select" value={status} onChange={(event) => setStatus(event.target.value)}><option value="activos">Activos</option><option value="inactivos">Inactivos</option><option value="todos">Todos</option></select>
    </div>

    <article className="panel requests-panel">
      <div className="table-wrap"><table className="approvals-table users-table"><thead><tr><th>Usuario</th><th>Contacto</th><th>Área / puesto</th><th>Permisos</th><th>Estado</th><th>Creación</th></tr></thead>
        <tbody>
          {loading && <tr><td colSpan="6" className="empty-table">Cargando usuarios…</td></tr>}
          {!loading && filtered.length === 0 && <tr><td colSpan="6" className="empty-table">No se encontraron usuarios.</td></tr>}
          {filtered.map((item) => <tr className="user-table-row" key={item.idUsuario} role="link" tabIndex="0" onClick={() => onSelect(item.idUsuario)} onKeyDown={(event) => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); onSelect(item.idUsuario) } }}>
            <td><div className="user-cell"><span className="person-avatar">{initials(item.nombreCompleto)}</span><span><strong>{item.nombreCompleto || item.idUsuario}</strong><small>{item.idUsuario}</small></span></div></td>
            <td>{item.correo || '—'}<span className="cell-sub">{item.telefono || 'Sin teléfono'}</span></td>
            <td>{item.area || 'Sin área'}<span className="cell-sub">{item.puesto || 'Sin puesto'}</span></td>
            <td><div className="user-role-list">{(item.roles?.split(',') ?? []).map((role) => <span key={role}>{role}</span>)}{!item.roles && <span className="muted">Usuario</span>}</div></td>
            <td><span className={`access-status ${item.activo ? 'approved' : 'rejected'}`}>{item.activo ? 'Activo' : 'Inactivo'}</span></td>
            <td>{formatDateTime(item.fechaCreacion)}</td>
          </tr>)}
        </tbody>
      </table></div>
    </article>
  </>
}
