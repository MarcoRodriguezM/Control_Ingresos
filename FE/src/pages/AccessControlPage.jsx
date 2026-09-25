import { useMemo, useState } from 'react'
import { Icon } from '../components/Icon'
import { formatDateTime } from '../utils/formatters'

export function AccessControlPage({ people = [], movements = [], loading, saving, onRegister }) {
  const [personId, setPersonId] = useState('')
  const [type, setType] = useState('ENTRADA')
  const [observations, setObservations] = useState('')
  const selected = useMemo(() => people.find((item) => Number(item.idPersona) === Number(personId)), [people, personId])

  async function submit(event) {
    event.preventDefault()
    if (!personId) return
    const result = await onRegister({ idPersona: Number(personId), tipoMovimiento: type, observaciones: observations.trim() || null })
    if (result?.success) setObservations('')
  }

  return <>
    <div className="page-heading requests-heading">
      <div><p className="eyebrow">Portería</p><h1>Control de entradas y salidas</h1><p>Valida la autorización vigente y registra cada movimiento de las personas.</p></div>
    </div>

    <form className="panel gate-form" onSubmit={submit}>
      <div className="section-heading"><h2>Registrar movimiento</h2><p>El backend bloqueará entradas sin una solicitud vigente y completamente aprobada.</p></div>
      <div className="form-grid">
        <div className="field full"><label>Persona <span className="required">*</span></label><select value={personId} onChange={(event) => setPersonId(event.target.value)} required><option value="">Selecciona por nombre o documento</option>{people.map((person) => <option key={person.idPersona} value={person.idPersona}>{person.nombreCompleto || 'Sin nombre'} · {person.numeroDocumento || 'Sin documento'}</option>)}</select></div>
        <div className="field"><label>Movimiento</label><select value={type} onChange={(event) => setType(event.target.value)}><option value="ENTRADA">Entrada</option><option value="SALIDA">Salida</option></select></div>
        <div className="field"><label>Persona seleccionada</label><div className="gate-person-summary"><strong>{selected?.nombreCompleto || 'Ninguna'}</strong><span>{selected?.empresa || selected?.numeroDocumento || 'Selecciona una persona'}</span></div></div>
        <div className="field full"><label>Observaciones</label><textarea maxLength="500" value={observations} onChange={(event) => setObservations(event.target.value)} placeholder="Incidencia, identificación presentada u observación opcional" /></div>
      </div>
      <div className="form-footer"><span className="gate-validation-note"><Icon name="shield" />La autorización se verifica al guardar.</span><button className={`primary-button ${type === 'ENTRADA' ? 'teal' : ''}`} disabled={saving || !personId}>{saving ? 'Registrando…' : `Registrar ${type.toLowerCase()}`}</button></div>
    </form>

    <article className="panel requests-panel gate-history">
      <div className="dashboard-panel-head"><div><h2>Movimientos recientes</h2><p>Últimos registros realizados en portería</p></div></div>
      <div className="table-wrap"><table><thead><tr><th>Fecha</th><th>Movimiento</th><th>Persona</th><th>Solicitud / actividad</th><th>Registrado por</th><th>Observación</th></tr></thead><tbody>
        {loading && <tr><td colSpan="6" className="empty-table">Cargando movimientos…</td></tr>}
        {!loading && movements.length === 0 && <tr><td colSpan="6" className="empty-table">Todavía no se han registrado entradas o salidas.</td></tr>}
        {movements.map((item) => <tr key={item.idRegistroIngreso}><td>{formatDateTime(item.fechaMovimiento)}</td><td><span className={`gate-movement ${item.tipoMovimiento === 'ENTRADA' ? 'entry' : 'exit'}`}>{item.tipoMovimiento}</span></td><td><strong>{item.nombreCompleto}</strong><span className="cell-sub">{item.numeroDocumento}</span></td><td>{item.numeroSolicitud}<span className="cell-sub">{item.actividad}</span></td><td>{item.usuarioSeguridad || item.idUsuarioSeguridad}</td><td>{item.observaciones || '—'}</td></tr>)}
      </tbody></table></div>
    </article>
  </>
}
