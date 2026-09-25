const API_URL = (import.meta.env.VITE_API_URL ?? 'https://localhost:7230').replace(/\/$/, '')

async function request(path, options = {}) {
  const response = await fetch(`${API_URL}${path}`, {
    ...options,
    credentials: 'include',
    headers: {
      Accept: 'application/json',
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
      ...options.headers,
    },
  })

  if (!response.ok) {
    const problem = await response.json().catch(() => null)

    const validationMessages = problem?.errors
      ? Object.values(problem.errors).flat().join(' ')
      : null

    const error = new Error(
      problem?.detail
      ?? validationMessages
      ?? problem?.title
      ?? `Error HTTP ${response.status}`,
    )

    error.status = response.status
    error.problem = problem

    if (response.status === 401 && path !== '/api/autenticacion/login') {
      localStorage.removeItem('control-ingresos-session')
      window.location.assign('/login')
    }

    throw error
  }

  if (response.status === 204) return null

  return response.json()
}

export const controlIngresosApi = {
  iniciarSesion: (credentials) => request('/api/autenticacion/login', {
    method: 'POST',
    body: JSON.stringify(credentials),
  }),
  cerrarSesion: () => request('/api/autenticacion/logout', { method: 'POST' }),
  obtenerMiPerfil: () => request('/api/autenticacion/perfil'),
  listarUsuarios: () => request('/api/usuarios'),
  crearUsuario: (usuario) => request('/api/usuarios', {
    method: 'POST',
    body: JSON.stringify(usuario),
  }),
  listarCatalogo: (catalogo) => request(`/api/catalogos/${encodeURIComponent(catalogo)}`),
  crearProveedor: (proveedor) => request('/api/proveedores', {
    method: 'POST',
    body: JSON.stringify(proveedor),
  }),

  crearPersona: (persona) => request('/api/personas', {
    method: 'POST',
    body: JSON.stringify(persona),
  }),
  listarPersonas: () => request('/api/personas'),
  obtenerPersonaAccesos: (id) => request(`/api/personas/${id}/accesos`),
  listarAprobaciones: () => request('/api/aprobaciones'),
  listarMisActividades: () => request('/api/actividades/mias'),
  decidirAprobacion: (idSolicitudPersonaArea, decision) => request(`/api/aprobaciones/${idSolicitudPersonaArea}/decision`, {
    method: 'PUT',
    body: JSON.stringify(decision),
  }),
  completarActividad: (idActividad, comentarios) => request(`/api/actividades/${idActividad}/completar`, {
    method: 'PUT',
    body: JSON.stringify({ comentarios }),
  }),
  listarSolicitudes: () => request('/api/solicitudes'),
  obtenerDatosFormularioSolicitud: () => request('/api/solicitudes/formulario-datos'),
  obtenerSolicitud: (id) => request(`/api/solicitudes/${id}`),
  crearSolicitud: (solicitud) => request('/api/solicitudes', {
    method: 'POST',
    body: JSON.stringify(solicitud),
  }),
  crearSolicitudCompleta: (payload) => request('/api/solicitudes/completa', {
    method: 'POST',
    body: JSON.stringify(payload),
  }),
  enviarSolicitud: (id) => request(`/api/solicitudes/${id}/enviar`, { method: 'POST' }),

  actualizarSolicitud: (id, solicitud) =>
    request(`/api/solicitudes/${id}`, {
      method: 'PUT',
      body: JSON.stringify(solicitud),
    }),

  eliminarSolicitud: (id) => request(`/api/solicitudes/${id}`, { method: 'DELETE' }),

  agregarPersonaSolicitud: (idSolicitud, persona) =>
    request(`/api/solicitudes/${idSolicitud}/personas`, {
      method: 'POST',
      body: JSON.stringify(persona),
    }),
  listarMovimientosIngreso: () => request('/api/control-accesos/movimientos'),
  registrarMovimientoIngreso: (movimiento) => request('/api/control-accesos/movimientos', {
    method: 'POST',
    body: JSON.stringify(movimiento),
  }),
}
