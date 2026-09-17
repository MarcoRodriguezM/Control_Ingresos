import { useEffect, useMemo, useState } from 'react'
import { controlIngresosApi } from './services/api'
import './App.css'

const today = () => new Date().toLocaleDateString('en-CA')
const initialForm = () => ({
  idTipoIngreso: '', idEstadoSolicitud: '', idProveedor: '', fechaInicio: today(), fechaFin: today(),
  nombreActividad: '', descripcionActividad: '', numeroContrato: '', cantidadEstimada: '1',
  contactoProveedor: '', correoProveedor: '', idAreaSolicitante: '', idUbicacion: '',
  idUsuarioSolicitante: '', observaciones: '',
})

function App() {
  const [page, setPage] = useState('list')
  const [step, setStep] = useState(1)
  const [editingId, setEditingId] = useState(null)
  const [form, setForm] = useState(initialForm)
  const [options, setOptions] = useState(null)
  const [solicitudes, setSolicitudes] = useState([])
  const [personas, setPersonas] = useState([])
  const [personaSeleccionada, setPersonaSeleccionada] = useState(null)
  const [personLoading, setPersonLoading] = useState(false)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(null)

  useEffect(() => {
    let active = true
    Promise.all([controlIngresosApi.obtenerDatosFormularioSolicitud(), controlIngresosApi.listarSolicitudes()])
      .then(([data, records]) => {
        if (!active) return
        setOptions(data)
        setSolicitudes(records)
        setForm((current) => withDefaults(current, data))
      })
      .catch((requestError) => active && setError(requestError.message))
      .finally(() => active && setLoading(false))
    return () => { active = false }
  }, [])

  const selected = useMemo(() => ({
    tipo: findOption(options?.tiposIngreso, form.idTipoIngreso),
    proveedor: findOption(options?.proveedores, form.idProveedor),
    area: findOption(options?.areas, form.idAreaSolicitante),
    ubicacion: findOption(options?.ubicaciones, form.idUbicacion),
    usuario: findOption(options?.usuarios, form.idUsuarioSolicitante),
  }), [form, options])

  function change(event) {
    const { name, value } = event.target
    setForm((current) => ({ ...current, [name]: value }))
    setError('')
  }

  function next() {
    goToStep(Math.min(3, step + 1))
  }

  function goToStep(targetStep) {
    for (let currentStep = 1; currentStep < targetStep; currentStep += 1) {
      const validation = validateStep(currentStep, form)
      if (validation) {
        setStep(currentStep)
        setError(validation)
        return
      }
    }
    setError('')
    setStep(targetStep)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  function openNew() {
    setEditingId(null)
    setForm(withDefaults(initialForm(), options))
    setStep(1)
    setError('')
    setSuccess(null)
    setPage('form')
  }

  async function openEdit(id) {
    setLoading(true)
    setError('')
    try {
      const item = await controlIngresosApi.obtenerSolicitud(id)
      setEditingId(id)
      setForm(formFromDetail(item, options))
      setStep(1)
      setPage('form')
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setLoading(false)
    }
  }

  async function remove(id, number) {
    if (!window.confirm(`¿Deseas eliminar la solicitud ${number ?? `#${id}`}?`)) return
    setError('')
    try {
      const user = form.idUsuarioSolicitante || options?.usuarios[0]?.id
      await controlIngresosApi.eliminarSolicitud(id, user)
      setSolicitudes(await controlIngresosApi.listarSolicitudes())
      setSuccess({ message: `La solicitud ${number ?? `#${id}`} fue eliminada.` })
    } catch (requestError) {
      setError(requestError.message)
    }
  }

  async function openPersons() {
    setPage('persons')
    setMenuOpen(false)
    setError('')
    setSuccess(null)
    setPersonLoading(true)
    try {
      const records = await controlIngresosApi.listarPersonas()
      setPersonas(records)
      const preferred = records.find((item) => item.nombreCompleto?.toLowerCase().includes('david')) ?? records[0]
      setPersonaSeleccionada(preferred ? await controlIngresosApi.obtenerPersonaAccesos(preferred.idPersona) : null)
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setPersonLoading(false)
    }
  }

  async function selectPerson(idPersona) {
    setPersonLoading(true)
    setError('')
    try {
      setPersonaSeleccionada(await controlIngresosApi.obtenerPersonaAccesos(idPersona))
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setPersonLoading(false)
    }
  }

  async function submit() {
    if (step !== 3) return
    const validation = validateStep(2, form)
    if (validation) { setStep(2); setError(validation); return }
    setSaving(true)
    setError('')
    try {
      const sentStatus = options.estadosSolicitud.find((item) => item.codigo === 'ENVIADA')
      const payload = {
        idTipoIngreso: numberOrNull(form.idTipoIngreso),
        idEstadoSolicitud: editingId ? numberOrNull(form.idEstadoSolicitud) : sentStatus?.id ?? numberOrNull(form.idEstadoSolicitud),
        fechaInicio: form.fechaInicio,
        fechaFin: form.fechaFin,
        nombreActividad: form.nombreActividad.trim(),
        descripcionActividad: textOrNull(form.descripcionActividad),
        idProveedor: numberOrNull(form.idProveedor),
        numeroContrato: textOrNull(form.numeroContrato),
        contactoProveedor: textOrNull(form.contactoProveedor),
        correoProveedor: textOrNull(form.correoProveedor),
        cantidadEstimada: numberOrNull(form.cantidadEstimada),
        idAreaSolicitante: numberOrNull(form.idAreaSolicitante),
        idUsuarioSolicitante: form.idUsuarioSolicitante,
        idUbicacion: numberOrNull(form.idUbicacion),
        observaciones: textOrNull(form.observaciones),
        usuario: form.idUsuarioSolicitante,
      }
      const created = editingId
        ? await controlIngresosApi.actualizarSolicitud(editingId, payload)
        : await controlIngresosApi.crearSolicitud(payload)
      setSuccess(editingId ? { message: 'La solicitud fue actualizada correctamente.' } : created)
      setSolicitudes(await controlIngresosApi.listarSolicitudes())
      setForm(withDefaults(initialForm(), options))
      setEditingId(null)
      setStep(1)
      setPage('list')
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="app-shell">
      {menuOpen && <button className="sidebar-backdrop" onClick={() => setMenuOpen(false)} aria-label="Cerrar menú" />}
      <aside className={`sidebar ${menuOpen ? 'open' : ''}`} aria-label="Navegación principal">
        <div className="brand"><span className="brand-mark"><Icon name="logo" /></span><span>Entrada</span></div>
        <p className="side-label">Gestión de ingresos</p>
        <nav className="main-nav">
          <Nav icon="home" label="Dashboard" onClick={() => setMenuOpen(false)} />
          <Nav icon="file" label="Solicitudes" count={solicitudes.length} active={page === 'list' || page === 'form'} onClick={() => { setPage('list'); setMenuOpen(false); setError('') }} />
          <Nav icon="check" label="Mis aprobaciones" count="3" onClick={() => setMenuOpen(false)} />
          <Nav icon="tasks" label="Mis actividades" count="7" onClick={() => setMenuOpen(false)} />
          <Nav icon="users" label="Personas" count={personas.length || undefined} active={page === 'persons'} onClick={openPersons} />
          <Nav icon="settings" label="Configuración" onClick={() => setMenuOpen(false)} />
        </nav>
        <div className="sidebar-footer">
          <div className="prototype-note">Entorno conectado<br />Los cambios se guardan en SQL Server.</div>
          <button className="nav-item"><Icon name="logout" /><span>Cerrar sesión</span></button>
          <div className="sidebar-profile"><div className="avatar">UD</div><div><strong>{selected.usuario?.nombre ?? 'Usuario demo'}</strong><span>Área solicitante</span></div></div>
        </div>
      </aside>

      <main className="main">
        <header className="topbar">
          <button className="icon-button menu-button" onClick={() => setMenuOpen((open) => !open)} aria-label="Abrir menú"><Icon name="menu" /></button>
          <div className="breadcrumb"><span>Inicio</span><strong>{page === 'persons' ? 'Personas y accesos' : page === 'list' ? 'Solicitudes' : editingId ? 'Editar solicitud' : 'Nueva solicitud'}</strong></div>
          <div className="top-actions"><button className="ghost-button"><Icon name="help" />Ayuda</button><button className="icon-button" aria-label="Notificaciones"><Icon name="bell" /><span className="dot" /></button><div className="avatar">UD</div></div>
        </header>

        <section className="content">
          {error && <div className="alert error" role="alert"><strong>No se pudo continuar.</strong> {error}</div>}
          {success && <div className="alert success" role="status"><strong>Operación completada.</strong> {success.message ?? `Se creó ${success.numero ?? `la solicitud #${success.id}`}.`}</div>}

          {page === 'list'
            ? <RequestsList items={solicitudes} loading={loading} onNew={openNew} onEdit={openEdit} onDelete={remove} />
            : page === 'persons'
              ? <PersonAccessView items={personas} selected={personaSeleccionada} loading={personLoading} onSelect={selectPerson} />
              : <>
          <div className="page-heading"><div><p className="eyebrow">{editingId ? 'Editar solicitud' : 'Nueva solicitud'}</p><h1>{editingId ? 'Actualizar solicitud de ingreso' : 'Registrar solicitud de ingreso'}</h1><p>Completa los datos del ingreso en tres pasos.</p></div></div>
          <Progress step={step} onStepChange={goToStep} />
          <div className="panel form-panel">
            {step === 1 && <StepOne form={form} options={options} loading={loading} change={change} />}
            {step === 2 && <StepTwo form={form} options={options} loading={loading} change={change} />}
            {step === 3 && <Review form={form} selected={selected} />}

            <div className="form-footer">
              <button type="button" className="ghost-button" onClick={() => { setForm(withDefaults(initialForm(), options)); setStep(1); setEditingId(null); setError(''); setPage('list') }}>Cancelar</button>
              <div className="action-row">
                {step > 1 && <button type="button" className="secondary-button" onClick={() => setStep((current) => current - 1)}><Icon name="back" />Atrás</button>}
                {step < 3
                  ? <button type="button" className="primary-button" onClick={next}>Siguiente <Icon name="arrow" /></button>
                  : <button type="button" className="primary-button teal" disabled={saving} onClick={submit}><Icon name="send" />{saving ? 'Guardando…' : editingId ? 'Guardar cambios' : 'Enviar al proveedor'}</button>}
              </div>
            </div>
          </div></>}
        </section>
      </main>
    </div>
  )
}

function RequestsList({ items, loading, onNew, onEdit, onDelete }) {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('')
  const statuses = [...new Set(items.map((item) => item.estado).filter(Boolean))]
  const normalizedQuery = query.trim().toLowerCase()
  const filtered = items.filter((item) => {
    const matchesQuery = !normalizedQuery || [item.numeroSolicitud, item.nombreActividad, item.tipoIngreso, item.usuarioSolicitante]
      .some((value) => value?.toLowerCase().includes(normalizedQuery))
    return matchesQuery && (!status || item.estado === status)
  })

  return <>
    <div className="page-heading requests-heading">
      <div><p className="eyebrow">Gestión</p><h1>Listado Solicitudes</h1><p>Crea, consulta y da seguimiento a las solicitudes de ingreso.</p></div>
      <button type="button" className="primary-button" onClick={onNew}><span className="plus-sign">+</span>Nueva solicitud</button>
    </div>
    <div className="filters">
      <div className="search-box"><Icon name="search" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar por número, actividad o solicitante" /></div>
      <select className="filter-select" value={status} onChange={(event) => setStatus(event.target.value)}><option value="">Estado: Todos</option>{statuses.map((item) => <option key={item}>{item}</option>)}</select>
    </div>
    <article className="panel requests-panel">
      <div className="table-wrap"><table><thead><tr><th>Solicitud</th><th>Tipo</th><th>Inicio</th><th>Fin</th><th>Personas</th><th>Estado</th><th>Acciones</th></tr></thead>
        <tbody>
          {loading && <tr><td colSpan="7" className="empty-table">Cargando solicitudes…</td></tr>}
          {!loading && filtered.length === 0 && <tr><td colSpan="7" className="empty-table">No se encontraron solicitudes.</td></tr>}
          {filtered.map((item) => <tr key={item.idSolicitud}><td><strong>{item.numeroSolicitud}</strong><span className="cell-sub">{item.nombreActividad}</span></td><td>{item.tipoIngreso ?? '—'}</td><td>{formatDate(item.fechaInicio)}</td><td>{formatDate(item.fechaFin)}</td><td>{item.cantidadPersonas}</td><td><span className="status-badge">{item.estado ?? 'Sin estado'}</span></td><td><div className="row-actions"><button type="button" onClick={() => onEdit(item.idSolicitud)}>Editar</button><button type="button" className="delete-action" onClick={() => onDelete(item.idSolicitud, item.numeroSolicitud)}>Eliminar</button></div></td></tr>)}
        </tbody>
      </table></div>
    </article>
  </>
}

function PersonAccessView({ items, selected, loading, onSelect }) {
  const [query, setQuery] = useState('')
  const normalizedQuery = query.trim().toLowerCase()
  const filtered = items.filter((item) => !normalizedQuery || [item.nombreCompleto, item.numeroDocumento, item.empresa]
    .some((value) => value?.toLowerCase().includes(normalizedQuery)))

  return <>
    <div className="page-heading">
      <div><p className="eyebrow">Control de acceso</p><h1>Persona con sus accesos</h1><p>Consulta la información personal, solicitudes, áreas autorizadas y estado de aprobación.</p></div>
    </div>
    <div className="people-layout">
      <aside className="panel people-panel">
        <div className="people-search"><Icon name="search" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar persona" /></div>
        <div className="people-results">
          {loading && items.length === 0 && <p className="people-empty">Cargando personas…</p>}
          {!loading && filtered.length === 0 && <p className="people-empty">No se encontraron personas.</p>}
          {filtered.map((person) => <button type="button" className={`person-row ${selected?.idPersona === person.idPersona ? 'active' : ''}`} key={person.idPersona} onClick={() => onSelect(person.idPersona)}>
            <span className="person-avatar">{initials(person.nombreCompleto)}</span>
            <span className="person-row-copy"><strong>{person.nombreCompleto || 'Sin nombre'}</strong><small>{person.empresa || person.numeroDocumento || 'Sin empresa'}</small></span>
            <span className="access-count">{person.cantidadAccesos}</span>
          </button>)}
        </div>
      </aside>

      <section className="panel person-detail-panel">
        {loading && !selected && <div className="person-placeholder">Cargando información…</div>}
        {!loading && !selected && <div className="person-placeholder">Selecciona una persona para consultar sus accesos.</div>}
        {selected && <>
          <div className="person-profile">
            <div className="person-avatar large">{initials(selected.nombreCompleto)}</div>
            <div><div className="profile-title"><h2>{selected.nombreCompleto}</h2><span className="status-badge success">{selected.estado || 'Sin estado'}</span></div><p>{selected.cargoFuncion || 'Cargo no indicado'} · {selected.empresa || 'Empresa no indicada'}</p></div>
          </div>
          <div className="person-data-grid">
            <InfoValue label="Documento" value={selected.numeroDocumento} />
            <InfoValue label="Teléfono" value={selected.telefono} />
            <InfoValue label="Correo" value={selected.correo} />
            <InfoValue label="Total de accesos" value={String(selected.accesos?.length ?? 0)} />
          </div>
          <div className="access-heading"><div><h3>Accesos asignados</h3><p>Áreas vinculadas a las solicitudes de ingreso de esta persona.</p></div><span>{selected.accesos?.length ?? 0} accesos</span></div>
          <div className="access-list">
            {selected.accesos?.length === 0 && <div className="access-empty"><Icon name="shield" /><strong>Sin accesos asignados</strong><span>La persona todavía no está vinculada a un área.</span></div>}
            {selected.accesos?.map((access) => <article className="access-card" key={access.idSolicitudPersonaArea}>
              <div className="access-icon"><Icon name="shield" /></div>
              <div className="access-main"><div className="access-title"><h4>{access.area || 'Área sin nombre'}</h4><span className={`access-status ${accessStatusClass(access.estadoAcceso)}`}>{access.estadoAcceso || 'Pendiente'}</span></div><p>{access.actividad || 'Actividad no indicada'} · {access.numeroSolicitud || 'Sin número'}</p><div className="access-meta"><span><strong>Ubicación</strong>{access.ubicacion || '—'}</span><span><strong>Vigencia</strong>{formatDate(access.fechaInicio)} – {formatDate(access.fechaFin)}</span>{access.fechaDecision && <span><strong>Decisión</strong>{formatDateTime(access.fechaDecision)}</span>}</div>{access.comentarioDecision && <div className="access-comment">{access.comentarioDecision}</div>}</div>
            </article>)}
          </div>
        </>}
      </section>
    </div>
  </>
}

function InfoValue({ label, value }) { return <div className="info-value"><span>{label}</span><strong>{value || '—'}</strong></div> }

function StepOne({ form, options, loading, change }) {
  return <><SectionHeading title="Información general" text="Define el tipo, las fechas y el propósito del ingreso." /><div className="form-grid">
    <Field label="Tipo de ingreso" required><Select name="idTipoIngreso" value={form.idTipoIngreso} onChange={change} items={options?.tiposIngreso} loading={loading} /></Field>
    <Field label="Empresa / proveedor"><Select name="idProveedor" value={form.idProveedor} onChange={change} items={options?.proveedores} loading={loading} emptyLabel="Sin proveedor" /></Field>
    <Field label="Fecha de inicio" required><input type="date" name="fechaInicio" value={form.fechaInicio} onChange={change} /></Field>
    <Field label="Fecha de finalización" required><input type="date" name="fechaFin" min={form.fechaInicio} value={form.fechaFin} onChange={change} /></Field>
    <Field label="Nombre de la actividad" required full><input name="nombreActividad" maxLength="200" value={form.nombreActividad} onChange={change} placeholder="Ej. Mantenimiento preventivo de infraestructura" /></Field>
    <Field label="Descripción general" full><textarea name="descripcionActividad" maxLength="1000" value={form.descripcionActividad} onChange={change} placeholder="Describe el propósito del ingreso" /></Field>
    <Field label="Contrato, cuando aplique"><input name="numeroContrato" maxLength="60" value={form.numeroContrato} onChange={change} placeholder="Ej. CT-2026-084" /></Field>
    <Field label="Cantidad estimada de personas"><input type="number" name="cantidadEstimada" min="1" value={form.cantidadEstimada} onChange={change} /></Field>
  </div></>
}

function StepTwo({ form, options, loading, change }) {
  return <><SectionHeading title="Contacto y ubicación" text="Indica quién coordina el ingreso y dónde se realizará." /><div className="form-grid">
    <Field label="Contacto del proveedor"><input name="contactoProveedor" maxLength="200" value={form.contactoProveedor} onChange={change} placeholder="Nombre del contacto" /></Field>
    <Field label="Correo del proveedor"><input type="email" name="correoProveedor" maxLength="254" value={form.correoProveedor} onChange={change} placeholder="contacto@empresa.com" /></Field>
    <Field label="Área solicitante" required><Select name="idAreaSolicitante" value={form.idAreaSolicitante} onChange={change} items={options?.areas} loading={loading} /></Field>
    <Field label="Ubicación / instalación" required><Select name="idUbicacion" value={form.idUbicacion} onChange={change} items={options?.ubicaciones} loading={loading} /></Field>
    <Field label="Usuario solicitante" required full><Select name="idUsuarioSolicitante" value={form.idUsuarioSolicitante} onChange={change} items={options?.usuarios} loading={loading} /></Field>
    <Field label="Observaciones" full><textarea name="observaciones" maxLength="1000" value={form.observaciones} onChange={change} placeholder="Indicaciones para el ingreso" /></Field>
  </div></>
}

function Review({ form, selected }) {
  const rows = [
    ['Tipo de ingreso', selected.tipo?.nombre], ['Empresa', selected.proveedor?.nombre ?? 'Sin proveedor'],
    ['Actividad', form.nombreActividad], ['Periodo', `${formatDate(form.fechaInicio)} – ${formatDate(form.fechaFin)}`],
    ['Contacto', form.contactoProveedor || 'No indicado'], ['Correo', form.correoProveedor || 'No indicado'],
    ['Área solicitante', selected.area?.nombre], ['Ubicación', selected.ubicacion?.nombre],
  ]
  return <><SectionHeading title="Revisa antes de enviar" text="La solicitud se guardará y quedará disponible para registrar las personas." /><div className="info-list">{rows.map(([label, value]) => <div className="info-item" key={label}><span>{label}</span><strong>{value || '—'}</strong></div>)}</div><div className="ticket-box"><div><h3>¿Qué ocurrirá al enviar?</h3><p>Se generará un número de solicitud y podrás continuar con el registro de las {form.cantidadEstimada || 0} personas.</p></div><Icon name="send" /></div></>
}

function Progress({ step, onStepChange }) {
  return <div className="progress-shell">{['Información básica', 'Contacto y ubicación', 'Revisión y envío'].map((label, index) => { const number = index + 1; const state = step === number ? 'active' : step > number ? 'done' : ''; return <button type="button" className={`step ${state}`} key={label} onClick={() => onStepChange(number)} aria-current={step === number ? 'step' : undefined}><span className="step-number">{step > number ? '✓' : number}</span><span>{label}</span></button> })}</div>
}

function Nav({ icon, label, count, active, onClick }) { return <button type="button" className={`nav-item ${active ? 'active' : ''}`} onClick={onClick}><Icon name={icon} /><span>{label}</span>{count && <span className="nav-count">{count}</span>}</button> }
function SectionHeading({ title, text }) { return <div className="section-heading"><h2>{title}</h2><p>{text}</p></div> }
function Field({ label, required, full, children }) { return <div className={`field ${full ? 'full' : ''}`}><label>{label} {required && <span className="required">*</span>}</label>{children}</div> }
function Select({ items = [], loading, emptyLabel = 'Selecciona una opción', ...props }) { return <select {...props}><option value="">{loading ? 'Cargando…' : emptyLabel}</option>{items?.map((item) => <option key={item.id} value={item.id}>{item.nombre ?? item.codigo}</option>)}</select> }

const iconPaths = {
  logo: <><path d="M7 5.5h10M7 12h8M7 18.5h10" /><path d="M5 3h14v18H5z" /></>, home: <><path d="M3 11.5 12 4l9 7.5" /><path d="M5.5 10.5V20h13v-9.5M9.5 20v-6h5v6" /></>,
  file: <><path d="M6 3h8l4 4v14H6z" /><path d="M14 3v5h5M9 12h6M9 16h6" /></>, check: <path d="m5 12 4 4L19 6" />, tasks: <><rect x="5" y="4" width="14" height="16" rx="2" /><path d="M9 9h6M9 13h6M9 17h4" /></>,
  users: <><circle cx="9" cy="7" r="4" /><path d="M2 21v-2a4 4 0 0 1 4-4h6a4 4 0 0 1 4 4v2M17 4a4 4 0 0 1 0 7" /></>, settings: <><circle cx="12" cy="12" r="3" /><path d="M19 12a7 7 0 1 1-14 0 7 7 0 0 1 14 0M12 3V1M12 23v-2M21 12h2M1 12h2" /></>,
  menu: <path d="M4 6h16M4 12h16M4 18h16" />, bell: <path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4" />, help: <><circle cx="12" cy="12" r="9" /><path d="M9.7 9a2.5 2.5 0 1 1 3.4 2.3c-.7.3-1.1.9-1.1 1.7v.5M12 17h.01" /></>,
  search: <><circle cx="11" cy="11" r="7" /><path d="m20 20-4-4" /></>,
  shield: <><path d="M12 3 5 6v5c0 4.8 2.8 8.1 7 10 4.2-1.9 7-5.2 7-10V6z" /><path d="m9 12 2 2 4-4" /></>,
  arrow: <path d="M5 12h14M14 7l5 5-5 5" />, back: <path d="M19 12H5M10 17l-5-5 5-5" />, send: <path d="m22 2-7 20-4-9-9-4zM22 2 11 13" />, logout: <path d="M10 17l5-5-5-5M15 12H3M15 4h5v16h-5" />,
}
function Icon({ name }) { return <svg className="icon-svg" viewBox="0 0 24 24" aria-hidden="true">{iconPaths[name] ?? iconPaths.file}</svg> }

function withDefaults(form, options) { if (!options) return form; return { ...form, idTipoIngreso: form.idTipoIngreso || String(options.tiposIngreso[0]?.id ?? ''), idEstadoSolicitud: form.idEstadoSolicitud || String(options.estadosSolicitud[0]?.id ?? ''), idProveedor: form.idProveedor || String(options.proveedores[0]?.id ?? ''), idAreaSolicitante: form.idAreaSolicitante || String(options.areas[0]?.id ?? ''), idUbicacion: form.idUbicacion || String(options.ubicaciones[0]?.id ?? ''), idUsuarioSolicitante: form.idUsuarioSolicitante || String(options.usuarios[0]?.id ?? '') } }
function formFromDetail(item, options) { return withDefaults({ idTipoIngreso: stringValue(item.idTipoIngreso), idEstadoSolicitud: stringValue(item.idEstadoSolicitud), idProveedor: stringValue(item.idProveedor), fechaInicio: item.fechaInicio ?? today(), fechaFin: item.fechaFin ?? today(), nombreActividad: item.nombreActividad ?? '', descripcionActividad: item.descripcionActividad ?? '', numeroContrato: item.numeroContrato ?? '', cantidadEstimada: stringValue(item.cantidadEstimada ?? 1), contactoProveedor: item.contactoProveedor ?? '', correoProveedor: item.correoProveedor ?? '', idAreaSolicitante: stringValue(item.idAreaSolicitante), idUbicacion: stringValue(item.idUbicacion), idUsuarioSolicitante: item.idUsuarioSolicitante ?? '', observaciones: item.observaciones ?? '' }, options) }
function validateStep(step, form) { if (step === 1 && (!form.idTipoIngreso || !form.nombreActividad.trim() || !form.fechaInicio || !form.fechaFin)) return 'Completa el tipo, nombre y fechas de la actividad.'; if (step === 1 && form.fechaFin < form.fechaInicio) return 'La fecha final no puede ser anterior a la fecha inicial.'; if (step === 2 && (!form.idAreaSolicitante || !form.idUbicacion || !form.idUsuarioSolicitante)) return 'Selecciona el área, la ubicación y el usuario solicitante.'; return '' }
const findOption = (items, id) => items?.find((item) => String(item.id) === String(id))
const stringValue = (value) => value == null ? '' : String(value)
const numberOrNull = (value) => value === '' ? null : Number(value)
const textOrNull = (value) => value.trim() === '' ? null : value.trim()
const formatDate = (value) => value ? new Intl.DateTimeFormat('es-HN', { day: '2-digit', month: 'short', year: 'numeric', timeZone: 'UTC' }).format(new Date(`${value}T00:00:00Z`)) : '—'
const formatDateTime = (value) => value ? new Intl.DateTimeFormat('es-HN', { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(value)) : '—'
const initials = (name) => name?.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase() || '—'
const accessStatusClass = (status = '') => { const value = status.toLowerCase(); if (value.includes('aprob')) return 'approved'; if (value.includes('rechaz')) return 'rejected'; if (value.includes('no requiere')) return 'neutral'; return 'pending' }

export default App
