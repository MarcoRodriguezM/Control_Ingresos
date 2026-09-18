import { Icon } from './Icon'

export function AlertModal({ message, onClose }) {
  if (!message) return null

  return <div className="alert-modal-backdrop" role="presentation" onMouseDown={onClose}>
    <section className="alert-modal" role="alertdialog" aria-modal="true" aria-labelledby="alert-modal-title" onMouseDown={(event) => event.stopPropagation()}>
      <span className="alert-modal-icon"><Icon name="warning" /></span>
      <div className="alert-modal-copy">
        <h2 id="alert-modal-title">No se pudo continuar</h2>
        <p>{message}</p>
      </div>
      <button type="button" className="primary-button alert-modal-button" onClick={onClose} autoFocus>Aceptar</button>
    </section>
  </div>
}
