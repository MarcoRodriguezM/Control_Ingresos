import { useMemo, useState } from 'react'
import { Icon } from '../components/Icon'
import { formatDate } from '../utils/formatters'

export function ProviderRequestsPage({ items = [], loading, onOpen }) {
  const pending = items.filter((item) => item.codigoEstado === 'PENDIENTE_PROVEEDOR')

  return <div className="provider-requests-page">
    <div className="page-heading provider-page-heading">
      <div><p className="eyebrow">Portal del proveedor</p><h1>Solicitudes</h1><p>Revisa y completa las solicitudes asignadas.</p></div>
      <span className="provider-request-total"><strong>{pending.length}</strong> {pending.length === 1 ? 'pendiente' : 'pendientes'}</span>
    </div>

    {loading && <div className="panel loading-state">Cargando solicitudes…</div>}
    {!loading && items.length === 0 && <div className="panel provider-empty-state"><span><Icon name="file" /></span><h2>No tienes solicitudes asignadas</h2><p>Cuando un solicitante envíe una solicitud a tu empresa aparecerá en este espacio.</p></div>}

    {!loading && items.length > 0 && <section className="panel provider-request-table-panel">
      <div className="table-wrap">
        <table className="provider-request-table">
          <thead><tr><th>Solicitud</th><th>Vigencia</th><th>Personas</th><th>Estado</th><th aria-label="Acción" /></tr></thead>
          <tbody>{items.map((item) => {
            const editable = item.codigoEstado === 'PENDIENTE_PROVEEDOR'
            const progress = Math.min((item.cantidadPersonas / Math.max(item.cantidadEstimada, 1)) * 100, 100)
            return <tr className={editable ? 'pending' : 'complete'} key={item.idSolicitud}>
              <td><strong className="provider-request-number">{item.numeroSolicitud || `Solicitud #${item.idSolicitud}`}</strong><span className="provider-request-title">{item.nombreActividad || 'Solicitud de ingreso'}</span><span className="provider-request-cell-sub">{item.usuarioSolicitante || 'Sin solicitante'}</span></td>
              <td><span className="provider-table-date"><Icon name="calendar" />{formatDate(item.fechaInicio)} – {formatDate(item.fechaFin)}</span><span className="provider-request-cell-sub"><Icon name="location" />{item.ubicacion || 'Pendiente'}</span></td>
              <td><div className="provider-table-progress"><div><strong>{item.cantidadPersonas}</strong><span> de {item.cantidadEstimada}</span></div><div className="provider-progress-track"><span style={{ width: `${progress}%` }} /></div></div></td>
              <td><span className={`provider-request-status ${editable ? 'pending' : 'complete'}`}>{item.estado || item.codigoEstado}</span></td>
              <td><button type="button" className="provider-table-action" onClick={() => onOpen(item.idSolicitud)}>{editable ? 'Completar' : 'Ver'} <Icon name="arrow" /></button></td>
            </tr>
          })}</tbody>
        </table>
      </div>
    </section>}
  </div>
}

export function ProviderRequestDetailPage({ request, people = [], loading, saving, onBack, onNewPerson, onAddPerson, onRemovePerson, onSend }) {
  const [personId, setPersonId] = useState('')
  const assignedIds = useMemo(() => new Set((request?.personas ?? []).map((item) => Number(item.idPersona))), [request])
  const availablePeople = people.filter((person) => !assignedIds.has(Number(person.idPersona)))
  const editable = request?.codigoEstado === 'PENDIENTE_PROVEEDOR'
  const remaining = Math.max((request?.cantidadEstimada ?? 0) - (request?.cantidadPersonas ?? 0), 0)

  async function addPerson() {
    if (!personId) return
    const result = await onAddPerson(Number(personId))
    if (result?.success) {
      setPersonId('')
    }
  }

  if (loading || !request) return <div className="panel loading-state">Cargando información de la solicitud…</div>

  return <div className="provider-request-detail-page">
    <button type="button" className="back-link" onClick={onBack}><Icon name="back" /> Volver a solicitudes</button>
    <section className="provider-request-detail-hero">
      <div><p className="eyebrow">{request.numeroSolicitud || `Solicitud #${request.idSolicitud}`}</p><h1>{request.nombreActividad}</h1><p>{request.descripcionActividad || 'Sin descripción adicional.'}</p></div>
      <div className="provider-detail-state"><span className={`provider-request-status ${editable ? 'pending' : 'complete'}`}>{request.estado}</span><strong>{request.cantidadPersonas} / {request.cantidadEstimada}</strong><small>personas registradas</small></div>
    </section>

    <section className="panel provider-request-summary">
      <Info label="Vigencia" value={`${formatDate(request.fechaInicio)} – ${formatDate(request.fechaFin)}`} />
      <Info label="Ubicación" value={request.ubicacion} />
      <Info label="Solicitante" value={request.usuarioSolicitante} />
      <Info label="Contacto" value={request.contactoProveedor} />
      <Info label="Correo" value={request.correoProveedor} />
      <Info label="Contrato" value={request.numeroContrato} />
    </section>

    {editable && <section className="panel provider-person-assignment">
      <div className="provider-card-heading"><span className="provider-card-icon"><Icon name="users" /></span><div><h2>Agregar personas a la solicitud</h2><p>Faltan {remaining} persona(s). Tu responsabilidad es únicamente registrar las personas.</p></div></div>
      <div className="provider-person-toolbar">
        <div className="field"><label>Persona del proveedor</label><select value={personId} onChange={(event) => setPersonId(event.target.value)}><option value="">Selecciona una persona</option>{availablePeople.map((person) => <option value={person.idPersona} key={person.idPersona}>{person.nombreCompleto} · {person.numeroDocumento || 'Sin documento'}</option>)}</select></div>
        <button type="button" className="secondary-button" onClick={onNewPerson}><Icon name="users" /> Registrar nueva</button>
      </div>
      <div className="provider-entry-note"><Icon name="users" /><div><strong>Las áreas serán asignadas por el solicitante</strong><p>Cuando envíes la solicitud, quedará pendiente de asignación de áreas.</p></div></div>
      <div className="provider-assignment-actions"><span>Sin asignación de áreas</span><button type="button" className="primary-button" disabled={saving || !personId || remaining === 0} onClick={addPerson}>{saving ? 'Agregando…' : 'Agregar a la solicitud'} <Icon name="arrow" /></button></div>
      <div className="provider-assignment-actions"><span>Puedes enviar con menos personas que la cantidad estimada.</span><button type="button" className="primary-button teal" disabled={saving || request.cantidadPersonas < 1} onClick={onSend}><Icon name="send" />{saving ? 'Procesando…' : 'Enviar solicitud'}</button></div>
    </section>}

    <section className="panel provider-assigned-people">
      <div className="provider-card-heading"><span className="provider-card-icon"><Icon name="check" /></span><div><h2>Personas registradas</h2><p>Personas que ya forman parte de esta solicitud.</p></div></div>
      {(request.personas ?? []).length === 0
        ? <div className="provider-inline-empty">Aún no se han agregado personas.</div>
        : <div className="provider-assigned-list">{request.personas.map((person) => <article key={person.idSolicitudPersona}><span className="provider-person-avatar">{initials(person.nombreCompleto)}</span><div><strong>{person.nombreCompleto}</strong><small>{person.numeroDocumento || 'Sin documento'}</small></div><span className={`provider-person-result ${personStatusClass(person.codigoEstadoAprobacion)}`}>{person.estadoAprobacion || 'Pendiente'}</span>{editable && <button type="button" className="remove-person-button" disabled={saving} onClick={() => onRemovePerson(person)}>Quitar</button>}</article>)}</div>}
    </section>
  </div>
}

function Info({ label, value }) {
  return <div><span>{label}</span><strong>{value || '—'}</strong></div>
}

function initials(name) {
  return (name || 'P').trim().split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase()
}

function personStatusClass(code) {
  return ({ APROBADA: 'approved', RECHAZADA: 'rejected', PENDIENTE: 'pending', PENDIENTE_AREAS: 'unassigned' })[code] ?? 'unassigned'
}
