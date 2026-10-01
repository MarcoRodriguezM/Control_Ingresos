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

  const authorized = persona?.areas?.filter((area) => area.tieneAcceso) ?? []
  const denied = persona?.areas?.filter((area) => !area.tieneAcceso) ?? []

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
      <div className="panel qr-identity-card">
        <div className="qr-person-summary">
          <div className="person-avatar large"><span>{initials(persona.nombreCompleto)}</span>{persona.fotografiaUrl && <img src={persona.fotografiaUrl} alt="Fotografía de la persona" />}</div>
          <div><p className="eyebrow">Persona identificada</p><h2>{persona.nombreCompleto || 'Sin nombre'}</h2><p>{persona.cargoFuncion || 'Cargo no indicado'} · {persona.empresa || 'Empresa no indicada'}</p></div>
        </div>
        <div className="person-data-grid"><Info label="Documento" value={persona.numeroDocumento} /><Info label="Teléfono" value={persona.telefono} /><Info label="Correo" value={persona.correo} /><Info label="Estado" value={persona.estado} /></div>
        <div className="qr-access-summary"><span className="qr-access-allowed"><strong>{authorized.length}</strong> áreas con acceso</span><span className="qr-access-denied"><strong>{denied.length}</strong> áreas sin acceso</span></div>
      </div>

      <div className="qr-area-columns">
        <AreaGroup title="Áreas autorizadas" items={authorized} allowed />
        <AreaGroup title="Áreas sin acceso" items={denied} />
      </div>
    </section>}
  </>
}

function AreaGroup({ title, items, allowed = false }) {
  return <section className="panel qr-area-group"><div className="qr-area-group-title"><Icon name={allowed ? 'check' : 'lock'} /><h2>{title}</h2><span>{items.length}</span></div>{items.length === 0 && <p className="qr-area-empty">No hay áreas en esta categoría.</p>}<div className="qr-area-list">{items.map((area) => <article className={`qr-area-card ${allowed ? 'allowed' : 'denied'}`} key={area.idArea}><div><strong>{area.area || 'Área sin nombre'}</strong><span className={`access-status ${allowed ? 'aprobada' : area.codigoAcceso === 'RECHAZADA' ? 'rechazada' : 'pendiente'}`}>{area.estadoAcceso}</span></div>{area.numeroSolicitud && <p>{area.numeroSolicitud} · {area.actividad || 'Actividad no indicada'}</p>}{area.fechaInicio && <small>Vigencia: {formatDate(area.fechaInicio)} – {formatDate(area.fechaFin)}</small>}{area.comentarioDecision && <blockquote>{area.comentarioDecision}</blockquote>}</article>)}</div></section>
}

function Info({ label, value }) {
  return <div className="info-value"><span>{label}</span><strong>{value || '—'}</strong></div>
}
