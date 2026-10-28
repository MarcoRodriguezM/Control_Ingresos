import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import './index.css'
import App from './App.jsx'

const preloadReloadKey = 'control-ingresos-vite-preload-reload'

window.addEventListener('vite:preloadError', (event) => {
  const now = Date.now()
  const lastReload = Number(sessionStorage.getItem(preloadReloadKey) || 0)

  if (now - lastReload < 10000) return

  event.preventDefault()
  sessionStorage.setItem(preloadReloadKey, String(now))
  window.location.reload()
})

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </StrictMode>,
)
