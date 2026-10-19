const configuredApiUrl = import.meta.env.VITE_API_URL?.trim()
const defaultApiUrl = import.meta.env.DEV ? 'https://localhost:7230' : '/backend'
export const API_URL = (configuredApiUrl || defaultApiUrl)
  .replace(/\/$/, '')

async function request(path, options = {}, redirectOnUnauthorized = true) {
  const bodyIsFormData = options.body instanceof FormData
  const response = await fetch(`${API_URL}${path}`, {
    ...options,
    credentials: 'include',
    headers: {
      Accept: 'application/json',
      ...(options.body && !bodyIsFormData ? { 'Content-Type': 'application/json' } : {}),
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

    if (redirectOnUnauthorized && response.status === 401 && path !== '/api/autenticacion/login') {
      localStorage.removeItem('control-ingresos-session')
      window.location.assign('/login')
    }

    throw error
  }

  if (response.status === 204) return null

  return response.json()
}

async function requestBlob(path, redirectOnUnauthorized = true) {
  const response = await fetch(`${API_URL}${path}`, {
    credentials: 'include',
    headers: { Accept: 'image/*' },
  })

  if (response.status === 404) return null

  if (!response.ok) {
    const problem = await response.json().catch(() => null)
    const error = new Error(problem?.detail ?? problem?.title ?? `Error HTTP ${response.status}`)
    error.status = response.status
    error.problem = problem

    if (redirectOnUnauthorized && response.status === 401) {
      localStorage.removeItem('control-ingresos-session')
      window.location.assign('/login')
    }

    throw error
  }

  return response.blob()
}

export const controlIngresosApi = {
  iniciarSesion: (credentials) => request('/api/autenticacion/login', {
    method: 'POST',
    body: JSON.stringify(credentials),
  }),
  cerrarSesion: () => request('/api/autenticacion/logout', { method: 'POST' }),
  obtenerMiPerfil: () => request('/api/autenticacion/perfil'),
  listarUsuarios: () => request('/api/usuarios'),
  obtenerUsuario: (idUsuario) => request(`/api/usuarios/${encodeURIComponent(idUsuario)}`),
  crearUsuario: (usuario) => request('/api/usuarios', {
    method: 'POST',
    body: JSON.stringify(usuario),
  }),
  actualizarUsuario: (idUsuario, usuario) => request(`/api/usuarios/${encodeURIComponent(idUsuario)}`, {
    method: 'PUT',
    body: JSON.stringify(usuario),
  }),
  listarCatalogo: (catalogo) => request(`/api/catalogos/${encodeURIComponent(catalogo)}`),
  crearProveedor: (proveedor) => request('/api/proveedores', {
    method: 'POST',
    body: JSON.stringify(proveedor),
  }),
  obtenerMiEmpresaProveedor: () => request('/api/proveedores/mi-empresa'),
  listarSolicitudesProveedor: () => request('/api/proveedores/solicitudes'),
  obtenerSolicitudProveedor: (id) => request(`/api/proveedores/solicitudes/${id}`),
  listarPersonasProveedor: () => request('/api/proveedores/personas'),
  agregarPersonaSolicitudProveedor: (idSolicitud, persona) => request(`/api/proveedores/solicitudes/${idSolicitud}/personas`, {
    method: 'POST',
    body: JSON.stringify(persona),
  }),

  crearPersona: (persona) => request('/api/personas', {
    method: 'POST',
    body: JSON.stringify(persona),
  }),
  subirFotografiaPersona: (archivo) => {
    const formData = new FormData()
    formData.append('archivo', archivo)
    return request('/api/personas/fotografia', {
      method: 'POST',
      body: formData,
    })
  },
  actualizarFotografiaPersona: (idPersona, archivo) => {
    const formData = new FormData()
    formData.append('archivo', archivo)
    return request(`/api/personas/${idPersona}/fotografia`, {
      method: 'POST',
      body: formData,
    })
  },
  listarPersonas: () => request('/api/personas'),
  listarEmpleados: (soloActivos = false) => request(`/api/empleados${soloActivos ? '?soloActivos=true' : ''}`),
  listarAccesosEmpleado: (codigoEmpleado) => request(`/api/empleados/${encodeURIComponent(codigoEmpleado)}/accesos`),
  listarEstadosEmpleado: () => request('/api/empleados/estados'),
  obtenerFotografiaEmpleado: (codigoEmpleado) => requestBlob(`/api/empleados/${encodeURIComponent(codigoEmpleado)}/fotografia`),
  obtenerQrEmpleado: (codigoEmpleado) => request(`/api/empleados/${encodeURIComponent(codigoEmpleado)}/qr`),
  consultarQrEmpleado: (codigoQr) => request(`/api/empleados/qr/${encodeURIComponent(codigoQr)}`),
  obtenerAutorizacionesEmpleado: (codigoEmpleado) => request(`/api/empleados/${encodeURIComponent(codigoEmpleado)}/autorizaciones`),
  consultarCredencialPublicaEmpleado: (codigoQr) => request(`/api/publico/empleados/qr/${encodeURIComponent(codigoQr)}`, {}, false),
  obtenerFotografiaPublicaEmpleado: (codigoQr) => requestBlob(`/api/publico/empleados/qr/${encodeURIComponent(codigoQr)}/fotografia`, false),
  agregarEmpleadoSolicitud: (idSolicitud, empleado) => request(`/api/solicitudes/${idSolicitud}/empleados`, {
    method: 'POST',
    body: JSON.stringify(empleado),
  }),
  listarPersonasConAccesos: () => request('/api/personas/accesos'),
  obtenerPersonaAccesos: (id) => request(`/api/personas/${id}/accesos`),
  obtenerQrPersona: (id) => request(`/api/personas/${id}/qr`),
  obtenerFotografiaPersona: (id) => request(`/api/personas/${id}/fotografia-contenido`),
  consultarQrPersona: (codigoQr) => request(`/api/personas/qr/${encodeURIComponent(codigoQr)}`),
  consultarCredencialPublicaPersona: (codigoQr) => request(`/api/publico/personas/qr/${encodeURIComponent(codigoQr)}`, {}, false),
  obtenerFotografiaPublicaPersona: (codigoQr) => requestBlob(`/api/publico/personas/qr/${encodeURIComponent(codigoQr)}/fotografia`, false),
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
  asignarAreasPersonaSolicitud: (idSolicitud, idSolicitudPersona, areas) =>
    request(`/api/solicitudes/${idSolicitud}/personas/${idSolicitudPersona}/areas`, {
      method: 'PUT',
      body: JSON.stringify({ areas }),
    }),
}
