import { useCallback, useEffect, useRef, useState } from 'react'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { formatDateTime } from '../utils/formatters'

const dateValue = (date) => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
const initialDates = () => {
  const end = new Date()
  const start = new Date(end)
  start.setDate(start.getDate() - 6)
  return { desde: dateValue(start), hasta: dateValue(end), persona: '' }
}

const methodLabels = { POST: 'Creacion', PUT: 'Actualizacion', PATCH: 'Cambio', DELETE: 'Eliminacion' }
const resourceLabels = {
  autenticacion: 'Sesion', solicitudes: 'Solicitudes', personas: 'Personas', empleados: 'Empleados',
  aprobaciones: 'Aprobaciones', actividades: 'Actividades', 'actividad-flujos': 'Flujos de acceso',
  proveedores: 'Proveedores', usuarios: 'Usuarios', freshservice: 'Freshservice', pantalla: 'Pantalla',
}

function actionLabel(item) {
  if (item.metodo === 'VIEW') return 'Ingreso a pantalla'
  if (item.recurso === 'api/autenticacion/login') return 'Inicio de sesion'
  if (item.recurso?.includes('autenticacion/logout')) return 'Cierre de sesion'
  if (item.recurso?.includes('fotografia')) return 'Cambio de fotografia'
  if (item.recurso?.includes('reenviar-aprobacion')) return 'Reenvio de aprobacion'
  if (item.recurso?.includes('/enviar')) return 'Envio de solicitud'
  if (item.recurso?.includes('/decision')) return 'Decision de aprobacion'
  if (item.recurso?.includes('/completar')) return 'Actividad completada'
  if (item.recurso?.includes('/ticket')) return 'Creacion de ticket'
  if (item.recurso?.includes('/movimientos')) return 'Registro de ingreso'
  if (item.recurso?.includes('/areas')) return 'Asignacion de areas'
  return methodLabels[item.metodo] || item.metodo
}

function actionTone(item) {
  if (item.metodo === 'VIEW') return 'viewed'
  if (item.recurso?.includes('autenticacion/')) return 'session'
  if (item.metodo === 'DELETE') return 'deleted'
  if (item.metodo === 'PUT' || item.metodo === 'PATCH') return 'updated'
  return 'created'
}

function resultLabel(item) {
  if (item.estado >= 400) return `Error ${item.estado}`
  if (item.metodo === 'VIEW') return 'Vista abierta'
  if (item.recurso?.includes('autenticacion/login')) return 'Sesion iniciada'
  if (item.recurso?.includes('autenticacion/logout')) return 'Sesion cerrada'
  if (item.metodo === 'DELETE') return 'Eliminado'
  if (item.metodo === 'PUT' || item.metodo === 'PATCH') return 'Actualizado'
  if (item.recurso?.includes('/enviar')) return 'Enviado'
  return 'Creado'
}

export function AuditLogPage() {
  const [draft, setDraft] = useState(initialDates)
  const [filters, setFilters] = useState(initialDates)
  const [page, setPage] = useState(1)
  const [result, setResult] = useState({ registros: [], total: 0, tamanoPagina: 50 })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const latestRequest = useRef(0)

  const load = useCallback(async () => {
    const requestId = ++latestRequest.current
    setLoading(true)
    setError('')
    try {
      const data = await controlIngresosApi.listarAuditoria({ ...filters, pagina: page })
      if (requestId === latestRequest.current) setResult(data)
    } catch (requestError) {
      if (requestId === latestRequest.current) setError(requestError.message)
    } finally {
      if (requestId === latestRequest.current) setLoading(false)
    }
  }, [filters, page])

  useEffect(() => {
    const timer = window.setTimeout(load, 0)
    return () => window.clearTimeout(timer)
  }, [load])

  function applyFilters(event) {
    event.preventDefault()
    if (draft.hasta < draft.desde) {
      setError('La fecha final debe ser igual o posterior a la fecha inicial.')
      return
    }
    setPage(1)
    setFilters({ ...draft, persona: draft.persona.trim() })
  }

  const pages = Math.max(1, Math.ceil(result.total / result.tamanoPagina))

  return <div className="audit-page">
    <div className="page-heading requests-heading">
      <div>
        <p className="eyebrow">ADMINISTRACION</p>
        <h1>Registro de actividad</h1>
        <p>Consulta entradas a pantallas y acciones realizadas por los usuarios, como crear, editar y eliminar.</p>
      </div>
      <button type="button" className="secondary-button audit-refresh" onClick={load} disabled={loading}>Actualizar</button>
    </div>

    <form className="audit-filters" onSubmit={applyFilters}>
      <label>Desde<input type="date" value={draft.desde} onChange={(event) => setDraft((current) => ({ ...current, desde: event.target.value }))} required /></label>
      <label>Hasta<input type="date" value={draft.hasta} onChange={(event) => setDraft((current) => ({ ...current, hasta: event.target.value }))} required /></label>
      <label className="audit-person-filter">Persona que realizo la accion
        <span className="audit-search"><Icon name="search" /><input value={draft.persona} onChange={(event) => setDraft((current) => ({ ...current, persona: event.target.value }))} placeholder="Nombre o usuario" /></span>
      </label>
      <button type="submit" className="primary-button" disabled={loading}>Filtrar</button>
    </form>

    {error && <p className="audit-error" role="alert">{error}</p>}

    <article className="panel requests-panel audit-results">
      <div className="audit-results-heading"><strong>{result.total} registro(s)</strong><span>Pagina {page} de {pages}</span></div>
      <div className="table-wrap"><table className="approvals-table audit-table">
        <thead><tr><th>Fecha y hora</th><th>Usuario</th><th>Accion</th><th>Recurso</th><th>Resultado</th></tr></thead>
        <tbody>
          {loading && <tr><td colSpan="5" className="empty-table">Cargando registros...</td></tr>}
          {!loading && result.registros.length === 0 && <tr><td colSpan="5" className="empty-table">No hay acciones para los filtros seleccionados.</td></tr>}
          {!loading && result.registros.map((item) => <tr key={item.id}>
            <td>{formatDateTime(item.fecha)}</td>
            <td><strong>{item.nombreUsuario || item.usuario || 'Desconocido'}</strong><span className="cell-sub">{item.usuario}</span></td>
            <td><span className={`audit-action ${actionTone(item)}`}>{actionLabel(item)}</span></td>
            <td><strong>{resourceLabels[item.recurso?.split('/')[1] || item.recurso] || 'Sistema'}</strong>{item.referencia && <span className="cell-sub">{item.referencia}</span>}</td>
            <td><span className={`audit-status ${item.estado >= 400 ? 'failed' : actionTone(item)}`}>{resultLabel(item)}</span></td>
          </tr>)}
        </tbody>
      </table></div>
      <div className="audit-pagination">
        <button type="button" className="secondary-button" disabled={loading || page <= 1} onClick={() => setPage((current) => current - 1)}>Anterior</button>
        <span>{page} / {pages}</span>
        <button type="button" className="secondary-button" disabled={loading || page >= pages} onClick={() => setPage((current) => current + 1)}>Siguiente</button>
      </div>
    </article>
  </div>
}
