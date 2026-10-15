export const formatDate = (value) => value
  ? new Intl.DateTimeFormat('es-HN', { day: '2-digit', month: 'short', year: 'numeric', timeZone: 'UTC' }).format(new Date(`${value}T00:00:00Z`))
  : '—'

export const formatDateTime = (value) => value
  ? new Intl.DateTimeFormat('es-HN', { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(value))
  : '—'

export const initials = (name) => name?.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase() || '—'

export const accessStatusClass = (codigoEstado = '') => ({
  PENDIENTE: 'pending',
  APROBADA: 'approved',
  AUTORIZADA: 'approved',
  RECHAZADA: 'rejected',
  VENCIDA: 'expired',
  NO_VIGENTE: 'future',
  SOLICITUD_NO_HABILITADA: 'neutral',
  PENDIENTE_AREAS: 'pending',
}[codigoEstado.trim().toUpperCase()] ?? 'neutral')
