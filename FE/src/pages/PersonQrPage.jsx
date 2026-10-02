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
  const [generatingPdf, setGeneratingPdf] = useState(false)

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

  async function downloadCredentialPdf() {
    setGeneratingPdf(true)
    try {
      const { jsPDF } = await import('jspdf')
      const pdf = new jsPDF({ orientation: 'landscape', unit: 'mm', format: [85.6, 54] })
    const pageWidth = pdf.internal.pageSize.getWidth()
    const pageHeight = pdf.internal.pageSize.getHeight()
    const name = persona.nombreCompleto || 'Persona sin nombre'
    const documentNumber = persona.numeroDocumento || 'Sin documento'
    const company = persona.empresa || 'Sin empresa'
    const personInitials = initials(name)
    const photograph = await loadPhotograph(persona.fotografiaUrl)

    pdf.setFillColor(255, 255, 255)
    pdf.roundedRect(0.6, 0.6, pageWidth - 1.2, pageHeight - 1.2, 3, 3, 'F')
    pdf.setFillColor(45, 61, 112)
    pdf.roundedRect(0.6, 0.6, pageWidth - 1.2, 11.5, 3, 3, 'F')
    pdf.rect(0.6, 8.5, pageWidth - 1.2, 4, 'F')
    pdf.setFillColor(244, 97, 77)
    pdf.rect(0.6, 11.4, pageWidth - 1.2, 1.2, 'F')

    pdf.setTextColor(255, 255, 255)
    pdf.setFont('helvetica', 'bold')
    pdf.setFontSize(8.5)
    pdf.text('CONTROL DE INGRESOS', 6, 7.2)
    pdf.setFont('helvetica', 'normal')
    pdf.setFontSize(5)
    pdf.text('IDENTIFICACIÓN DIGITAL', pageWidth - 6, 7.2, { align: 'right' })

    pdf.setFillColor(223, 247, 243)
    pdf.roundedRect(5.5, 17, 15.5, 15.5, 3, 3, 'F')
    if (photograph) {
      const properties = pdf.getImageProperties(photograph)
      const scale = Math.min(14.5 / properties.width, 14.5 / properties.height)
      const width = properties.width * scale
      const height = properties.height * scale
      pdf.addImage(photograph, properties.fileType, 6 + (14.5 - width) / 2, 17.5 + (14.5 - height) / 2, width, height)
    } else {
      pdf.setTextColor(8, 120, 107)
      pdf.setFont('helvetica', 'bold')
      pdf.setFontSize(11)
      pdf.text(personInitials, 13.25, 26.3, { align: 'center' })
    }

    pdf.setTextColor(23, 40, 58)
    pdf.setFontSize(8.2)
    pdf.text(fitText(pdf, name, 37), 24, 20.5)
    pdf.setFont('helvetica', 'normal')
    pdf.setTextColor(102, 121, 138)
    pdf.setFontSize(5.4)
    pdf.text('DOCUMENTO', 24, 25.2)
    pdf.setTextColor(23, 40, 58)
    pdf.setFont('helvetica', 'bold')
    pdf.setFontSize(6.3)
    pdf.text(fitText(pdf, documentNumber, 34), 24, 28.5)
    pdf.setFont('helvetica', 'normal')
    pdf.setTextColor(102, 121, 138)
    pdf.setFontSize(5.4)
    pdf.text('EMPRESA', 24, 33.3)
    pdf.setTextColor(23, 40, 58)
    pdf.setFont('helvetica', 'bold')
    pdf.setFontSize(6)
    pdf.text(fitText(pdf, company, 34), 24, 36.7)

    pdf.setFillColor(255, 255, 255)
    pdf.setDrawColor(220, 229, 236)
    pdf.roundedRect(pageWidth - 36, 14.5, 31, 31, 2, 2, 'FD')
    pdf.addImage(qrImage, 'PNG', pageWidth - 34.5, 16, 28, 28)

    pdf.setDrawColor(220, 229, 236)
    pdf.line(5.5, 41.5, pageWidth - 40, 41.5)
    pdf.setFont('helvetica', 'normal')
    pdf.setTextColor(102, 121, 138)
    pdf.setFontSize(4.6)
    pdf.text('Escanea el código para validar áreas y vigencia en tiempo real.', 5.5, 45.5)
    pdf.setFont('helvetica', 'bold')
    pdf.setTextColor(40, 103, 232)
    pdf.text('CREDENCIAL VERIFICABLE', 5.5, 49)

    const safeDocument = documentNumber.replace(/[^a-z0-9_-]+/gi, '-').replace(/^-|-$/g, '')
      pdf.save(`carnet-${safeDocument || persona.idPersona}.pdf`)
    } catch (error) {
      onError(error.message || 'No fue posible generar el carnet PDF.')
    } finally {
      setGeneratingPdf(false)
    }
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
          <button type="button" className="primary-button" onClick={downloadCredentialPdf} disabled={generatingPdf}><Icon name="download" />{generatingPdf ? 'Generando PDF…' : 'Descargar carnet PDF'}</button>
          <button type="button" className="secondary-button" onClick={copyLink}><Icon name="copy" />{copied ? 'Enlace copiado' : 'Copiar enlace'}</button>
        </div>
      </section>

      <aside className="panel qr-instructions">
        <Icon name="qr" />
        <h2>¿Cómo se usa?</h2>
        <ol><li>Descarga e imprime el carnet en formato horizontal.</li><li>El usuario de control abre <strong>Escanear QR</strong>.</li><li>El sistema muestra únicamente las áreas asignadas y su vigencia actual.</li></ol>
        <p>La información siempre se toma de SQL Server mediante procedimientos almacenados.</p>
      </aside>
    </div>
  </>
}

function fitText(pdf, value, maximumWidth) {
  const text = String(value)
  if (pdf.getTextWidth(text) <= maximumWidth) return text
  let shortened = text
  while (shortened.length > 3 && pdf.getTextWidth(`${shortened}…`) > maximumWidth) shortened = shortened.slice(0, -1)
  return `${shortened}…`
}

async function loadPhotograph(url) {
  if (!url) return null
  try {
    const response = await fetch(url, { credentials: 'include' })
    if (!response.ok) return null
    const blob = await response.blob()
    return await new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload = () => resolve(reader.result)
      reader.onerror = () => reject(reader.error)
      reader.readAsDataURL(blob)
    })
  } catch {
    return null
  }
}
