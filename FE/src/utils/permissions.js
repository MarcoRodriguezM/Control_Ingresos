export const permissionGroups = [
  { title: 'Solicitudes', items: [
    ['VER_SOLICITUDES', 'Ver solicitudes'],
    ['CREAR_SOLICITUDES', 'Crear solicitudes'],
    ['EDITAR_SOLICITUDES', 'Editar solicitudes y asignar areas'],
    ['ELIMINAR_SOLICITUDES', 'Eliminar solicitudes'],
    ['ENVIAR_SOLICITUDES', 'Enviar solicitudes'],
    ['APROBAR_ACCESOS', 'Aprobar o rechazar accesos'],
    ['CREAR_TICKETS', 'Crear tickets de actividades'],
  ] },
  { title: 'Personas y empleados', items: [
    ['VER_PERSONAS', 'Ver personas'],
    ['CREAR_PERSONAS', 'Crear personas'],
    ['EDITAR_PERSONAS', 'Cambiar fotos de personas'],
    ['VER_EMPLEADOS', 'Ver empleados'],
  ] },
  { title: 'Actividades', items: [
    ['VER_ACTIVIDADES', 'Ver actividades propias'],
    ['GESTIONAR_ACTIVIDADES', 'Asignar actividades'],
    ['COMPLETAR_ACTIVIDADES', 'Marcar actividades realizadas'],
    ['APROBAR_ACTIVIDADES', 'Aprobar actividades'],
    ['GESTIONAR_FLUJOS', 'Configurar flujos'],
  ] },
  { title: 'Proveedor y seguridad', items: [
    ['CREAR_PROVEEDORES', 'Crear proveedores'],
    ['VER_PORTAL_PROVEEDOR', 'Ver portal de proveedor'],
    ['REGISTRAR_PERSONAS_PROVEEDOR', 'Registrar personas del proveedor'],
    ['ESCANEAR_QR', 'Escanear codigos QR'],
    ['REGISTRAR_INGRESOS', 'Registrar entradas y salidas'],
  ] },
  { title: 'Administracion', items: [
    ['GESTIONAR_USUARIOS', 'Crear y editar usuarios'],
    ['VER_FRESHSERVICE', 'Ver pruebas Freshservice'],
  ] },
]

export const allPermissions = permissionGroups.flatMap((group) => group.items.map(([code]) => code))

export function roleNames(value) {
  return Array.isArray(value)
    ? value.map((role) => String(role).trim().toUpperCase())
    : String(value ?? '').split(',').map((role) => role.trim().toUpperCase()).filter(Boolean)
}

export function permissionsFromRoles(value) {
  const roles = roleNames(value)
  if (roles.includes('PERM_CONFIGURADO')) return allPermissions.filter((code) => roles.includes(code))
  if (roles.includes('ADMINISTRADOR')) return [...allPermissions]

  const granted = new Set()
  const add = (...codes) => codes.forEach((code) => granted.add(code))
  if (roles.includes('PROVEEDOR')) add('VER_PORTAL_PROVEEDOR', 'REGISTRAR_PERSONAS_PROVEEDOR')
  else if (roles.includes('GUARDIA')) add('ESCANEAR_QR')
  else {
    if (roles.includes('SOLICITANTE')) add('VER_SOLICITUDES', 'CREAR_SOLICITUDES', 'EDITAR_SOLICITUDES', 'ELIMINAR_SOLICITUDES', 'ENVIAR_SOLICITUDES', 'VER_PERSONAS', 'CREAR_PERSONAS', 'EDITAR_PERSONAS', 'VER_EMPLEADOS', 'VER_ACTIVIDADES', 'COMPLETAR_ACTIVIDADES', 'CREAR_TICKETS', 'CREAR_PROVEEDORES', 'ESCANEAR_QR')
    if (roles.includes('APROBADOR')) add('VER_SOLICITUDES', 'APROBAR_ACCESOS', 'VER_PERSONAS', 'VER_EMPLEADOS', 'VER_ACTIVIDADES', 'GESTIONAR_ACTIVIDADES', 'COMPLETAR_ACTIVIDADES', 'APROBAR_ACTIVIDADES', 'ESCANEAR_QR')
    if (roles.includes('RESPONSABLE')) add('VER_SOLICITUDES', 'VER_ACTIVIDADES', 'COMPLETAR_ACTIVIDADES', 'ESCANEAR_QR')
    if (roles.includes('SEGURIDAD')) add('VER_PERSONAS', 'VER_EMPLEADOS', 'ESCANEAR_QR', 'REGISTRAR_INGRESOS')
    if (roles.includes('AUDITOR')) add('VER_SOLICITUDES', 'VER_PERSONAS', 'VER_EMPLEADOS', 'VER_ACTIVIDADES')
  }
  return allPermissions.filter((code) => granted.has(code))
}

export function hasPermission(session, code) {
  return permissionsFromRoles(session?.roles).includes(code)
}
