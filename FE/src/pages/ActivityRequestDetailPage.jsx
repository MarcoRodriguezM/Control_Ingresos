import { Icon } from '../components/Icon'
import { activityStatusLabel, formatDate, formatDateTime } from '../utils/formatters'

export function ActivityRequestDetailPage({ request, activities = [], options, loading, onBack }) {
  if (loading || !request) return <section className="panel activity-request-loading">Cargando información de la solicitud…</section>

  const person = activities.find((item) => item.persona)?.persona
    ? activities.find((item) => item.persona)
    : null
  const groups = groupByAccessArea(activities)

  return <div className="activity-request-page">
    <div className="page-heading activity-request-heading">
      <div><p className="eyebrow">Consulta de actividad</p><h1>{request.numeroSolicitud || `Solicitud #${request.idSolicitud}`}</h1><p>Información de la solicitud y actividades requeridas para el acceso.</p></div>
      <button type="button" className="secondary-button" onClick={onBack}><Icon name="back" />Volver a mis actividades</button>
    </div>

    <section className="panel activity-request-summary">
      <div className="activity-request-title"><span><Icon name="file" /></span><div><small>Actividad de la solicitud</small><h2>{request.nombreActividad || 'Solicitud de ingreso'}</h2><p>{request.descripcionActividad || 'Sin descripción adicional.'}</p></div></div>
      <div className="activity-request-data">
        <ReadOnly label="Tipo de ingreso" value={optionName(options?.tiposIngreso, request.idTipoIngreso)} />
        <ReadOnly label="Vigencia" value={`${formatDate(request.fechaInicio)} — ${formatDate(request.fechaFin)}`} />
        <ReadOnly label="Área solicitante" value={optionName(options?.areas, request.idAreaSolicitante)} />
        <ReadOnly label="Ubicación" value={optionName(options?.ubicaciones, request.idUbicacion)} />
        <ReadOnly label="Solicitante" value={optionName(options?.usuarios, request.idUsuarioSolicitante) || request.idUsuarioSolicitante} />
        <ReadOnly label="Estado" value={optionName(options?.estadosSolicitud, request.idEstadoSolicitud)} />
      </div>
      {request.observaciones && <div className="activity-request-note"><strong>Observaciones</strong><p>{request.observaciones}</p></div>}
    </section>

    {person && <section className="panel activity-request-person"><span className="activity-request-person-avatar">{initials(person.persona)}</span><div><small>Persona relacionada</small><h2>{person.persona}</h2><p>{person.numeroDocumento || 'Sin documento registrado'}</p></div></section>}

    <div className="activity-request-section-heading"><div><p className="eyebrow">Accesos requeridos</p><h2>Áreas y actividades</h2><p>Estas son las actividades que deben completarse antes de autorizar el ingreso.</p></div><span>{activities.length} actividad(es)</span></div>

    {groups.length === 0
      ? <section className="panel activity-request-empty"><Icon name="tasks" /><strong>No hay actividades asociadas</strong><span>Esta solicitud no tiene actividades asignadas para la persona seleccionada.</span></section>
      : <div className="activity-access-groups">{groups.map((group) => <section className="panel activity-access-group" key={group.key}>
        <header><span><Icon name="shield" /></span><div><small>Área de acceso</small><h3>{group.name}</h3></div><strong>{group.items.length}</strong></header>
        <div>{group.items.map((activity, index) => <article className="activity-access-step" key={activity.idActividad}>
          <span className="activity-access-order">{index + 1}</span>
          <div className="activity-access-copy"><div><h4>{activity.nombreActividad || `Actividad #${activity.idActividad}`}</h4><span className={`access-status ${statusClass(activity.codigoEstado)}`}>{activityStatusLabel(activity.codigoEstado, 'Pendiente')}</span></div><p>Responsable: {activity.areaResponsable || 'Area no indicada'}</p><div className="activity-access-dates"><span><strong>Fecha limite</strong>{formatDateTime(activity.fechaLimite)}</span><span><strong>Realizada</strong>{formatDateTime(activity.fechaFinalizacion)}</span></div>{activity.requiereTicketExterno && <p className="activity-ticket-detail">{activity.ticket ? <>Ticket: <strong>{activity.ticket.plataforma} · {activity.ticket.numeroTicket}</strong>{activity.ticket.urlTicket?.startsWith('https://') && <> · <a href={activity.ticket.urlTicket} target="_blank" rel="noopener noreferrer">Abrir ticket</a></>}</> : 'Ticket pendiente del solicitante'}</p>}{activity.comentarios && <blockquote>{activity.comentarios}</blockquote>}</div>
        </article>)}</div>
      </section>)}</div>}
  </div>
}

function ReadOnly({ label, value }) {
  return <div><span>{label}</span><strong>{value || '—'}</strong></div>
}

function optionName(items, id) {
  return items?.find((item) => String(item.id) === String(id))?.nombre
}

function initials(name) {
  return name?.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase() || '—'
}

function statusClass(code = '') {
  return ({ APROBADA: 'approved', RECHAZADA: 'rejected', PENDIENTE_APROBACION: 'pending' }[code] ?? 'pending')
}

function groupByAccessArea(activities) {
  const groups = new Map()
  activities.forEach((activity) => {
    const key = String(activity.idAreaAcceso ?? activity.areaAcceso ?? activity.areaResponsable ?? 'sin-area')
    if (!groups.has(key)) groups.set(key, { key, name: activity.areaAcceso || activity.areaResponsable || 'Área no indicada', items: [] })
    groups.get(key).items.push(activity)
  })
  return [...groups.values()]
}
