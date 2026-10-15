import { useEffect, useState } from 'react'
import { Icon } from '../components/Icon'
import { controlIngresosApi } from '../services/api'

const emptyForm = {
  nombreCompleto: '',
  correo: '',
  telefono: '',
  puesto: '',
  idArea: '',
  puedeSolicitar: false,
  esAprobador: false,
  esSeguridad: false,
  esGuardia: false,
  esProveedor: false,
  activo: true,
}

export function UserEditPage({ idUsuario, areas = [], onUpdate, onCancel, onError }) {
  const [form, setForm] = useState(emptyForm)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const areaRequired = form.puedeSolicitar || form.esAprobador

  useEffect(() => {
    let active = true
    setLoading(true)
    onError('')

    controlIngresosApi.obtenerUsuario(idUsuario)
      .then((user) => {
        if (!active) return
        const assignedArea = user.areas?.find((area) => area.esAprobadorPrincipal)
          ?? user.areas?.find((area) => area.esAreaPrincipal)
          ?? user.areas?.[0]
        const roles = user.roles?.split(',').map((role) => role.trim().toUpperCase()) ?? []
        setForm({
          nombreCompleto: user.nombreCompleto ?? '',
          correo: user.correo ?? '',
          telefono: user.telefono ?? '',
          puesto: user.puesto ?? '',
          idArea: assignedArea ? String(assignedArea.idArea) : '',
          puedeSolicitar: Boolean(user.areas?.some((area) => area.puedeSolicitar && area.activo)),
          esAprobador: Boolean(user.areas?.some((area) => area.esAprobador && area.activo)),
          esSeguridad: roles.includes('SEGURIDAD'),
          esGuardia: roles.includes('GUARDIA'),
          esProveedor: roles.includes('PROVEEDOR'),
          activo: Boolean(user.activo),
        })
      })
      .catch((error) => active && onError(error.status === 404 ? 'El usuario seleccionado no existe.' : error.message))
      .finally(() => active && setLoading(false))

    return () => { active = false }
  }, [idUsuario, onError])

  function change(event) {
    const { name, value, checked, type } = event.target
    setForm((current) => {
      const next = { ...current, [name]: type === 'checkbox' ? checked : value }
      if (['esGuardia', 'esProveedor'].includes(name) && checked) {
        return {
          ...next,
          idArea: '',
          puedeSolicitar: false,
          esAprobador: false,
          esSeguridad: false,
          esGuardia: name === 'esGuardia',
          esProveedor: name === 'esProveedor',
        }
      }
      if (checked && ['puedeSolicitar', 'esAprobador', 'esSeguridad'].includes(name)) {
        next.esGuardia = false
        next.esProveedor = false
      }
      return next
    })
  }

  async function submit(event) {
    event.preventDefault()
    setSaving(true)
    try {
      await onUpdate({
        nombreCompleto: form.nombreCompleto.trim(),
        correo: textOrNull(form.correo),
        telefono: textOrNull(form.telefono),
        puesto: textOrNull(form.puesto),
        idArea: numberOrNull(form.idArea),
        puedeSolicitar: form.puedeSolicitar,
        esAprobador: form.esAprobador,
        esSeguridad: form.esSeguridad,
        esGuardia: form.esGuardia,
        esProveedor: form.esProveedor,
        activo: form.activo,
      })
    } finally {
      setSaving(false)
    }
  }

  if (loading) return <div className="panel profile-placeholder">Cargando usuario…</div>

  return <>
    <div className="page-heading">
      <div><p className="eyebrow">Administracion</p><h1>Editar usuario</h1><p>Actualiza los datos, el area principal y los permisos de la cuenta.</p></div>
    </div>

    <form className="panel form-panel user-create-form" onSubmit={submit}>
      <div className="section-heading"><h2>Informacion de la cuenta</h2><p>El identificador y la contrasena no se modifican desde esta pantalla.</p></div>
      <div className="form-grid">
        <Field label="Identificador de usuario"><input value={idUsuario} disabled /></Field>
        <Field label="Nombre completo" required><input name="nombreCompleto" maxLength="200" value={form.nombreCompleto} onChange={change} required /></Field>
        <Field label="Correo electronico"><input type="email" name="correo" maxLength="254" value={form.correo} onChange={change} /></Field>
        <Field label="Telefono"><input type="tel" name="telefono" maxLength="30" value={form.telefono} onChange={change} /></Field>
        <Field label="Puesto"><input name="puesto" maxLength="150" value={form.puesto} onChange={change} /></Field>
        <Field label="Area principal" required={areaRequired}>
          <Select name="idArea" value={form.idArea} onChange={change} items={areas} required={areaRequired} />
          {areaRequired && <small className="field-help">El area es obligatoria para solicitantes y aprobadores.</small>}
        </Field>
      </div>

      <div className="section-heading user-permissions-heading"><h2>Permisos y estado</h2><p>Los cambios se aplicaran al guardar.</p></div>
      <div className="user-permissions">
        <Check name="puedeSolicitar" checked={form.puedeSolicitar} onChange={change} label="Puede crear solicitudes" description="Permite registrar solicitudes de ingreso para el area seleccionada." />
        <Check name="esAprobador" checked={form.esAprobador} onChange={change} label="Aprobador del area" description="Permite revisar y decidir accesos del area seleccionada." />
        <Check name="esSeguridad" checked={form.esSeguridad} onChange={change} label="Personal de seguridad" description="Asigna o retira el rol de seguridad." />
        <Check name="esGuardia" checked={form.esGuardia} onChange={change} label="Guardia de acceso" description="Restringe la cuenta al escaner QR y la consulta de resultados." />
        <Check name="esProveedor" checked={form.esProveedor} onChange={change} label="Usuario proveedor" description="Asigna el acceso exclusivo al portal de proveedores." />
        <Check name="activo" checked={form.activo} onChange={change} label="Usuario activo" description="Permite que la cuenta continue iniciando sesion." />
      </div>

      {form.esProveedor && <p className="provider-account-help">El correo de esta cuenta debe coincidir con el correo principal registrado para el proveedor.</p>}

      <div className="form-footer"><button type="button" className="ghost-button" onClick={onCancel}>Cancelar</button><button type="submit" className="primary-button teal" disabled={saving}><Icon name="check" />{saving ? 'Guardando…' : 'Guardar cambios'}</button></div>
    </form>
  </>
}

function Field({ label, required, children }) {
  return <div className="field"><label>{label} {required && <span className="required">*</span>}</label>{children}</div>
}

function Select({ items = [], ...props }) {
  return <select {...props}><option value="">Sin area asignada</option>{items.map((item) => <option key={item.id} value={item.id}>{item.nombre ?? item.codigo}</option>)}</select>
}

function Check({ name, checked, onChange, label, description }) {
  return <label className="user-permission"><input type="checkbox" name={name} checked={checked} onChange={onChange} /><span><strong>{label}</strong><small>{description}</small></span></label>
}

function numberOrNull(value) {
  return value === '' || value == null ? null : Number(value)
}

function textOrNull(value) {
  const normalized = value?.trim()
  return normalized || null
}
