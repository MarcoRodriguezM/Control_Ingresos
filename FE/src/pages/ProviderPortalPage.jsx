import { Icon } from '../components/Icon'

export function ProviderPortalPage({ session, requests = [], onCreatePerson, onRequests, onTracking }) {
  return <div className="provider-dashboard">
    <div className="provider-section-heading">
      <div><p className="eyebrow">Gestión de ingresos</p><h2>Tu espacio de trabajo</h2><p>Estas serán las herramientas disponibles para atender el proceso de ingreso.</p></div>
    </div>

    <section className="provider-feature-grid" aria-label="Herramientas del portal">
      <FeatureCard icon="file" tone="blue" title="Solicitudes recibidas" description="Consulta las solicitudes enviadas a tu empresa y registra las personas requeridas." actionLabel={`Ver solicitudes${requests.length ? ` (${requests.length})` : ''}`} onAction={onRequests} />
      <FeatureCard icon="users" tone="teal" title="Personas del proveedor" description="Registra las personas que participarán en cada ingreso." actionLabel="Registrar persona" onAction={onCreatePerson} />
      <FeatureCard icon="check" tone="green" title="Seguimiento" description="Conoce el avance de las validaciones y el estado de cada acceso." actionLabel="Ver seguimiento" onAction={onTracking} />
    </section>

    <div className="provider-bottom-grid">
      <aside className="panel provider-info-card">
        <span className="provider-info-icon"><Icon name="shield" /></span>
        <div><p className="eyebrow">Acceso seguro</p><h2>Portal independiente</h2><p>Tu cuenta solo tiene acceso a la información correspondiente al portal de proveedores.</p></div>
        <div className="provider-user-summary"><span>Sesión iniciada como</span><strong>{session?.nombreCompleto || session?.idUsuario}</strong><small>{session?.correo || session?.idUsuario}</small></div>
      </aside>
    </div>
  </div>
}

function FeatureCard({ icon, tone, title, description, actionLabel, onAction }) {
  return <article className={`panel provider-feature ${tone}`}>
    <div className="provider-feature-top"><span className="provider-feature-icon"><Icon name={icon} /></span><span className={`provider-coming-soon ${onAction ? 'available' : ''}`}>{onAction ? 'Disponible' : 'Próximamente'}</span></div>
    <h2>{title}</h2>
    <p>{description}</p>
    {onAction
      ? <button type="button" className="provider-feature-link" onClick={onAction}>{actionLabel}<Icon name="arrow" /></button>
      : <span className="provider-feature-link">Módulo del proveedor <Icon name="arrow" /></span>}
  </article>
}
