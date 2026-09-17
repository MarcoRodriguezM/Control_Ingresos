const API_URL = (import.meta.env.VITE_API_URL ?? 'https://localhost:7230').replace(/\/$/, '')

async function request(path, options = {}) {
  const response = await fetch(`${API_URL}${path}`, {
    ...options,
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
    throw error
  }

  if (response.status === 204) return null
  return response.json()
}

export const controlIngresosApi = {
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
  listarSolicitudes: () => request('/api/solicitudes'),
  obtenerDatosFormularioSolicitud: () => request('/api/solicitudes/formulario-datos'),
  obtenerSolicitud: (id) => request(`/api/solicitudes/${id}`),
  crearSolicitud: (solicitud) => request('/api/solicitudes', {
    method: 'POST',
    body: JSON.stringify(solicitud),
  }),
  actualizarSolicitud: (id, solicitud) => request(`/api/solicitudes/${id}`, {
    method: 'PUT',
    body: JSON.stringify(solicitud),
  }),
  eliminarSolicitud: (id, usuario) => request(`/api/solicitudes/${id}?usuario=${encodeURIComponent(usuario)}`, {
    method: 'DELETE',
  }),
  agregarPersonaSolicitud: (idSolicitud, persona) => request(`/api/solicitudes/${idSolicitud}/personas`, {
    method: 'POST',
    body: JSON.stringify(persona),
  }),
}
