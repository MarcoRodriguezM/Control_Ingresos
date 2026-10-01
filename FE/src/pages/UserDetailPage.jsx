import { useEffect, useState } from 'react'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { formatDate, formatDateTime, initials } from '../utils/formatters'

export function UserDetailPage({ idUsuario, onBack, onEdit, onError }) {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let active = true
    setLoading(true)
    setUser(null)
    onError('')

    controlIngresosApi.obtenerUsuario(idUsuario)
      .then((data) => active && setUser(data))
      .catch((error) => active && onError(error.status === 404 ? 'El usuario seleccionado no existe.' : error.message))
      .finally(() => active && setLoading(false))

    return () => { active = false }
  }, [idUsuario, onError])

  if (loading) return <div className="panel profile-placeholder">Cargando información del usuario…</div>
  if (!user) return <div className="panel profile-placeholder"><button type="button" className="secondary-button" onClick={onBack}><Icon name="back" />Volver al listado</button></div>

  const roles = user.roles?.split(',').map((role) => role.trim()).filter(Boolean) ?? []

  return <>
    <div className="page-heading user-detail-heading">
      <div><p className="eyebrow">Administración</p><h1>Detalle del usuario</h1><p>Información de la cuenta, permisos y áreas asignadas.</p></div>
      <div className="action-row"><button type="button" className="secondary-button" onClick={onBack}><Icon name="back" />Volver a usuarios</button><button type="button" className="primary-button" onClick={onEdit}><Icon name="settings" />Editar usuario</button></div>
    </div>

    <section className="panel profile-identity">
      <div className="profile-avatar">{initials(user.nombreCompleto)}</div>
      <div className="profile-identity-copy">
        <div className="profile-title"><h2>{user.nombreCompleto || user.idUsuario}</h2><span className={`access-status ${user.activo ? 'approved' : 'rejected'}`}>{user.estado || (user.activo ? 'Activo' : 'Inactivo')}</span></div>
        <p>@{user.idUsuario}{user.puesto ? ` · ${user.puesto}` : ''}</p>
        <div className="profile-roles">{roles.length > 0 ? roles.map((role) => <span key={role}>{role}</span>) : <span>Sin roles asignados</span>}</div>
      </div>
    </section>

    <div className="profile-grid">
      <section className="panel profile-section">
        <div className="profile-section-head"><Icon name="user" /><h2>Datos del usuario</h2></div>
        <dl className="profile-details">
          <Detail label="Identificador" value={user.idUsuario} />
          <Detail label="Nombre completo" value={user.nombreCompleto} />
          <Detail label="Correo electrónico" value={user.correo} />
          <Detail label="Teléfono" value={user.telefono} />
          <Detail label="Puesto" value={user.puesto} />
          <Detail label="Estado" value={user.estado} />
        </dl>
      </section>

      <section className="panel profile-section">
        <div className="profile-section-head"><Icon name="tasks" /><h2>Auditoría</h2></div>
        <dl className="profile-details">
          <Detail label="Fecha de creación" value={formatDateTime(user.fechaCreacion)} />
          <Detail label="Creado por" value={user.usuarioCreacion} />
          <Detail label="Última modificación" value={formatDateTime(user.fechaModificacion)} />
          <Detail label="Modificado por" value={user.usuarioModificacion} />
        </dl>
      </section>
    </div>

    <section className="panel profile-section user-areas-section">
      <div className="profile-section-head"><Icon name="settings" /><h2>Áreas y permisos</h2></div>
      {user.areas?.length === 0
        ? <p className="profile-empty">Este usuario no tiene áreas asignadas.</p>
        : <div className="profile-area-list">{user.areas.map((area) => <div className="profile-area" key={area.idArea}>
          <div className="user-area-title"><strong>{area.nombre || `Área #${area.idArea}`}</strong><span className={`access-status ${area.activo ? 'approved' : 'rejected'}`}>{area.activo ? 'Activa' : 'Inactiva'}</span></div>
          <span className="cell-sub">{area.codigo || 'Sin código'} · {formatDate(area.fechaInicio)} – {formatDate(area.fechaFin)}</span>
          <div className="profile-area-badges">
            {area.esAreaPrincipal && <span>Área principal</span>}
            {area.puedeSolicitar && <span>Puede solicitar</span>}
            {area.esAprobador && <span>{area.esAprobadorPrincipal ? 'Aprobador principal' : 'Aprobador'}</span>}
          </div>
        </div>)}</div>}
    </section>
  </>
}

function Detail({ label, value }) {
  return <div><dt>{label}</dt><dd>{value || '—'}</dd></div>
}
