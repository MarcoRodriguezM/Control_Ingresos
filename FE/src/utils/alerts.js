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
