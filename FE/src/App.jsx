import { useEffect, useMemo, useState } from 'react'
import { Link, Navigate, Route, Routes, matchPath, useLocation, useNavigate } from 'react-router-dom'
import { Icon } from './components/Icon'
import { AlertModal } from './components/AlertModal'
import auraLogo from './assets/logo-aura.png'
import {
  AccessControlPage,
  ApprovalsPage,
  DashboardPage,
  LoginPage,
  MyActivitiesPage,
  PersonAccessPage,
  PersonFormPage,
  ProfilePage,
  RequestApprovalDetailPage,
  RequestFormPage,
  RequestsListPage,
  UserManagementPage,
} from './pages'
import { controlIngresosApi } from './services/api'
import { showSuccessAlert } from './utils/alerts'
import { initials } from './utils/formatters'
import './App.css'

const today = () => new Date().toLocaleDateString('en-CA')
const sessionKey = 'control-ingresos-session'
const initialForm = () => ({
  idTipoIngreso: '', idEstadoSolicitud: '', idProveedor: '', fechaInicio: today(), fechaFin: today(),
  nombreActividad: '', descripcionActividad: '', numeroContrato: '', cantidadEstimada: '1',
  contactoProveedor: '', correoProveedor: '', idAreaSolicitante: '', idUbicacion: '',
  idUsuarioSolicitante: '', observaciones: '',
})

function App() {
  const navigate = useNavigate()
  const [session, setSession] = useState(readSession)

  async function login(credentials) {
    const authenticatedUser = await controlIngresosApi.iniciarSesion(credentials)
    localStorage.setItem(sessionKey, JSON.stringify(authenticatedUser))
    setSession(authenticatedUser)
    navigate('/dashboard', { replace: true })
  }

  async function logout() {
    try {
      await controlIngresosApi.cerrarSesion()
    } catch {
      // La sesión local siempre debe cerrarse, incluso si la API no está disponible.
    } finally {
      localStorage.removeItem(sessionKey)
      setSession(null)
      navigate('/login', { replace: true })
    }
  }

  if (!session) {
    return <Routes>
      <Route path="/login" element={<LoginPage onLogin={login} />} />
      <Route path="*" element={<Navigate to="/login" replace />} />
    </Routes>
  }

  return <AuthenticatedApp session={session} onLogout={logout} />
}

function AuthenticatedApp({ session, onLogout }) {
  const location = useLocation()
  const navigate = useNavigate()
  const isAdministrator = hasRole(session, 'Administrador')
  const canApprove = isAdministrator || hasRole(session, 'Aprobador')
  const canUseGate = isAdministrator || hasRole(session, 'Seguridad')
  const editRoute = matchPath('/solicitudes/:id/editar', location.pathname)
  const personRoute = matchPath('/personas/:idPersona', location.pathname)
  const isNewPersonRoute = location.pathname === '/personas/nueva'
  const approvalDetailRoute = matchPath('/aprobaciones/:idSolicitudPersonaArea/detalle', location.pathname)
  const isPersonsRoute = location.pathname.startsWith('/personas')
  const isRequestsRoute = location.pathname.startsWith('/solicitudes')
  const isApprovalsRoute = location.pathname.startsWith('/aprobaciones')
  const isActivitiesRoute = location.pathname === '/mis-actividades'
  const isUsersRoute = location.pathname === '/usuarios'
  const isAccessControlRoute = location.pathname === '/control-accesos'
  const isProfileRoute = location.pathname === '/perfil'
  const isDashboardRoute = location.pathname === '/dashboard' || location.pathname === '/'
  const [step, setStep] = useState(1)
  const [editingId, setEditingId] = useState(null)
  const [form, setForm] = useState(initialForm)
  const [options, setOptions] = useState(null)
  const [solicitudes, setSolicitudes] = useState([])
  const [personas, setPersonas] = useState([])
  const [requestPeople, setRequestPeople] = useState([])
  const [existingRequestPeople, setExistingRequestPeople] = useState([])
  const [peopleEntryMode, setPeopleEntryMode] = useState('')
  const [personaSeleccionada, setPersonaSeleccionada] = useState(null)
  const [aprobaciones, setAprobaciones] = useState([])
  const [actividades, setActividades] = useState([])
  const [activitiesLoading, setActivitiesLoading] = useState(false)
  const [usuarios, setUsuarios] = useState([])
  const [movements, setMovements] = useState([])
  const [gateLoading, setGateLoading] = useState(false)
  const [gateSaving, setGateSaving] = useState(false)
  const [usersLoading, setUsersLoading] = useState(false)
  const [profile, setProfile] = useState(null)
  const [profileLoading, setProfileLoading] = useState(true)
  const [approvalsLoading, setApprovalsLoading] = useState(false)
  const [approvalDetail, setApprovalDetail] = useState(null)
  const [approvalDetailLoading, setApprovalDetailLoading] = useState(false)
  const [personLoading, setPersonLoading] = useState(false)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)
  const [error, setError] = useState('')
  const activeEditingId = editRoute ? editingId : null

  useEffect(() => {
    let active = true
    Promise.all([controlIngresosApi.obtenerDatosFormularioSolicitud(), controlIngresosApi.listarSolicitudes(), controlIngresosApi.listarPersonas()])
      .then(([data, records, people]) => {
        if (!active) return
        setOptions(data)
        setSolicitudes(records)
        setPersonas(people)
        setForm((current) => withDefaults(current, data, session.idUsuario))
      })
      .catch((requestError) => active && setError(requestError.message))
      .finally(() => active && setLoading(false))
    return () => { active = false }
  }, [session.idUsuario])

  useEffect(() => {
    const id = Number(editRoute?.params.id)
    if (!id || !options || editingId === id) return
    let active = true
    const load = async () => {
      await Promise.resolve()
      if (!active) return
      setLoading(true)
      setError('')
      try {
        const item = await controlIngresosApi.obtenerSolicitud(id)
        if (!active) return
        setEditingId(id)
        setForm(formFromDetail(item, options))
        setExistingRequestPeople(item.personas ?? [])
        setRequestPeople([])
        setPeopleEntryMode(item.personas?.length ? 'manual' : '')
        setStep(1)
      } catch (requestError) {
        if (active) setError(requestError.message)
      } finally {
        if (active) setLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [location.pathname, options, editRoute?.params.id, editingId])

  useEffect(() => {
    if (!isPersonsRoute || isNewPersonRoute) return
    let active = true
    const load = async () => {
      await Promise.resolve()
      if (!active) return
      setPersonLoading(true)
      setError('')
      try {
        const records = personas.length ? personas : await controlIngresosApi.listarPersonas()
        if (!active) return
        setPersonas(records)
        const routeId = Number(personRoute?.params.idPersona)
        const preferred = routeId
          ? records.find((item) => item.idPersona === routeId)
          : records.find((item) => item.nombreCompleto?.toLowerCase().includes('david')) ?? records[0]
        if (!preferred) {
          setPersonaSeleccionada(null)
          return
        }
        if (personaSeleccionada?.idPersona !== preferred.idPersona) {
          const detail = await controlIngresosApi.obtenerPersonaAccesos(preferred.idPersona)
          if (active) setPersonaSeleccionada(detail)
        }
      } catch (requestError) {
        if (active) setError(requestError.message)
      } finally {
        if (active) setPersonLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [isPersonsRoute, isNewPersonRoute, personRoute?.params.idPersona, personas, personaSeleccionada?.idPersona])

  useEffect(() => {
    if ((!isApprovalsRoute && !isDashboardRoute) || !canApprove) return
    let active = true
    const load = async () => {
      await Promise.resolve()
      if (!active) return
      setApprovalsLoading(true)
      setError('')
      try {
        const records = await controlIngresosApi.listarAprobaciones()
        if (active) setAprobaciones(records)
      } catch (requestError) {
        if (active) setError(requestError.message)
      } finally {
        if (active) setApprovalsLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [isApprovalsRoute, isDashboardRoute, canApprove, session.idUsuario])

  useEffect(() => {
    if (!isActivitiesRoute) return
    let active = true
    const load = async () => {
      await Promise.resolve()
      if (!active) return
      setActivitiesLoading(true)
      setError('')
      try {
        const records = await controlIngresosApi.listarMisActividades()
        if (active) setActividades(records)
      } catch (requestError) {
        if (active) setError(requestError.message)
      } finally {
        if (active) setActivitiesLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [isActivitiesRoute])

  useEffect(() => {
    if (!isUsersRoute || !isAdministrator) return
    let active = true
    const load = async () => {
      await Promise.resolve()
      if (!active) return
      setUsersLoading(true)
      setError('')
      try {
        const records = await controlIngresosApi.listarUsuarios()
        if (active) setUsuarios(records)
      } catch (requestError) {
        if (active) setError(requestError.message)
      } finally {
        if (active) setUsersLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [isUsersRoute, isAdministrator])

  useEffect(() => {
    if (!isAccessControlRoute || !canUseGate) return
    let active = true
    setGateLoading(true)
    controlIngresosApi.listarMovimientosIngreso()
      .then((records) => active && setMovements(records))
      .catch((requestError) => active && setError(requestError.message))
      .finally(() => active && setGateLoading(false))
    return () => { active = false }
  }, [isAccessControlRoute, canUseGate])

  useEffect(() => {
    if (!isProfileRoute) return
    let active = true
    const load = async () => {
      await Promise.resolve()
      if (!active) return
      setProfileLoading(true)
      setError('')
      try {
        const data = await controlIngresosApi.obtenerMiPerfil()
        if (active) setProfile(data)
      } catch (requestError) {
        if (active) setError(requestError.message)
      } finally {
        if (active) setProfileLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [isProfileRoute])

  useEffect(() => {
    const idSolicitudPersonaArea = Number(approvalDetailRoute?.params.idSolicitudPersonaArea)
    if (!idSolicitudPersonaArea) return

    const approval = aprobaciones.find((item) => item.idSolicitudPersonaArea === idSolicitudPersonaArea)
    if (!approval?.idSolicitud) return

    let active = true
    const load = async () => {
      setApprovalDetailLoading(true)
      setApprovalDetail(null)
      setError('')
      try {
        const detail = await controlIngresosApi.obtenerSolicitud(approval.idSolicitud)
        if (active) setApprovalDetail(detail)
      } catch (requestError) {
        if (active) setError(requestError.message)
      } finally {
        if (active) setApprovalDetailLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [approvalDetailRoute?.params.idSolicitudPersonaArea, aprobaciones])

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

  function next() { goToStep(Math.min(4, step + 1)) }

  function goToStep(targetStep) {
    for (let currentStep = 1; currentStep < targetStep; currentStep += 1) {
      const validation = validateStep(currentStep, form)
        || (currentStep === 3 && !peopleEntryMode ? 'Indica quién ingresará las personas de la solicitud.' : '')
        || (currentStep === 3 && peopleEntryMode === 'provider' && !form.idProveedor ? 'Selecciona un proveedor en el paso de información básica.' : '')
        || (currentStep === 3 && peopleEntryMode === 'manual' && requestPeople.some((person) => person.areas.length === 0) ? 'Selecciona al menos un área para cada persona agregada.' : '')
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
    setForm(withDefaults(initialForm(), options, session.idUsuario))
    setRequestPeople([])
    setExistingRequestPeople([])
    setPeopleEntryMode('')
    setStep(1)
    setError('')
    navigate('/solicitudes/nueva')
  }

  function openEdit(id) {
    setError('')
    navigate(`/solicitudes/${id}/editar`)
  }

  async function remove(id, number) {
    if (!window.confirm(`¿Deseas eliminar la solicitud ${number ?? `#${id}`}?`)) return
    setError('')
    try {
      await controlIngresosApi.eliminarSolicitud(id)
      setSolicitudes(await controlIngresosApi.listarSolicitudes())
      showSuccessAlert(`La solicitud ${number ?? `#${id}`} fue eliminada.`)
    } catch (requestError) {
      setError(requestError.message)
    }
  }

  function openPersons() {
    navigate('/personas')
    setMenuOpen(false)
    setError('')
  }

  function openNewPerson() {
    navigate('/personas/nueva')
    setMenuOpen(false)
    setError('')
  }

  function personCreated(created) {
    setPersonas([])
    setPersonaSeleccionada(null)
    setError('')
    navigate(`/personas/${created.id}`)
  }

  function openProfile() {
    navigate('/perfil')
    setMenuOpen(false)
    setError('')
  }

  function selectPerson(idPersona) {
    setError('')
    navigate(`/personas/${idPersona}`)
  }

  function openApprovalDetail(idSolicitudPersonaArea) {
    setError('')
    navigate(`/aprobaciones/${idSolicitudPersonaArea}/detalle`)
  }

  async function decideApproval(idSolicitudPersonaArea, codigoEstado, comentarioDecision) {
    const result = await decideApprovals([idSolicitudPersonaArea], codigoEstado, comentarioDecision)
    const failure = result.failures.find((item) => item.idSolicitudPersonaArea === idSolicitudPersonaArea)
    return failure ? { success: false, message: failure.message } : { success: true }
  }

  async function decideApprovals(idSolicitudPersonaAreas, codigoEstado, comentarioDecision) {
    setError('')
    const successIds = []
    const failures = []
    for (const idSolicitudPersonaArea of [...new Set(idSolicitudPersonaAreas)]) {
      try {
        await controlIngresosApi.decidirAprobacion(idSolicitudPersonaArea, {
          idUsuarioAprobador: session.idUsuario,
          codigoEstado,
          comentarioDecision: comentarioDecision.trim() || null,
        })
        successIds.push(idSolicitudPersonaArea)
      } catch (requestError) {
        failures.push({ idSolicitudPersonaArea, message: requestError.message })
      }
    }

    try {
      setAprobaciones(await controlIngresosApi.listarAprobaciones())
    } catch (requestError) {
      setError(requestError.message)
    }
    return { successIds, failures }
  }

  async function completeActivity(idActividad) {
    const comentarios = window.prompt('Comentario de finalización (opcional):')
    if (comentarios === null) return
    setError('')
    try {
      await controlIngresosApi.completarActividad(idActividad, comentarios.trim() || null)
      setActividades(await controlIngresosApi.listarMisActividades())
      showSuccessAlert('La actividad fue enviada para aprobación.')
    } catch (requestError) {
      setError(requestError.message)
    }
  }

  async function createUser(user) {
    setError('')
    try {
      await controlIngresosApi.crearUsuario(user)
      const [records, refreshedOptions] = await Promise.all([
        controlIngresosApi.listarUsuarios(),
        controlIngresosApi.obtenerDatosFormularioSolicitud(),
      ])
      setUsuarios(records)
      setOptions(refreshedOptions)
      showSuccessAlert('El usuario fue creado correctamente.')
      return { success: true }
    } catch (requestError) {
      setError(requestError.message)
      return { success: false, message: requestError.message }
    }
  }

  async function registerMovement(movement) {
    setGateSaving(true)
    setError('')
    try {
      await controlIngresosApi.registrarMovimientoIngreso(movement)
      setMovements(await controlIngresosApi.listarMovimientosIngreso())
      showSuccessAlert(`${movement.tipoMovimiento === 'ENTRADA' ? 'Entrada' : 'Salida'} registrada correctamente.`)
      return { success: true }
    } catch (requestError) {
      setError(requestError.message)
      return { success: false, message: requestError.message }
    } finally {
      setGateSaving(false)
    }
  }

  async function submit() {
    if (step !== 4) return
    if (editRoute && !activeEditingId) {
      setError('No fue posible cargar la solicitud que deseas editar.')
      return
    }
    const validation = validateStep(2, form)
    if (validation) { setStep(2); setError(validation); return }
    setSaving(true)
    setError('')
    try {
      const payload = {
        idTipoIngreso: numberOrNull(form.idTipoIngreso),
        idEstadoSolicitud: activeEditingId ? numberOrNull(form.idEstadoSolicitud) : null,
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
        usuario: session.idUsuario,
      }
      const personPayloads = requestPeople.map((person) => ({
        idPersona: person.idPersona,
        idEstadoPersonaSolicitud: null,
        datosCompletos: true,
        observacionesRevision: null,
        areas: person.areas,
        requerimientos: null,
        usuario: session.idUsuario,
      }))
      const created = activeEditingId
        ? await controlIngresosApi.actualizarSolicitud(activeEditingId, payload)
        : await controlIngresosApi.crearSolicitudCompleta({ solicitud: payload, personas: personPayloads })
      const requestId = activeEditingId ?? created.id
      const failedPeople = []
      for (const person of activeEditingId ? personPayloads : []) {
        try {
          await controlIngresosApi.agregarPersonaSolicitud(requestId, person)
        } catch (personError) {
          failedPeople.push({ ...person, error: personError.message })
        }
      }
      if (failedPeople.length > 0) {
        setRequestPeople(failedPeople)
        setEditingId(requestId)
        navigate(`/solicitudes/${requestId}/editar`, { replace: true })
        setError(`La solicitud fue guardada, pero no se pudieron agregar ${failedPeople.length} persona(s): ${failedPeople.map((person) => person.error).join(' ')}`)
        return
      }
      await controlIngresosApi.enviarSolicitud(requestId)
      showSuccessAlert(activeEditingId ? 'La solicitud fue actualizada y enviada correctamente.' : `Se creó y envió ${created.numero ?? `la solicitud #${created.id}`}.`)
      setSolicitudes(await controlIngresosApi.listarSolicitudes())
      setForm(withDefaults(initialForm(), options, session.idUsuario))
      setRequestPeople([])
      setExistingRequestPeople([])
      setPeopleEntryMode('')
      setEditingId(null)
      setStep(1)
      navigate('/solicitudes')
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setSaving(false)
    }
  }

  function cancelForm() {
    setForm(withDefaults(initialForm(), options, session.idUsuario))
    setRequestPeople([])
    setExistingRequestPeople([])
    setPeopleEntryMode('')
    setStep(1)
    setEditingId(null)
    setError('')
    navigate('/solicitudes')
  }

  return (
    <div className="app-shell">
      <AlertModal message={error} onClose={() => setError('')} />
      {menuOpen && <button className="sidebar-backdrop" onClick={() => setMenuOpen(false)} aria-label="Cerrar menú" />}
      <aside className={`sidebar ${menuOpen ? 'open' : ''}`} aria-label="Navegación principal">
        <div className="sidebar-brand"><img className="sidebar-brand-logo" src={auraLogo} alt="Aura Minerals" /></div>
        <p className="side-label">Control de ingresos</p>
        <nav className="main-nav">
          <Nav icon="home" label="Dashboard" active={isDashboardRoute} onClick={() => { navigate('/dashboard'); setMenuOpen(false); setError('') }} />
          <Nav icon="file" label="Solicitudes" count={solicitudes.length} active={isRequestsRoute} onClick={() => { navigate('/solicitudes'); setMenuOpen(false); setError('') }} />
          {canApprove && <Nav icon="check" label="Mis aprobaciones" count={aprobaciones.filter((item) => item.codigoEstado === 'PENDIENTE').length || undefined} active={isApprovalsRoute} onClick={() => { navigate('/aprobaciones'); setMenuOpen(false); setError('') }} />}
          <Nav icon="tasks" label="Mis actividades" count={actividades.filter((item) => !item.esEstadoFinal).length || undefined} active={isActivitiesRoute} onClick={() => { navigate('/mis-actividades'); setMenuOpen(false); setError('') }} />
          <Nav icon="users" label="Personas" count={personas.length || undefined} active={isPersonsRoute} onClick={openPersons} />
          {canUseGate && <Nav icon="shield" label="Control de accesos" active={isAccessControlRoute} onClick={() => { navigate('/control-accesos'); setMenuOpen(false); setError('') }} />}
          {isAdministrator && <Nav icon="settings" label="Usuarios" count={usuarios.length || undefined} active={isUsersRoute} onClick={() => { navigate('/usuarios'); setMenuOpen(false); setError('') }} />}
        </nav>
        <div className="sidebar-footer">
          <button type="button" className="nav-item" onClick={onLogout}><Icon name="logout" /><span>Cerrar sesión</span></button>
        </div>
      </aside>

      <main className="main">
        <header className="topbar">
          <button className="icon-button menu-button" onClick={() => setMenuOpen((open) => !open)} aria-label="Abrir menú"><Icon name="menu" /></button>
          <div className="breadcrumb">
            <Link to="/dashboard" onClick={() => { setError(''); setMenuOpen(false) }}>Inicio</Link>
            <strong>{approvalDetailRoute ? 'Detalle de solicitud' : isDashboardRoute ? 'Dashboard' : isProfileRoute ? 'Mi perfil' : isAccessControlRoute ? 'Control de accesos' : isUsersRoute ? 'Usuarios' : isActivitiesRoute ? 'Mis actividades' : isApprovalsRoute ? 'Mis aprobaciones' : isNewPersonRoute ? 'Nueva persona' : isPersonsRoute ? 'Personas y accesos' : editRoute ? 'Editar solicitud' : location.pathname === '/solicitudes/nueva' ? 'Nueva solicitud' : 'Solicitudes'}</strong>
          </div>
          <div className="top-actions">
            {/* <button className="ghost-button"><Icon name="help" />Ayuda</button> */}
            <div className="top-profile"><div><strong>{session.nombreCompleto ?? session.idUsuario}</strong><span>{session.puesto ?? session.area ?? 'Usuario'}</span></div><button type="button" className="avatar profile-trigger" onClick={openProfile} aria-label="Abrir mi perfil" title="Mi perfil">{initials(session.nombreCompleto)}</button></div>
          </div>
        </header>

        <section className="content">
          <Routes>
            <Route path="/" element={<Navigate to="/dashboard" replace />} />
            <Route path="/dashboard" element={<DashboardPage session={{ ...session, esAprobador: canApprove }} requests={solicitudes} approvals={aprobaciones} loading={loading} approvalsLoading={approvalsLoading} onNew={openNew} onRequests={() => navigate('/solicitudes')} onRequest={openEdit} onApprovals={() => navigate('/aprobaciones')} onPersons={openPersons} />} />
            <Route path="/mis-actividades" element={<MyActivitiesPage items={actividades} loading={activitiesLoading} onRequest={openEdit} onComplete={completeActivity} />} />
            <Route path="/usuarios" element={isAdministrator ? <UserManagementPage items={usuarios} loading={usersLoading} areas={options?.areas ?? []} onCreate={createUser} /> : <Navigate to="/dashboard" replace />} />
            <Route path="/control-accesos" element={canUseGate ? <AccessControlPage people={personas} movements={movements} loading={gateLoading} saving={gateSaving} onRegister={registerMovement} /> : <Navigate to="/dashboard" replace />} />
            <Route path="/perfil" element={<ProfilePage profile={profile} loading={profileLoading} onOpenRequest={openEdit} />} />
            <Route path="/solicitudes" element={<RequestsListPage items={solicitudes} loading={loading} onNew={openNew} onEdit={openEdit} onDelete={remove} />} />
            <Route path="/solicitudes/nueva" element={<RequestFormPage form={form} options={options} people={personas} requestPeople={requestPeople} existingPeople={existingRequestPeople} peopleEntryMode={peopleEntryMode} loading={loading} saving={saving} editingId={null} step={step} selected={selected} onPeopleEntryModeChange={(mode) => { setPeopleEntryMode(mode); if (mode === 'provider') setRequestPeople([]) }} onPeopleChange={setRequestPeople} onChange={change} onStepChange={goToStep} onNext={next} onBack={() => setStep((current) => current - 1)} onCancel={cancelForm} onSubmit={submit} />} />
            <Route path="/solicitudes/:id/editar" element={<RequestFormPage form={form} options={options} people={personas} requestPeople={requestPeople} existingPeople={existingRequestPeople} peopleEntryMode={peopleEntryMode} loading={loading} saving={saving} editingId={activeEditingId} step={step} selected={selected} onPeopleEntryModeChange={(mode) => { setPeopleEntryMode(mode); if (mode === 'provider') setRequestPeople([]) }} onPeopleChange={setRequestPeople} onChange={change} onStepChange={goToStep} onNext={next} onBack={() => setStep((current) => current - 1)} onCancel={cancelForm} onSubmit={submit} />} />
            <Route path="/personas" element={<PersonAccessPage items={personas} selected={personaSeleccionada} loading={personLoading} onSelect={selectPerson} onNew={openNewPerson} />} />
            <Route path="/personas/nueva" element={<PersonFormPage session={session} providers={options?.proveedores} onCancel={openPersons} onCreated={personCreated} onError={setError} />} />
            <Route path="/personas/:idPersona" element={<PersonAccessPage items={personas} selected={personaSeleccionada} loading={personLoading} onSelect={selectPerson} onNew={openNewPerson} />} />
            <Route path="/aprobaciones" element={canApprove ? <ApprovalsPage items={aprobaciones} loading={approvalsLoading} onDecide={decideApproval} onDecideMany={decideApprovals} onViewDetail={openApprovalDetail} /> : <Navigate to="/solicitudes" replace />} />
            <Route path="/aprobaciones/:idSolicitudPersonaArea/detalle" element={canApprove ? <RequestApprovalDetailPage request={approvalDetail} options={options} approvalItems={aprobaciones} loading={approvalDetailLoading || !approvalDetail} onBack={() => navigate('/aprobaciones')} onDecide={decideApproval} /> : <Navigate to="/solicitudes" replace />} />
            <Route path="/login" element={<Navigate to="/dashboard" replace />} />
            <Route path="*" element={<Navigate to="/dashboard" replace />} />
          </Routes>
        </section>
      </main>
    </div>
  )
}

function Nav({ icon, label, count, active, onClick }) {
  return <button type="button" className={`nav-item ${active ? 'active' : ''}`} onClick={onClick}><Icon name={icon} /><span>{label}</span>{count && <span className="nav-count">{count}</span>}</button>
}

function withDefaults(form, options, preferredUser) {
  if (!options) return form
  return {
    ...form,
    idTipoIngreso: form.idTipoIngreso || String(options.tiposIngreso[0]?.id ?? ''),
    idEstadoSolicitud: form.idEstadoSolicitud || String(options.estadosSolicitud[0]?.id ?? ''),
    idProveedor: form.idProveedor || String(options.proveedores[0]?.id ?? ''),
    idAreaSolicitante: form.idAreaSolicitante || String(options.areas[0]?.id ?? ''),
    idUbicacion: form.idUbicacion || String(options.ubicaciones[0]?.id ?? ''),
    idUsuarioSolicitante: form.idUsuarioSolicitante || String(options.usuarios.find((item) => item.id === preferredUser)?.id ?? options.usuarios[0]?.id ?? ''),
  }
}

function formFromDetail(item, options) {
  return withDefaults({
    idTipoIngreso: stringValue(item.idTipoIngreso), idEstadoSolicitud: stringValue(item.idEstadoSolicitud),
    idProveedor: stringValue(item.idProveedor), fechaInicio: item.fechaInicio ?? today(), fechaFin: item.fechaFin ?? today(),
    nombreActividad: item.nombreActividad ?? '', descripcionActividad: item.descripcionActividad ?? '',
    numeroContrato: item.numeroContrato ?? '', cantidadEstimada: stringValue(item.cantidadEstimada ?? 1),
    contactoProveedor: item.contactoProveedor ?? '', correoProveedor: item.correoProveedor ?? '',
    idAreaSolicitante: stringValue(item.idAreaSolicitante), idUbicacion: stringValue(item.idUbicacion),
    idUsuarioSolicitante: item.idUsuarioSolicitante ?? '', observaciones: item.observaciones ?? '',
  }, options)
}

function validateStep(step, form) {
  if (step === 1 && (!form.idTipoIngreso || !form.nombreActividad.trim() || !form.fechaInicio || !form.fechaFin)) return 'Completa el tipo, nombre y fechas de la actividad.'
  if (step === 1 && form.fechaFin < form.fechaInicio) return 'La fecha final no puede ser anterior a la fecha inicial.'
  if (step === 2 && (!form.idAreaSolicitante || !form.idUbicacion || !form.idUsuarioSolicitante)) return 'Selecciona el área, la ubicación y el usuario solicitante.'
  return ''
}

const findOption = (items, id) => items?.find((item) => String(item.id) === String(id))
const stringValue = (value) => value == null ? '' : String(value)
const numberOrNull = (value) => value === '' ? null : Number(value)
const textOrNull = (value) => value.trim() === '' ? null : value.trim()
const hasRole = (session, role) => Boolean(
  session.roles?.some((item) => item.toLowerCase() === role.toLowerCase())
  || (role === 'Administrador' && session.puesto?.toLowerCase().includes('administrador'))
  || (role === 'Aprobador' && session.esAprobador),
)

function readSession() {
  try {
    return JSON.parse(localStorage.getItem(sessionKey))
  } catch {
    localStorage.removeItem(sessionKey)
    return null
  }
}

export default App
