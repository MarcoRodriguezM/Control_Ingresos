import { Icon } from '../components/Icon'
import { formatDate } from '../utils/formatters'

export function RequestFormPage({ form, options, loading, saving, editingId, step, selected, onChange, onStepChange, onNext, onBack, onCancel, onSubmit }) {
  return <>
    <div className="page-heading"><div><p className="eyebrow">{editingId ? 'Editar solicitud' : 'Nueva solicitud'}</p><h1>{editingId ? 'Actualizar solicitud de ingreso' : 'Registrar solicitud de ingreso'}</h1><p>Completa los datos del ingreso en tres pasos.</p></div></div>
    <Progress step={step} onStepChange={onStepChange} />
    <div className="panel form-panel">
      {step === 1 && <StepOne form={form} options={options} loading={loading} change={onChange} />}
      {step === 2 && <StepTwo form={form} options={options} loading={loading} change={onChange} />}
      {step === 3 && <Review form={form} selected={selected} />}
      <div className="form-footer">
        <button type="button" className="ghost-button" onClick={onCancel}>Cancelar</button>
        <div className="action-row">
          {step > 1 && <button type="button" className="secondary-button" onClick={onBack}><Icon name="back" />Atrás</button>}
          {step < 3
            ? <button type="button" className="primary-button" onClick={onNext}>Siguiente <Icon name="arrow" /></button>
            : <button type="button" className="primary-button teal" disabled={saving} onClick={onSubmit}><Icon name="send" />{saving ? 'Guardando…' : editingId ? 'Guardar cambios' : 'Enviar al proveedor'}</button>}
        </div>
      </div>
    </div>
  </>
}

function StepOne({ form, options, loading, change }) {
  return <><SectionHeading title="Información general" text="Define el tipo, las fechas y el propósito del ingreso." /><div className="form-grid"><Field label="Tipo de ingreso" required><Select name="idTipoIngreso" value={form.idTipoIngreso} onChange={change} items={options?.tiposIngreso} loading={loading} /></Field><Field label="Empresa / proveedor"><Select name="idProveedor" value={form.idProveedor} onChange={change} items={options?.proveedores} loading={loading} emptyLabel="Sin proveedor" /></Field><Field label="Fecha de inicio" required><input type="date" name="fechaInicio" value={form.fechaInicio} onChange={change} /></Field><Field label="Fecha de finalización" required><input type="date" name="fechaFin" min={form.fechaInicio} value={form.fechaFin} onChange={change} /></Field><Field label="Nombre de la actividad" required full><input name="nombreActividad" maxLength="200" value={form.nombreActividad} onChange={change} placeholder="Ej. Mantenimiento preventivo de infraestructura" /></Field><Field label="Descripción general" full><textarea name="descripcionActividad" maxLength="1000" value={form.descripcionActividad} onChange={change} placeholder="Describe el propósito del ingreso" /></Field><Field label="Contrato, cuando aplique"><input name="numeroContrato" maxLength="60" value={form.numeroContrato} onChange={change} placeholder="Ej. CT-2026-084" /></Field><Field label="Cantidad estimada de personas"><input type="number" name="cantidadEstimada" min="1" value={form.cantidadEstimada} onChange={change} /></Field></div></>
}

function StepTwo({ form, options, loading, change }) {
  return <><SectionHeading title="Contacto y ubicación" text="Indica quién coordina el ingreso y dónde se realizará." /><div className="form-grid"><Field label="Contacto del proveedor"><input name="contactoProveedor" maxLength="200" value={form.contactoProveedor} onChange={change} placeholder="Nombre del contacto" /></Field><Field label="Correo del proveedor"><input type="email" name="correoProveedor" maxLength="254" value={form.correoProveedor} onChange={change} placeholder="contacto@empresa.com" /></Field><Field label="Área solicitante" required><Select name="idAreaSolicitante" value={form.idAreaSolicitante} onChange={change} items={options?.areas} loading={loading} /></Field><Field label="Ubicación / instalación" required><Select name="idUbicacion" value={form.idUbicacion} onChange={change} items={options?.ubicaciones} loading={loading} /></Field><Field label="Usuario solicitante" required full><Select name="idUsuarioSolicitante" value={form.idUsuarioSolicitante} onChange={change} items={options?.usuarios} loading={loading} /></Field><Field label="Observaciones" full><textarea name="observaciones" maxLength="1000" value={form.observaciones} onChange={change} placeholder="Indicaciones para el ingreso" /></Field></div></>
}

function Review({ form, selected }) {
  const rows = [['Tipo de ingreso', selected.tipo?.nombre], ['Empresa', selected.proveedor?.nombre ?? 'Sin proveedor'], ['Actividad', form.nombreActividad], ['Periodo', `${formatDate(form.fechaInicio)} – ${formatDate(form.fechaFin)}`], ['Contacto', form.contactoProveedor || 'No indicado'], ['Correo', form.correoProveedor || 'No indicado'], ['Área solicitante', selected.area?.nombre], ['Ubicación', selected.ubicacion?.nombre]]
  return <><SectionHeading title="Revisa antes de enviar" text="La solicitud se guardará y quedará disponible para registrar las personas." /><div className="info-list">{rows.map(([label, value]) => <div className="info-item" key={label}><span>{label}</span><strong>{value || '—'}</strong></div>)}</div><div className="ticket-box"><div><h3>¿Qué ocurrirá al enviar?</h3><p>Se generará un número de solicitud y podrás continuar con el registro de las {form.cantidadEstimada || 0} personas.</p></div><Icon name="send" /></div></>
}

function Progress({ step, onStepChange }) {
  return <div className="progress-shell">{['Información básica', 'Contacto y ubicación', 'Revisión y envío'].map((label, index) => { const number = index + 1; const state = step === number ? 'active' : step > number ? 'done' : ''; return <button type="button" className={`step ${state}`} key={label} onClick={() => onStepChange(number)} aria-current={step === number ? 'step' : undefined}><span className="step-number">{step > number ? '✓' : number}</span><span>{label}</span></button> })}</div>
}

function SectionHeading({ title, text }) { return <div className="section-heading"><h2>{title}</h2><p>{text}</p></div> }
function Field({ label, required, full, children }) { return <div className={`field ${full ? 'full' : ''}`}><label>{label} {required && <span className="required">*</span>}</label>{children}</div> }
function Select({ items = [], loading, emptyLabel = 'Selecciona una opción', ...props }) { return <select {...props}><option value="">{loading ? 'Cargando…' : emptyLabel}</option>{items?.map((item) => <option key={item.id} value={item.id}>{item.nombre ?? item.codigo}</option>)}</select> }
