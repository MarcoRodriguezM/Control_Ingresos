import { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { formatDate, initials } from '../utils/formatters'
import auraLogo from '../assets/aura-logo-default.png'

const qrPattern = /^[a-f0-9]{64}$/i

export function PublicPersonCredentialPage({ authenticated = false, onLogin }) {
  const codigoQr = new URLSearchParams(window.location.search).get('codigo')?.trim() ?? ''
  const codigoQrValido = qrPattern.test(codigoQr)
  const [persona, setPersona] = useState(null)
  const [photographUrl, setPhotographUrl] = useState('')
  const [qrImage, setQrImage] = useState('')
  const [loading, setLoading] = useState(codigoQrValido)
  const [error, setError] = useState(codigoQrValido ? '' : 'El enlace de la credencial no es válido.')

  useEffect(() => {
    if (!codigoQrValido) return undefined

    let active = true
    let localPhotographUrl = ''
    Promise.allSettled([
      controlIngresosApi.consultarCredencialPublicaPersona(codigoQr),
      controlIngresosApi.obtenerFotografiaPublicaPersona(codigoQr),
      QRCode.toDataURL(window.location.href, {
        width: 260,
        margin: 2,
        errorCorrectionLevel: 'H',
        color: { dark: '#0a2035', light: '#ffffff' },
      }),
    ]).then(([personResult, photoResult, qrResult]) => {
      if (!active) return
      if (personResult.status === 'rejected') {
        setError(personResult.reason?.status === 404
          ? 'No se encontró una credencial vigente para este código.'
          : personResult.reason?.message || 'No fue posible consultar la credencial.')
        return
      }

      setPersona(personResult.value)
      if (photoResult.status === 'fulfilled' && photoResult.value) {
        localPhotographUrl = URL.createObjectURL(photoResult.value)
        setPhotographUrl(localPhotographUrl)
      }
      if (qrResult.status === 'fulfilled') setQrImage(qrResult.value)
    }).finally(() => active && setLoading(false))

    return () => {
      active = false
      if (localPhotographUrl) URL.revokeObjectURL(localPhotographUrl)
    }
  }, [codigoQr, codigoQrValido])

  const assignedAreas = persona?.areas?.filter((area) => area.numeroSolicitud) ?? []
  const authorizedCount = assignedAreas.filter(hasCurrentAccess).length

  const content = <div className="public-credential-content">
    <header className="public-credential-header">
      <img src={auraLogo} alt="Aura Minerals" />
      {!authenticated && <button type="button" className="primary-button" onClick={onLogin}><Icon name="user" />Iniciar sesión para ver más información</button>}
    </header>

    {loading && <section className="panel public-credential-message">Consultando información vigente de la persona…</section>}
    {!loading && error && <section className="panel public-credential-message public-credential-error"><Icon name="lock" /><strong>No fue posible mostrar la credencial</strong><span>{error}</span></section>}
    {!loading && persona && <section className="qr-result">
      <div className={`panel qr-access-identity ${authorizedCount > 0 ? 'has-access' : 'without-access'}`}>
        <div className="qr-access-person">
          <div className="person-avatar qr-person-photo"><span>{initials(persona.nombreCompleto)}</span>{photographUrl && <img src={photographUrl} alt="Fotografía de la persona" />}</div>
          <div className="qr-access-person-copy"><p className="eyebrow">Persona identificada</p><h2>{persona.nombreCompleto || 'Sin nombre'}</h2><p>{persona.numeroDocumento || 'Sin documento'} · {persona.empresa || 'Empresa no indicada'}</p></div>
        </div>
        <div className="qr-current-access"><Icon name={authorizedCount > 0 ? 'check' : 'lock'} /><span><strong>{authorizedCount > 0 ? 'Acceso vigente' : 'Sin acceso vigente'}</strong><small>{authorizedCount > 0 ? `${authorizedCount} ${authorizedCount === 1 ? 'área autorizada' : 'áreas autorizadas'} en este momento` : 'No tiene áreas autorizadas en este momento'}</small></span></div>
      </div>

      <section className="panel qr-assigned-areas">
        <div className="qr-assigned-heading"><div><p className="eyebrow">Permisos de ingreso</p><h2>Áreas asignadas</h2><p>La autorización se calcula con la aprobación y las fechas de vigencia actuales.</p></div><span>{assignedAreas.length}</span></div>
        {assignedAreas.length === 0
          ? <div className="qr-no-areas"><Icon name="lock" /><strong>No tiene áreas asignadas</strong><span>Esta persona no cuenta con permisos de ingreso registrados.</span></div>
          : <div className="qr-assigned-list">{assignedAreas.map((area) => <PublicArea key={`${area.idArea}-${area.numeroSolicitud}`} area={area} />)}</div>}
        {qrImage && <div className="public-credential-qr"><img src={qrImage} alt="Código validador de la credencial" /><span>Código validador</span></div>}
      </section>
    </section>}
  </div>

  return authenticated ? content : <main className="public-credential-shell">{content}</main>
}

function PublicArea({ area }) {
  const validity = getValidity(area)
  const allowed = area.tieneAcceso && validity.kind === 'active'

  return <article className={`qr-assigned-card ${allowed ? 'allowed' : 'denied'}`}>
    <div className="qr-area-symbol"><Icon name={allowed ? 'check' : 'lock'} /></div>
    <div className="qr-assigned-copy">
      <div className="qr-assigned-title"><div><h3>{area.area || 'Área sin nombre'}</h3><p>{area.actividad || 'Actividad no indicada'} · {area.numeroSolicitud}</p></div><span className={`qr-access-state ${allowed ? 'allowed' : 'denied'}`}>{allowed ? 'Acceso autorizado' : 'Sin acceso'}</span></div>
      <div className="qr-validity-row"><span><strong>Vigencia</strong>{area.fechaInicio && area.fechaFin ? `${formatDate(area.fechaInicio)} – ${formatDate(area.fechaFin)}` : 'Sin fechas definidas'}</span>{area.ubicacion && <span><strong>Ubicación</strong>{area.ubicacion}</span>}<span className={`qr-validity-message ${validity.kind}`}><strong>Estado actual</strong>{allowed ? validity.message : accessMessage(area, validity)}</span></div>
    </div>
  </article>
}

function hasCurrentAccess(area) {
  return area.tieneAcceso && getValidity(area).kind === 'active'
}

function getValidity(area) {
  if (!area.fechaInicio || !area.fechaFin) return { kind: 'unknown', message: 'Vigencia no definida' }
  const today = startOfDay(new Date())
  const start = parseDate(area.fechaInicio)
  const end = parseDate(area.fechaFin)
  if (today < start) return { kind: 'future', message: `Inicia en ${daysBetween(today, start)} día(s)` }
  if (today > end) return { kind: 'expired', message: `Venció hace ${daysBetween(end, today)} día(s)` }
  const remaining = daysBetween(today, end)
  return { kind: 'active', message: remaining === 0 ? 'Vence hoy' : `${remaining} día(s) restante(s)` }
}

function accessMessage(area, validity) {
  if (validity.kind === 'expired' || validity.kind === 'future') return validity.message
  if (area.codigoAcceso === 'RECHAZADA') return 'Acceso rechazado'
  if (area.codigoAcceso === 'PENDIENTE') return 'Pendiente de aprobación'
  return area.estadoAcceso || 'Acceso no autorizado'
}

function parseDate(value) {
  const [year, month, day] = String(value).slice(0, 10).split('-').map(Number)
  return new Date(year, month - 1, day)
}

function startOfDay(value) {
  return new Date(value.getFullYear(), value.getMonth(), value.getDate())
}

function daysBetween(start, end) {
  return Math.max(0, Math.round((startOfDay(end) - startOfDay(start)) / 86400000))
}
