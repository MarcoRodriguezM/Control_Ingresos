import { Icon } from '../components/Icon'
import { formatDate } from '../utils/formatters'

const normalize = (value) => (value ?? '').trim().toLocaleLowerCase('es')

export function DashboardPage({ session, requests, approvals, loading, approvalsLoading, onNew, onRequests, onRequest, onApprovals, onPersons }) {
  const today = new Date().toLocaleDateString('en-CA')
  const pendingApprovals = approvals.filter((item) => item.codigoEstado === 'PENDIENTE').length
  const sent = requests.filter((item) => normalize(item.estado).includes('enviad')).length
  const active = requests.filter((item) => item.fechaInicio && item.fechaFin && item.fechaInicio <= today && item.fechaFin >= today).length
  const linkedPeople = requests.reduce((total, item) => total + (Number(item.cantidadPersonas) || 0), 0)
  const recent = [...requests].sort((a, b) => b.idSolicitud - a.idSolicitud).slice(0, 5)
  const upcoming = requests
    .filter((item) => item.fechaInicio && item.fechaInicio >= today)
    .sort((a, b) => a.fechaInicio.localeCompare(b.fechaInicio))
    .slice(0, 4)

  return <div className="dashboard-page">
    <div className="page-heading dashboard-heading">
      <div><p className="eyebrow">Panel principal</p><h1>Bienvenido, {session.nombreCompleto?.split(/\s+/)[0] || session.idUsuario}</h1><p>Consulta el estado de los ingresos y continúa con tus tareas.</p></div>
      <button type="button" className="primary-button" onClick={onNew}><span className="plus-sign">+</span>Nueva solicitud</button>
    </div>

    <section className="dashboard-stats" aria-label="Resumen de solicitudes">
      <StatCard icon="file" label="Solicitudes" value={requests.length} loading={loading} hint="Registradas en el sistema" tone="blue" />
      <StatCard icon="send" label="Enviadas" value={sent} loading={loading} hint="En proceso de revisión" tone="teal" />
      <StatCard icon="check" label="Fecha vigente" value={active} loading={loading} hint="Solicitudes dentro de su rango" tone="green" />
      {session.esAprobador
        ? <StatCard icon="shield" label="Por aprobar" value={pendingApprovals} loading={approvalsLoading} hint="Decisiones pendientes" tone="amber" />
        : <StatCard icon="users" label="Personas vinculadas" value={linkedPeople} loading={loading} hint="En todas las solicitudes" tone="amber" />}
    </section>

    <div className="dashboard-grid">
      <section className="panel dashboard-panel dashboard-recent">
        <div className="dashboard-panel-head"><div><h2>Solicitudes recientes</h2><p>Últimos registros disponibles</p></div><button type="button" className="dashboard-link" onClick={onRequests}>Ver todas <Icon name="arrow" /></button></div>
        {loading ? <p className="dashboard-empty">Cargando solicitudes…</p> : recent.length === 0 ? <p className="dashboard-empty">Todavía no hay solicitudes. Crea la primera para verla aquí.</p> :
          <div className="dashboard-request-list">{recent.map((item) => <button type="button" className="dashboard-request" key={item.idSolicitud} onClick={() => onRequest(item.idSolicitud)}>
            <span className="dashboard-request-icon"><Icon name="file" /></span>
            <span className="dashboard-request-copy"><strong>{item.nombreActividad || item.numeroSolicitud || `Solicitud #${item.idSolicitud}`}</strong><small>{item.numeroSolicitud || `#${item.idSolicitud}`} · {item.tipoIngreso || 'Sin tipo'}</small></span>
            <span className="dashboard-request-meta"><span className="status-badge">{item.estado || 'Sin estado'}</span><small>{formatDate(item.fechaInicio)}</small></span>
          </button>)}</div>}
      </section>

      <div className="dashboard-side">
        <section className="panel dashboard-panel">
          <div className="dashboard-panel-head"><div><h2>Próximas fechas</h2><p>Solicitudes con fecha de inicio próxima</p></div></div>
          {loading ? <p className="dashboard-empty">Cargando fechas…</p> : upcoming.length === 0 ? <p className="dashboard-empty">No hay solicitudes próximas registradas.</p> :
            <div className="dashboard-upcoming-list">{upcoming.map((item) => <button type="button" className="dashboard-upcoming" key={item.idSolicitud} onClick={() => onRequest(item.idSolicitud)}>
              <span className="dashboard-date">{formatDate(item.fechaInicio)}</span><span><strong>{item.nombreActividad || item.numeroSolicitud || `Solicitud #${item.idSolicitud}`}</strong><small>{item.numeroSolicitud || `#${item.idSolicitud}`}</small></span><Icon name="arrow" />
            </button>)}</div>}
        </section>

        <section className="panel dashboard-panel dashboard-shortcuts">
          <div className="dashboard-panel-head"><div><h2>Accesos rápidos</h2><p>Ve directamente a lo que necesitas</p></div></div>
          <button type="button" onClick={onNew}><Icon name="file" /><span>Crear solicitud</span><Icon name="arrow" /></button>
          <button type="button" onClick={onPersons}><Icon name="users" /><span>Personas y accesos</span><Icon name="arrow" /></button>
          {session.esAprobador && <button type="button" onClick={onApprovals}><Icon name="shield" /><span>Mis aprobaciones</span><Icon name="arrow" /></button>}
        </section>
      </div>
    </div>
  </div>
}

function StatCard({ icon, label, value, loading, hint, tone }) {
  return <article className={`panel dashboard-stat ${tone}`}><span className="dashboard-stat-icon"><Icon name={icon} /></span><span className="dashboard-stat-label">{label}</span><strong>{loading ? '—' : value}</strong><small>{hint}</small></article>
}
