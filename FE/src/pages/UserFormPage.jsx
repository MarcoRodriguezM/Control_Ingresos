import { useState } from 'react'
import { Icon } from '../components/Icon'

const initialForm = {
  idUsuario: '',
  nombreCompleto: '',
  correo: '',
  telefono: '',
  puesto: '',
  contrasena: '',
  idArea: '',
  puedeSolicitar: true,
  esAprobador: false,
  esSeguridad: false,
  esGuardia: false,
  esProveedor: false,
  activo: true,
}

export function UserFormPage({ areas = [], onCreate, onCancel }) {
  const [form, setForm] = useState(initialForm)
  const [saving, setSaving] = useState(false)

  const areaRequired = form.puedeSolicitar || form.esAprobador

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
      await onCreate({
        idUsuario: form.idUsuario.trim(),
        nombreCompleto: form.nombreCompleto.trim(),
        correo: textOrNull(form.correo),
        telefono: textOrNull(form.telefono),
        puesto: textOrNull(form.puesto),
        contrasena: form.contrasena,
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

  return <>
    <div className="page-heading">
      <div><p className="eyebrow">Administracion</p><h1>Crear usuario</h1><p>Registra la cuenta y define el area y los permisos iniciales.</p></div>
    </div>

    <form className="panel form-panel user-create-form" onSubmit={submit}>
      <div className="section-heading"><h2>Informacion de la cuenta</h2><p>Los campos marcados con * son obligatorios.</p></div>
      <div className="form-grid">
        <Field label="Identificador de usuario" required><input name="idUsuario" maxLength="50" value={form.idUsuario} onChange={change} required placeholder="Ej. nombre.apellido" autoComplete="off" /></Field>
        <Field label="Nombre completo" required><input name="nombreCompleto" maxLength="200" value={form.nombreCompleto} onChange={change} required /></Field>
        <Field label="Correo electronico"><input type="email" name="correo" maxLength="254" value={form.correo} onChange={change} /></Field>
        <Field label="Telefono"><input type="tel" name="telefono" maxLength="30" value={form.telefono} onChange={change} /></Field>
        <Field label="Puesto"><input name="puesto" maxLength="150" value={form.puesto} onChange={change} /></Field>
        <Field label="Area principal" required={areaRequired}>
          <Select name="idArea" value={form.idArea} onChange={change} items={areas} required={areaRequired} />
          {areaRequired && <small className="field-help">El area es obligatoria para solicitantes y aprobadores.</small>}
        </Field>
        <Field label="Contrasena inicial" required full><input type="password" name="contrasena" minLength="8" maxLength="200" value={form.contrasena} onChange={change} required autoComplete="new-password" /></Field>
      </div>

      <div className="section-heading user-permissions-heading"><h2>Permisos iniciales</h2><p>Selecciona las funciones que tendra la nueva cuenta.</p></div>
      <div className="user-permissions">
        <Check name="puedeSolicitar" checked={form.puedeSolicitar} onChange={change} label="Puede crear solicitudes" description="Permite registrar solicitudes de ingreso para su area." />
        <Check name="esAprobador" checked={form.esAprobador} onChange={change} label="Aprobador del area" description="Permite revisar y decidir accesos correspondientes al area seleccionada." />
        <Check name="esSeguridad" checked={form.esSeguridad} onChange={change} label="Personal de seguridad" description="Permite validar autorizaciones y registrar entradas y salidas." />
        <Check name="esGuardia" checked={form.esGuardia} onChange={change} label="Guardia de acceso" description="Solo permite escanear codigos QR y consultar la informacion presentada." />
        <Check name="esProveedor" checked={form.esProveedor} onChange={change} label="Usuario proveedor" description="Asigna el acceso exclusivo al portal y las futuras vistas para proveedores." />
        <Check name="activo" checked={form.activo} onChange={change} label="Usuario activo" description="Permite iniciar sesion inmediatamente despues de crear la cuenta." />
      </div>

      {form.esProveedor && <p className="provider-account-help">El correo de esta cuenta debe coincidir con el correo principal registrado para el proveedor.</p>}

      <div className="form-footer"><button type="button" className="ghost-button" onClick={onCancel}>Cancelar</button><button type="submit" className="primary-button teal" disabled={saving}><Icon name="users" />{saving ? 'Guardando…' : 'Crear usuario'}</button></div>
    </form>
  </>
}

function Field({ label, required, full, children }) {
  return <div className={`field ${full ? 'full' : ''}`}><label>{label} {required && <span className="required">*</span>}</label>{children}</div>
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
