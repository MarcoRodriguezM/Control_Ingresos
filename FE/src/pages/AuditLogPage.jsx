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

const methodLabels = { GET: 'Consulta', POST: 'Creacion', PUT: 'Actualizacion', PATCH: 'Cambio', DELETE: 'Eliminacion' }
const resourceLabels = {
  autenticacion: 'Sesion', solicitudes: 'Solicitudes', personas: 'Personas', empleados: 'Empleados',
  aprobaciones: 'Aprobaciones', actividades: 'Actividades', 'actividad-flujos': 'Flujos de acceso',
  proveedores: 'Proveedores', usuarios: 'Usuarios', freshservice: 'Freshservice',
}

function actionLabel(item) {
  if (item.recurso === 'api/autenticacion/login') return 'Inicio de sesion'
  if (item.recurso?.includes('autenticacion/logout')) return 'Cierre de sesion'
  return methodLabels[item.metodo] || item.metodo
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
        <p>Consulta las acciones de los usuarios. Los registros comienzan desde que se habilito esta auditoria.</p>
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
            <td>{actionLabel(item)}</td>
            <td><strong>{resourceLabels[item.recurso?.split('/')[1]] || 'Sistema'}</strong><span className="cell-sub audit-resource">{item.recurso}{item.referencia ? ` · ${item.referencia}` : ''}</span></td>
            <td><span className={`audit-status ${item.estado >= 400 ? 'failed' : 'ok'}`}>{item.estado >= 400 ? 'Error' : 'Correcto'} · {item.estado}</span></td>
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
