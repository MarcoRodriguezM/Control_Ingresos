import { useState } from 'react'
import { Icon } from '../components/Icon'
import { formatDate } from '../utils/formatters'

export function RequestFormPage({ form, options, people, requestPeople, existingPeople, peopleEntryMode, loading, saving, editingId, step, selected, canSend, onPeopleEntryModeChange, onPeopleChange, onChange, onStepChange, onNext, onBack, onCancel, onSubmit }) {
  return <>
    <div className="page-heading"><div><p className="eyebrow">{editingId ? 'Editar solicitud' : 'Nueva solicitud'}</p><h1>{editingId ? 'Actualizar solicitud de ingreso' : 'Registrar solicitud de ingreso'}</h1><p>Completa los datos e indica quién registrará a las personas que ingresarán.</p></div></div>
    <Progress step={step} onStepChange={onStepChange} />
    <div className="panel form-panel">
      {step === 1 && <StepOne form={form} options={options} loading={loading} change={onChange} />}
      {step === 2 && <StepTwo form={form} options={options} selectedType={selected.tipo} loading={loading} change={onChange} />}
      {step === 3 && <PeopleStep mode={peopleEntryMode} provider={selected.proveedor} estimatedCount={form.cantidadEstimada} people={people} selectedPeople={requestPeople} existingPeople={existingPeople} areas={options?.areas ?? []} onModeChange={onPeopleEntryModeChange} onChange={onPeopleChange} />}
      {step === 4 && <Review form={form} selected={selected} people={people} selectedPeople={requestPeople} existingPeople={existingPeople} peopleEntryMode={peopleEntryMode} />}
      <div className="form-footer">
        <button type="button" className="ghost-button" onClick={onCancel}>Cancelar</button>
        <div className="action-row">
          {step > 1 && <button type="button" className="secondary-button" onClick={onBack}><Icon name="back" />Atrás</button>}
          {step < 4
            ? <button type="button" className="primary-button" onClick={onNext}>Siguiente <Icon name="arrow" /></button>
            : <>
              <button type="button" className="primary-button teal" disabled={saving} onClick={() => onSubmit(false)}>{saving ? 'Guardando…' : editingId ? 'Guardar cambios' : 'Crear solicitud'}</button>
              {editingId && selected.estado?.codigo === 'BORRADOR' && <button type="button" className="primary-button" disabled={saving || !canSend} onClick={() => onSubmit(true)}><Icon name="send" />Enviar solicitud</button>}
            </>}
        </div>
      </div>
    </div>
  </>
}

function StepOne({ form, options, loading, change }) {
  return <><SectionHeading title="Información general" text="Define el tipo, las fechas y el propósito del ingreso." /><div className="form-grid"><Field label="Tipo de ingreso" required><Select name="idTipoIngreso" value={form.idTipoIngreso} onChange={change} items={options?.tiposIngreso} loading={loading} /></Field><Field label="Empresa / proveedor"><Select name="idProveedor" value={form.idProveedor} onChange={change} items={options?.proveedores} loading={loading} emptyLabel="Sin proveedor" /></Field><Field label="Fecha de inicio" required><input type="date" name="fechaInicio" value={form.fechaInicio} onChange={change} /></Field><Field label="Fecha de finalización" required><input type="date" name="fechaFin" min={form.fechaInicio} value={form.fechaFin} onChange={change} /></Field><Field label="Nombre de la actividad" required full><input name="nombreActividad" maxLength="200" value={form.nombreActividad} onChange={change} placeholder="Ej. Mantenimiento preventivo de infraestructura" /></Field><Field label="Descripción general" full><textarea name="descripcionActividad" maxLength="1000" value={form.descripcionActividad} onChange={change} placeholder="Describe el propósito del ingreso" /></Field><Field label="Contrato, cuando aplique"><input name="numeroContrato" maxLength="60" value={form.numeroContrato} onChange={change} placeholder="Ej. CT-2026-084" /></Field><Field label="Cantidad estimada de personas" required><input type="number" name="cantidadEstimada" min="1" step="1" value={form.cantidadEstimada} onChange={change} /></Field></div></>
}

function StepTwo({ form, options, selectedType, loading, change }) {
  const isEmployee = selectedType?.codigo?.toUpperCase() === 'EMPLEADO' || selectedType?.nombre?.trim().toLocaleLowerCase('es') === 'empleado'
  const contactLabel = isEmployee ? 'Contacto del empleado' : 'Contacto del proveedor'
  const emailLabel = isEmployee ? 'Correo del empleado' : 'Correo del proveedor'
  return <><SectionHeading title="Contacto y ubicación" text="Indica quién coordina el ingreso y dónde se realizará." /><div className="form-grid"><Field label={contactLabel} required><input name="contactoProveedor" maxLength="200" value={form.contactoProveedor} onChange={change} placeholder={isEmployee ? 'Nombre del empleado' : 'Nombre del contacto'} /></Field><Field label={emailLabel} required><input type="email" name="correoProveedor" maxLength="254" value={form.correoProveedor} onChange={change} placeholder={isEmployee ? 'empleado@empresa.com' : 'contacto@empresa.com'} /></Field><Field label="Área solicitante" required><Select name="idAreaSolicitante" value={form.idAreaSolicitante} onChange={change} items={options?.areas} loading={loading} /></Field><Field label="Ubicación / instalación" required><Select name="idUbicacion" value={form.idUbicacion} onChange={change} items={options?.ubicaciones} loading={loading} /></Field><Field label="Usuario solicitante" required full><Select name="idUsuarioSolicitante" value={form.idUsuarioSolicitante} onChange={change} items={options?.usuarios} loading={loading} disabled /><small className="field-help">Se asigna automáticamente desde la sesión iniciada.</small></Field><Field label="Observaciones" full><textarea name="observaciones" maxLength="1000" value={form.observaciones} onChange={change} placeholder="Indicaciones para el ingreso" /></Field></div></>
}

function PeopleStep({ mode, provider, estimatedCount, people, selectedPeople, existingPeople, areas, onModeChange, onChange }) {
  const [personId, setPersonId] = useState('')
  const selectedIds = new Set([...selectedPeople.map((item) => Number(item.idPersona)), ...existingPeople.map((item) => Number(item.idPersona))])
  const available = people.filter((person) => !selectedIds.has(Number(person.idPersona)))
  const maximum = Number(estimatedCount) || 0
  const total = selectedPeople.length + existingPeople.length
  const limitReached = maximum > 0 && total >= maximum

  function addPerson() {
    const idPersona = Number(personId)
    if (!idPersona || limitReached) return
    onChange([...selectedPeople, { idPersona, areas: [] }])
    setPersonId('')
  }

  function toggleArea(idPersona, idArea) {
    onChange(selectedPeople.map((person) => person.idPersona !== idPersona ? person : {
      ...person,
      areas: person.areas.includes(idArea) ? person.areas.filter((id) => id !== idArea) : [...person.areas, idArea],
    }))
  }

  return <>
    <SectionHeading title="Registro de personas" text="Indica si registrarás las personas ahora o si el proveedor se encargará de ingresarlas." />
    <div className="people-entry-options" role="radiogroup" aria-label="Responsable del registro de personas">
      <button type="button" role="radio" aria-checked={mode === 'manual'} className={`people-entry-option ${mode === 'manual' ? 'active' : ''}`} onClick={() => onModeChange('manual')}>
        <span className="people-entry-radio" aria-hidden="true" />
        <span><strong>Las ingreso manualmente</strong><small>Seleccionaré cada persona y las áreas a las que tendrá acceso.</small></span>
      </button>
      <button type="button" role="radio" aria-checked={mode === 'provider'} className={`people-entry-option ${mode === 'provider' ? 'active' : ''}`} onClick={() => onModeChange('provider')}>
        <span className="people-entry-radio" aria-hidden="true" />
        <span><strong>Las ingresa el proveedor</strong><small>El proveedor seleccionado registrará las personas posteriormente.</small></span>
      </button>
    </div>

    {mode === 'provider' && <div className={`provider-entry-note ${provider ? '' : 'warning'}`}><Icon name="users" /><div><strong>{provider ? `${provider.nombre} ingresará las personas` : 'Selecciona primero un proveedor'}</strong><p>{provider ? 'Puedes continuar al siguiente paso. No es necesario agregar personas manualmente.' : 'Regresa a Información básica y selecciona la empresa o proveedor responsable.'}</p></div></div>}

    {mode === 'manual' && <>
      <div className={`request-people-count ${total === maximum ? 'complete' : 'incomplete'}`}><strong>{total} de {maximum} personas agregadas</strong><span>{limitReached ? 'Alcanzaste la cantidad máxima indicada.' : `Puedes agregar ${Math.max(maximum - total, 0)} persona(s) más.`}</span></div>
      <div className="request-person-picker">
        <div className="field"><label>Persona registrada</label><select value={personId} onChange={(event) => setPersonId(event.target.value)}><option value="">Selecciona una persona</option>{available.map((person) => <option key={person.idPersona} value={person.idPersona}>{person.nombreCompleto || 'Sin nombre'} · {person.numeroDocumento || 'Sin documento'}</option>)}</select></div>
        <button type="button" className="primary-button" disabled={!personId || limitReached} onClick={addPerson}><Icon name="users" />Agregar persona</button>
      </div>

      {existingPeople.length > 0 && <section className="existing-request-people"><h3>Personas ya asociadas</h3><div>{existingPeople.map((person) => <span key={person.idPersona}>{person.nombreCompleto || person.numeroDocumento || `Persona #${person.idPersona}`}</span>)}</div></section>}

      <div className="request-people-list">
        {selectedPeople.length === 0 && <div className="request-people-empty"><Icon name="users" /><strong>No has agregado personas nuevas</strong><span>Puedes continuar sin personas y agregarlas después al editar la solicitud.</span></div>}
        {selectedPeople.map((entry) => {
          const person = people.find((item) => Number(item.idPersona) === Number(entry.idPersona))
          return <article className="request-person-card" key={entry.idPersona}>
            <div className="request-person-head"><div><strong>{person?.nombreCompleto || `Persona #${entry.idPersona}`}</strong><span>{person?.numeroDocumento || person?.empresa || 'Sin información adicional'}</span></div><button type="button" className="remove-person-button" onClick={() => onChange(selectedPeople.filter((item) => item.idPersona !== entry.idPersona))}>Quitar</button></div>
            <div className="request-area-options"><p>Áreas autorizadas <span className="required">*</span></p>{areas.map((area) => <label key={area.id}><input type="checkbox" checked={entry.areas.includes(Number(area.id))} onChange={() => toggleArea(entry.idPersona, Number(area.id))} /><span>{area.nombre ?? area.codigo}</span></label>)}</div>
            {entry.areas.length === 0 && <small className="request-person-warning">Selecciona al menos un área.</small>}
            {entry.error && <small className="request-person-error">{entry.error}</small>}
          </article>
        })}
      </div>
    </>}
  </>
}

function Review({ form, selected, people, selectedPeople, existingPeople, peopleEntryMode }) {
  const totalPeople = selectedPeople.length + existingPeople.length
  const providerWillRegister = peopleEntryMode === 'provider'
  const isEmployee = selected.tipo?.codigo?.toUpperCase() === 'EMPLEADO' || selected.tipo?.nombre?.trim().toLocaleLowerCase('es') === 'empleado'
  const rows = [['Tipo de ingreso', selected.tipo?.nombre], ['Empresa', selected.proveedor?.nombre ?? 'Sin proveedor'], ['Actividad', form.nombreActividad], ['Periodo', `${formatDate(form.fechaInicio)} – ${formatDate(form.fechaFin)}`], [isEmployee ? 'Contacto del empleado' : 'Contacto del proveedor', form.contactoProveedor], [isEmployee ? 'Correo del empleado' : 'Correo del proveedor', form.correoProveedor], ['Área solicitante', selected.area?.nombre], ['Ubicación', selected.ubicacion?.nombre], ['Registro de personas', providerWillRegister ? 'A cargo del proveedor' : 'Ingreso manual'], ['Personas asociadas', providerWillRegister ? 'Pendientes de registro' : `${totalPeople} de ${form.cantidadEstimada}`]]
  return <><SectionHeading title="Revisa antes de guardar" text="Confirma los datos y quién será responsable de registrar las personas." /><div className="info-list">{rows.map(([label, value]) => <div className="info-item" key={label}><span>{label}</span><strong>{value || '—'}</strong></div>)}</div>{selectedPeople.length > 0 && <div className="review-people"><h3>Personas nuevas</h3>{selectedPeople.map((entry) => { const person = people.find((item) => Number(item.idPersona) === Number(entry.idPersona)); return <span key={entry.idPersona}>{person?.nombreCompleto || `Persona #${entry.idPersona}`} · {entry.areas.length} área(s)</span> })}</div>}<div className="ticket-box"><div><h3>La solicitud se guardará como borrador</h3><p>Podrás enviarla inmediatamente después de crearla o conservarla para completar y enviar más tarde.</p></div></div></>
}

function Progress({ step, onStepChange }) {
  return <div className="progress-shell request-progress">{['Información básica', 'Contacto y ubicación', 'Personas y áreas', 'Revisión y guardado'].map((label, index) => { const number = index + 1; const state = step === number ? 'active' : step > number ? 'done' : ''; return <button type="button" className={`step ${state}`} key={label} onClick={() => onStepChange(number)} aria-current={step === number ? 'step' : undefined}><span className="step-number">{step > number ? '✓' : number}</span><span>{label}</span></button> })}</div>
}

function SectionHeading({ title, text }) { return <div className="section-heading"><h2>{title}</h2><p>{text}</p></div> }
function Field({ label, required, full, children }) { return <div className={`field ${full ? 'full' : ''}`}><label>{label} {required && <span className="required">*</span>}</label>{children}</div> }
function Select({ items = [], loading, emptyLabel = 'Selecciona una opción', ...props }) { return <select {...props}><option value="">{loading ? 'Cargando…' : emptyLabel}</option>{items?.map((item) => <option key={item.id} value={item.id}>{item.nombre ?? item.codigo}</option>)}</select> }
