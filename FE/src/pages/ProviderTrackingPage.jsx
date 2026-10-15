import { useMemo, useState } from 'react'
import { Icon } from '../components/Icon'
import { formatDate } from '../utils/formatters'

const statusClass = (code) => ({
  APROBADA: 'approved',
  RECHAZADA: 'rejected',
  PENDIENTE: 'pending',
  PENDIENTE_AREAS: 'unassigned',
}[code] ?? 'unassigned')

export function ProviderTrackingPage({ items = [], loading, onOpen }) {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('')
  const people = useMemo(() => items.flatMap((request) => request.personas ?? []), [items])
  const normalizedQuery = query.trim().toLowerCase()
  const filtered = items.filter((request) => {
    const matchesRequest = !normalizedQuery || [
      request.numeroSolicitud,
      request.nombreActividad,
      request.ubicacion,
      ...(request.personas ?? []).flatMap((person) => [person.nombreCompleto, person.numeroDocumento]),
    ].some((value) => value?.toLowerCase().includes(normalizedQuery))
    const matchesStatus = !status || (request.personas ?? []).some((person) => person.codigoEstadoAprobacion === status)
    return matchesRequest && matchesStatus
  })

  const count = (code) => people.filter((person) => person.codigoEstadoAprobacion === code).length

  return <div className="provider-tracking-page">
    <div className="page-heading provider-page-heading">
      <div><p className="eyebrow">Portal del proveedor</p><h1>Seguimiento</h1><p>Consulta el avance de las validaciones y el resultado de acceso de cada persona.</p></div>
      <span className="provider-request-total"><strong>{items.length}</strong> solicitudes</span>
    </div>

    <section className="provider-tracking-stats" aria-label="Resumen del seguimiento">
      <TrackingStat icon="file" label="Solicitudes" value={items.length} tone="blue" />
      <TrackingStat icon="users" label="Personas" value={people.length} tone="navy" />
      <TrackingStat icon="check" label="Aprobadas" value={count('APROBADA')} tone="green" />
      <TrackingStat icon="clock" label="Pendientes" value={count('PENDIENTE') + count('PENDIENTE_AREAS')} tone="amber" />
      <TrackingStat icon="close" label="Rechazadas" value={count('RECHAZADA')} tone="red" />
    </section>

    <div className="provider-tracking-toolbar">
      <label className="search-box"><Icon name="search" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar solicitud, persona o documento" /></label>
      <select value={status} onChange={(event) => setStatus(event.target.value)} aria-label="Filtrar por estado">
        <option value="">Todos los estados</option>
        <option value="PENDIENTE_AREAS">Pendiente de areas</option>
        <option value="PENDIENTE">Pendiente de aprobacion</option>
        <option value="APROBADA">Aprobada</option>
        <option value="RECHAZADA">Rechazada</option>
      </select>
    </div>

    {loading && <div className="panel loading-state">Cargando seguimiento...</div>}
    {!loading && items.length === 0 && <div className="panel provider-empty-state"><span><Icon name="check" /></span><h2>No hay solicitudes en seguimiento</h2><p>Las solicitudes enviadas a tu empresa apareceran aqui.</p></div>}
    {!loading && items.length > 0 && filtered.length === 0 && <div className="panel provider-empty-state"><span><Icon name="search" /></span><h2>Sin resultados</h2><p>No encontramos solicitudes o personas con los filtros seleccionados.</p></div>}

    {!loading && filtered.length > 0 && <section className="provider-tracking-list">
      {filtered.map((request) => <article className="panel provider-tracking-card" key={request.idSolicitud}>
        <header>
          <div><span>{request.numeroSolicitud || `Solicitud #${request.idSolicitud}`}</span><h2>{request.nombreActividad || 'Solicitud de ingreso'}</h2><p><Icon name="calendar" /> {formatDate(request.fechaInicio)} - {formatDate(request.fechaFin)} <Icon name="location" /> {request.ubicacion || 'Sin ubicacion'}</p></div>
          <div className="provider-tracking-request-state"><span>{request.estado || request.codigoEstado}</span><button type="button" onClick={() => onOpen(request.idSolicitud)}>Ver detalle <Icon name="arrow" /></button></div>
        </header>
        {(request.personas ?? []).length === 0
          ? <div className="provider-tracking-empty">Esta solicitud aun no tiene personas registradas.</div>
          : <div className="provider-tracking-people">
            {request.personas.map((person) => <div className="provider-tracking-person" key={person.idSolicitudPersona}>
              <span className="provider-person-avatar">{initials(person.nombreCompleto)}</span>
              <div className="provider-tracking-person-data"><strong>{person.nombreCompleto}</strong><small>{person.numeroDocumento || 'Sin documento'}</small></div>
              <div className="provider-access-counts">
                <span className="approved">{person.areasAprobadas} aprobadas</span>
                <span className="pending">{person.areasPendientes} pendientes</span>
                <span className="rejected">{person.areasRechazadas} rechazadas</span>
              </div>
              <span className={`provider-person-result ${statusClass(person.codigoEstadoAprobacion)}`}>{person.estadoAprobacion || 'Pendiente'}</span>
            </div>)}
          </div>}
      </article>)}
    </section>}
  </div>
}

function TrackingStat({ icon, label, value, tone }) {
  return <article className={`panel provider-tracking-stat ${tone}`}><span><Icon name={icon} /></span><div><small>{label}</small><strong>{value}</strong></div></article>
}

function initials(name) {
  return (name || 'P').trim().split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase()
}
