import { useEffect, useState } from 'react'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'

const initialForm = {
  codigo: '',
  nombreLegal: '',
  nombreComercial: '',
  rtn: '',
  contactoPrincipal: '',
  correoPrincipal: '',
  telefonoPrincipal: '',
  idEstadoGeneral: '',
}

export function ProviderFormPage({ session, onCreate, onCancel, onError }) {
  const [form, setForm] = useState(initialForm)
  const [statuses, setStatuses] = useState([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    let active = true
    controlIngresosApi.listarCatalogo('estados-generales')
      .then((items) => {
        if (!active) return
        const activeStatus = items.find((item) => item.codigo?.toUpperCase() === 'ACTIVO') ?? items[0]
        setStatuses(items)
        setForm((current) => ({
          ...current,
          idEstadoGeneral: current.idEstadoGeneral || String(activeStatus?.id ?? ''),
        }))
      })
      .catch((error) => active && onError(error.message))
      .finally(() => active && setLoading(false))

    return () => { active = false }
  }, [onError])

  function change(event) {
    const { name, value } = event.target
    setForm((current) => ({ ...current, [name]: value }))
    onError('')
  }

  async function submit(event) {
    event.preventDefault()
    setSaving(true)
    onError('')

    try {
      await onCreate({
        codigo: textOrNull(form.codigo),
        nombreLegal: form.nombreLegal.trim(),
        nombreComercial: textOrNull(form.nombreComercial),
        rtn: textOrNull(form.rtn),
        contactoPrincipal: textOrNull(form.contactoPrincipal),
        correoPrincipal: textOrNull(form.correoPrincipal),
        telefonoPrincipal: textOrNull(form.telefonoPrincipal),
        idEstadoGeneral: numberOrNull(form.idEstadoGeneral),
        usuario: session.idUsuario,
      })
    } finally {
      setSaving(false)
    }
  }

  return <>
    <div className="page-heading">
      <div><p className="eyebrow">Administración</p><h1>Nuevo proveedor</h1><p>Registra la empresa y sus datos principales de contacto.</p></div>
    </div>

    <form className="panel form-panel provider-form" onSubmit={submit}>
      <div className="section-heading"><h2>Información de la empresa</h2><p>Al guardar se creará automáticamente una cuenta con rol Proveedor.</p></div>
      <div className="form-grid">
        <Field label="Código interno"><input name="codigo" maxLength="30" value={form.codigo} onChange={change} placeholder="Ej. PROV-001" /></Field>
        <Field label="RTN"><input name="rtn" maxLength="30" value={form.rtn} onChange={change} placeholder="Registro tributario" /></Field>
        <Field label="Nombre legal" required><input name="nombreLegal" maxLength="200" value={form.nombreLegal} onChange={change} required placeholder="Razón social de la empresa" /></Field>
        <Field label="Nombre comercial"><input name="nombreComercial" maxLength="200" value={form.nombreComercial} onChange={change} placeholder="Nombre con el que opera" /></Field>
        <Field label="Estado" required>
          <select name="idEstadoGeneral" value={form.idEstadoGeneral} onChange={change} required disabled={loading}>
            <option value="">{loading ? 'Cargando…' : 'Selecciona un estado'}</option>
            {statuses.map((item) => <option key={item.id} value={item.id}>{item.nombre ?? item.codigo}</option>)}
          </select>
        </Field>
      </div>

      <div className="section-heading person-form-section"><h2>Contacto principal</h2><p>Estos datos se utilizarán para coordinar las solicitudes de ingreso.</p></div>
      <div className="form-grid">
        <Field label="Nombre del contacto"><input name="contactoPrincipal" maxLength="200" value={form.contactoPrincipal} onChange={change} placeholder="Nombre completo" /></Field>
        <Field label="Correo electrónico" required><input type="email" name="correoPrincipal" maxLength="254" value={form.correoPrincipal} onChange={change} placeholder="contacto@empresa.com" required /></Field>
        <Field label="Teléfono"><input type="tel" name="telefonoPrincipal" maxLength="30" value={form.telefonoPrincipal} onChange={change} placeholder="+504 0000-0000" /></Field>
      </div>

      <div className="form-note">
        <Icon name="mail" />
        <span>Las credenciales de acceso se enviarán al correo principal indicado.</span>
      </div>

      <div className="form-footer">
        <button type="button" className="ghost-button" onClick={onCancel} disabled={saving}>Cancelar</button>
        <button type="submit" className="primary-button teal" disabled={saving || loading}><Icon name="company" />{saving ? 'Guardando…' : 'Crear proveedor'}</button>
      </div>
    </form>
  </>
}

function Field({ label, required, children }) {
  return <div className="field"><label>{label} {required && <span className="required">*</span>}</label>{children}</div>
}

function textOrNull(value) {
  const normalized = value?.trim()
  return normalized || null
}

function numberOrNull(value) {
  return value === '' || value == null ? null : Number(value)
}
