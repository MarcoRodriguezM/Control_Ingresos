import { useState } from 'react'
import { Icon } from '../components/Icon'
import { accessStatusClass, formatDate, formatDateTime, initials } from '../utils/formatters'

export function PersonAccessPage({ items, selected, loading, onSelect }) {
  const [query, setQuery] = useState('')
  const normalizedQuery = query.trim().toLowerCase()
  const filtered = items.filter((item) => !normalizedQuery || [item.nombreCompleto, item.numeroDocumento, item.empresa]
    .some((value) => value?.toLowerCase().includes(normalizedQuery)))

  return <>
    <div className="page-heading">
      <div><p className="eyebrow">Control de acceso</p><h1>Persona con sus accesos</h1><p>Consulta la información personal, solicitudes, áreas autorizadas y estado de aprobación.</p></div>
    </div>
    <div className="people-layout">
      <aside className="panel people-panel">
        <div className="people-search"><Icon name="search" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar persona" /></div>
        <div className="people-results">
          {loading && items.length === 0 && <p className="people-empty">Cargando personas…</p>}
          {!loading && filtered.length === 0 && <p className="people-empty">No se encontraron personas.</p>}
          {filtered.map((person) => <button type="button" className={`person-row ${selected?.idPersona === person.idPersona ? 'active' : ''}`} key={person.idPersona} onClick={() => onSelect(person.idPersona)}>
            <span className="person-avatar">{initials(person.nombreCompleto)}</span>
            <span className="person-row-copy"><strong>{person.nombreCompleto || 'Sin nombre'}</strong><small>{person.empresa || person.numeroDocumento || 'Sin empresa'}</small></span>
            <span className="access-count">{person.cantidadAccesos}</span>
          </button>)}
        </div>
      </aside>

      <section className="panel person-detail-panel">
        {loading && !selected && <div className="person-placeholder">Cargando información…</div>}
        {!loading && !selected && <div className="person-placeholder">Selecciona una persona para consultar sus accesos.</div>}
        {selected && <>
          <div className="person-profile"><div className="person-avatar large">{initials(selected.nombreCompleto)}</div><div><div className="profile-title"><h2>{selected.nombreCompleto}</h2><span className="status-badge success">{selected.estado || 'Sin estado'}</span></div><p>{selected.cargoFuncion || 'Cargo no indicado'} · {selected.empresa || 'Empresa no indicada'}</p></div></div>
          <div className="person-data-grid"><InfoValue label="Documento" value={selected.numeroDocumento} /><InfoValue label="Teléfono" value={selected.telefono} /><InfoValue label="Correo" value={selected.correo} /><InfoValue label="Total de accesos" value={String(selected.accesos?.length ?? 0)} /></div>
          <div className="access-heading"><div><h3>Accesos asignados</h3><p>Áreas vinculadas a las solicitudes de ingreso de esta persona.</p></div><span>{selected.accesos?.length ?? 0} accesos</span></div>
          <div className="access-list">
            {selected.accesos?.length === 0 && <div className="access-empty"><Icon name="shield" /><strong>Sin accesos asignados</strong><span>La persona todavía no está vinculada a un área.</span></div>}
            {selected.accesos?.map((access) => <article className="access-card" key={access.idSolicitudPersonaArea}><div className="access-icon"><Icon name="shield" /></div><div className="access-main"><div className="access-title"><h4>{access.area || 'Área sin nombre'}</h4><span className={`access-status ${accessStatusClass(access.estadoAcceso)}`}>{access.estadoAcceso || 'Pendiente'}</span></div><p>{access.actividad || 'Actividad no indicada'} · {access.numeroSolicitud || 'Sin número'}</p><div className="access-meta"><span><strong>Ubicación</strong>{access.ubicacion || '—'}</span><span><strong>Vigencia</strong>{formatDate(access.fechaInicio)} – {formatDate(access.fechaFin)}</span>{access.fechaDecision && <span><strong>Decisión</strong>{formatDateTime(access.fechaDecision)}</span>}</div>{access.comentarioDecision && <div className="access-comment">{access.comentarioDecision}</div>}</div></article>)}
          </div>
        </>}
      </section>
    </div>
  </>
}

function InfoValue({ label, value }) {
  return <div className="info-value"><span>{label}</span><strong>{value || '—'}</strong></div>
}
