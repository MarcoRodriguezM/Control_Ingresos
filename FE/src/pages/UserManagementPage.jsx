import { useState } from 'react'
import { Icon } from '../components/Icon'
import { formatDateTime, initials } from '../utils/formatters'

const initialForm = {
  idUsuario: '', nombreCompleto: '', correo: '', telefono: '', puesto: '', contrasena: '',
  idArea: '', puedeSolicitar: true, esAprobador: false, activo: true,
}

export function UserManagementPage({ items, loading, areas, onCreate }) {
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState(initialForm)
  const [saving, setSaving] = useState(false)
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('activos')

  const normalizedQuery = query.trim().toLowerCase()
  const filtered = items.filter((item) => {
    const matchesQuery = !normalizedQuery || [item.idUsuario, item.nombreCompleto, item.correo, item.puesto, item.area]
      .some((value) => value?.toLowerCase().includes(normalizedQuery))
    const matchesStatus = status === 'todos' || (status === 'activos' && item.activo) || (status === 'inactivos' && !item.activo)
    return matchesQuery && matchesStatus
  })

  function change(event) {
    const { name, value, checked, type } = event.target
    setForm((current) => ({ ...current, [name]: type === 'checkbox' ? checked : value }))
  }

  async function submit(event) {
    event.preventDefault()
    setSaving(true)
    const result = await onCreate({
      idUsuario: form.idUsuario.trim(),
      nombreCompleto: form.nombreCompleto.trim(),
      correo: textOrNull(form.correo),
      telefono: textOrNull(form.telefono),
      puesto: textOrNull(form.puesto),
      contrasena: form.contrasena,
      idArea: numberOrNull(form.idArea),
      puedeSolicitar: form.puedeSolicitar,
      esAprobador: form.esAprobador,
      activo: form.activo,
    })
    setSaving(false)
    if (!result?.success) return
    setForm(initialForm)
    setShowForm(false)
  }

  return <>
    <div className="page-heading requests-heading">
      <div><p className="eyebrow">Administración</p><h1>Usuarios</h1><p>Administra las cuentas, áreas y permisos del sistema.</p></div>
      <button type="button" className="primary-button" onClick={() => setShowForm((current) => !current)}><Icon name="users" />{showForm ? 'Cerrar formulario' : 'Nuevo usuario'}</button>
    </div>

    {showForm && <form className="panel form-panel user-create-form" onSubmit={submit}>
      <div className="section-heading"><h2>Registrar usuario</h2><p>La contraseña inicial debe contener al menos ocho caracteres.</p></div>
      <div className="form-grid">
        <Field label="Identificador de usuario" required><input name="idUsuario" maxLength="50" value={form.idUsuario} onChange={change} required placeholder="Ej. nombre.apellido" autoComplete="off" /></Field>
        <Field label="Nombre completo" required><input name="nombreCompleto" maxLength="200" value={form.nombreCompleto} onChange={change} required /></Field>
        <Field label="Correo electrónico"><input type="email" name="correo" maxLength="254" value={form.correo} onChange={change} /></Field>
        <Field label="Teléfono"><input type="tel" name="telefono" maxLength="30" value={form.telefono} onChange={change} /></Field>
        <Field label="Puesto"><input name="puesto" maxLength="150" value={form.puesto} onChange={change} /></Field>
        <Field label="Área principal"><Select name="idArea" value={form.idArea} onChange={change} items={areas} /></Field>
        <Field label="Contraseña inicial" required full><input type="password" name="contrasena" minLength="8" maxLength="200" value={form.contrasena} onChange={change} required autoComplete="new-password" /></Field>
      </div>
      <div className="user-permissions">
        <Check name="puedeSolicitar" checked={form.puedeSolicitar} onChange={change} label="Puede crear solicitudes" description="Permite registrar solicitudes de ingreso para su área." />
        <Check name="esAprobador" checked={form.esAprobador} onChange={change} label="Es aprobador" description="Permite aprobar accesos y administrar actividades y usuarios." />
        <Check name="activo" checked={form.activo} onChange={change} label="Usuario activo" description="Permite iniciar sesión inmediatamente." />
      </div>
      <div className="form-footer"><button type="button" className="ghost-button" onClick={() => setShowForm(false)}>Cancelar</button><button type="submit" className="primary-button teal" disabled={saving}>{saving ? 'Guardando…' : 'Crear usuario'}</button></div>
    </form>}

    <div className="filters user-filters">
      <div className="search-box"><Icon name="search" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar usuario, correo, puesto o área" /></div>
      <select className="filter-select" value={status} onChange={(event) => setStatus(event.target.value)}><option value="activos">Activos</option><option value="inactivos">Inactivos</option><option value="todos">Todos</option></select>
    </div>

    <article className="panel requests-panel">
      <div className="table-wrap"><table className="approvals-table users-table"><thead><tr><th>Usuario</th><th>Contacto</th><th>Área / puesto</th><th>Permisos</th><th>Estado</th><th>Creación</th></tr></thead>
        <tbody>
          {loading && <tr><td colSpan="6" className="empty-table">Cargando usuarios…</td></tr>}
          {!loading && filtered.length === 0 && <tr><td colSpan="6" className="empty-table">No se encontraron usuarios.</td></tr>}
          {filtered.map((item) => <tr key={item.idUsuario}>
            <td><div className="user-cell"><span className="person-avatar">{initials(item.nombreCompleto)}</span><span><strong>{item.nombreCompleto || item.idUsuario}</strong><small>{item.idUsuario}</small></span></div></td>
            <td>{item.correo || '—'}<span className="cell-sub">{item.telefono || 'Sin teléfono'}</span></td>
            <td>{item.area || 'Sin área'}<span className="cell-sub">{item.puesto || 'Sin puesto'}</span></td>
            <td><div className="user-role-list">{item.puedeSolicitar && <span>Solicitante</span>}{item.esAprobador && <span>Aprobador</span>}{!item.puedeSolicitar && !item.esAprobador && <span className="muted">Usuario</span>}</div></td>
            <td><span className={`access-status ${item.activo ? 'approved' : 'rejected'}`}>{item.activo ? 'Activo' : 'Inactivo'}</span></td>
            <td>{formatDateTime(item.fechaCreacion)}</td>
          </tr>)}
        </tbody>
      </table></div>
    </article>
  </>
}

function Field({ label, required, full, children }) { return <div className={`field ${full ? 'full' : ''}`}><label>{label} {required && <span className="required">*</span>}</label>{children}</div> }
function Select({ items = [], ...props }) { return <select {...props}><option value="">Sin área asignada</option>{items.map((item) => <option key={item.id} value={item.id}>{item.nombre ?? item.codigo}</option>)}</select> }
function Check({ name, checked, onChange, label, description }) { return <label className="user-permission"><input type="checkbox" name={name} checked={checked} onChange={onChange} /><span><strong>{label}</strong><small>{description}</small></span></label> }
function numberOrNull(value) { return value === '' || value == null ? null : Number(value) }
function textOrNull(value) { const normalized = value?.trim(); return normalized || null }
