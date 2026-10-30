import { useEffect, useState } from 'react'
import { useParams, useSearchParams } from 'react-router-dom'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'

export function RequestTicketsPage({ onBack }) {
  const { id } = useParams()
  const [searchParams] = useSearchParams()
  const personId = searchParams.get('persona')
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [selected, setSelected] = useState(null)
  const [form, setForm] = useState({ idTicketExterno: '', plataforma: '', numeroTicket: '', urlTicket: '', idsActividad: [] })
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    let active = true
    controlIngresosApi.listarTicketsSolicitud(id)
      .then((result) => { if (active) setItems(result ?? []) })
      .catch((requestError) => { if (active) setError(requestError.message) })
      .finally(() => { if (active) setLoading(false) })
    return () => { active = false }
  }, [id])

  async function saveTicket(event) {
    event.preventDefault()
    if (!selected || (!form.idTicketExterno && (!form.plataforma.trim() || !form.numeroTicket.trim()))) return
    setSaving(true)
    setError('')
    try {
      await controlIngresosApi.crearTicketActividad(selected.idActividad, {
        idTicketExterno: form.idTicketExterno ? Number(form.idTicketExterno) : null,
        idsActividad: form.idsActividad,
        plataforma: form.plataforma.trim(),
        numeroTicket: form.numeroTicket.trim(),
        urlTicket: form.urlTicket.trim() || null,
      })
      setItems(await controlIngresosApi.listarTicketsSolicitud(id))
      setSelected(null)
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setSaving(false)
    }
  }

  const visibleItems = personId ? items.filter((item) => String(item.idSolicitudPersona) === personId) : items
  const existingTickets = [...new Map(items.flatMap((item) => item.tickets ?? (item.ticket ? [item.ticket] : [])).map((ticket) => [ticket.idActividadTicket, ticket])).values()]
  const pending = visibleItems.filter((item) => (item.tickets?.length ?? (item.ticket ? 1 : 0)) === 0 && !item.esEstadoFinal && (!item.fechaFin || new Date(`${item.fechaFin.slice(0, 10)}T23:59:59`) >= new Date())).length

  return <div className="request-tickets-page">
    <div className="page-heading request-tickets-heading">
      <div><p className="eyebrow">Solicitud {items[0]?.numeroSolicitud || `#${id}`}</p><h1>Tickets de actividades</h1><p>Registra los tickets requeridos para las personas incluidas en tu solicitud.</p></div>
      <button type="button" className="secondary-button" onClick={onBack}><Icon name="back" />Volver al seguimiento</button>
    </div>
    <div className="request-ticket-count"><strong>{pending}</strong><span>ticket(s) pendientes</span></div>
    {error && !selected && <p className="activity-ticket-error" role="alert">{error}</p>}
    <section className="panel request-ticket-list" aria-label="Tickets de la solicitud">
      {loading ? <p className="activity-empty">Cargando tickets…</p> : visibleItems.length === 0
        ? <p className="activity-empty">Esta solicitud no tiene actividades que requieran ticket. Las actividades aparecen despues de asignar las personas y enviar la solicitud.</p>
        : visibleItems.map((item) => {
          const expired = item.fechaFin && new Date(`${item.fechaFin.slice(0, 10)}T23:59:59`) < new Date()
          const activityTickets = item.tickets ?? (item.ticket ? [item.ticket] : [])
          return <article className="request-ticket-row" key={item.idActividad}>
            <div><small>{item.persona || 'Persona no indicada'} · {item.areaResponsable || 'Area no indicada'}</small><h2>{item.nombreActividad || `Actividad #${item.idActividad}`}</h2>
              {activityTickets.length ? <div className="request-ticket-links">{activityTickets.map((ticket) => <p key={ticket.idActividadTicket}>Ticket registrado: <strong>{ticket.plataforma} · {ticket.numeroTicket}</strong>{ticket.urlTicket?.startsWith('https://') && <> · <a href={ticket.urlTicket} target="_blank" rel="noopener noreferrer">Abrir enlace</a></>}</p>)}</div>
                : <p>{item.esEstadoFinal ? 'Actividad finalizada sin ticket.' : expired ? 'La solicitud ya vencio.' : 'Esta actividad requiere un ticket antes de completarse.'}</p>}
            </div>
            <span className={`access-status ${activityTickets.length ? 'approved' : 'pending'}`}>{activityTickets.length ? `${activityTickets.length} registrado(s)` : 'Pendiente'}</span>
            {!item.esEstadoFinal && !expired && <button type="button" className="primary-button" onClick={() => { setError(''); setForm({ idTicketExterno: '', plataforma: '', numeroTicket: '', urlTicket: '', idsActividad: [item.idActividad] }); setSelected(item) }}>{activityTickets.length ? 'Agregar otro ticket' : 'Creacion de ticket'}</button>}
          </article>
        })}
    </section>

    {selected && <div className="approval-modal-backdrop" role="presentation" onMouseDown={() => !saving && setSelected(null)}>
      <section className="approval-modal approve activity-completion-modal" role="dialog" aria-modal="true" aria-labelledby="ticket-title" onMouseDown={(event) => event.stopPropagation()}>
        <h2 id="ticket-title" className="approval-modal-title">Creacion de ticket</h2>
        <div className="decision-copy"><div><h3>{selected.nombreActividad}</h3><p>{selected.persona || 'Persona no indicada'}</p></div></div>
        <form className="decision-form activity-ticket-form" onSubmit={saveTicket}>
          {existingTickets.length > 0 && <label>Usar ticket existente<select value={form.idTicketExterno} onChange={(event) => setForm({ ...form, idTicketExterno: event.target.value })}><option value="">Crear un ticket nuevo</option>{existingTickets.map((ticket) => <option key={ticket.idActividadTicket} value={ticket.idActividadTicket}>{ticket.plataforma} · {ticket.numeroTicket}</option>)}</select></label>}
          <label>Plataforma<input required={!form.idTicketExterno} disabled={Boolean(form.idTicketExterno)} maxLength="100" value={form.plataforma} onChange={(event) => setForm({ ...form, plataforma: event.target.value })} placeholder="Ej. Mesa de ayuda" autoFocus /></label>
          <label>Numero de ticket<input required={!form.idTicketExterno} disabled={Boolean(form.idTicketExterno)} maxLength="80" value={form.numeroTicket} onChange={(event) => setForm({ ...form, numeroTicket: event.target.value })} placeholder="Ej. INC-12345" /></label>
          <label>Enlace del ticket (opcional)<input type="url" disabled={Boolean(form.idTicketExterno)} maxLength="500" value={form.urlTicket} onChange={(event) => setForm({ ...form, urlTicket: event.target.value })} placeholder="https://..." /></label>
          <fieldset className="workflow-entry-types"><legend>Actividades cubiertas por este ticket</legend>{items.filter((item) => !item.esEstadoFinal).map((item) => <label key={item.idActividad}><input type="checkbox" checked={form.idsActividad.includes(item.idActividad)} disabled={item.idActividad === selected.idActividad} onChange={(event) => setForm({ ...form, idsActividad: event.target.checked ? [...form.idsActividad, item.idActividad] : form.idsActividad.filter((idActividad) => idActividad !== item.idActividad) })} />{item.persona || 'Persona no indicada'} · {item.nombreActividad}</label>)}<small>Un mismo ticket puede respaldar actividades de varias personas de esta solicitud.</small></fieldset>
          {error && <p className="activity-ticket-error" role="alert">{error}</p>}
          <div className="action-row"><button type="button" className="secondary-button" disabled={saving} onClick={() => setSelected(null)}>Cancelar</button><button type="submit" className="primary-button teal" disabled={saving}>{saving ? 'Guardando…' : 'Guardar ticket'}</button></div>
        </form>
      </section>
    </div>}
  </div>
}
