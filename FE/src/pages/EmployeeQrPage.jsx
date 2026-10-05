import { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { initials } from '../utils/formatters'

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
        const url = `${window.location.origin}/escanear-qr?tipo=empleado&codigo=${encodeURIComponent(qr.codigoQr)}`
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
      const pdf = new jsPDF({ orientation: 'landscape', unit: 'mm', format: [85.6, 54] })
      const pageWidth = pdf.internal.pageSize.getWidth()
      const pageHeight = pdf.internal.pageSize.getHeight()
      const name = employee.nombreCompleto || 'Empleado sin nombre'
      const employeeCode = employee.codigoEmpleado || codigoEmpleado
      const department = employee.departamento || 'Departamento no indicado'
      const position = employee.cargoNivel || 'Cargo no indicado'
      const employeeInitials = initials(name)
      const photograph = await loadPhotograph(photographUrl)

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
      pdf.text('CARNET DE EMPLEADO', pageWidth - 6, 7.2, { align: 'right' })

      const photoX = 5.5
      const photoY = 16.5
      const photoWidth = 17.5
      const photoHeight = 22
      pdf.setFillColor(223, 247, 243)
      pdf.roundedRect(photoX, photoY, photoWidth, photoHeight, 2.5, 2.5, 'F')
      if (photograph) {
        const properties = pdf.getImageProperties(photograph)
        const scale = Math.min((photoWidth - 1) / properties.width, (photoHeight - 1) / properties.height)
        const width = properties.width * scale
        const height = properties.height * scale
        pdf.addImage(
          photograph,
          properties.fileType,
          photoX + (photoWidth - width) / 2,
          photoY + (photoHeight - height) / 2,
          width,
          height,
        )
      } else {
        pdf.setTextColor(8, 120, 107)
        pdf.setFont('helvetica', 'bold')
        pdf.setFontSize(10)
        pdf.text(employeeInitials, photoX + photoWidth / 2, photoY + photoHeight / 2 + 2, { align: 'center' })
      }

      const detailX = 27
      const detailWidth = 29
      pdf.setTextColor(23, 40, 58)
      pdf.setFont('helvetica', 'bold')
      pdf.setFontSize(7.2)
      pdf.text(limitLines(pdf.splitTextToSize(name, detailWidth), 2), detailX, 19)
      pdf.setFont('helvetica', 'normal')
      pdf.setTextColor(102, 121, 138)
      pdf.setFontSize(4.8)
      pdf.text('CÓDIGO DE EMPLEADO', detailX, 27)
      pdf.setTextColor(23, 40, 58)
      pdf.setFont('helvetica', 'bold')
      pdf.setFontSize(5.8)
      pdf.text(fitText(pdf, employeeCode, detailWidth), detailX, 30.2)
      pdf.setFont('helvetica', 'normal')
      pdf.setTextColor(102, 121, 138)
      pdf.setFontSize(4.8)
      pdf.text('DEPARTAMENTO', detailX, 35)
      pdf.setTextColor(23, 40, 58)
      pdf.setFont('helvetica', 'bold')
      pdf.setFontSize(5.2)
      pdf.text(limitLines(pdf.splitTextToSize(department, detailWidth), 2), detailX, 38.1)

      pdf.setFillColor(255, 255, 255)
      pdf.setDrawColor(220, 229, 236)
      const qrShellSize = 22
      const qrShellX = pageWidth - qrShellSize - 4.5
      const qrShellY = 16
      pdf.roundedRect(qrShellX, qrShellY, qrShellSize, qrShellSize, 2, 2, 'FD')
      pdf.addImage(qrImage, 'PNG', qrShellX + 1.3, qrShellY + 1.3, qrShellSize - 2.6, qrShellSize - 2.6)

      pdf.setDrawColor(220, 229, 236)
      pdf.line(5.5, 42, 56.5, 42)
      pdf.setFont('helvetica', 'normal')
      pdf.setTextColor(102, 121, 138)
      pdf.setFontSize(4.6)
      pdf.text(fitText(pdf, position, 51), 5.5, 45.5)
      pdf.setFont('helvetica', 'bold')
      pdf.setTextColor(40, 103, 232)
      pdf.text('INFORMACIÓN VERIFICADA EN TIEMPO REAL', 5.5, 49)

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
        <ol><li>Descarga e imprime el carnet en formato horizontal.</li><li>El usuario de control abre <strong>Escanear QR</strong>.</li><li>El sistema consulta en HTIS la identidad, el cargo, el departamento y el estado laboral actual.</li></ol>
        <p>La base local conserva únicamente la relación entre el código del empleado y su identificador QR.</p>
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
