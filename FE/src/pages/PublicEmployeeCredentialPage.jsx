import { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { formatDateTime, initials } from '../utils/formatters'
import auraLogo from '../assets/aura-logo-default.png'

const qrPattern = /^[a-f0-9]{64}$/i

export function PublicEmployeeCredentialPage({ authenticated = false, onLogin }) {
  const codigoQr = new URLSearchParams(window.location.search).get('codigo')?.trim() ?? ''
  const codigoQrValido = qrPattern.test(codigoQr)
  const [employee, setEmployee] = useState(null)
  const [photographUrl, setPhotographUrl] = useState('')
  const [qrImage, setQrImage] = useState('')
  const [loading, setLoading] = useState(codigoQrValido)
  const [error, setError] = useState(codigoQrValido ? '' : 'El enlace de la credencial no es válido.')

  useEffect(() => {
    if (!codigoQrValido) return undefined

    let active = true
    let localPhotographUrl = ''
    Promise.allSettled([
      controlIngresosApi.consultarCredencialPublicaEmpleado(codigoQr),
      controlIngresosApi.obtenerFotografiaPublicaEmpleado(codigoQr),
      QRCode.toDataURL(window.location.href, {
        width: 260,
        margin: 2,
        errorCorrectionLevel: 'H',
        color: { dark: '#0a2035', light: '#ffffff' },
      }),
    ]).then(([employeeResult, photoResult, qrResult]) => {
      if (!active) return
      if (employeeResult.status === 'rejected') {
        setError(employeeResult.reason?.status === 404
          ? 'No se encontró una credencial vigente para este código.'
          : employeeResult.reason?.message || 'No fue posible consultar la credencial.')
        return
      }
      setEmployee(employeeResult.value)
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

  const content = <div className="public-credential-content">
    <header className="public-credential-header">
      <img src={auraLogo} alt="Aura Minerals" />
      {!authenticated && <button type="button" className="primary-button" onClick={onLogin}><Icon name="user" />Iniciar sesión para ver más información</button>}
    </header>

    {loading && <section className="panel public-credential-message">Consultando información vigente del empleado…</section>}
    {!loading && error && <section className="panel public-credential-message public-credential-error"><Icon name="lock" /><strong>No fue posible mostrar la credencial</strong><span>{error}</span></section>}
    {!loading && employee && <>
      <section className="panel public-employee-identity">
        <div className="public-employee-photo"><span>{initials(employee.nombre)}</span>{photographUrl && <img src={photographUrl} alt="Fotografía del empleado" />}</div>
        <div><p className="eyebrow">Empleado identificado</p><h1>{employee.nombre || 'Nombre no disponible'}</h1><p>{employee.cargo || 'Cargo no indicado'} · {employee.area || 'Área no indicada'}</p></div>
        <span className="status-badge">{employee.estado || 'Estado no indicado'}</span>
      </section>

      {employee.aviso && <div className="public-credential-warning"><Icon name="warning" /><span>{employee.aviso}</span></div>}

      <div className="public-credential-columns">
        <section className="panel public-credential-data">
          <div className="employee-section-heading"><Icon name="user" /><h2>Información del empleado</h2></div>
          <div className="employee-detail-grid">
            <CredentialValue label="Carnet" value={employee.codigoEmpleado} />
            <CredentialValue label="Empresa" value={employee.empresa} />
            <CredentialValue label="Área" value={employee.area} />
            <CredentialValue label="Cargo" value={employee.cargo} />
            <CredentialValue label="Tipo sanguíneo" value={employee.tipoSangre} />
            <CredentialValue label="CNH" value={employee.numeroLicencia} />
            <CredentialValue label="Categoría CNH" value={employee.categoriaLicencia} />
            <CredentialValue label="Validez de CNH" value={formatDate(employee.validezLicencia)} />
            <CredentialValue label="Validez de ASO" value={formatDate(employee.validezAso)} />
            <CredentialValue label="Autorizado para conducir vehículo" value={employee.autorizadoConducirVehiculo || 'No informado'} />
          </div>
        </section>

        <section className="panel public-training-panel">
          <div className="employee-section-heading"><Icon name="tasks" /><h2>Entrenamientos</h2><span>{employee.entrenamientos?.length ?? 0}</span></div>
          {employee.entrenamientos?.length
            ? <div className="public-training-list">{employee.entrenamientos.map((training, index) => <article key={`${training.entrenamiento}-${index}`}><strong>{training.entrenamiento || 'Entrenamiento sin nombre'}</strong><span>Validez: {training.validez || 'No indicada'}</span></article>)}</div>
            : <p className="public-training-empty">No hay entrenamientos disponibles para mostrar.</p>}
          <div className="public-credential-qr">
            {qrImage && <img src={qrImage} alt="Código validador de la credencial" />}
            <span>Código validador</span>
            <small>Emisión: {formatDateTime(new Date().toISOString())}</small>
          </div>
        </section>
      </div>
    </>}
  </div>

  return authenticated ? content : <main className="public-credential-shell">{content}</main>
}

function CredentialValue({ label, value }) {
  return <div className="info-value"><span>{label}</span><strong>{value || '—'}</strong></div>
}

function formatDate(value) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('es-HN', { day: '2-digit', month: '2-digit', year: 'numeric' }).format(new Date(value))
}
