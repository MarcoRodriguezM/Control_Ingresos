import { useEffect, useState } from 'react'
import { Icon } from '../components/Icon'
import { accessStatusClass, formatDate } from '../utils/formatters'

export function RequestFormPage({ form, options, people, employees = [], employeesLoading = false, employeesError = '', requestPeople, existingPeople, peopleEntryMode, loading, saving, editingId, step, selected, canSend, onPeopleEntryModeChange, onPeopleChange, onChange, onStepChange, onNext, onBack, onCancel, onSubmit }) {
  const typeCode = normalizeTypeCode(selected.tipo)
  return <>
    <div className="page-heading"><div><p className="eyebrow">{editingId ? 'Editar solicitud' : 'Nueva solicitud'}</p><h1>{editingId ? 'Actualizar solicitud de ingreso' : 'Registrar solicitud de ingreso'}</h1><p>Completa los datos e indica quién registrará a las personas que ingresarán.</p></div></div>
    <Progress step={step} onStepChange={onStepChange} />
    <div className="panel form-panel">
      {step === 1 && <StepOne form={form} options={options} selectedType={selected.tipo} loading={loading} change={onChange} />}
      {step === 2 && <StepTwo form={form} options={options} selectedType={selected.tipo} loading={loading} change={onChange} />}
      {step === 3 && <PeopleStep typeCode={typeCode} mode={peopleEntryMode} provider={selected.proveedor} estimatedCount={form.cantidadEstimada} people={people} employees={employees} employeesLoading={employeesLoading} employeesError={employeesError} selectedPeople={requestPeople} existingPeople={existingPeople} areas={options?.areas ?? []} onModeChange={onPeopleEntryModeChange} onChange={onPeopleChange} />}
      {step === 4 && <Review form={form} selected={selected} people={people} employees={employees} selectedPeople={requestPeople} existingPeople={existingPeople} peopleEntryMode={peopleEntryMode} />}
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

function StepOne({ form, options, selectedType, loading, change }) {
  const providerDisabled = isEmployeeFlow(normalizeTypeCode(selectedType))
  function changeEstimatedPeople(event) {
    const value = event.target.value
    if (value === '' || (Number.isInteger(Number(value)) && Number(value) >= 1)) change(event)
  }

  function normalizeEstimatedPeople(event) {
    if (!Number.isInteger(Number(event.target.value)) || Number(event.target.value) < 1) {
      change({ target: { name: 'cantidadEstimada', value: '1' } })
    }
  }

  return <><SectionHeading title="Información general" text="Define el tipo, las fechas y el propósito del ingreso." /><div className="form-grid"><Field label="Tipo de ingreso" required><Select name="idTipoIngreso" value={form.idTipoIngreso} onChange={change} items={options?.tiposIngreso} loading={loading} /></Field><Field label="Empresa / proveedor"><Select name="idProveedor" value={form.idProveedor} onChange={change} items={options?.proveedores} loading={loading} emptyLabel={providerDisabled ? 'No aplica para este tipo de ingreso' : 'Sin proveedor'} disabled={providerDisabled} /><small className="field-help">{providerDisabled ? 'Los tipos de empleado no se vinculan con un proveedor.' : 'Selecciona el proveedor cuando corresponda.'}</small></Field><Field label="Fecha de inicio" required><input type="date" name="fechaInicio" value={form.fechaInicio} onChange={change} /></Field><Field label="Fecha de finalización" required><input type="date" name="fechaFin" min={form.fechaInicio} value={form.fechaFin} onChange={change} /></Field><Field label="Nombre de la actividad" required full><input name="nombreActividad" maxLength="200" value={form.nombreActividad} onChange={change} placeholder="Ej. Mantenimiento preventivo de infraestructura" /></Field><Field label="Descripción general" full><textarea name="descripcionActividad" maxLength="1000" value={form.descripcionActividad} onChange={change} placeholder="Describe el propósito del ingreso" /></Field><Field label="Contrato, cuando aplique"><input name="numeroContrato" maxLength="60" value={form.numeroContrato} onChange={change} placeholder="Ej. CT-2026-084" /></Field><Field label="Cantidad estimada de personas" required><input type="number" name="cantidadEstimada" min="1" step="1" value={form.cantidadEstimada} onChange={changeEstimatedPeople} onBlur={normalizeEstimatedPeople} required /><small className="field-help">Mínimo una persona.</small></Field></div></>
}

function StepTwo({ form, options, selectedType, loading, change }) {
  const typeCode = normalizeTypeCode(selectedType)
  const isEmployee = typeCode === 'EMPLEADO'
  const isNewEmployee = typeCode === 'NUEVO_EMPLEADO'
  const contactLabel = isNewEmployee ? 'Nombre del nuevo empleado' : 'Contacto del proveedor'
  const emailLabel = isNewEmployee ? 'Correo del nuevo empleado' : 'Correo del proveedor'
  return <><SectionHeading title="Contacto y ubicación" text={isEmployee ? 'Indica el área, la ubicación y el usuario responsable de la solicitud.' : 'Indica quién coordina el ingreso y dónde se realizará.'} /><div className="form-grid">{!isEmployee && <><Field label={contactLabel} required><input name="contactoProveedor" maxLength="200" value={form.contactoProveedor} onChange={change} placeholder={isNewEmployee ? 'Nombre completo del nuevo empleado' : 'Nombre del contacto'} /></Field><Field label={emailLabel} required><input type="email" name="correoProveedor" maxLength="254" value={form.correoProveedor} onChange={change} placeholder={isNewEmployee ? 'nuevo.empleado@empresa.com' : 'contacto@empresa.com'} /></Field></>}<Field label="Área solicitante" required><Select name="idAreaSolicitante" value={form.idAreaSolicitante} onChange={change} items={options?.areas} loading={loading} /></Field><Field label="Ubicación / instalación" required><Select name="idUbicacion" value={form.idUbicacion} onChange={change} items={options?.ubicaciones} loading={loading} /></Field><Field label="Usuario solicitante" required full><Select name="idUsuarioSolicitante" value={form.idUsuarioSolicitante} onChange={change} items={options?.usuarios} loading={loading} disabled /><small className="field-help">Se asigna automáticamente desde la sesión iniciada.</small></Field><Field label="Observaciones" full><textarea name="observaciones" maxLength="1000" value={form.observaciones} onChange={change} placeholder="Indicaciones para el ingreso" /></Field></div></>
}

function PeopleStep({ typeCode, mode, provider, estimatedCount, people, employees, employeesLoading, employeesError, selectedPeople, existingPeople, areas, onModeChange, onChange }) {
  const [selectedValue, setSelectedValue] = useState('')
  const usesHtis = typeCode === 'EMPLEADO'
  const isNewEmployee = typeCode === 'NUEVO_EMPLEADO'
  const effectiveMode = usesHtis ? 'employee' : isNewEmployee ? 'manual' : mode
  const sourceItems = usesHtis ? employees : people
  const selectedKeys = new Set([...selectedPeople, ...existingPeople].map((item) => requestEntryKey(item, usesHtis)))
  const available = sourceItems.filter((item) => !selectedKeys.has(sourceItemKey(item, usesHtis)))
  const maximum = Number(estimatedCount) || 0
  const total = selectedPeople.length + existingPeople.length
  const limitReached = maximum > 0 && total >= maximum

  useEffect(() => setSelectedValue(''), [usesHtis])

  function addEntry() {
    if (!selectedValue || limitReached) return
    onChange([...selectedPeople, usesHtis
      ? { idPersona: null, codigoEmpleadoHtis: selectedValue, areas: [] }
      : { idPersona: Number(selectedValue), codigoEmpleadoHtis: null, areas: [] }])
    setSelectedValue('')
  }

  function toggleArea(entryKey, idArea) {
    onChange(selectedPeople.map((entry) => requestEntryKey(entry, usesHtis) !== entryKey ? entry : {
      ...entry,
      areas: entry.areas.includes(idArea) ? entry.areas.filter((id) => id !== idArea) : [...entry.areas, idArea],
    }))
  }

  return <>
    <SectionHeading title={usesHtis ? 'Selección de empleados' : 'Registro de personas'} text={usesHtis ? 'Selecciona empleados activos de HTIS y las áreas para las que se solicita acceso.' : isNewEmployee ? 'Selecciona la persona registrada que se convertirá en nuevo empleado.' : 'Indica si registrarás las personas ahora o si el proveedor se encargará de ingresarlas.'} />
    {!usesHtis && !isNewEmployee && <div className="people-entry-options" role="radiogroup" aria-label="Responsable del registro de personas">
      <button type="button" role="radio" aria-checked={mode === 'manual'} className={`people-entry-option ${mode === 'manual' ? 'active' : ''}`} onClick={() => onModeChange('manual')}>
        <span className="people-entry-radio" aria-hidden="true" />
        <span><strong>Las ingreso manualmente</strong><small>Seleccionaré cada persona y las áreas a las que tendrá acceso.</small></span>
      </button>
      <button type="button" role="radio" aria-checked={mode === 'provider'} className={`people-entry-option ${mode === 'provider' ? 'active' : ''}`} onClick={() => onModeChange('provider')}>
        <span className="people-entry-radio" aria-hidden="true" />
        <span><strong>Las ingresa el proveedor</strong><small>El proveedor seleccionado registrará las personas posteriormente.</small></span>
      </button>
    </div>}

    {effectiveMode === 'provider' && <div className={`provider-entry-note ${provider ? '' : 'warning'}`}><Icon name="users" /><div><strong>{provider ? `${provider.nombre} ingresará las personas` : 'Selecciona primero un proveedor'}</strong><p>{provider ? 'Puedes continuar al siguiente paso. No es necesario agregar personas manualmente.' : 'Regresa a Información básica y selecciona la empresa o proveedor responsable.'}</p></div></div>}

    {effectiveMode !== 'provider' && <>
      <div className={`request-people-count ${total === maximum ? 'complete' : 'incomplete'}`}><strong>{total} de {maximum} personas agregadas</strong><span>{limitReached ? 'Alcanzaste la cantidad máxima indicada.' : `Puedes agregar ${Math.max(maximum - total, 0)} persona(s) más.`}</span></div>
      {usesHtis && employeesError && <div className="provider-entry-note warning htis-unavailable-note"><Icon name="users" /><div><strong>No fue posible consultar HTIS</strong><p>{employeesError} Puedes conservar el borrador e intentar nuevamente después.</p></div></div>}
      <div className="request-person-picker">
        <div className="field"><label>{usesHtis ? 'Empleado activo en HTIS' : 'Persona registrada'}</label><select value={selectedValue} onChange={(event) => setSelectedValue(event.target.value)} disabled={usesHtis && (employeesLoading || Boolean(employeesError))}><option value="">{usesHtis && employeesLoading ? 'Consultando empleados…' : usesHtis ? 'Selecciona un empleado' : 'Selecciona una persona'}</option>{available.map((item) => <option key={sourceItemKey(item, usesHtis)} value={usesHtis ? item.codigoEmpleado : item.idPersona}>{usesHtis ? `${item.nombreCompleto || 'Sin nombre'} · ${item.codigoEmpleado || 'Sin código'}` : `${item.nombreCompleto || 'Sin nombre'} · ${item.numeroDocumento || 'Sin documento'}`}</option>)}</select></div>
        <button type="button" className="primary-button" disabled={!selectedValue || limitReached || (usesHtis && employeesLoading)} onClick={addEntry}><Icon name="users" />{usesHtis ? 'Agregar empleado' : 'Agregar persona'}</button>
      </div>

      {existingPeople.length > 0 && <section className="existing-request-people"><h3>{usesHtis ? 'Empleados ya asociados' : 'Personas ya asociadas'}</h3><div>{existingPeople.map((person) => <article className={`existing-person-status ${person.codigoEstadoAprobacion?.toLowerCase() ?? 'pendiente'}`} key={person.idSolicitudPersona ?? requestEntryKey(person, usesHtis)}><div><strong>{person.nombreCompleto || person.codigoEmpleadoHtis || person.numeroDocumento || `Persona #${person.idPersona}`}</strong><span>{person.codigoEmpleadoHtis || person.numeroDocumento || 'Sin documento'}</span></div><span className={`access-status ${accessStatusClass(person.codigoEstadoAprobacion)}`}>{person.estadoAprobacion || 'Pendiente'}</span><small>{person.areasAprobadas ?? 0} aprobada(s) · {person.areasPendientes ?? 0} pendiente(s) · {person.areasRechazadas ?? 0} rechazada(s)</small>{person.detalleRechazos && <p><strong>Motivo del rechazo:</strong> {person.detalleRechazos}</p>}</article>)}</div></section>}

      <div className="request-people-list">
        {selectedPeople.length === 0 && <div className="request-people-empty"><Icon name="users" /><strong>{usesHtis ? 'No has agregado empleados' : 'No has agregado personas nuevas'}</strong><span>Puedes continuar sin integrantes y agregarlos después al editar la solicitud.</span></div>}
        {selectedPeople.map((entry) => {
          const key = requestEntryKey(entry, usesHtis)
          const source = sourceItems.find((item) => sourceItemKey(item, usesHtis) === key)
          return <article className="request-person-card" key={key}>
            <div className="request-person-head"><div><strong>{source?.nombreCompleto || entry.codigoEmpleadoHtis || `Persona #${entry.idPersona}`}</strong><span>{usesHtis ? source?.codigoEmpleado || entry.codigoEmpleadoHtis : source?.numeroDocumento || source?.empresa || 'Sin información adicional'}</span></div><button type="button" className="remove-person-button" onClick={() => onChange(selectedPeople.filter((item) => requestEntryKey(item, usesHtis) !== key))}>Quitar</button></div>
            <div className="request-area-options"><p>Áreas autorizadas <span className="required">*</span></p>{areas.map((area) => <label key={area.id}><input type="checkbox" checked={entry.areas.includes(Number(area.id))} onChange={() => toggleArea(key, Number(area.id))} /><span>{area.nombre ?? area.codigo}</span></label>)}</div>
            {entry.areas.length === 0 && <small className="request-person-warning">Selecciona al menos un área.</small>}
            {entry.error && <small className="request-person-error">{entry.error}</small>}
          </article>
        })}
      </div>
    </>}
  </>
}

function Review({ form, selected, people, employees, selectedPeople, existingPeople, peopleEntryMode }) {
  const totalPeople = selectedPeople.length + existingPeople.length
  const providerWillRegister = peopleEntryMode === 'provider'
  const typeCode = normalizeTypeCode(selected.tipo)
  const usesHtis = typeCode === 'EMPLEADO'
  const isNewEmployee = typeCode === 'NUEVO_EMPLEADO'
  const rows = [['Tipo de ingreso', selected.tipo?.nombre], ['Empresa', isEmployeeFlow(typeCode) ? 'No aplica' : selected.proveedor?.nombre ?? 'Sin proveedor'], ['Actividad', form.nombreActividad], ['Período', `${formatDate(form.fechaInicio)} – ${formatDate(form.fechaFin)}`], ...(!usesHtis ? [[isNewEmployee ? 'Nombre del nuevo empleado' : 'Contacto del proveedor', form.contactoProveedor], [isNewEmployee ? 'Correo del nuevo empleado' : 'Correo del proveedor', form.correoProveedor]] : []), ['Área solicitante', selected.area?.nombre], ['Ubicación', selected.ubicacion?.nombre], ['Registro de personas', usesHtis ? 'Empleados activos de HTIS' : providerWillRegister ? 'A cargo del proveedor' : 'Ingreso manual'], ['Personas asociadas', providerWillRegister ? 'Pendientes de registro' : `${totalPeople} de ${form.cantidadEstimada}`]]
  const sourceItems = usesHtis ? employees : people
  return <><SectionHeading title="Revisa antes de guardar" text="Confirma los datos y quién será responsable de registrar las personas." /><div className="info-list">{rows.map(([label, value]) => <div className="info-item" key={label}><span>{label}</span><strong>{value || '—'}</strong></div>)}</div>{selectedPeople.length > 0 && <div className="review-people"><h3>{usesHtis ? 'Empleados nuevos en la solicitud' : 'Personas nuevas'}</h3>{selectedPeople.map((entry) => { const key = requestEntryKey(entry, usesHtis); const item = sourceItems.find((candidate) => sourceItemKey(candidate, usesHtis) === key); return <span key={key}>{item?.nombreCompleto || entry.codigoEmpleadoHtis || `Persona #${entry.idPersona}`} · {entry.areas.length} área(s)</span> })}</div>}{existingPeople.length > 0 && <div className="review-people"><h3>Estado de integrantes asociados</h3>{existingPeople.map((person) => <span className={`review-person-state ${person.codigoEstadoAprobacion?.toLowerCase() ?? 'pendiente'}`} key={person.idSolicitudPersona ?? requestEntryKey(person, usesHtis)}>{person.nombreCompleto || person.codigoEmpleadoHtis || `Persona #${person.idPersona}`} · {person.estadoAprobacion || 'Pendiente'}</span>)}</div>}<div className="ticket-box"><div><h3>{editingIdMessage(existingPeople)}</h3><p>Los accesos rechazados permanecerán visibles, pero no estarán autorizados para ingresar.</p></div></div></>
}

function normalizeTypeCode(type) {
  return type?.codigo?.trim().toUpperCase() ?? ''
}

function isEmployeeFlow(typeCode) {
  return typeCode === 'EMPLEADO' || typeCode === 'NUEVO_EMPLEADO'
}

function requestEntryKey(entry, usesHtis) {
  return usesHtis
    ? String(entry.codigoEmpleadoHtis ?? '').trim().toLocaleLowerCase('es')
    : String(entry.idPersona ?? '')
}

function sourceItemKey(item, usesHtis) {
  return usesHtis
    ? String(item.codigoEmpleado ?? '').trim().toLocaleLowerCase('es')
    : String(item.idPersona ?? '')
}

function editingIdMessage(existingPeople) {
  return existingPeople.some((person) => person.codigoEstadoAprobacion === 'RECHAZADA')
    ? 'La solicitud contiene personas rechazadas'
    : 'La solicitud se guardará como borrador'
}

function Progress({ step, onStepChange }) {
  return <div className="progress-shell request-progress">{['Información básica', 'Contacto y ubicación', 'Personas y áreas', 'Revisión y guardado'].map((label, index) => { const number = index + 1; const state = step === number ? 'active' : step > number ? 'done' : ''; return <button type="button" className={`step ${state}`} key={label} onClick={() => onStepChange(number)} aria-current={step === number ? 'step' : undefined}><span className="step-number">{step > number ? '✓' : number}</span><span>{label}</span></button> })}</div>
}

function SectionHeading({ title, text }) { return <div className="section-heading"><h2>{title}</h2><p>{text}</p></div> }
function Field({ label, required, full, children }) { return <div className={`field ${full ? 'full' : ''}`}><label>{label} {required && <span className="required">*</span>}</label>{children}</div> }
function Select({ items = [], loading, emptyLabel = 'Selecciona una opción', ...props }) { return <select {...props}><option value="">{loading ? 'Cargando…' : emptyLabel}</option>{items?.map((item) => <option key={item.id} value={item.id}>{item.nombre ?? item.codigo}</option>)}</select> }
