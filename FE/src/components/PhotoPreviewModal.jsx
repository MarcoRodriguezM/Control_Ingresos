import { useEffect, useRef } from 'react'
import { createPortal } from 'react-dom'

export function PhotoPreviewModal({ src, name, onClose }) {
  const closeButton = useRef(null)
  const onCloseRef = useRef(onClose)

  useEffect(() => {
    onCloseRef.current = onClose
  }, [onClose])

  useEffect(() => {
    const previousFocus = document.activeElement
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    closeButton.current?.focus()

    function handleKeyDown(event) {
      if (event.key === 'Escape') onCloseRef.current()
      if (event.key === 'Tab') {
        event.preventDefault()
        closeButton.current?.focus()
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => {
      document.removeEventListener('keydown', handleKeyDown)
      document.body.style.overflow = previousOverflow
      previousFocus?.focus?.()
    }
  }, [])

  return createPortal(
    <div className="photo-preview-backdrop" role="presentation" onMouseDown={onClose}>
      <section className="photo-preview-dialog" role="dialog" aria-modal="true" aria-label={`Fotografia de ${name}`} onMouseDown={(event) => event.stopPropagation()}>
        <button ref={closeButton} type="button" className="photo-preview-close" onClick={onClose} aria-label="Cerrar fotografia">
          <svg viewBox="0 0 24 24" width="30" height="30" fill="none" stroke="currentColor" strokeWidth="2.8" strokeLinecap="round" aria-hidden="true"><path d="M5 5l14 14M19 5L5 19" /></svg>
        </button>
        <img src={src} alt={`Fotografia ampliada de ${name}`} />
      </section>
    </div>,
    document.body,
  )
}
