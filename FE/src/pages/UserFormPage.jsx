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
      if (name === 'esGuardia' && checked) {
        return { ...next, idArea: '', puedeSolicitar: false, esAprobador: false, esSeguridad: false }
      }
      if (checked && ['puedeSolicitar', 'esAprobador', 'esSeguridad'].includes(name)) {
        next.esGuardia = false
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
        activo: form.activo,
      })
    } finally {
      setSaving(false)
    }
  }

  return <>
    <div className="page-heading">
      <div><p className="eyebrow">Administración</p><h1>Crear usuario</h1><p>Registra la cuenta y define el área y los permisos iniciales.</p></div>
    </div>

    <form className="panel form-panel user-create-form" onSubmit={submit}>
      <div className="section-heading"><h2>Información de la cuenta</h2><p>Los campos marcados con * son obligatorios.</p></div>
      <div className="form-grid">
        <Field label="Identificador de usuario" required><input name="idUsuario" maxLength="50" value={form.idUsuario} onChange={change} required placeholder="Ej. nombre.apellido" autoComplete="off" /></Field>
        <Field label="Nombre completo" required><input name="nombreCompleto" maxLength="200" value={form.nombreCompleto} onChange={change} required /></Field>
        <Field label="Correo electrónico"><input type="email" name="correo" maxLength="254" value={form.correo} onChange={change} /></Field>
        <Field label="Teléfono"><input type="tel" name="telefono" maxLength="30" value={form.telefono} onChange={change} /></Field>
        <Field label="Puesto"><input name="puesto" maxLength="150" value={form.puesto} onChange={change} /></Field>
        <Field label="Área principal" required={areaRequired}>
          <Select name="idArea" value={form.idArea} onChange={change} items={areas} required={areaRequired} />
          {areaRequired && <small className="field-help">El área es obligatoria para solicitantes y aprobadores.</small>}
        </Field>
        <Field label="Contraseña inicial" required full><input type="password" name="contrasena" minLength="8" maxLength="200" value={form.contrasena} onChange={change} required autoComplete="new-password" /></Field>
      </div>

      <div className="section-heading user-permissions-heading"><h2>Permisos iniciales</h2><p>Selecciona las funciones que tendrá la nueva cuenta.</p></div>
      <div className="user-permissions">
        <Check name="puedeSolicitar" checked={form.puedeSolicitar} onChange={change} label="Puede crear solicitudes" description="Permite registrar solicitudes de ingreso para su área." />
        <Check name="esAprobador" checked={form.esAprobador} onChange={change} label="Aprobador del área" description="Permite revisar y decidir accesos correspondientes al área seleccionada." />
        <Check name="esSeguridad" checked={form.esSeguridad} onChange={change} label="Personal de seguridad" description="Permite validar autorizaciones y registrar entradas y salidas." />
        <Check name="esGuardia" checked={form.esGuardia} onChange={change} label="Guardia de acceso" description="Solo permite escanear códigos QR y consultar la información presentada." />
        <Check name="activo" checked={form.activo} onChange={change} label="Usuario activo" description="Permite iniciar sesión inmediatamente después de crear la cuenta." />
      </div>

      <div className="form-footer"><button type="button" className="ghost-button" onClick={onCancel}>Cancelar</button><button type="submit" className="primary-button teal" disabled={saving}><Icon name="users" />{saving ? 'Guardando…' : 'Crear usuario'}</button></div>
    </form>
  </>
}

function Field({ label, required, full, children }) {
  return <div className={`field ${full ? 'full' : ''}`}><label>{label} {required && <span className="required">*</span>}</label>{children}</div>
}

function Select({ items = [], ...props }) {
  return <select {...props}><option value="">Sin área asignada</option>{items.map((item) => <option key={item.id} value={item.id}>{item.nombre ?? item.codigo}</option>)}</select>
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
