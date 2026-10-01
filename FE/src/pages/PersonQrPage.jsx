import { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { initials } from '../utils/formatters'

export function PersonQrPage({ idPersona, onBack, onError }) {
  const [persona, setPersona] = useState(null)
  const [qrImage, setQrImage] = useState('')
  const [scanUrl, setScanUrl] = useState('')
  const [loading, setLoading] = useState(true)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    let active = true
    const load = async () => {
      setLoading(true)
      try {
        const [detail, qr] = await Promise.all([
          controlIngresosApi.obtenerPersonaAccesos(idPersona),
          controlIngresosApi.obtenerQrPersona(idPersona),
        ])
        const url = `${window.location.origin}/escanear-qr?codigo=${encodeURIComponent(qr.codigoQr)}`
        const image = await QRCode.toDataURL(url, {
          width: 420,
          margin: 2,
          errorCorrectionLevel: 'H',
          color: { dark: '#0a2035', light: '#ffffff' },
        })
        if (!active) return
        setPersona(detail)
        setScanUrl(url)
        setQrImage(image)
      } catch (error) {
        if (active) onError(error.message)
      } finally {
        if (active) setLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [idPersona, onError])

  async function copyLink() {
    await navigator.clipboard.writeText(scanUrl)
    setCopied(true)
    window.setTimeout(() => setCopied(false), 1800)
  }

  if (loading) return <div className="panel qr-placeholder">Generando código QR…</div>
  if (!persona || !qrImage) return null

  return <>
    <div className="page-heading qr-page-heading">
      <div><p className="eyebrow">Identificación digital</p><h1>QR de la persona</h1><p>Este código permite consultar sus datos y el estado de acceso de cada área.</p></div>
      <button type="button" className="secondary-button" onClick={onBack}><Icon name="back" />Volver a la persona</button>
    </div>

    <div className="qr-detail-layout">
      <section className="panel qr-card">
        <div className="qr-person-summary">
          <div className="person-avatar large"><span>{initials(persona.nombreCompleto)}</span>{persona.fotografiaUrl && <img src={persona.fotografiaUrl} alt="Fotografía de la persona" />}</div>
          <div><h2>{persona.nombreCompleto || 'Persona sin nombre'}</h2><p>{persona.numeroDocumento || 'Sin documento'} · {persona.empresa || 'Sin empresa'}</p></div>
        </div>
        <div className="qr-image-shell"><img src={qrImage} alt={`Código QR de ${persona.nombreCompleto || 'la persona'}`} /></div>
        <p className="qr-security-note"><Icon name="shield" />El QR contiene un identificador seguro; los datos personales se consultan desde el sistema al escanearlo.</p>
        <div className="qr-actions">
          <a className="primary-button" href={qrImage} download={`qr-${persona.numeroDocumento || persona.idPersona}.png`}><Icon name="download" />Descargar QR</a>
          <button type="button" className="secondary-button" onClick={copyLink}><Icon name="copy" />{copied ? 'Enlace copiado' : 'Copiar enlace'}</button>
        </div>
      </section>

      <aside className="panel qr-instructions">
        <Icon name="qr" />
        <h2>¿Cómo se usa?</h2>
        <ol><li>El usuario de control abre <strong>Escanear QR</strong>.</li><li>Apunta la cámara al código de la persona.</li><li>El sistema muestra identidad, vigencia y todas las áreas autorizadas o denegadas.</li></ol>
        <p>La información siempre se toma de SQL Server mediante procedimientos almacenados.</p>
      </aside>
    </div>
  </>
}
