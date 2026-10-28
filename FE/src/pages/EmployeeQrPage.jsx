import { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { initials } from '../utils/formatters'
import auraWordmarkUrl from '../assets/aura-logo-default.png'
import auraSymbolUrl from '../assets/aura-symbol-half.png'

const credentialHeightMm = 85.6
const credentialWidthMm = credentialHeightMm * (640 / 1006)

export function EmployeeQrPage({ codigoEmpleado, employee, photographUrl, loading, onBack, onError }) {
  const [qrImage, setQrImage] = useState('')
  const [scanUrl, setScanUrl] = useState('')
  const [qrLoading, setQrLoading] = useState(true)
  const [copied, setCopied] = useState(false)
  const [generatingPdf, setGeneratingPdf] = useState(false)

  useEffect(() => {
    let active = true
    const load = async () => {
      setQrLoading(true)
      try {
        const qr = await controlIngresosApi.obtenerQrEmpleado(codigoEmpleado)
        const url = `${window.location.origin}/credencial/empleado?codigo=${encodeURIComponent(qr.codigoQr)}`
        const image = await QRCode.toDataURL(url, {
          width: 420,
          margin: 2,
          errorCorrectionLevel: 'H',
          color: { dark: '#0a2035', light: '#ffffff' },
        })
        if (!active) return
        setScanUrl(url)
        setQrImage(image)
      } catch (error) {
        if (active) onError(error.status === 404 ? 'No se encontró el empleado solicitado.' : error.message)
      } finally {
        if (active) setQrLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [codigoEmpleado, onError])

  async function copyLink() {
    await navigator.clipboard.writeText(scanUrl)
    setCopied(true)
    window.setTimeout(() => setCopied(false), 1800)
  }

  async function downloadCredentialPdf() {
    setGeneratingPdf(true)
    try {
      const { jsPDF } = await import('jspdf')
      const pdf = new jsPDF({ orientation: 'portrait', unit: 'mm', format: [credentialWidthMm, credentialHeightMm] })
      const pageWidth = pdf.internal.pageSize.getWidth()
      const pageHeight = pdf.internal.pageSize.getHeight()
      const name = employee.nombreCompleto || 'Empleado sin nombre'
      const employeeCode = employee.codigoEmpleado || codigoEmpleado
      const department = employee.departamento || 'Departamento no indicado'
      const bloodType = employee.tipoSangre || 'No indicado'
      const employeeInitials = initials(name)
      const [photograph, auraSymbol, auraWordmark] = await Promise.all([
        loadImageDataUrl(photographUrl),
        loadImageDataUrl(auraSymbolUrl),
        loadImageDataUrl(auraWordmarkUrl),
      ])
      if (!auraSymbol || !auraWordmark) throw new Error('No fue posible cargar el logotipo de Aura.')
      const circularPhotograph = photograph ? await createCircularPhotograph(photograph) : null
      const frontWordmark = await createPdfAuraLogo(auraWordmark)

      pdf.setProperties({
        title: `Carnet de empleado - ${name}`,
        subject: 'Carnet de empleado',
        author: 'Control de Ingresos',
      })

      drawCardBase(pdf, pageWidth, pageHeight)

      pdf.setFillColor(46, 62, 113)
      pdf.roundedRect(0, 0, pageWidth, 27, 1.5, 1.5, 'F')
      pdf.rect(0, 0, pageWidth, 1.5, 'F')

      const photoCenterX = pageWidth / 2
      const photoCenterY = 26.2
      const photoRadius = 15

      drawAuraSymbolAroundPhotograph(pdf, auraSymbol, photoCenterX, photoCenterY, 42)

      pdf.setFillColor(255, 255, 255)
      pdf.circle(photoCenterX, photoCenterY, photoRadius + 0.45, 'F')

      if (circularPhotograph) {
        pdf.addImage(
          circularPhotograph,
          'PNG',
          photoCenterX - photoRadius,
          photoCenterY - photoRadius,
          photoRadius * 2,
          photoRadius * 2,
        )
      } else {
        pdf.setFillColor(238, 247, 247)
        pdf.circle(photoCenterX, photoCenterY, photoRadius, 'F')
        pdf.setTextColor(46, 62, 113)
        pdf.setFont('helvetica', 'bold')
        pdf.setFontSize(10)
        pdf.text(employeeInitials, photoCenterX, photoCenterY + 1.8, { align: 'center' })
      }

      drawCenteredText(pdf, name.toUpperCase(), 51.2, 43, 10.2, 6.2, 2, 'bold')
      drawCenteredText(pdf, department.toUpperCase(), 60.7, 39, 8.1, 5.7, 2, 'normal')
      drawAuraLogo(pdf, frontWordmark, pageWidth / 2, 70.2, 11.6)

      pdf.setTextColor(30, 52, 111)
      pdf.setFont('helvetica', 'bold')
      pdf.setFontSize(9.2)
      pdf.text('Minerales de Occidente', pageWidth / 2, 79.4, { align: 'center' })

      pdf.setLineWidth(0.8)
      pdf.setDrawColor(46, 62, 113)
      pdf.line(6.2, pageHeight - 3.5, pageWidth / 2, pageHeight - 3.5)
      pdf.setDrawColor(244, 91, 76)
      pdf.line(pageWidth / 2, pageHeight - 3.5, pageWidth - 6.2, pageHeight - 3.5)

      pdf.addPage([credentialWidthMm, credentialHeightMm], 'portrait')
      drawCardBase(pdf, pageWidth, pageHeight)

      drawLabeledValue(pdf, 'Registro:', employeeCode, pageWidth * 0.27, 5.8)
      drawLabeledValue(pdf, 'Tipo de Sangre:', bloodType, pageWidth * 0.73, 5.8)

      const qrShellSize = 30
      const qrShellX = (pageWidth - qrShellSize) / 2
      const qrShellY = 14
      pdf.setFillColor(255, 255, 255)
      pdf.setDrawColor(218, 226, 233)
      pdf.roundedRect(qrShellX, qrShellY, qrShellSize, qrShellSize, 1.8, 1.8, 'FD')
      pdf.addImage(qrImage, 'PNG', qrShellX + 1.2, qrShellY + 1.2, qrShellSize - 2.4, qrShellSize - 2.4)

      pdf.setTextColor(30, 52, 111)
      pdf.setFont('helvetica', 'normal')
      pdf.setFontSize(10.2)
      pdf.text('Contacto de Emergencia:', pageWidth / 2, 48.8, { align: 'center' })
      pdf.setFont('helvetica', 'bold')
      pdf.text('+504 96936663', pageWidth / 2, 53.2, { align: 'center' })
      pdf.setFontSize(8.2)
      pdf.text('Frecuencia Radio #1', pageWidth / 2, 56.8, { align: 'center' })

      drawWaveLayer(pdf, pageWidth, pageHeight, [244, 91, 76], (ratio) => 60 + (1.6 * Math.sin(ratio * Math.PI)) - (5.3 * ratio * ratio))
      drawWaveLayer(pdf, pageWidth, pageHeight, [0, 178, 173], (ratio) => 64.3 + (1.2 * Math.sin(ratio * Math.PI)) - (4.9 * ratio * ratio))
      drawWaveLayer(pdf, pageWidth, pageHeight, [46, 62, 113], (ratio) => 68.7 + (0.9 * Math.sin(ratio * Math.PI)) - (4.5 * ratio * ratio))

      drawAuraLogo(pdf, auraWordmark, pageWidth / 2, 70, 27)

      const safeCode = employeeCode.replace(/[^a-z0-9_-]+/gi, '-').replace(/^-|-$/g, '')
      pdf.save(`carnet-empleado-${safeCode || 'sin-codigo'}.pdf`)
    } catch (error) {
      onError(error.message || 'No fue posible generar el carnet PDF.')
    } finally {
      setGeneratingPdf(false)
    }
  }

  if (loading || qrLoading) return <div className="panel qr-placeholder">Generando código QR del empleado…</div>
  if (!employee || !qrImage) return null

  return <>
    <div className="page-heading qr-page-heading">
      <div><p className="eyebrow">Identificación digital</p><h1>QR del empleado</h1><p>Este código permite consultar la identidad y la información laboral vigente del empleado.</p></div>
      <button type="button" className="secondary-button" onClick={onBack}><Icon name="back" />Volver al empleado</button>
    </div>

    <div className="qr-detail-layout">
      <section className="panel qr-card">
        <div className="qr-person-summary">
          <div className="person-avatar large"><span>{initials(employee.nombreCompleto)}</span>{photographUrl && <img src={photographUrl} alt="Fotografía del empleado" />}</div>
          <div><h2>{employee.nombreCompleto || 'Empleado sin nombre'}</h2><p>{employee.codigoEmpleado || 'Sin código'} · {employee.departamento || 'Departamento no indicado'}</p></div>
        </div>
        <div className="qr-image-shell"><img src={qrImage} alt={`Código QR de ${employee.nombreCompleto || 'el empleado'}`} /></div>
        <p className="qr-security-note"><Icon name="shield" />El QR contiene un identificador seguro; los datos del empleado se consultan desde HTIS al escanearlo.</p>
        <div className="qr-actions">
          <button type="button" className="primary-button" onClick={downloadCredentialPdf} disabled={generatingPdf}><Icon name="download" />{generatingPdf ? 'Generando PDF…' : 'Descargar carnet PDF'}</button>
          <button type="button" className="secondary-button" onClick={copyLink}><Icon name="copy" />{copied ? 'Enlace copiado' : 'Copiar enlace'}</button>
        </div>
      </section>

      <aside className="panel qr-instructions">
        <Icon name="qr" />
        <h2>¿Cómo se usa?</h2>
        <ol><li>Descarga e imprime ambas caras del carnet en formato vertical.</li><li>El usuario de control abre <strong>Escanear QR</strong>.</li><li>El sistema consulta en HTIS la identidad, el cargo, el departamento y el estado laboral actual.</li></ol>
        <p>La base local conserva únicamente la relación entre el código del empleado y su identificador QR.</p>
      </aside>
    </div>
  </>
}

function drawCardBase(pdf, pageWidth, pageHeight) {
  pdf.setFillColor(255, 255, 255)
  pdf.roundedRect(0.6, 0.6, pageWidth - 1.2, pageHeight - 1.2, 2.4, 2.4, 'F')
}

function drawCenteredText(pdf, value, y, maximumWidth, preferredSize, minimumSize, maximumLines, fontStyle) {
  pdf.setTextColor(30, 52, 111)
  pdf.setFont('helvetica', fontStyle)

  let fontSize = preferredSize
  let lines = []
  do {
    pdf.setFontSize(fontSize)
    lines = pdf.splitTextToSize(String(value), maximumWidth)
    if (lines.length <= maximumLines) break
    fontSize -= 0.3
  } while (fontSize >= minimumSize)

  pdf.text(limitLines(lines, maximumLines), pdf.internal.pageSize.getWidth() / 2, y, {
    align: 'center',
    lineHeightFactor: 1.12,
  })
}

function drawAuraLogo(pdf, imageData, centerX, topY, width) {
  const properties = pdf.getImageProperties(imageData)
  const height = width * (properties.height / properties.width)
  pdf.addImage(imageData, 'PNG', centerX - (width / 2), topY, width, height)
}

function drawAuraSymbolAroundPhotograph(pdf, imageData, centerX, centerY, width) {
  const properties = pdf.getImageProperties(imageData)
  const height = width * (properties.height / properties.width)
  const ringCenterXRatio = 801 / 1331
  const ringCenterYRatio = 532 / 1064
  const left = centerX - (width * ringCenterXRatio)
  const top = centerY - (height * ringCenterYRatio)
  pdf.addImage(imageData, 'PNG', left, top, width, height)
}

function drawLabeledValue(pdf, label, value, centerX, labelY) {
  pdf.setTextColor(30, 52, 111)
  pdf.setFontSize(7.7)
  pdf.setFont('helvetica', 'bold')
  pdf.text(label, centerX, labelY, { align: 'center' })
  pdf.setFontSize(6.7)
  pdf.setFont('helvetica', 'bold')
  pdf.text(String(value), centerX, labelY + 3.7, { align: 'center' })
}

function drawWaveLayer(pdf, pageWidth, pageHeight, color, calculateY) {
  const steps = 27
  const points = Array.from({ length: steps + 1 }, (_, index) => {
    const x = (pageWidth * index) / steps
    return [x, calculateY(x / pageWidth)]
  })
  const segments = []
  for (let index = 1; index < points.length; index += 1) {
    segments.push([points[index][0] - points[index - 1][0], points[index][1] - points[index - 1][1]])
  }
  const lastPoint = points[points.length - 1]
  segments.push([0, pageHeight - lastPoint[1]])
  segments.push([-pageWidth, 0])
  segments.push([0, points[0][1] - pageHeight])

  pdf.setFillColor(...color)
  pdf.lines(segments, points[0][0], points[0][1], [1, 1], 'F', true)
}

function limitLines(lines, maximumLines) {
  const normalized = Array.isArray(lines) ? lines.slice(0, maximumLines) : [String(lines)]
  if (Array.isArray(lines) && lines.length > maximumLines) {
    normalized[maximumLines - 1] = `${normalized[maximumLines - 1].replace(/…?$/, '')}…`
  }
  return normalized
}

async function loadImageDataUrl(url) {
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

async function createCircularPhotograph(dataUrl) {
  const image = await loadHtmlImage(dataUrl, 'No fue posible preparar la fotografía del empleado.')
  const size = 600
  const canvas = document.createElement('canvas')
  canvas.width = size
  canvas.height = size
  const context = canvas.getContext('2d')
  const scale = Math.max(size / image.naturalWidth, size / image.naturalHeight)
  const width = image.naturalWidth * scale
  const height = image.naturalHeight * scale

  context.save()
  context.beginPath()
  context.arc(size / 2, size / 2, size / 2, 0, Math.PI * 2)
  context.clip()
  context.drawImage(image, (size - width) / 2, (size - height) / 2, width, height)
  context.restore()

  return canvas.toDataURL('image/png')
}

async function createPdfAuraLogo(dataUrl) {
  const image = await loadHtmlImage(dataUrl, 'No fue posible preparar el logotipo de Aura.')
  const canvas = document.createElement('canvas')
  canvas.width = image.naturalWidth
  canvas.height = image.naturalHeight
  const context = canvas.getContext('2d')
  context.drawImage(image, 0, 0)

  const pixels = context.getImageData(0, 0, canvas.width, canvas.height)
  for (let index = 0; index < pixels.data.length; index += 4) {
    if (pixels.data[index + 3] === 0) continue
    const red = pixels.data[index]
    const green = pixels.data[index + 1]
    const blue = pixels.data[index + 2]
    const isCoral = red > 140 && red > green * 1.35 && red > blue * 1.15
    if (isCoral) continue
    pixels.data[index] = 30
    pixels.data[index + 1] = 52
    pixels.data[index + 2] = 111
  }
  context.putImageData(pixels, 0, 0)
  return canvas.toDataURL('image/png')
}

function loadHtmlImage(dataUrl, errorMessage) {
  return new Promise((resolve, reject) => {
    const element = new Image()
    element.onload = () => resolve(element)
    element.onerror = () => reject(new Error(errorMessage))
    element.src = dataUrl
  })
}
