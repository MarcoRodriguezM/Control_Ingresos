export const formatDate = (value) => value
  ? new Intl.DateTimeFormat('es-HN', { day: '2-digit', month: 'short', year: 'numeric', timeZone: 'UTC' }).format(new Date(`${value}T00:00:00Z`))
  : '—'

export const formatDateTime = (value) => value
  ? new Intl.DateTimeFormat('es-HN', { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(value))
  : '—'

export const initials = (name) => name?.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase() || '—'

export const accessStatusClass = (status = '') => {
  const value = status.toLowerCase()
  if (value.includes('aprob')) return 'approved'
  if (value.includes('rechaz')) return 'rejected'
  if (value.includes('no requiere')) return 'neutral'
  return 'pending'
}
