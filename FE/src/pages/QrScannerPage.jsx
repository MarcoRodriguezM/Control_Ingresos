import { useEffect, useRef, useState } from 'react'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { formatDate, initials } from '../utils/formatters'

const qrPattern = /[a-f0-9]{64}/i

export function QrScannerPage({ onError }) {
  const [value, setValue] = useState('')
  const [persona, setPersona] = useState(null)
  const [loading, setLoading] = useState(false)
  const [cameraActive, setCameraActive] = useState(false)
  const videoRef = useRef(null)
  const streamRef = useRef(null)
  const frameRef = useRef(null)
  const processingRef = useRef(false)

  function stopCamera() {
    if (frameRef.current) cancelAnimationFrame(frameRef.current)
    frameRef.current = null
    streamRef.current?.getTracks().forEach((track) => track.stop())
    streamRef.current = null
    if (videoRef.current) videoRef.current.srcObject = null
    setCameraActive(false)
  }

  async function consult(rawValue) {
    const match = String(rawValue ?? '').match(qrPattern)
    if (!match) {
      onError('El código leído no corresponde a una persona registrada en el sistema.')
      return
    }

    setLoading(true)
    setPersona(null)
    try {
      const result = await controlIngresosApi.consultarQrPersona(match[0].toLowerCase())
      setValue(match[0].toLowerCase())
      setPersona(result)
    } catch (error) {
      onError(error.status === 404 ? 'El código QR no existe o ya no es válido.' : error.message)
    } finally {
      setLoading(false)
      processingRef.current = false
    }
  }

  useEffect(() => {
    const initialCode = new URLSearchParams(window.location.search).get('codigo')
    if (initialCode) consult(initialCode)
    return stopCamera
    // La consulta inicial solo corresponde al código presente al abrir la ruta.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  async function startCamera() {
    if (!('BarcodeDetector' in window) || !navigator.mediaDevices?.getUserMedia) {
      onError('Este navegador no permite leer QR directamente. Puedes pegar el código o abrir el enlace del QR.')
      return
    }

    try {
      const detector = new window.BarcodeDetector({ formats: ['qr_code'] })
      const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' } }, audio: false })
      streamRef.current = stream
      videoRef.current.srcObject = stream
      await videoRef.current.play()
      setCameraActive(true)

      const scan = async () => {
        if (!videoRef.current || !streamRef.current) return
        try {
          const codes = await detector.detect(videoRef.current)
          if (codes.length && !processingRef.current) {
            processingRef.current = true
            const rawValue = codes[0].rawValue
            stopCamera()
            await consult(rawValue)
            return
          }
        } catch {
          // Un fotograma todavía no disponible se intenta nuevamente.
        }
        frameRef.current = requestAnimationFrame(scan)
      }
      frameRef.current = requestAnimationFrame(scan)
    } catch (error) {
      stopCamera()
      onError(error.name === 'NotAllowedError' ? 'Debes permitir el acceso a la cámara para escanear el QR.' : 'No fue posible iniciar la cámara del dispositivo.')
    }
  }

  async function submit(event) {
    event.preventDefault()
    stopCamera()
    await consult(value)
  }

  const assignedAreas = persona?.areas?.filter((area) => area.numeroSolicitud) ?? []
  const authorizedCount = assignedAreas.filter((area) => area.tieneAcceso).length

  return <>
    <div className="page-heading qr-page-heading">
      <div><p className="eyebrow">Control de ingreso</p><h1>Escanear QR</h1><p>Identifica a la persona y verifica en tiempo real a qué áreas puede ingresar.</p></div>
    </div>

    <section className="panel scanner-panel">
      <div className={`camera-shell ${cameraActive ? 'active' : ''}`}>
        <video ref={videoRef} playsInline muted />
        {!cameraActive && <div className="camera-placeholder"><Icon name="qr" /><strong>Cámara detenida</strong><span>Presiona el botón para comenzar a escanear.</span></div>}
        {cameraActive && <div className="scanner-frame" aria-hidden="true" />}
      </div>
      <div className="scanner-controls">
        <button type="button" className={cameraActive ? 'danger-button primary-button' : 'primary-button'} onClick={cameraActive ? stopCamera : startCamera}><Icon name={cameraActive ? 'close' : 'camera'} />{cameraActive ? 'Detener cámara' : 'Abrir cámara'}</button>
        <span>o ingresa el código/enlace manualmente</span>
        <form onSubmit={submit} className="qr-manual-form"><input value={value} onChange={(event) => setValue(event.target.value)} placeholder="Pega aquí el código o enlace del QR" aria-label="Código QR" /><button type="submit" className="secondary-button" disabled={loading}>{loading ? 'Consultando…' : 'Consultar'}</button></form>
      </div>
    </section>

    {loading && <div className="panel qr-placeholder">Consultando información de la persona…</div>}
    {persona && <section className="qr-result">
      <div className={`panel qr-access-identity ${authorizedCount > 0 ? 'has-access' : 'without-access'}`}>
        <div className="qr-access-person">
          <div className="person-avatar qr-person-photo"><span>{initials(persona.nombreCompleto)}</span>{persona.fotografiaUrl && <img src={persona.fotografiaUrl} alt="Fotografía de la persona" />}</div>
          <div className="qr-access-person-copy"><p className="eyebrow">Persona identificada</p><h2>{persona.nombreCompleto || 'Sin nombre'}</h2><p>{persona.numeroDocumento || 'Sin documento'} · {persona.empresa || 'Empresa no indicada'}</p></div>
        </div>
        <div className="qr-current-access"><Icon name={authorizedCount > 0 ? 'check' : 'lock'} /><span><strong>{authorizedCount > 0 ? 'Acceso vigente' : 'Sin acceso vigente'}</strong><small>{authorizedCount > 0 ? `${authorizedCount} ${authorizedCount === 1 ? 'área autorizada' : 'áreas autorizadas'} en este momento` : 'No tiene áreas autorizadas en este momento'}</small></span></div>
      </div>

      <section className="panel qr-assigned-areas">
        <div className="qr-assigned-heading"><div><p className="eyebrow">Permisos de ingreso</p><h2>Áreas asignadas</h2><p>La autorización se calcula con el estado de aprobación y las fechas de vigencia.</p></div><span>{assignedAreas.length}</span></div>
        {assignedAreas.length === 0
          ? <div className="qr-no-areas"><Icon name="lock" /><strong>No tiene áreas asignadas</strong><span>Esta persona no cuenta con permisos de ingreso registrados.</span></div>
          : <div className="qr-assigned-list">{assignedAreas.map((area) => <AssignedArea key={`${area.idArea}-${area.numeroSolicitud}`} area={area} />)}</div>}
      </section>
    </section>}
  </>
}

function AssignedArea({ area }) {
  const validity = getValidity(area)
  const allowed = area.tieneAcceso && validity.kind === 'active'

  return <article className={`qr-assigned-card ${allowed ? 'allowed' : 'denied'}`}>
    <div className="qr-area-symbol"><Icon name={allowed ? 'check' : 'lock'} /></div>
    <div className="qr-assigned-copy">
      <div className="qr-assigned-title"><div><h3>{area.area || 'Área sin nombre'}</h3><p>{area.actividad || 'Actividad no indicada'} · {area.numeroSolicitud}</p></div><span className={`qr-access-state ${allowed ? 'allowed' : 'denied'}`}>{allowed ? 'Acceso autorizado' : 'Sin acceso'}</span></div>
      <div className="qr-validity-row"><span><strong>Vigencia</strong>{area.fechaInicio && area.fechaFin ? `${formatDate(area.fechaInicio)} – ${formatDate(area.fechaFin)}` : 'Sin fechas definidas'}</span>{area.ubicacion && <span><strong>Ubicación</strong>{area.ubicacion}</span>}<span className={`qr-validity-message ${validity.kind}`}><strong>Estado actual</strong>{allowed ? validity.message : accessMessage(area, validity)}</span></div>
      {area.comentarioDecision && !allowed && <p className="qr-access-reason">{area.comentarioDecision}</p>}
    </div>
  </article>
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
  if (area.codigoAcceso === 'SOLICITUD_NO_HABILITADA') return 'Solicitud aún no habilitada'
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
  return Math.max(0, Math.ceil((end - start) / 86400000))
}
