import { useEffect, useMemo, useState } from 'react'
import { Link, Navigate, Route, Routes, matchPath, useLocation, useNavigate } from 'react-router-dom'
import { Icon } from './components/Icon'
import { AlertModal } from './components/AlertModal'
import auraLogo from './assets/logo-aura.png'
import {
  ApprovalsPage,
  ActivityRequestDetailPage,
  ActivityWorkflowPage,
  DashboardPage,
  EmployeeListPage,
  EmployeeQrPage,
  LoginPage,
  MyActivitiesPage,
  PersonAccessPage,
  PersonFormPage,
  PersonQrPage,
  ProfilePage,
  PublicEmployeeCredentialPage,
  PublicPersonCredentialPage,
  ProviderFormPage,
  ProviderPortalPage,
  ProviderRequestDetailPage,
  ProviderRequestsPage,
  ProviderTrackingPage,
  QrScannerPage,
  RequestApprovalDetailPage,
  RequestFormPage,
  RequestsListPage,
  UserDetailPage,
  UserEditPage,
  UserFormPage,
  UserManagementPage,
} from './pages'
import { controlIngresosApi } from './services/api'
import { confirmSendDraft, showSuccessAlert } from './utils/alerts'
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
  const location = useLocation()
  const [session, setSession] = useState(readSession)

  useEffect(() => {
    if (!session && location.pathname !== '/login') {
      sessionStorage.setItem('control-ingresos-return-to', `${location.pathname}${location.search}`)
    }
  }, [session, location.pathname, location.search])

  async function login(credentials) {
    const authenticatedUser = await controlIngresosApi.iniciarSesion(credentials)
    localStorage.setItem(sessionKey, JSON.stringify(authenticatedUser))
    setSession(authenticatedUser)
    const returnTo = isGuardSession(authenticatedUser)
      ? '/escanear-qr'
      : isProviderSession(authenticatedUser)
        ? '/portal-proveedor'
        : sessionStorage.getItem('control-ingresos-return-to') || '/dashboard'
    sessionStorage.removeItem('control-ingresos-return-to')
    navigate(returnTo, { replace: true })
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
      <Route path="/credencial/empleado" element={<PublicEmployeeCredentialPage onLogin={() => navigate('/login')} />} />
      <Route path="/credencial/persona" element={<PublicPersonCredentialPage onLogin={() => navigate('/login')} />} />
      <Route path="*" element={<Navigate to="/login" replace />} />
    </Routes>
  }

  if (isGuardSession(session)) {
    return <GuardApp session={session} onLogout={logout} />
  }

  if (isProviderSession(session)) {
    return <ProviderApp session={session} onLogout={logout} />
  }

  return <AuthenticatedApp session={session} onLogout={logout} />
}

function ProviderApp({ session, onLogout }) {
  const navigate = useNavigate()
  const location = useLocation()
  const [menuOpen, setMenuOpen] = useState(false)
  const [error, setError] = useState('')
  const [providerCompany, setProviderCompany] = useState(null)
  const [providerRequests, setProviderRequests] = useState([])
  const [providerPeople, setProviderPeople] = useState([])
  const [providerRequest, setProviderRequest] = useState(null)
  const [providerTracking, setProviderTracking] = useState([])
  const [providerLoading, setProviderLoading] = useState(true)
  const [providerTrackingLoading, setProviderTrackingLoading] = useState(false)
  const [providerSaving, setProviderSaving] = useState(false)
  const requestRoute = matchPath('/portal-proveedor/solicitudes/:id', location.pathname)
  const requestPersonRoute = matchPath('/portal-proveedor/solicitudes/:id/personas/nueva', location.pathname)
  const isTrackingRoute = location.pathname === '/portal-proveedor/seguimiento'

  useEffect(() => {
    let active = true
    Promise.all([
      controlIngresosApi.obtenerMiEmpresaProveedor(),
      controlIngresosApi.listarSolicitudesProveedor(),
      controlIngresosApi.listarPersonasProveedor(),
    ])
      .then(([company, requests, people]) => {
        if (!active) return
        setProviderCompany(company)
        setProviderRequests(requests)
        setProviderPeople(people)
      })
      .catch((requestError) => active && setError(requestError.status === 404
        ? 'La cuenta de proveedor no tiene una empresa asignada.'
        : requestError.message))
      .finally(() => active && setProviderLoading(false))
    return () => { active = false }
  }, [])

  useEffect(() => {
    const id = Number(requestRoute?.params.id)
    if (!id) {
      setProviderRequest(null)
      return undefined
    }
    let active = true
    setProviderLoading(true)
    controlIngresosApi.obtenerSolicitudProveedor(id)
      .then((request) => active && setProviderRequest(request))
      .catch((requestError) => active && setError(requestError.message))
      .finally(() => active && setProviderLoading(false))
    return () => { active = false }
  }, [requestRoute?.params.id])

  useEffect(() => {
    if (!isTrackingRoute) return undefined
    if (providerRequests.length === 0) return undefined

    let active = true
    setProviderTrackingLoading(true)
    Promise.all(providerRequests.map((request) => controlIngresosApi.obtenerSolicitudProveedor(request.idSolicitud)))
      .then((items) => active && setProviderTracking(items.filter(Boolean)))
      .catch((requestError) => active && setError(requestError.message))
      .finally(() => active && setProviderTrackingLoading(false))
    return () => { active = false }
  }, [isTrackingRoute, providerRequests])

  function openPortal() {
    setError('')
    setMenuOpen(false)
    navigate('/portal-proveedor')
  }

  function openRequests() {
    setError('')
    setMenuOpen(false)
    navigate('/portal-proveedor/solicitudes')
  }

  function openTracking() {
    setError('')
    setMenuOpen(false)
    navigate('/portal-proveedor/seguimiento')
  }

  function openPersonForm(requestId = null) {
    setError('')
    setMenuOpen(false)
    navigate(requestId
      ? `/portal-proveedor/solicitudes/${requestId}/personas/nueva`
      : '/portal-proveedor/personas/nueva')
  }

  async function personCreated(created, requestId = null) {
    try {
      setProviderPeople(await controlIngresosApi.listarPersonasProveedor())
    } catch {
      // La persona ya fue creada; el listado se actualizará en la siguiente carga.
    }
    if (requestId) navigate(`/portal-proveedor/solicitudes/${requestId}`)
    else openPortal()
    return created
  }

  async function addProviderPerson(idPersona) {
    const idSolicitud = Number(requestRoute?.params.id)
    if (!idSolicitud) return { success: false }
    setProviderSaving(true)
    setError('')
    try {
      await controlIngresosApi.agregarPersonaSolicitudProveedor(idSolicitud, {
        idPersona,
        idEstadoPersonaSolicitud: null,
        datosCompletos: true,
        observacionesRevision: null,
        areas: [],
        requerimientos: null,
        usuario: session.idUsuario,
      })
      const [detail, requests] = await Promise.all([
        controlIngresosApi.obtenerSolicitudProveedor(idSolicitud),
        controlIngresosApi.listarSolicitudesProveedor(),
      ])
      setProviderRequest(detail)
      setProviderRequests(requests)
      await showSuccessAlert(detail.cantidadPersonas >= detail.cantidadEstimada
        ? 'Se completó el registro de personas y la solicitud avanzó al siguiente estado.'
        : 'La persona fue agregada correctamente a la solicitud.')
      return { success: true }
    } catch (requestError) {
      setError(requestError.message)
      return { success: false, message: requestError.message }
    } finally {
      setProviderSaving(false)
    }
  }

  const breadcrumb = requestPersonRoute
    ? 'Registrar persona'
    : requestRoute
      ? 'Detalle de solicitud'
      : isTrackingRoute
        ? 'Seguimiento'
        : location.pathname === '/portal-proveedor/solicitudes'
        ? 'Solicitudes recibidas'
        : location.pathname.endsWith('/personas/nueva')
          ? 'Registrar persona'
          : 'Inicio'

  return <div className="app-shell">
    <AlertModal message={error} onClose={() => setError('')} />
    {menuOpen && <button className="sidebar-backdrop" onClick={() => setMenuOpen(false)} aria-label="Cerrar menú" />}
    <aside className={`sidebar ${menuOpen ? 'open' : ''}`} aria-label="Navegación del proveedor">
      <div className="sidebar-brand"><img className="sidebar-brand-logo" src={auraLogo} alt="Aura Minerals" /></div>
      <p className="side-label">Portal del proveedor</p>
      <nav className="main-nav">
        <Nav icon="home" label="Inicio" active={location.pathname === '/portal-proveedor'} onClick={openPortal} />
        <Nav icon="file" label="Solicitudes" count={providerRequests.filter((item) => item.codigoEstado === 'PENDIENTE_PROVEEDOR').length || undefined} active={location.pathname.startsWith('/portal-proveedor/solicitudes')} onClick={openRequests} />
        <Nav icon="users" label="Registrar persona" active={location.pathname === '/portal-proveedor/personas/nueva'} onClick={() => openPersonForm()} />
        <Nav icon="check" label="Seguimiento" active={isTrackingRoute} onClick={openTracking} />
      </nav>
      <div className="sidebar-footer">
        <button type="button" className="nav-item" onClick={onLogout}><Icon name="logout" /><span>Cerrar sesión</span></button>
      </div>
    </aside>

    <main className="main">
      <header className="topbar">
        <button className="icon-button menu-button" onClick={() => setMenuOpen((open) => !open)} aria-label="Abrir menú"><Icon name="menu" /></button>
        <div className="breadcrumb"><span>Proveedor</span><strong>{breadcrumb}</strong></div>
        <div className="top-actions">
          <div className="top-profile"><div><strong>{session.nombreCompleto ?? session.idUsuario}</strong><span>Proveedor</span></div><div className="avatar">{initials(session.nombreCompleto)}</div></div>
        </div>
      </header>
      <section className="content">
        <Routes>
          <Route path="/portal-proveedor" element={<ProviderPortalPage session={session} requests={providerRequests} onCreatePerson={() => openPersonForm()} onRequests={openRequests} onTracking={openTracking} />} />
          <Route path="/portal-proveedor/solicitudes" element={<ProviderRequestsPage items={providerRequests} loading={providerLoading} onOpen={(id) => navigate(`/portal-proveedor/solicitudes/${id}`)} />} />
          <Route path="/portal-proveedor/solicitudes/:id" element={<ProviderRequestDetailPage request={providerRequest} people={providerPeople} loading={providerLoading} saving={providerSaving} onBack={location.state?.fromTracking ? openTracking : openRequests} onNewPerson={() => openPersonForm(Number(requestRoute?.params.id))} onAddPerson={addProviderPerson} />} />
          <Route path="/portal-proveedor/solicitudes/:id/personas/nueva" element={<PersonFormPage session={session} providerMode providerCompany={providerCompany} onCancel={() => navigate(`/portal-proveedor/solicitudes/${requestPersonRoute?.params.id}`)} onCreated={(created) => personCreated(created, Number(requestPersonRoute?.params.id))} onError={setError} />} />
          <Route path="/portal-proveedor/personas/nueva" element={<PersonFormPage session={session} providerMode providerCompany={providerCompany} onCancel={openPortal} onCreated={(created) => personCreated(created)} onError={setError} />} />
          <Route path="/portal-proveedor/seguimiento" element={<ProviderTrackingPage items={providerTracking} loading={providerTrackingLoading || providerLoading} onOpen={(id) => navigate(`/portal-proveedor/solicitudes/${id}`, { state: { fromTracking: true } })} />} />
          <Route path="*" element={<Navigate to="/portal-proveedor" replace />} />
        </Routes>
      </section>
    </main>
  </div>
}

function GuardApp({ session, onLogout }) {
  const navigate = useNavigate()
  const location = useLocation()
  const [menuOpen, setMenuOpen] = useState(false)
  const [error, setError] = useState('')

  function openScanner() {
    setError('')
    setMenuOpen(false)
    navigate('/escanear-qr')
  }

  return <div className="app-shell">
    <AlertModal message={error} onClose={() => setError('')} />
    {menuOpen && <button className="sidebar-backdrop" onClick={() => setMenuOpen(false)} aria-label="Cerrar menú" />}
    <aside className={`sidebar ${menuOpen ? 'open' : ''}`} aria-label="Navegación principal">
      <div className="sidebar-brand"><img className="sidebar-brand-logo" src={auraLogo} alt="Aura Minerals" /></div>
      <p className="side-label">Control de ingresos</p>
      <nav className="main-nav">
        <Nav icon="qr" label="Escanear QR" active={location.pathname === '/escanear-qr'} onClick={openScanner} />
      </nav>
      <div className="sidebar-footer">
        <button type="button" className="nav-item" onClick={onLogout}><Icon name="logout" /><span>Cerrar sesión</span></button>
      </div>
    </aside>

    <main className="main">
      <header className="topbar">
        <button className="icon-button menu-button" onClick={() => setMenuOpen((open) => !open)} aria-label="Abrir menú"><Icon name="menu" /></button>
        <div className="breadcrumb"><span>Control de ingreso</span><strong>Escanear QR</strong></div>
        <div className="top-actions">
          <div className="top-profile"><div><strong>{session.nombreCompleto ?? session.idUsuario}</strong><span>Guardia</span></div><div className="avatar">{initials(session.nombreCompleto)}</div></div>
        </div>
      </header>
      <section className="content">
        <Routes>
          <Route path="/escanear-qr" element={<QrScannerPage onError={setError} />} />
          <Route path="*" element={<Navigate to="/escanear-qr" replace />} />
        </Routes>
      </section>
    </main>
  </div>
}

function AuthenticatedApp({ session, onLogout }) {
  const location = useLocation()
  const navigate = useNavigate()
  const isAdministrator = hasRole(session, 'Administrador')
  const canApprove = isAdministrator || hasRole(session, 'Aprobador')
  const editRoute = matchPath('/solicitudes/:id/editar', location.pathname)
  const personQrRoute = matchPath('/personas/:idPersona/qr', location.pathname)
  const personRoute = matchPath('/personas/:idPersona', location.pathname)
  const employeeQrRoute = matchPath('/empleados/:codigoEmpleado/qr', location.pathname)
  const employeeQrCode = employeeQrRoute?.params.codigoEmpleado
  const employeeRoute = employeeQrRoute ? null : matchPath('/empleados/:codigoEmpleado', location.pathname)
  const isNewPersonRoute = location.pathname === '/personas/nueva'
  const isNewProviderRoute = location.pathname === '/proveedores/nuevo'
  const approvalDetailRoute = matchPath('/aprobaciones/:idSolicitudPersonaArea/detalle', location.pathname)
  const isPersonsRoute = location.pathname.startsWith('/personas')
  const isEmployeesRoute = location.pathname.startsWith('/empleados')
  const isQrScannerRoute = location.pathname === '/escanear-qr'
  const isPublicEmployeeCredentialRoute = location.pathname === '/credencial/empleado'
  const isPublicPersonCredentialRoute = location.pathname === '/credencial/persona'
  const isRequestsRoute = location.pathname.startsWith('/solicitudes')
  const isApprovalsRoute = location.pathname.startsWith('/aprobaciones')
  const activityRequestRoute = matchPath('/mis-actividades/solicitudes/:idSolicitud/personas/:idSolicitudPersona', location.pathname)
    ?? matchPath('/mis-actividades/solicitudes/:idSolicitud', location.pathname)
  const isActivitiesRoute = location.pathname.startsWith('/mis-actividades')
  const isActivityWorkflowsRoute = location.pathname === '/configuracion/actividades'
  const isUsersRoute = location.pathname.startsWith('/usuarios')
  const isNewUserRoute = location.pathname === '/usuarios/nuevo'
  const userEditRoute = matchPath('/usuarios/:idUsuario/editar', location.pathname)
  const userDetailRoute = !isNewUserRoute && !userEditRoute ? matchPath('/usuarios/:idUsuario', location.pathname) : null
  const isProfileRoute = location.pathname === '/perfil'
  const isDashboardRoute = location.pathname === '/dashboard' || location.pathname === '/'
  const [step, setStep] = useState(1)
  const [editingId, setEditingId] = useState(null)
  const [form, setForm] = useState(initialForm)
  const [options, setOptions] = useState(null)
  const [solicitudes, setSolicitudes] = useState([])
  const [personas, setPersonas] = useState([])
  const [personasConAccesos, setPersonasConAccesos] = useState([])
  const [empleados, setEmpleados] = useState([])
  const [employeeStatuses, setEmployeeStatuses] = useState([])
  const [employeePhotograph, setEmployeePhotograph] = useState(null)
  const [employeeSingular, setEmployeeSingular] = useState(null)
  const [requestPeople, setRequestPeople] = useState([])
  const [existingRequestPeople, setExistingRequestPeople] = useState([])
  const [peopleEntryMode, setPeopleEntryMode] = useState('')
  const [personaSeleccionada, setPersonaSeleccionada] = useState(null)
  const [aprobaciones, setAprobaciones] = useState([])
  const [actividades, setActividades] = useState([])
  const [actividadesPorAprobar, setActividadesPorAprobar] = useState([])
  const [activityRequestDetail, setActivityRequestDetail] = useState(null)
  const [activityRequestLoading, setActivityRequestLoading] = useState(false)
  const [flujosActividades, setFlujosActividades] = useState([])
  const [activitiesLoading, setActivitiesLoading] = useState(false)
  const [usuarios, setUsuarios] = useState([])
  const [usersLoading, setUsersLoading] = useState(false)
  const [profile, setProfile] = useState(null)
  const [profileLoading, setProfileLoading] = useState(true)
  const [approvalsLoading, setApprovalsLoading] = useState(false)
  const [approvalDetail, setApprovalDetail] = useState(null)
  const [approvalDetailLoading, setApprovalDetailLoading] = useState(false)
  const [personLoading, setPersonLoading] = useState(false)
  const [employeesLoading, setEmployeesLoading] = useState(false)
  const [employeesError, setEmployeesError] = useState('')
  const [employeePhotographLoading, setEmployeePhotographLoading] = useState(false)
  const [employeeSingularLoading, setEmployeeSingularLoading] = useState(false)
  const [employeeSingularError, setEmployeeSingularError] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)
  const [error, setError] = useState('')
  const activeEditingId = editRoute ? editingId : null
  const requestTypeCode = typeCodeFromId(options?.tiposIngreso, form.idTipoIngreso)
  const requestUsesEmployees = requestTypeCode === 'EMPLEADO'

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
    if (requestUsesEmployees && peopleEntryMode !== 'manual') setPeopleEntryMode('manual')
  }, [requestUsesEmployees, peopleEntryMode])

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
        setExistingRequestPeople((item.personas ?? []).map((person) => ({
          ...person,
          areas: person.areas ?? [],
          originalAreas: person.areas ?? [],
        })))
        setRequestPeople([])
        const itemTypeCode = typeCodeFromId(options.tiposIngreso, item.idTipoIngreso)
        setPeopleEntryMode(itemTypeCode === 'EMPLEADO' ? 'employee' : itemTypeCode === 'NUEVO_EMPLEADO' ? 'manual' : item.personas?.length ? 'manual' : item.idProveedor ? 'provider' : '')
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
    if (!isRequestsRoute) return
    let active = true
    controlIngresosApi.listarSolicitudes()
      .then((records) => active && setSolicitudes(records))
      .catch((requestError) => active && setError(requestError.message))
    return () => { active = false }
  }, [isRequestsRoute])

  useEffect(() => {
    if (!isRequestsRoute) return
    let active = true
    controlIngresosApi.obtenerFlujosActividades()
      .then((result) => active && setFlujosActividades(result.areas ?? []))
      .catch((requestError) => active && setError(requestError.message))
    return () => { active = false }
  }, [isRequestsRoute])

  useEffect(() => {
    if (!isPersonsRoute || isNewPersonRoute || personQrRoute) return
    let active = true
    const load = async (showLoading = true) => {
      await Promise.resolve()
      if (!active) return
      if (showLoading) setPersonLoading(true)
      setError('')
      try {
        const records = await controlIngresosApi.listarPersonasConAccesos()
        if (!active) return
        setPersonasConAccesos(records)
        const routeId = Number(personRoute?.params.idPersona)
        const preferred = routeId
          ? records.find((item) => item.idPersona === routeId)
          : records[0]
        if (!preferred) {
          setPersonaSeleccionada(null)
          return
        }
        const detail = await controlIngresosApi.obtenerPersonaAccesos(preferred.idPersona)
        if (active) setPersonaSeleccionada(detail)
      } catch (requestError) {
        if (active) setError(requestError.message)
      } finally {
        if (active && showLoading) setPersonLoading(false)
      }
    }
    load()
    const refreshTimer = window.setInterval(() => load(false), 60_000)
    return () => {
      active = false
      window.clearInterval(refreshTimer)
    }
  }, [isPersonsRoute, isNewPersonRoute, personQrRoute, personRoute?.params.idPersona, session.idUsuario])

  useEffect(() => {
    const requestNeedsEmployees = isRequestsRoute && requestTypeCode === 'EMPLEADO'
    if (!isEmployeesRoute && !requestNeedsEmployees) return
    let active = true
    const load = async () => {
      await Promise.resolve()
      if (!active) return
      setEmployeesLoading(true)
      setEmployeesError('')
      if (isEmployeesRoute) setError('')
      try {
        const records = await controlIngresosApi.listarEmpleados(requestNeedsEmployees)
        let statuses = []
        if (isEmployeesRoute) {
          try {
            statuses = await controlIngresosApi.listarEstadosEmpleado()
          } catch {
            // El catálogo solo traduce el código de estado. Su ausencia no debe
            // impedir consultar el directorio ni el detalle de los empleados.
          }
        }
        if (!active) return
        const descriptions = new Map(statuses.map((status) => [String(status.statusId), status.descripcion]))
        if (isEmployeesRoute) setEmployeeStatuses(statuses)
        setEmpleados(records.map((employee) => ({
          ...employee,
          descripcionStatus: descriptions.get(String(employee.codigoStatus).trim()) ?? null,
        })))
      } catch (requestError) {
        if (active) {
          setEmployeesError(requestError.message)
          if (isEmployeesRoute) setError(requestError.message)
        }
      } finally {
        if (active) setEmployeesLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [isEmployeesRoute, isRequestsRoute, requestTypeCode, session.idUsuario])

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
        const [records, reviewRecords] = await Promise.all([
          controlIngresosApi.listarMisActividades(),
          canApprove ? controlIngresosApi.listarActividades() : Promise.resolve([]),
        ])
        if (active) {
          setActividades(records)
          setActividadesPorAprobar(reviewRecords)
        }
      } catch (requestError) {
        if (active) setError(requestError.message)
      } finally {
        if (active) setActivitiesLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [isActivitiesRoute, canApprove])

  useEffect(() => {
    const idSolicitud = Number(activityRequestRoute?.params.idSolicitud)
    if (!idSolicitud) return
    let active = true
    const load = async () => {
      await Promise.resolve()
      if (!active) return
      setActivityRequestLoading(true)
      setError('')
      try {
        const detail = await controlIngresosApi.obtenerSolicitud(idSolicitud)
        if (active) setActivityRequestDetail(detail)
      } catch (requestError) {
        if (active) setError(requestError.message)
      } finally {
        if (active) setActivityRequestLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [activityRequestRoute?.params.idSolicitud])

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
    estado: findOption(options?.estadosSolicitud, form.idEstadoSolicitud),
    proveedor: findOption(options?.proveedores, form.idProveedor),
    area: findOption(options?.areas, form.idAreaSolicitante),
    ubicacion: findOption(options?.ubicaciones, form.idUbicacion),
    usuario: findOption(options?.usuarios, form.idUsuarioSolicitante),
  }), [form, options])
  const selectedEmployee = useMemo(() => {
    if (!isEmployeesRoute) return null
    const employeeCode = employeeQrRoute?.params.codigoEmpleado ?? employeeRoute?.params.codigoEmpleado
    return (employeeCode
      ? empleados.find((employee) => String(employee.codigoEmpleado) === employeeCode)
      : empleados[0]) ?? null
  }, [isEmployeesRoute, empleados, employeeQrRoute?.params.codigoEmpleado, employeeRoute?.params.codigoEmpleado])

  useEffect(() => {
    const codigoEmpleado = selectedEmployee?.codigoEmpleado
    setEmployeePhotograph(null)

    if (!codigoEmpleado) {
      setEmployeePhotographLoading(false)
      return undefined
    }

    let active = true
    let photographUrl = ''
    const load = async () => {
      setEmployeePhotographLoading(true)
      try {
        const photograph = await controlIngresosApi.obtenerFotografiaEmpleado(codigoEmpleado)
        if (!active || !photograph) return
        photographUrl = URL.createObjectURL(photograph)
        setEmployeePhotograph({ codigoEmpleado, url: photographUrl })
      } catch (requestError) {
        if (active) setError(requestError.message)
      } finally {
        if (active) setEmployeePhotographLoading(false)
      }
    }
    load()

    return () => {
      active = false
      if (photographUrl) URL.revokeObjectURL(photographUrl)
    }
  }, [selectedEmployee?.codigoEmpleado])

  useEffect(() => {
    const codigoEmpleado = selectedEmployee?.codigoEmpleado
    let active = true
    const load = async () => {
      await Promise.resolve()
      if (!active) return
      setEmployeeSingular(null)
      setEmployeeSingularError('')
      if (!codigoEmpleado || employeeQrCode) {
        setEmployeeSingularLoading(false)
        return
      }

      setEmployeeSingularLoading(true)
      try {
        const result = await controlIngresosApi.obtenerAutorizacionesEmpleado(codigoEmpleado)
        if (active) setEmployeeSingular(result)
      } catch (requestError) {
        if (active) setEmployeeSingularError(requestError.message)
      } finally {
        if (active) setEmployeeSingularLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [selectedEmployee?.codigoEmpleado, employeeQrCode])
  const totalRequestPeople = requestPeople.length + existingRequestPeople.length
  const estimatedPeople = Number(form.cantidadEstimada) || 0
  const allExistingPeopleHaveAreas = existingRequestPeople.every((person) => (person.areas ?? []).length > 0)
  const allNewPeopleHaveActivities = requestPeople.every((person) => person.areas.every((idArea) => {
    const configured = flujosActividades.find((area) => Number(area.idArea) === Number(idArea))?.pasos ?? []
    return configured.length === 0 || configured.some((paso) => (person.requerimientos ?? []).includes(paso.idRequerimiento))
  }))
  const canSendRequest = peopleEntryMode === 'provider'
    ? Boolean(form.idProveedor) && totalRequestPeople === 0
    : estimatedPeople > 0 && totalRequestPeople === estimatedPeople
      && requestPeople.every((person) => person.areas.length > 0)
      && allNewPeopleHaveActivities
      && allExistingPeopleHaveAreas

  function change(event) {
    const { name, value } = event.target
    if (name === 'idTipoIngreso') {
      const nextTypeCode = typeCodeFromId(options?.tiposIngreso, value)
      const nextUsesHtis = nextTypeCode === 'EMPLEADO'
      const existingUsesHtis = existingRequestPeople.some((item) => Boolean(item.codigoEmpleadoHtis))
      const existingUsesPeople = existingRequestPeople.some((item) => item.idPersona != null)
      if ((nextUsesHtis && existingUsesPeople) || (!nextUsesHtis && existingUsesHtis)) {
        setError('No puedes cambiar el tipo de ingreso mientras la solicitud tenga integrantes asociados de otro origen.')
        return
      }

      setForm((current) => ({
        ...current,
        idTipoIngreso: value,
        idProveedor: isEmployeeTypeCode(nextTypeCode) ? '' : current.idProveedor,
        contactoProveedor: nextTypeCode === 'EMPLEADO' ? '' : current.contactoProveedor,
        correoProveedor: nextTypeCode === 'EMPLEADO' ? '' : current.correoProveedor,
      }))
      setRequestPeople([])
      setPeopleEntryMode(nextTypeCode === 'EMPLEADO' ? 'employee' : nextTypeCode === 'NUEVO_EMPLEADO' ? 'manual' : '')
      setEmployeesError('')
      setError('')
      return
    }

    setForm((current) => ({ ...current, [name]: value }))
    setError('')
  }

  async function addRequestEmployee(codigoEmpleado) {
    const employee = empleados.find((item) => String(item.codigoEmpleado) === String(codigoEmpleado))
    if (!employee) return
    try {
      const accesosActuales = await controlIngresosApi.listarAccesosEmpleado(codigoEmpleado)
      setRequestPeople((current) => [...current, { codigoEmpleado, areas: [], accesosActuales }])
    } catch (requestError) {
      setError(requestError.message)
      throw requestError
    }
  }

  function next() {
    const steps = requestUsesEmployees ? [1, 3, 4] : [1, 2, 3, 4]
    const currentIndex = steps.indexOf(step)
    goToStep(steps[Math.min(steps.length - 1, currentIndex + 1)])
  }

  function previous() {
    const steps = requestUsesEmployees ? [1, 3, 4] : [1, 2, 3, 4]
    const currentIndex = steps.indexOf(step)
    setStep(steps[Math.max(0, currentIndex - 1)])
  }

  function goToStep(targetStep) {
    for (let currentStep = 1; currentStep < targetStep; currentStep += 1) {
      const validation = validateStep(currentStep, form, requestTypeCode, peopleEntryMode, requestPeople, existingRequestPeople, flujosActividades)
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
    const newForm = withDefaults(initialForm(), options, session.idUsuario)
    const newTypeCode = typeCodeFromId(options?.tiposIngreso, newForm.idTipoIngreso)
    setForm(newForm)
    setRequestPeople([])
    setExistingRequestPeople([])
    setPeopleEntryMode(newTypeCode === 'EMPLEADO' ? 'employee' : newTypeCode === 'NUEVO_EMPLEADO' ? 'manual' : '')
    setStep(1)
    setError('')
    navigate('/solicitudes/nueva')
  }

  function openEdit(id) {
    setError('')
    navigate(`/solicitudes/${id}/editar`)
  }

  function openActivityRequest(idSolicitud, idSolicitudPersona = null) {
    if (!idSolicitud) return
    setError('')
    const personPath = idSolicitudPersona ? `/personas/${idSolicitudPersona}` : ''
    navigate(`/mis-actividades/solicitudes/${idSolicitud}${personPath}`)
  }

  async function remove(id, number) {
    setError('')
    try {
      await controlIngresosApi.eliminarSolicitud(id)
      setSolicitudes(await controlIngresosApi.listarSolicitudes())
      showSuccessAlert(`La solicitud ${number ?? `#${id}`} fue eliminada.`)
      return { success: true }
    } catch (requestError) {
      setError(requestError.message)
      return { success: false, message: requestError.message }
    }
  }

  function openPersons() {
    navigate('/personas')
    setMenuOpen(false)
    setError('')
  }

  function openEmployees() {
    navigate('/empleados')
    setMenuOpen(false)
    setError('')
  }

  function openNewPerson() {
    navigate('/personas/nueva')
    setMenuOpen(false)
    setError('')
  }

  function openNewProvider() {
    navigate('/proveedores/nuevo')
    setMenuOpen(false)
    setError('')
  }

  function personCreated(created) {
    setPersonas([])
    setPersonasConAccesos([])
    setPersonaSeleccionada(null)
    setError('')
    showSuccessAlert(`La persona #${created.id} fue registrada correctamente.`)
    navigate('/personas')
  }

  function openProfile() {
    navigate('/perfil')
    setMenuOpen(false)
    setError('')
  }

  function selectPerson(idPersona) {
    setError('')
    navigate(`/personas/${idPersona}`, { state: { directory: 'personas' } })
  }

  function selectEmployee(employee) {
    if (!employee?.codigoEmpleado) return
    setError('')
    navigate(`/empleados/${encodeURIComponent(employee.codigoEmpleado)}`, { state: { directory: 'empleados' } })
  }

  async function updatePersonPhotograph(idPersona, photograph) {
    setError('')
    try {
      await controlIngresosApi.actualizarFotografiaPersona(idPersona, photograph)
      const detail = await controlIngresosApi.obtenerPersonaAccesos(idPersona)
      setPersonaSeleccionada(detail)
      await showSuccessAlert('La fotografía fue actualizada correctamente.')
      return { success: true }
    } catch (requestError) {
      setError(requestError.message)
      return { success: false, message: requestError.message }
    }
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
      const [approvalRecords, requestRecords] = await Promise.all([
        controlIngresosApi.listarAprobaciones(),
        controlIngresosApi.listarSolicitudes(),
      ])
      setAprobaciones(approvalRecords)
      setSolicitudes(requestRecords)
    } catch (requestError) {
      setError(requestError.message)
    }
    return { successIds, failures }
  }

  async function completeActivity(idActividad, comentarios = null) {
    setError('')
    try {
      await controlIngresosApi.completarActividad(idActividad, comentarios?.trim() || null)
      const [records, reviewRecords, approvalRecords] = await Promise.all([
        controlIngresosApi.listarMisActividades(),
        canApprove ? controlIngresosApi.listarActividades() : Promise.resolve([]),
        canApprove ? controlIngresosApi.listarAprobaciones() : Promise.resolve(aprobaciones),
      ])
      setActividades(records)
      setActividadesPorAprobar(reviewRecords)
      if (canApprove) setAprobaciones(approvalRecords)
      showSuccessAlert('La actividad fue registrada y aprobada automaticamente.')
      return { success: true }
    } catch (requestError) {
      setError(requestError.message)
      return { success: false, message: requestError.message }
    }
  }

  async function decideActivity(idActividad, codigoEstado, comentarioDecision = null) {
    setError('')
    try {
      await controlIngresosApi.decidirActividad(idActividad, {
        codigoEstado,
        comentarioDecision: comentarioDecision?.trim() || null,
      })
      const [records, reviewRecords] = await Promise.all([
        controlIngresosApi.listarMisActividades(),
        controlIngresosApi.listarActividades(),
      ])
      setActividades(records)
      setActividadesPorAprobar(reviewRecords)
      showSuccessAlert(codigoEstado === 'APROBADA' ? 'La actividad fue aprobada.' : 'La actividad fue rechazada.')
      return { success: true }
    } catch (requestError) {
      setError(requestError.message)
      return { success: false, message: requestError.message }
    }
  }

  async function createUser(user) {
    setError('')
    try {
      await controlIngresosApi.crearUsuario(user)
      try {
        setUsuarios(await controlIngresosApi.listarUsuarios())
      } catch {
        // La creación ya fue confirmada por el servidor. El listado se recargará
        // al volver a entrar para que un fallo de refresco no simule un fallo al crear.
      }
      await showSuccessAlert('El usuario fue creado correctamente.')
      navigate('/usuarios')
      return { success: true }
    } catch (requestError) {
      setError(requestError.message)
      return { success: false, message: requestError.message }
    }
  }

  async function createProvider(provider) {
    setError('')
    try {
      const created = await controlIngresosApi.crearProveedor(provider)
      let refreshedOptions = null
      try {
        refreshedOptions = await controlIngresosApi.obtenerDatosFormularioSolicitud()
        setOptions(refreshedOptions)
      } catch {
        // El proveedor ya fue creado; el catálogo se actualizará al recargar la aplicación.
      }

      const message = created.credencialesEnviadas
        ? `El proveedor #${created.id} y el usuario ${created.idUsuario} fueron creados. Las credenciales se enviaron a su correo.`
        : `El proveedor #${created.id} y el usuario ${created.idUsuario} fueron creados, pero el correo no pudo enviarse. Contraseña temporal: ${created.contrasenaTemporal}`
      await showSuccessAlert(message)
      if (refreshedOptions) {
        setEditingId(null)
        setRequestPeople([])
        setExistingRequestPeople([])
        setPeopleEntryMode('')
        setStep(1)
        setForm({
          ...withDefaults(initialForm(), refreshedOptions, session.idUsuario),
          idProveedor: String(created.id),
        })
        navigate('/solicitudes/nueva')
      } else {
        navigate('/solicitudes')
      }
      return { success: true, id: created.id }
    } catch (requestError) {
      setError(requestError.message)
      return { success: false, message: requestError.message }
    }
  }

  async function updateUser(idUsuario, user) {
    setError('')
    try {
      await controlIngresosApi.actualizarUsuario(idUsuario, user)
      setUsuarios(await controlIngresosApi.listarUsuarios())
      await showSuccessAlert('El usuario fue actualizado correctamente.')
      navigate(`/usuarios/${encodeURIComponent(idUsuario)}`)
      return { success: true }
    } catch (requestError) {
      setError(requestError.message)
      return { success: false, message: requestError.message }
    }
  }

  async function submit(sendAfterSave = false) {
    if (step !== 4) return
    if (editRoute && !activeEditingId) {
      setError('No fue posible cargar la solicitud que deseas editar.')
      return
    }
    for (let currentStep = 1; currentStep <= 3; currentStep += 1) {
      const validation = validateStep(currentStep, form, requestTypeCode, peopleEntryMode, requestPeople, existingRequestPeople, flujosActividades)
      if (validation) {
        setStep(currentStep)
        setError(validation)
        return
      }
    }
    if (sendAfterSave && !canSendRequest) {
      setStep(3)
      setError(`Completa las ${estimatedPeople} personas indicadas antes de enviar la solicitud.`)
      return
    }
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
        idProveedor: isEmployeeTypeCode(requestTypeCode) ? null : numberOrNull(form.idProveedor),
        numeroContrato: textOrNull(form.numeroContrato),
        contactoProveedor: requestTypeCode === 'EMPLEADO' ? null : textOrNull(form.contactoProveedor),
        correoProveedor: requestTypeCode === 'EMPLEADO' ? null : textOrNull(form.correoProveedor),
        cantidadEstimada: numberOrNull(form.cantidadEstimada),
        idAreaSolicitante: numberOrNull(form.idAreaSolicitante),
        idUsuarioSolicitante: form.idUsuarioSolicitante,
        idUbicacion: numberOrNull(form.idUbicacion),
        observaciones: textOrNull(form.observaciones),
        usuario: session.idUsuario,
      }
      const personPayloads = requestPeople.map((person) => ({
        idPersona: person.idPersona ?? null,
        codigoEmpleadoHtis: person.codigoEmpleadoHtis ?? null,
        idEstadoPersonaSolicitud: null,
        datosCompletos: true,
        observacionesRevision: null,
        areas: person.areas,
        requerimientos: (person.requerimientos ?? []).map((idRequerimiento) => ({
          idRequerimiento,
          idTipoAplicacion: null,
          seleccionado: true,
          configuradoAutomatico: false,
          observaciones: null,
        })),
        usuario: session.idUsuario,
      }))
      const created = activeEditingId
        ? await controlIngresosApi.actualizarSolicitud(activeEditingId, payload)
        : await controlIngresosApi.crearSolicitudCompleta({ solicitud: payload, personas: personPayloads })
      const requestId = activeEditingId ?? created.id
      const failedPeople = []
      const peopleToAdd = activeEditingId ? personPayloads : []
      for (const person of peopleToAdd) {
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
      for (const person of existingRequestPeople) {
        const areas = person.areas ?? []
        const originalAreas = person.originalAreas ?? []
        if (JSON.stringify([...areas].sort()) !== JSON.stringify([...originalAreas].sort())) {
          await controlIngresosApi.asignarAreasPersonaSolicitud(requestId, person.idSolicitudPersona, areas)
        }
      }
      let shouldSend = sendAfterSave
      if (!activeEditingId && canSendRequest) {
        shouldSend = await confirmSendDraft(created.numero ?? `#${created.id}`)
      }
      if (shouldSend) {
        await controlIngresosApi.enviarSolicitud(requestId)
        showSuccessAlert(activeEditingId ? 'La solicitud fue actualizada y enviada correctamente.' : `Se creó y envió ${created.numero ?? `la solicitud #${created.id}`}.`)
      } else {
        showSuccessAlert(activeEditingId ? 'La solicitud fue actualizada correctamente.' : `Se creó ${created.numero ?? `la solicitud #${created.id}`} como borrador.`)
      }
      setSolicitudes(await controlIngresosApi.listarSolicitudes())
      setForm(withDefaults(initialForm(), options, session.idUsuario))
      setRequestPeople([])
      setExistingRequestPeople([])
      setPeopleEntryMode('')
      setEmployeesError('')
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
    setEmployeesError('')
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
          <Nav icon="tasks" label="Mis actividades" count={(actividades.filter((item) => !item.esEstadoFinal).length + (canApprove ? actividadesPorAprobar.filter((item) => item.codigoEstado === 'PENDIENTE_APROBACION').length : 0)) || undefined} active={isActivitiesRoute} onClick={() => { navigate('/mis-actividades'); setMenuOpen(false); setError('') }} />
          {isAdministrator && <Nav icon="settings" label="Flujos de acceso" active={isActivityWorkflowsRoute} onClick={() => { navigate('/configuracion/actividades'); setMenuOpen(false); setError('') }} />}
          <Nav icon="users" label="Personas" count={personas.length || undefined} active={isPersonsRoute} onClick={openPersons} />
          <Nav icon="user" label="Empleados" count={empleados.length || undefined} active={isEmployeesRoute} onClick={openEmployees} />
          <Nav icon="company" label="Nuevo proveedor" active={isNewProviderRoute} onClick={openNewProvider} />
          <Nav icon="qr" label="Escanear QR" active={isQrScannerRoute} onClick={() => { navigate('/escanear-qr'); setMenuOpen(false); setError('') }} />
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
            <strong>{approvalDetailRoute ? 'Detalle de solicitud' : activityRequestRoute ? 'Consulta de solicitud' : isDashboardRoute ? 'Dashboard' : isProfileRoute ? 'Mi perfil' : isNewUserRoute ? 'Crear usuario' : userEditRoute ? 'Editar usuario' : userDetailRoute ? 'Detalle del usuario' : isUsersRoute ? 'Usuarios' : isActivityWorkflowsRoute ? 'Flujos de acceso' : isActivitiesRoute ? 'Mis actividades' : isApprovalsRoute ? 'Mis aprobaciones' : isQrScannerRoute ? 'Escanear QR' : isPublicEmployeeCredentialRoute ? 'Credencial del empleado' : isPublicPersonCredentialRoute ? 'Credencial de la persona' : personQrRoute ? 'QR de la persona' : employeeQrRoute ? 'QR del empleado' : isNewPersonRoute ? 'Nueva persona' : isNewProviderRoute ? 'Nuevo proveedor' : isPersonsRoute ? 'Personas y accesos' : isEmployeesRoute ? 'Empleados' : editRoute ? 'Editar solicitud' : location.pathname === '/solicitudes/nueva' ? 'Nueva solicitud' : 'Solicitudes'}</strong>
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
            <Route path="/mis-actividades" element={<MyActivitiesPage items={actividades} reviewItems={actividadesPorAprobar} canApprove={canApprove} loading={activitiesLoading} onRequest={openActivityRequest} onComplete={completeActivity} onDecide={decideActivity} />} />
            <Route path="/mis-actividades/solicitudes/:idSolicitud" element={<ActivityRequestDetailPage request={activityRequestDetail} activities={(canApprove ? actividadesPorAprobar : actividades).filter((item) => Number(item.idSolicitud) === Number(activityRequestRoute?.params.idSolicitud))} options={options} loading={activityRequestLoading} onBack={() => navigate('/mis-actividades')} />} />
            <Route path="/mis-actividades/solicitudes/:idSolicitud/personas/:idSolicitudPersona" element={<ActivityRequestDetailPage request={activityRequestDetail} activities={(canApprove ? actividadesPorAprobar : actividades).filter((item) => Number(item.idSolicitud) === Number(activityRequestRoute?.params.idSolicitud) && Number(item.idSolicitudPersona) === Number(activityRequestRoute?.params.idSolicitudPersona))} options={options} loading={activityRequestLoading} onBack={() => navigate('/mis-actividades')} />} />
            <Route path="/configuracion/actividades" element={isAdministrator ? <ActivityWorkflowPage onError={setError} /> : <Navigate to="/dashboard" replace />} />
            <Route path="/usuarios" element={isAdministrator ? <UserManagementPage items={usuarios} loading={usersLoading} onNew={() => { setError(''); navigate('/usuarios/nuevo') }} onSelect={(idUsuario) => { setError(''); navigate(`/usuarios/${encodeURIComponent(idUsuario)}`) }} /> : <Navigate to="/dashboard" replace />} />
            <Route path="/usuarios/nuevo" element={isAdministrator ? <UserFormPage areas={options?.areas ?? []} onCreate={createUser} onCancel={() => { setError(''); navigate('/usuarios') }} /> : <Navigate to="/dashboard" replace />} />
            <Route path="/usuarios/:idUsuario" element={isAdministrator ? <UserDetailPage idUsuario={userDetailRoute?.params.idUsuario ?? ''} onBack={() => { setError(''); navigate('/usuarios') }} onEdit={() => { setError(''); navigate(`/usuarios/${encodeURIComponent(userDetailRoute?.params.idUsuario ?? '')}/editar`) }} onError={setError} /> : <Navigate to="/dashboard" replace />} />
            <Route path="/usuarios/:idUsuario/editar" element={isAdministrator ? <UserEditPage idUsuario={userEditRoute?.params.idUsuario ?? ''} areas={options?.areas ?? []} onUpdate={(user) => updateUser(userEditRoute?.params.idUsuario ?? '', user)} onCancel={() => { setError(''); navigate(`/usuarios/${encodeURIComponent(userEditRoute?.params.idUsuario ?? '')}`) }} onError={setError} /> : <Navigate to="/dashboard" replace />} />
            <Route path="/perfil" element={<ProfilePage profile={profile} loading={profileLoading} onOpenRequest={openEdit} />} />
            <Route path="/solicitudes" element={<RequestsListPage items={solicitudes} loading={loading} onNew={openNew} onEdit={openEdit} onDelete={remove} />} />
            <Route path="/solicitudes/nueva" element={<RequestFormPage form={form} options={options} activityFlows={flujosActividades} people={personas} employees={empleados} employeesLoading={employeesLoading} employeesError={employeesError} requestPeople={requestPeople} existingPeople={existingRequestPeople} peopleEntryMode={peopleEntryMode} loading={loading} saving={saving} editingId={null} step={step} selected={selected} canSend={canSendRequest} onPeopleEntryModeChange={(mode) => { setPeopleEntryMode(mode); if (mode === 'provider') setRequestPeople([]) }} onPeopleChange={setRequestPeople} onChange={change} onStepChange={goToStep} onNext={next} onBack={() => setStep((current) => current - 1)} onCancel={cancelForm} onSubmit={submit} />} />
            <Route path="/solicitudes/:id/editar" element={<RequestFormPage form={form} options={options} activityFlows={flujosActividades} people={personas} employees={empleados} employeesLoading={employeesLoading} employeesError={employeesError} requestPeople={requestPeople} existingPeople={existingRequestPeople} peopleEntryMode={peopleEntryMode} loading={loading} saving={saving} editingId={activeEditingId} step={step} selected={selected} canSend={canSendRequest} onPeopleEntryModeChange={(mode) => { setPeopleEntryMode(mode); if (mode === 'provider') setRequestPeople([]) }} onPeopleChange={setRequestPeople} onChange={change} onStepChange={goToStep} onNext={next} onBack={() => setStep((current) => current - 1)} onCancel={cancelForm} onSubmit={submit} />} />
            <Route path="/proveedores/nuevo" element={<ProviderFormPage session={session} onCreate={createProvider} onCancel={() => { setError(''); navigate('/solicitudes') }} onError={setError} />} />
            <Route path="/personas/nueva" element={<PersonFormPage session={session} providers={options?.proveedores} onCancel={openPersons} onCreated={personCreated} onError={setError} />} />
            <Route path="/personas/:idPersona/qr" element={<PersonQrPage idPersona={Number(personQrRoute?.params.idPersona)} onBack={() => navigate(`/personas/${personQrRoute?.params.idPersona}`)} onError={setError} />} />
            <Route path="/personas/:idPersona?" element={<PersonAccessPage items={personasConAccesos} selected={personaSeleccionada} loading={personLoading} mobileDetailOpen={Boolean(personRoute)} onSelect={selectPerson} onBack={() => location.state?.directory === 'personas' ? navigate(-1) : navigate('/personas')} onNew={openNewPerson} onQr={(idPersona) => navigate(`/personas/${idPersona}/qr`)} onPhotographChange={updatePersonPhotograph} />} />
            <Route path="/empleados/:codigoEmpleado/qr" element={<EmployeeQrPage codigoEmpleado={employeeQrRoute?.params.codigoEmpleado ?? ''} employee={selectedEmployee} photographUrl={employeePhotograph?.codigoEmpleado === selectedEmployee?.codigoEmpleado ? employeePhotograph?.url ?? '' : ''} loading={employeesLoading || employeePhotographLoading} onBack={() => navigate(`/empleados/${encodeURIComponent(employeeQrRoute?.params.codigoEmpleado ?? '')}`)} onError={setError} />} />
            <Route path="/empleados/:codigoEmpleado?" element={<EmployeeListPage items={empleados} statuses={employeeStatuses} selected={selectedEmployee} loading={employeesLoading} photographUrl={employeePhotograph?.codigoEmpleado === selectedEmployee?.codigoEmpleado ? employeePhotograph?.url ?? '' : ''} photographLoading={employeePhotographLoading} singular={employeeSingular} singularLoading={employeeSingularLoading} singularError={employeeSingularError} mobileDetailOpen={Boolean(employeeRoute)} onSelect={selectEmployee} onBack={() => location.state?.directory === 'empleados' ? navigate(-1) : navigate('/empleados')} onQr={(codigoEmpleado) => navigate(`/empleados/${encodeURIComponent(codigoEmpleado)}/qr`)} />} />
            <Route path="/escanear-qr" element={<QrScannerPage onError={setError} />} />
            <Route path="/credencial/empleado" element={<PublicEmployeeCredentialPage authenticated />} />
            <Route path="/credencial/persona" element={<PublicPersonCredentialPage authenticated />} />
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
  const idTipoIngreso = form.idTipoIngreso || String(options.tiposIngreso[0]?.id ?? '')
  const typeCode = typeCodeFromId(options.tiposIngreso, idTipoIngreso)
  return {
    ...form,
    idTipoIngreso,
    idEstadoSolicitud: form.idEstadoSolicitud || String(options.estadosSolicitud[0]?.id ?? ''),
    idProveedor: isEmployeeTypeCode(typeCode) ? '' : form.idProveedor || String(options.proveedores[0]?.id ?? ''),
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

function validateStep(step, form, typeCode, peopleEntryMode, requestPeople = [], existingPeople = [], activityFlows = []) {
  if (step === 1 && (!form.idTipoIngreso || !form.nombreActividad.trim() || !form.fechaInicio || !form.fechaFin)) return 'Completa el tipo, nombre y fechas de la actividad.'
  if (step === 1 && form.fechaFin < form.fechaInicio) return 'La fecha final no puede ser anterior a la fecha inicial.'
  const estimatedPeople = Number(form.cantidadEstimada)
  const totalPeople = requestPeople.length + existingPeople.length
  if (step === 1 && (!Number.isInteger(estimatedPeople) || estimatedPeople < 1)) return 'La cantidad estimada de personas debe ser un número entero mayor que cero.'
  if (step === 1 && totalPeople > estimatedPeople) return `La cantidad estimada no puede ser menor que las ${totalPeople} personas ya agregadas.`
  if (step === 2 && typeCode !== 'EMPLEADO' && (!form.contactoProveedor.trim() || !form.correoProveedor.trim())) return typeCode === 'NUEVO_EMPLEADO' ? 'Completa el nombre y el correo del nuevo empleado.' : 'Completa el contacto y el correo del proveedor.'
  if (step === 2 && typeCode !== 'EMPLEADO' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.correoProveedor.trim())) return 'Ingresa un correo electrónico válido.'
  if (step === 2 && (!form.idAreaSolicitante || !form.idUbicacion || !form.idUsuarioSolicitante)) return 'Selecciona el área, la ubicación y el usuario solicitante.'
  if (step === 3 && !isEmployeeTypeCode(typeCode) && !peopleEntryMode) return 'Indica quién ingresará las personas de la solicitud.'
  if (step === 3 && peopleEntryMode === 'provider' && !form.idProveedor) return 'Selecciona un proveedor en el paso de información básica.'
  if (step === 3 && totalPeople > estimatedPeople) return `Solo puedes agregar ${estimatedPeople} persona(s) a esta solicitud.`
  if (step === 3 && peopleEntryMode !== 'provider' && requestPeople.some((person) => person.areas.length === 0)) return 'Selecciona al menos un área para cada integrante agregado.'
  if (step === 3 && peopleEntryMode !== 'provider' && requestPeople.some((person) => person.areas.some((idArea) => {
    const configured = activityFlows.find((area) => Number(area.idArea) === Number(idArea))?.pasos ?? []
    return configured.length > 0 && !configured.some((paso) => (person.requerimientos ?? []).includes(paso.idRequerimiento))
  }))) return 'Selecciona al menos una actividad para cada área configurada de la persona.'
  if (step === 3 && typeCode === 'EMPLEADO' && requestPeople.some((person) => !person.codigoEmpleadoHtis || person.idPersona != null)) return 'Selecciona los empleados desde HTIS.'
  if (step === 3 && typeCode !== 'EMPLEADO' && requestPeople.some((person) => person.idPersona == null || person.codigoEmpleadoHtis)) return 'Selecciona personas registradas en Control Ingresos.'
  return ''
}

const findOption = (items, id) => items?.find((item) => String(item.id) === String(id))
const typeCodeFromId = (items, id) => findOption(items, id)?.codigo?.trim().toUpperCase() ?? ''
const isEmployeeTypeCode = (typeCode) => typeCode === 'EMPLEADO' || typeCode === 'NUEVO_EMPLEADO'
const stringValue = (value) => value == null ? '' : String(value)
const numberOrNull = (value) => value === '' ? null : Number(value)
const textOrNull = (value) => value.trim() === '' ? null : value.trim()
const hasRole = (session, role) => Boolean(
  session.roles?.some((item) => item.toLowerCase() === role.toLowerCase())
  || (role === 'Administrador' && session.puesto?.toLowerCase().includes('administrador'))
  || (role === 'Aprobador' && session.esAprobador),
)

const isGuardSession = (session) => hasRole(session, 'Guardia') && !hasRole(session, 'Administrador')
const isProviderSession = (session) => hasRole(session, 'Proveedor') && !hasRole(session, 'Administrador')

function readSession() {
  try {
    return JSON.parse(localStorage.getItem(sessionKey))
  } catch {
    localStorage.removeItem(sessionKey)
    return null
  }
}

export default App
