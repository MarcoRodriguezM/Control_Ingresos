import { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { initials } from '../utils/formatters'

export function PersonQrPage({ idPersona, onBack, onError }) {
  const [persona, setPersona] = useState(null)
  const [qrImage, setQrImage] = useState('')
  const [scanUrl, setScanUrl] = useState('')
  const [photograph, setPhotograph] = useState(null)
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
        const photographDataUrl = await resolvePhotograph(detail)
        if (!active) return
        setPersona(detail)
        setScanUrl(url)
        setQrImage(image)
        setPhotograph(photographDataUrl)
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
    try {
      await navigator.clipboard.writeText(scanUrl)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 1800)
    } catch {
      onError('No fue posible copiar el enlace del código QR.')
    }
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

      const photoX = 5.5
      const photoY = 16.5
      const photoWidth = 17.5
      const photoHeight = 22
      pdf.setFillColor(223, 247, 243)
      pdf.roundedRect(photoX, photoY, photoWidth, photoHeight, 2.5, 2.5, 'F')
      if (photograph) {
        const croppedPhotograph = await cropPhotograph(photograph, photoWidth / photoHeight)
        pdf.addImage(croppedPhotograph, 'JPEG', photoX, photoY, photoWidth, photoHeight)
        pdf.setDrawColor(220, 229, 236)
        pdf.roundedRect(photoX, photoY, photoWidth, photoHeight, 2.5, 2.5, 'S')
      } else {
        pdf.setTextColor(8, 120, 107)
        pdf.setFont('helvetica', 'bold')
        pdf.setFontSize(10)
        pdf.text(personInitials, photoX + photoWidth / 2, photoY + photoHeight / 2 + 2, { align: 'center' })
      }

      const detailX = 27
      const detailWidth = 29
      pdf.setTextColor(23, 40, 58)
      pdf.setFontSize(7.2)
      const nameLines = limitLines(pdf.splitTextToSize(name, detailWidth), 2)
      pdf.text(nameLines, detailX, 19)
      pdf.setFont('helvetica', 'normal')
      pdf.setTextColor(102, 121, 138)
      pdf.setFontSize(4.8)
      pdf.text('DOCUMENTO', detailX, 27)
      pdf.setTextColor(23, 40, 58)
      pdf.setFont('helvetica', 'bold')
      pdf.setFontSize(5.8)
      pdf.text(fitText(pdf, documentNumber, detailWidth), detailX, 30.2)
      pdf.setFont('helvetica', 'normal')
      pdf.setTextColor(102, 121, 138)
      pdf.setFontSize(4.8)
      pdf.text('EMPRESA', detailX, 35)
      pdf.setTextColor(23, 40, 58)
      pdf.setFont('helvetica', 'bold')
      pdf.setFontSize(5.2)
      pdf.text(limitLines(pdf.splitTextToSize(company, detailWidth), 2), detailX, 38.1)

      pdf.setFillColor(255, 255, 255)
      pdf.setDrawColor(220, 229, 236)
      const qrShellSize = 22
      const qrShellX = pageWidth - qrShellSize - 4.5
      const qrShellY = 16
      pdf.roundedRect(qrShellX, qrShellY, qrShellSize, qrShellSize, 2, 2, 'FD')
      pdf.addImage(qrImage, 'PNG', qrShellX + 1.3, qrShellY + 1.3, qrShellSize - 2.6, qrShellSize - 2.6)

      pdf.setDrawColor(220, 229, 236)
      pdf.line(5.5, 42, 56.5, 42)
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
          <div className="person-avatar large"><span>{initials(persona.nombreCompleto)}</span>{photograph && <img src={photograph} alt="Fotografía de la persona" />}</div>
          <div><h2>{persona.nombreCompleto || 'Persona sin nombre'}</h2><p>{persona.numeroDocumento || 'Sin documento'} · {persona.empresa || 'Sin empresa'}</p></div>
        </div>
        <div className="qr-image-shell"><img src={qrImage} alt={`Código QR de ${persona.nombreCompleto || 'la persona'}`} /></div>
        <p className="qr-security-note"><Icon name="shield" />El QR contiene un identificador seguro; los datos personales se consultan desde el sistema al escanearlo.</p>
        <div className="qr-actions">
          <button type="button" className="primary-button" onClick={downloadCredentialPdf} disabled={generatingPdf}><Icon name="download" />{generatingPdf ? 'Generando PDF…' : 'Descargar carnet PDF'}</button>
          <button type="button" className="secondary-button" onClick={copyLink}><Icon name="copy" />{copied ? 'Enlace copiado' : 'Copiar enlace'}</button>
        </div>
      </section>
    </div>
  </>
}

async function resolvePhotograph(persona) {
  if (!persona?.fotografiaUrl) return null

  try {
    const result = await controlIngresosApi.obtenerFotografiaPersona(persona.idPersona)
    if (result?.dataUrl) return result.dataUrl
  } catch {
    // Permite fotografías externas o instalaciones antiguas que todavía sirven la URL directamente.
  }

  try {
    const photographUrl = new URL(persona.fotografiaUrl, window.location.origin)
    if (photographUrl.pathname.startsWith('/uploads/personas/')) return null
  } catch {
    return null
  }

  return loadPhotograph(persona.fotografiaUrl)
}

function fitText(pdf, value, maximumWidth) {
  const text = String(value)
  if (pdf.getTextWidth(text) <= maximumWidth) return text
  let shortened = text
  while (shortened.length > 3 && pdf.getTextWidth(`${shortened}…`) > maximumWidth) shortened = shortened.slice(0, -1)
  return `${shortened}…`
}

function limitLines(lines, maximumLines) {
  const normalized = Array.isArray(lines) ? lines.slice(0, maximumLines) : [String(lines)]
  if (Array.isArray(lines) && lines.length > maximumLines) {
    normalized[maximumLines - 1] = `${normalized[maximumLines - 1].replace(/…?$/, '')}…`
  }
  return normalized
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

async function cropPhotograph(dataUrl, targetAspectRatio) {
  const image = await new Promise((resolve, reject) => {
    const element = new Image()
    element.onload = () => resolve(element)
    element.onerror = () => reject(new Error('No fue posible preparar la fotografía para el carnet.'))
    element.src = dataUrl
  })

  const zoom = 1.35
  let sourceWidth = image.naturalWidth
  let sourceHeight = sourceWidth / targetAspectRatio
  if (sourceHeight > image.naturalHeight) {
    sourceHeight = image.naturalHeight
    sourceWidth = sourceHeight * targetAspectRatio
  }

  sourceWidth /= zoom
  sourceHeight /= zoom
  const sourceX = (image.naturalWidth - sourceWidth) / 2
  const sourceY = Math.max(0, (image.naturalHeight - sourceHeight) * 0.32)
  const canvas = document.createElement('canvas')
  canvas.width = 700
  canvas.height = Math.round(canvas.width / targetAspectRatio)
  const context = canvas.getContext('2d', { alpha: false })
  if (!context) throw new Error('El navegador no pudo procesar la fotografía.')

  context.fillStyle = '#ffffff'
  context.fillRect(0, 0, canvas.width, canvas.height)
  context.drawImage(
    image,
    sourceX,
    sourceY,
    sourceWidth,
    sourceHeight,
    0,
    0,
    canvas.width,
    canvas.height,
  )
  return canvas.toDataURL('image/jpeg', 0.92)
}
