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
