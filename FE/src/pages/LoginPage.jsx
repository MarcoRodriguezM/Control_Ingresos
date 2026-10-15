import { useState } from 'react'
import auraLogo from '../assets/aura-logo-default.png'

export function LoginPage({ onLogin }) {
  const [form, setForm] = useState({ usuario: '', contrasena: '' })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  function change(event) {
    setForm((current) => ({ ...current, [event.target.name]: event.target.value }))
    setError('')
  }

  async function submit(event) {
    event.preventDefault()
    if (!form.usuario.trim() || !form.contrasena) {
      setError('Escribe tu usuario y contraseña.')
      return
    }
    setLoading(true)
    try {
      await onLogin({ usuario: form.usuario.trim(), contrasena: form.contrasena })
    } catch (requestError) {
      setError(requestError.message)
    } finally {
      setLoading(false)
    }
  }

  return <main className="login-page">
    <section className="login-shell" aria-labelledby="login-title">
      <form className="login-card" onSubmit={submit}>
        <div className="login-card-brand">
          <img src={auraLogo} alt="Aura Minerals" />
        </div>
        <div className="login-card-body">
          <header className="login-heading">
            <p>Control de ingresos</p>
            <h1 id="login-title">Iniciar sesión</h1>
            <span>Utiliza tus credenciales para continuar.</span>
          </header>
          {error && <div className="alert error" role="alert">{error}</div>}
          <label className="login-field">
            <span>Usuario o correo</span>
            <input name="usuario" value={form.usuario} onChange={change} autoComplete="username" placeholder="Ingresa tu usuario" autoFocus />
          </label>
          <label className="login-field">
            <span>Contraseña</span>
            <input type="password" name="contrasena" value={form.contrasena} onChange={change} autoComplete="current-password" placeholder="Ingresa tu contraseña" />
          </label>
          <button type="submit" className="primary-button login-button" disabled={loading}>{loading ? 'Ingresando…' : 'Ingresar'}</button>
        </div>
      </form>
      <p className="login-access-note">Uso interno de Aura Minerals</p>
    </section>
  </main>
}
