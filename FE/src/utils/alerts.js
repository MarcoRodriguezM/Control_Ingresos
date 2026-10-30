import Swal from 'sweetalert2'
import 'sweetalert2/dist/sweetalert2.min.css'

export function showSuccessAlert(message) {
  return Swal.fire({
    icon: 'success',
    title: 'Operación completada',
    text: message,
    timer: 1500,
    timerProgressBar: true,
    showConfirmButton: false,
    allowEscapeKey: true,
    allowOutsideClick: true,
  })
}

export async function confirmSendDraft(number) {
  const result = await Swal.fire({
    icon: 'question',
    title: 'Solicitud guardada como borrador',
    text: `La solicitud ${number || ''} fue creada correctamente. ¿Deseas enviarla ahora?`.replace('solicitud  fue', 'solicitud fue'),
    showCancelButton: true,
    confirmButtonText: 'Enviar ahora',
    cancelButtonText: 'Enviar después',
    confirmButtonColor: '#119c87',
    cancelButtonColor: '#64748b',
    reverseButtons: true,
    allowEscapeKey: false,
    allowOutsideClick: false,
  })

  return result.isConfirmed
}

async function confirmAction({ title, text, confirmButtonText, confirmButtonColor = '#119c87', icon = 'question' }) {
  const result = await Swal.fire({
    icon,
    title,
    text,
    showCancelButton: true,
    confirmButtonText,
    cancelButtonText: 'Cancelar',
    confirmButtonColor,
    cancelButtonColor: '#64748b',
    reverseButtons: true,
    allowEscapeKey: false,
    allowOutsideClick: false,
  })

  return result.isConfirmed
}

export function confirmSendRequest(number) {
  return confirmAction({
    title: 'Enviar solicitud',
    text: `¿Deseas guardar y enviar ${number || 'esta solicitud'} al siguiente paso del proceso?`,
    confirmButtonText: 'Sí, enviar solicitud',
  })
}

export function confirmDeleteRequest(number) {
  return confirmAction({
    icon: 'warning',
    title: 'Cancelar solicitud',
    text: `¿Deseas cancelar ${number || 'esta solicitud'}? Dejará de estar disponible para continuar el proceso.`,
    confirmButtonText: 'Sí, cancelar solicitud',
    confirmButtonColor: '#dc2626',
  })
}

export function confirmProviderSend(number, peopleCount) {
  return confirmAction({
    title: 'Enviar personas registradas',
    text: `Se enviará ${number || 'la solicitud'} con ${peopleCount} persona(s). Después no podrás agregar ni quitar personas.`,
    confirmButtonText: 'Sí, enviar',
  })
}

export function confirmRemoveProviderPerson(personName) {
  return confirmAction({
    icon: 'warning',
    title: 'Quitar persona',
    text: `¿Deseas desagregar a ${personName || 'esta persona'} de la solicitud?`,
    confirmButtonText: 'Sí, quitar persona',
    confirmButtonColor: '#dc2626',
  })
}
