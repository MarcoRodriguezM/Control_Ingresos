import { Icon } from '../components/Icon'
import { formatDate, initials } from '../utils/formatters'

export function ProfilePage({ profile, loading, onOpenRequest }) {
  if (loading && !profile) return <div className="panel profile-placeholder">Cargando perfil…</div>
  if (!profile) return <div className="panel profile-placeholder">No fue posible cargar tu perfil.</div>

  const solicitudes = profile.solicitudes ?? []
  const areas = profile.areas ?? []
  const sent = solicitudes.filter((item) => item.estado?.toLocaleLowerCase('es').includes('enviad')).length
  const drafts = solicitudes.filter((item) => item.estado?.toLocaleLowerCase('es').includes('borrador')).length
  const roles = [profile.puedeSolicitar && 'Solicitante', profile.esAprobador && 'Aprobador de área'].filter(Boolean)

  return <div className="profile-page">
    <div className="page-heading"><div><p className="eyebrow">Cuenta</p><h1>Mi perfil</h1><p>Tu información, áreas asignadas y seguimiento de solicitudes.</p></div></div>

    <section className="panel profile-identity">
      <div className="profile-avatar">{initials(profile.nombreCompleto ?? profile.idUsuario)}</div>
      <div className="profile-identity-copy"><h2>{profile.nombreCompleto || profile.idUsuario}</h2><p>@{profile.idUsuario}{profile.puesto ? ` · ${profile.puesto}` : ''}</p><div className="profile-roles">{roles.length ? roles.map((role) => <span key={role}>{role}</span>) : <span>Usuario</span>}</div></div>
    </section>

    <div className="profile-grid">
      <section className="panel profile-section">
        <div className="profile-section-head"><Icon name="user" /><h2>Información personal</h2></div>
        <dl className="profile-details"><div><dt>Nombre completo</dt><dd>{profile.nombreCompleto || '—'}</dd></div><div><dt>Usuario</dt><dd>{profile.idUsuario}</dd></div><div><dt>Correo</dt><dd>{profile.correo || 'No registrado'}</dd></div><div><dt>Teléfono</dt><dd>{profile.telefono || 'No registrado'}</dd></div><div><dt>Puesto</dt><dd>{profile.puesto || 'No registrado'}</dd></div></dl>
      </section>

      <section className="panel profile-section">
        <div className="profile-section-head"><Icon name="shield" /><h2>Áreas y funciones</h2></div>
        {areas.length === 0 ? <p className="profile-empty">No tienes áreas asignadas.</p> : <div className="profile-area-list">{areas.map((area) => <div className="profile-area" key={area.idArea}><strong>{area.nombre || `Área #${area.idArea}`}</strong><div className="profile-area-badges">{area.esAreaPrincipal && <span>Área principal</span>}{area.puedeSolicitar && <span>Puede solicitar</span>}{area.esAprobador && <span>{area.esAprobadorPrincipal ? 'Aprobador principal' : 'Aprobador'}</span>}</div></div>)}</div>}
        <p className="profile-role-note">“Aprobador principal” indica la asignación principal de aprobación del área; no implica un cargo administrativo adicional.</p>
      </section>
    </div>

    <section className="profile-requests">
      <div className="profile-requests-heading"><div><h2>Mis solicitudes</h2><p>Estado actual de las solicitudes registradas a tu nombre.</p></div><div className="profile-request-counts"><span><strong>{solicitudes.length}</strong> Total</span><span><strong>{sent}</strong> Enviadas</span><span><strong>{drafts}</strong> Borradores</span></div></div>
      <div className="panel requests-panel"><div className="table-wrap"><table><thead><tr><th>Solicitud</th><th>Tipo</th><th>Periodo</th><th>Personas</th><th>Estado / proceso</th><th>Acción</th></tr></thead><tbody>
        {solicitudes.length === 0 && <tr><td colSpan="6" className="empty-table">Todavía no tienes solicitudes registradas.</td></tr>}
        {solicitudes.map((item) => <tr key={item.idSolicitud}><td><strong>{item.numeroSolicitud || `#${item.idSolicitud}`}</strong><span className="cell-sub">{item.nombreActividad || 'Sin actividad'}</span></td><td>{item.tipoIngreso || '—'}</td><td>{formatDate(item.fechaInicio)}<span className="cell-sub">hasta {formatDate(item.fechaFin)}</span></td><td>{item.cantidadPersonas}</td><td><span className="status-badge">{item.estado || 'Sin estado'}</span></td><td><button type="button" className="profile-open-request" onClick={() => onOpenRequest(item.idSolicitud)}>Abrir <Icon name="arrow" /></button></td></tr>)}
      </tbody></table></div></div>
    </section>
  </div>
}
