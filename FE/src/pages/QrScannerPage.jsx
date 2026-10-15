import { useEffect, useRef, useState } from 'react'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { formatDate, formatDateTime, initials } from '../utils/formatters'

const qrPattern = /[a-f0-9]{64}/i

export function QrScannerPage({ onError }) {
  const [value, setValue] = useState('')
  const [persona, setPersona] = useState(null)
  const [empleado, setEmpleado] = useState(null)
  const [personPhotoUrl, setPersonPhotoUrl] = useState('')
  const [employeePhotoUrl, setEmployeePhotoUrl] = useState('')
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

  async function consult(rawValue, explicitType = null) {
    const match = String(rawValue ?? '').match(qrPattern)
    if (!match) {
      processingRef.current = false
      onError('El código leído no corresponde a una identificación registrada en el sistema.')
      return
    }

    setLoading(true)
    setPersona(null)
    setEmpleado(null)
    setPersonPhotoUrl('')
    setEmployeePhotoUrl('')
    try {
      const code = match[0].toLowerCase()
      const result = await resolveQr(code, explicitType ?? qrTypeFromValue(rawValue))
      setValue(code)
      if (result.type === 'empleado') {
        setEmpleado(result.data)
        try {
          const photograph = await controlIngresosApi.obtenerFotografiaEmpleado(result.data.codigoEmpleado)
          setEmployeePhotoUrl(URL.createObjectURL(photograph))
        } catch {
          // La fotografía es opcional y no impide validar al empleado.
        }
      } else {
        setPersona(result.data)
        try {
          const photograph = await controlIngresosApi.obtenerFotografiaPersona(result.data.idPersona)
          setPersonPhotoUrl(photograph?.dataUrl ?? '')
        } catch {
          // La fotografía es opcional y no impide validar a la persona.
        }
      }
    } catch (error) {
      onError(error.status === 404 ? 'El código QR no existe o ya no es válido.' : error.message)
    } finally {
      setLoading(false)
      processingRef.current = false
    }
  }

  useEffect(() => {
    const parameters = new URLSearchParams(window.location.search)
    const initialCode = parameters.get('codigo')
    if (initialCode) consult(initialCode, parameters.get('tipo'))
    return stopCamera
    // La consulta inicial solo corresponde al código presente al abrir la ruta.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => () => {
    if (employeePhotoUrl) URL.revokeObjectURL(employeePhotoUrl)
  }, [employeePhotoUrl])

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
      <div><p className="eyebrow">Control de ingreso</p><h1>Escanear QR</h1><p>Identifica personas o empleados y consulta su información vigente en tiempo real.</p></div>
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

    {loading && <div className="panel qr-placeholder">Consultando información de la identificación…</div>}
    {persona && <section className="qr-result">
      <div className={`panel qr-access-identity ${authorizedCount > 0 ? 'has-access' : 'without-access'}`}>
        <div className="qr-access-person">
          <div className="person-avatar qr-person-photo"><span>{initials(persona.nombreCompleto)}</span>{personPhotoUrl && <img src={personPhotoUrl} alt="Fotografía de la persona" />}</div>
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
    {empleado && <EmployeeQrResult employee={empleado} photographUrl={employeePhotoUrl} />}
  </>
}

function EmployeeQrResult({ employee, photographUrl }) {
  return <section className="qr-result">
    <div className="panel qr-access-identity employee-qr-identity">
      <div className="qr-access-person">
        <div className="person-avatar qr-person-photo"><span>{initials(employee.nombreCompleto)}</span>{photographUrl && <img src={photographUrl} alt="Fotografía del empleado" />}</div>
        <div className="qr-access-person-copy"><p className="eyebrow">Empleado identificado</p><h2>{employee.nombreCompleto || 'Sin nombre'}</h2><p>{employee.codigoEmpleado || 'Sin código'} · {employee.departamento || 'Departamento no indicado'}</p></div>
      </div>
      <div className="employee-qr-status"><Icon name="user" /><span><strong>{employee.descripcionStatus || employee.codigoStatus || 'Estado no indicado'}</strong><small>Estado laboral consultado en HTIS</small></span></div>
    </div>

    <section className="panel employee-qr-information">
      <div className="qr-assigned-heading"><div><p className="eyebrow">Información laboral</p><h2>Datos actuales del empleado</h2><p>Estos datos no se almacenan con el QR; se consultan en el servidor de empleados.</p></div></div>
      <div className="employee-detail-grid employee-qr-grid">
        <EmployeeValue label="Código de empleado" value={employee.codigoEmpleado} />
        <EmployeeValue label="Estado" value={employee.descripcionStatus || employee.codigoStatus} />
        <EmployeeValue label="Departamento" value={employee.departamento} />
        <EmployeeValue label="Cargo / nivel" value={employee.cargoNivel} />
        <EmployeeValue label="Fecha de ingreso" value={employee.fechaIngreso ? formatDateTime(employee.fechaIngreso) : null} />
        <EmployeeValue label="Fecha de egreso" value={employee.fechaEgreso ? formatDateTime(employee.fechaEgreso) : null} />
        <EmployeeValue label="Correo" value={employee.correo} />
        <EmployeeValue label="Tipo de licencia" value={employee.tipoLicencia} />
      </div>
    </section>
  </section>
}

function EmployeeValue({ label, value }) {
  return <div className="info-value"><span>{label}</span><strong>{value || '—'}</strong></div>
}

async function resolveQr(code, typeHint) {
  if (typeHint === 'empleado') {
    return { type: 'empleado', data: await controlIngresosApi.consultarQrEmpleado(code) }
  }
  if (typeHint === 'persona') {
    return { type: 'persona', data: await controlIngresosApi.consultarQrPersona(code) }
  }

  try {
    return { type: 'persona', data: await controlIngresosApi.consultarQrPersona(code) }
  } catch (error) {
    if (error.status !== 404) throw error
    return { type: 'empleado', data: await controlIngresosApi.consultarQrEmpleado(code) }
  }
}

function qrTypeFromValue(value) {
  try {
    const url = new URL(String(value ?? ''), window.location.origin)
    const type = url.searchParams.get('tipo')?.toLocaleLowerCase('es')
    return type === 'empleado' || type === 'persona' ? type : null
  } catch {
    return null
  }
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
