import { useEffect, useState } from 'react'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'
import { showSuccessAlert } from '../utils/alerts'
import { formatFileSize, preparePhotograph } from '../utils/photographs'

const initialForm = {
  idTipoDocumento: '',
  numeroDocumento: '',
  nombreCompleto: '',
  telefono: '',
  correo: '',
  cargoFuncion: '',
  idProveedor: '',
  empresaTexto: '',
  informacionAdicional: '',
  idEstadoGeneral: '',
}

export function PersonFormPage({ session, providers = [], onCancel, onCreated, onError }) {
  const [form, setForm] = useState(initialForm)
  const [catalogs, setCatalogs] = useState({ documentTypes: [], statuses: [] })
  const [photograph, setPhotograph] = useState(null)
  const [photographPreview, setPhotographPreview] = useState('')
  const [processingPhotograph, setProcessingPhotograph] = useState(false)
  const [photographWasCompressed, setPhotographWasCompressed] = useState(false)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    let active = true

    Promise.all([
      controlIngresosApi.listarCatalogo('tipos-documento'),
      controlIngresosApi.listarCatalogo('estados-generales'),
    ])
      .then(([documentTypes, statuses]) => {
        if (!active) return
        const activeStatus = statuses.find((item) => item.codigo?.toUpperCase() === 'ACTIVO') ?? statuses[0]
        setCatalogs({ documentTypes, statuses })
        setForm((current) => ({
          ...current,
          idTipoDocumento: current.idTipoDocumento || String(documentTypes[0]?.id ?? ''),
          idEstadoGeneral: current.idEstadoGeneral || String(activeStatus?.id ?? ''),
        }))
      })
      .catch((error) => active && onError(error.message))
      .finally(() => active && setLoading(false))

    return () => { active = false }
  }, [onError])

  useEffect(() => () => {
    if (photographPreview) URL.revokeObjectURL(photographPreview)
  }, [photographPreview])

  function change(event) {
    const { name, value } = event.target
    setForm((current) => ({ ...current, [name]: value }))
  }

  async function changePhotograph(event) {
    const file = event.target.files?.[0] ?? null
    const input = event.target
    onError('')

    if (!file) {
      setPhotograph(null)
      setPhotographPreview('')
      setPhotographWasCompressed(false)
      return
    }

    setProcessingPhotograph(true)
    try {
      const optimized = await preparePhotograph(file)

      setPhotograph(optimized)
      setPhotographWasCompressed(optimized !== file)
      setPhotographPreview(URL.createObjectURL(optimized))
    } catch (error) {
      input.value = ''
      setPhotograph(null)
      setPhotographPreview('')
      setPhotographWasCompressed(false)
      onError(error.message || 'No fue posible procesar la fotografía seleccionada.')
    } finally {
      setProcessingPhotograph(false)
    }
  }

  async function submit(event) {
    event.preventDefault()
    onError('')

    if (!form.numeroDocumento.trim() || !form.nombreCompleto.trim()) {
      onError('El número de documento y el nombre completo son obligatorios.')
      return
    }

    setSaving(true)
    try {
      const uploadedPhotograph = photograph
        ? await controlIngresosApi.subirFotografiaPersona(photograph)
        : null

      const created = await controlIngresosApi.crearPersona({
        idTipoDocumento: numberOrNull(form.idTipoDocumento),
        numeroDocumento: form.numeroDocumento.trim(),
        nombreCompleto: form.nombreCompleto.trim(),
        fotografiaUrl: uploadedPhotograph?.url ?? null,
        telefono: textOrNull(form.telefono),
        correo: textOrNull(form.correo),
        cargoFuncion: textOrNull(form.cargoFuncion),
        idProveedor: numberOrNull(form.idProveedor),
        empresaTexto: textOrNull(form.empresaTexto),
        informacionAdicional: textOrNull(form.informacionAdicional),
        idEstadoGeneral: numberOrNull(form.idEstadoGeneral),
        usuario: session.idUsuario,
      })

      await showSuccessAlert('La persona fue registrada correctamente.')
      onCreated(created)
    } catch (error) {
      onError(error.message)
    } finally {
      setSaving(false)
    }
  }

  return <>
    <div className="page-heading">
      <div><p className="eyebrow">Personas</p><h1>Registrar nueva persona</h1><p>Ingresa los datos de identificación, contacto y empresa de la persona.</p></div>
    </div>
    <form className="panel form-panel" onSubmit={submit}>
      <div className="section-heading"><h2>Información personal</h2><p>Los campos marcados con * son obligatorios.</p></div>
      <div className="form-grid">
        <Field label="Tipo de documento">
          <Select name="idTipoDocumento" value={form.idTipoDocumento} onChange={change} items={catalogs.documentTypes} loading={loading} />
        </Field>
        <Field label="Número de documento" required>
          <input name="numeroDocumento" maxLength="60" value={form.numeroDocumento} onChange={change} placeholder="Número de identidad, pasaporte u otro" required />
        </Field>
        <Field label="Nombre completo" required full>
          <input name="nombreCompleto" maxLength="200" value={form.nombreCompleto} onChange={change} placeholder="Nombres y apellidos" required />
        </Field>
        <Field label="Teléfono">
          <input type="tel" name="telefono" maxLength="30" value={form.telefono} onChange={change} placeholder="Ej. +504 9999-9999" />
        </Field>
        <Field label="Correo electrónico">
          <input type="email" name="correo" maxLength="254" value={form.correo} onChange={change} placeholder="persona@empresa.com" />
        </Field>
        <Field label="Cargo o función">
          <input name="cargoFuncion" maxLength="150" value={form.cargoFuncion} onChange={change} placeholder="Ej. Técnico electricista" />
        </Field>
        <Field label="Estado">
          <Select name="idEstadoGeneral" value={form.idEstadoGeneral} onChange={change} items={catalogs.statuses} loading={loading} />
        </Field>
      </div>

      <div className="section-heading person-form-section"><h2>Empresa e información adicional</h2><p>Selecciona un proveedor registrado o escribe el nombre de la empresa.</p></div>
      <div className="form-grid">
        <Field label="Proveedor">
          <Select name="idProveedor" value={form.idProveedor} onChange={change} items={providers} emptyLabel="Sin proveedor registrado" />
        </Field>
        <Field label="Empresa">
          <input name="empresaTexto" maxLength="200" value={form.empresaTexto} onChange={change} placeholder="Nombre de la empresa" />
        </Field>
        <Field label="Fotografía" full>
          <div className="photograph-picker">
            <div className={`photograph-preview ${photographPreview ? 'has-image' : ''}`}>
              {photographPreview
                ? <img src={photographPreview} alt="Vista previa de la fotografía seleccionada" />
                : <Icon name="user" />}
            </div>
            <div className="photograph-picker-copy">
              <label className="photograph-button" htmlFor="person-photograph">
                <Icon name="file" />
                {processingPhotograph ? 'Optimizando…' : photograph ? 'Cambiar fotografía' : 'Seleccionar fotografía'}
              </label>
              <input
                id="person-photograph"
                className="photograph-input"
                type="file"
                accept="image/jpeg,image/png,image/webp"
                onChange={changePhotograph}
                disabled={processingPhotograph || saving}
              />
              <span>{processingPhotograph
                ? 'Reduciendo la imagen para que pueda subirse…'
                : photograph
                  ? `${photograph.name} · ${formatFileSize(photograph.size)}${photographWasCompressed ? ' · optimizada automáticamente' : ''}`
                  : 'JPG, PNG o WebP. Las imágenes mayores de 5 MB se optimizan automáticamente.'}</span>
            </div>
          </div>
        </Field>
        <Field label="Información adicional" full>
          <textarea name="informacionAdicional" maxLength="1000" value={form.informacionAdicional} onChange={change} placeholder="Observaciones relevantes sobre la persona" />
        </Field>
      </div>

      <div className="form-footer">
        <button type="button" className="ghost-button" onClick={onCancel}>Cancelar</button>
        <button type="submit" className="primary-button teal" disabled={saving || loading || processingPhotograph}><Icon name="send" />{saving ? 'Guardando…' : processingPhotograph ? 'Procesando foto…' : 'Registrar persona'}</button>
      </div>
    </form>
  </>
}

function Field({ label, required, full, children }) {
  return <div className={`field ${full ? 'full' : ''}`}><label>{label} {required && <span className="required">*</span>}</label>{children}</div>
}

function Select({ items = [], loading, emptyLabel = 'Selecciona una opción', ...props }) {
  return <select {...props}><option value="">{loading ? 'Cargando…' : emptyLabel}</option>{items.map((item) => <option key={item.id} value={item.id}>{item.nombre ?? item.codigo}</option>)}</select>
}

function numberOrNull(value) {
  return value === '' || value == null ? null : Number(value)
}

function textOrNull(value) {
  const normalized = value?.trim()
  return normalized || null
}
