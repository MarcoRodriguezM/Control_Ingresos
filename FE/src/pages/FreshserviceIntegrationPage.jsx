import { useMemo, useState } from 'react'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'

const initialFieldValue = (field) => {
  if (field.type === 'checkbox') return String(field.defaultValue).toLowerCase() === 'true'
  if (field.type === 'multiselect') return []
  return field.defaultValue ?? ''
}

export function FreshserviceIntegrationPage() {
  const [workspaceId, setWorkspaceId] = useState('')
  const [page, setPage] = useState(1)
  const [catalog, setCatalog] = useState(null)
  const [catalogLoading, setCatalogLoading] = useState(false)
  const [serviceLoading, setServiceLoading] = useState(false)
  const [selected, setSelected] = useState(null)
  const [values, setValues] = useState({})
  const [preview, setPreview] = useState(null)
  const [search, setSearch] = useState('')
  const [error, setError] = useState('')

  const filteredItems = useMemo(() => {
    const query = search.trim().toLowerCase()
    if (!query) return catalog?.items ?? []
    return (catalog?.items ?? []).filter((item) => [item.name, item.shortDescription, item.displayId]
      .some((value) => String(value ?? '').toLowerCase().includes(query)))
  }, [catalog, search])

  const requiredUnsupported = selected?.fields?.filter((field) => field.required && !field.supported) ?? []
  const supportedCount = selected?.fields?.filter((field) => field.supported).length ?? 0
  const unsupportedCount = selected?.fields?.filter((field) => !field.supported).length ?? 0

  async function loadCatalog(targetPage = 1) {
    setCatalogLoading(true)
    setError('')
    setSelected(null)
    setPreview(null)
    try {
      const result = await controlIngresosApi.listarCatalogoFreshservice({
        page: targetPage,
        perPage: 30,
        workspaceId: workspaceId.trim() || null,
      })
      setCatalog(result)
      setPage(targetPage)
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setCatalogLoading(false)
    }
  }

  async function selectService(item) {
    setServiceLoading(true)
    setError('')
    setPreview(null)
    try {
      const result = await controlIngresosApi.obtenerServicioFreshservice(
        item.displayId,
        workspaceId.trim() || item.workspaceId || null,
      )
      setSelected(result)
      setValues(Object.fromEntries((result.fields ?? [])
        .filter((field) => field.supported && field.type !== 'info' && field.apiName)
        .map((field) => [field.apiName, initialFieldValue(field)])))
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setServiceLoading(false)
    }
  }

  function updateField(field, value) {
    setValues((current) => ({ ...current, [field.apiName]: value }))
    setPreview(null)
  }

  function generatePreview(event) {
    event.preventDefault()
    const customFields = {}
    for (const field of selected.fields ?? []) {
      if (!field.supported || field.type === 'info' || !field.apiName) continue
      const value = values[field.apiName]
      const empty = value == null || value === '' || (Array.isArray(value) && value.length === 0)
      if (empty && !field.required) continue
      customFields[field.apiName] = field.type === 'number' || field.type === 'decimal'
        ? value === '' ? null : Number(value)
        : value
    }

    setPreview({
      email: '[correo del usuario autenticado]',
      quantity: 1,
      ...(selected.workspaceId ? { workspace_id: selected.workspaceId } : {}),
      custom_fields: customFields,
    })
  }

  return <div className="freshservice-page">
    <div className="page-heading freshservice-heading">
      <div>
        <p className="eyebrow">Integración de solo lectura</p>
        <h1>Laboratorio de Freshservice</h1>
        <p>Consulta el catálogo, inspecciona sus campos y simula el formulario sin crear tickets.</p>
      </div>
      <span className="freshservice-readonly"><Icon name="lock" />Sin escrituras</span>
    </div>

    <section className="panel freshservice-controls" aria-label="Consulta del catálogo">
      <label>
        <span>Workspace ID opcional</span>
        <input type="number" min="1" value={workspaceId} onChange={(event) => setWorkspaceId(event.target.value)} placeholder="Usar workspace principal" />
      </label>
      <button type="button" className="primary-button" disabled={catalogLoading} onClick={() => loadCatalog(1)}>
        <Icon name="search" />{catalogLoading ? 'Consultando…' : 'Consultar catálogo'}
      </button>
      <p><strong>Importante:</strong> esta acción realiza únicamente un GET al catálogo corporativo.</p>
    </section>

    {error && <div className="freshservice-message error" role="alert"><Icon name="warning" /><div><strong>No se completó la consulta</strong><span>{error}</span></div></div>}

    {catalog && <div className="freshservice-layout">
      <section className="panel freshservice-catalog">
        <header>
          <div><p className="eyebrow">Página {catalog.page}</p><h2>Servicios disponibles</h2></div>
          <span>{catalog.items?.length ?? 0}</span>
        </header>
        <div className="freshservice-search"><Icon name="search" /><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Filtrar esta página" /></div>
        <div className="freshservice-service-list">
          {filteredItems.length === 0 && <p className="freshservice-empty">No hay servicios que coincidan con el filtro.</p>}
          {filteredItems.map((item) => <button type="button" key={item.displayId} className={`freshservice-service ${selected?.displayId === item.displayId ? 'selected' : ''}`} onClick={() => selectService(item)} disabled={serviceLoading}>
            <span className="freshservice-service-id">#{item.displayId}</span>
            <span><strong>{item.name || 'Servicio sin nombre'}</strong><small>{item.shortDescription || `${item.fieldCount} campo(s) reportado(s)`}</small></span>
            <Icon name="arrow" />
          </button>)}
        </div>
        <footer className="freshservice-pagination">
          <button type="button" className="secondary-button" disabled={catalogLoading || page <= 1} onClick={() => loadCatalog(page - 1)}>Anterior</button>
          <span>Página {page}</span>
          <button type="button" className="secondary-button" disabled={catalogLoading || !catalog.hasNextPage} onClick={() => loadCatalog(page + 1)}>Siguiente</button>
        </footer>
      </section>

      <section className="panel freshservice-detail">
        {serviceLoading && <div className="freshservice-empty"><strong>Consultando definición del servicio…</strong></div>}
        {!serviceLoading && !selected && <div className="freshservice-empty"><Icon name="file" /><strong>Selecciona un servicio</strong><span>Aquí se mostrará la interpretación de sus campos personalizados.</span></div>}
        {!serviceLoading && selected && <>
          <header className="freshservice-detail-heading">
            <div><p className="eyebrow">Servicio #{selected.displayId}</p><h2>{selected.name || 'Servicio sin nombre'}</h2><p>{selected.shortDescription || 'Sin descripción breve.'}</p></div>
            <div className="freshservice-field-counts"><span><strong>{supportedCount}</strong> compatibles</span><span className={unsupportedCount ? 'warning' : ''}><strong>{unsupportedCount}</strong> pendientes</span></div>
          </header>

          <div className="freshservice-service-facts">
            <span><strong>Workspace</strong>{selected.workspaceId ?? 'Principal'}</span>
            <span><strong>Cantidad</strong>{selected.allowQuantity ? 'Permitida' : 'Fija'}</span>
            <span><strong>Adjuntos</strong>{selected.allowAttachments ? 'Permitidos' : 'No permitidos'}</span>
            <span><strong>Bundle</strong>{selected.isBundle ? 'Sí' : 'No'}</span>
          </div>

          {requiredUnsupported.length > 0 && <div className="freshservice-message warning"><Icon name="warning" /><div><strong>El servicio aún no sería enviable</strong><span>{requiredUnsupported.length} campo(s) obligatorio(s) requieren implementación específica.</span></div></div>}

          <form className="freshservice-dynamic-form" onSubmit={generatePreview}>
            <div className="freshservice-form-heading"><div><h3>Formulario dinámico de prueba</h3><p>Los valores solo se usan para construir la vista previa local.</p></div><span>{selected.fields?.length ?? 0} campo(s)</span></div>
            {(selected.fields?.length ?? 0) === 0 && <p className="freshservice-empty compact">Freshservice no reportó campos personalizados para este servicio.</p>}
            {(selected.fields ?? []).map((field, index) => <DynamicField key={`${field.apiName || field.rawType}-${index}`} field={field} value={field.apiName ? values[field.apiName] : ''} onChange={(value) => updateField(field, value)} />)}
            <div className="freshservice-form-actions">
              <span><Icon name="lock" />No se enviará información a Freshservice.</span>
              <button type="submit" className="primary-button">Generar vista previa local</button>
            </div>
          </form>

          {preview && <section className="freshservice-preview" aria-label="Vista previa del payload">
            <header><div><p className="eyebrow">Simulación local</p><h3>Payload propuesto</h3></div><span>No enviado</span></header>
            <pre>{JSON.stringify(preview, null, 2)}</pre>
          </section>}

          <details className="freshservice-schema">
            <summary>Ver contrato normalizado del formulario</summary>
            <pre>{JSON.stringify(selected, null, 2)}</pre>
          </details>
        </>}
      </section>
    </div>}
  </div>
}

function DynamicField({ field, value, onChange }) {
  if (!field.supported) return <div className="freshservice-field unsupported">
    <div><strong>{field.label || field.apiName || 'Campo sin nombre'}</strong><span>{field.rawType}</span></div>
    <p>{field.unsupportedReason}</p>
    {field.required && <small>Obligatorio en Freshservice</small>}
  </div>

  if (field.type === 'info') return <div className="freshservice-field information">
    <strong>{field.label || 'Información del servicio'}</strong>
    {field.description && <p>{field.description}</p>}
  </div>

  const description = field.description || (!field.displayedToRequester ? 'Este campo no se muestra al solicitante en el portal.' : '')
  return <label className={`freshservice-field ${field.type === 'checkbox' ? 'checkbox' : ''}`}>
    <span className="freshservice-field-label">{field.label || field.apiName}{field.required && <strong aria-label="Obligatorio">*</strong>}</span>
    {field.type === 'textarea' && <textarea required={field.required} value={value ?? ''} placeholder={field.placeholder ?? ''} onChange={(event) => onChange(event.target.value)} />}
    {field.type === 'checkbox' && <span className="freshservice-checkbox"><input type="checkbox" checked={Boolean(value)} onChange={(event) => onChange(event.target.checked)} /><span>{field.placeholder || 'Activar opción'}</span></span>}
    {field.type === 'dropdown' && <select required={field.required} value={value ?? ''} onChange={(event) => onChange(event.target.value)}><option value="">Seleccionar</option>{field.options.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}</select>}
    {field.type === 'multiselect' && <select multiple required={field.required} value={Array.isArray(value) ? value : []} onChange={(event) => onChange([...event.target.selectedOptions].map((option) => option.value))}>{field.options.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}</select>}
    {!['textarea', 'checkbox', 'dropdown', 'multiselect'].includes(field.type) && <input
      type={field.type === 'decimal' ? 'number' : field.type === 'datetime' ? 'datetime-local' : field.type}
      step={field.type === 'decimal' ? 'any' : undefined}
      required={field.required}
      value={value ?? ''}
      placeholder={field.placeholder ?? ''}
      onChange={(event) => onChange(event.target.value)}
    />}
    <small>{description || field.apiName}{!field.requesterCanEdit && ' · No editable por solicitante'}</small>
  </label>
}

