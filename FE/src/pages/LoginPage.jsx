import { useState } from 'react'
import { Icon } from '../components/Icon'

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
    <section className="login-brand-panel">
      <div className="login-brand"><span className="brand-mark"><Icon name="logo" /></span><span>Entrada</span></div>
      <div className="login-message"><span className="login-shield"><Icon name="shield" /></span><p className="eyebrow">Control de ingresos</p><h1>Accesos claros, seguros y bajo control.</h1><p>Administra solicitudes, personas y aprobaciones desde un mismo lugar.</p></div>
      <p className="login-copyright">Sistema interno de gestión de ingresos</p>
    </section>
    <section className="login-form-panel">
      <form className="login-card" onSubmit={submit}>
        <div className="login-mobile-brand"><span className="brand-mark"><Icon name="logo" /></span><strong>Entrada</strong></div>
        <p className="eyebrow">Bienvenido</p>
        <h2>Iniciar sesión</h2>
        <p className="login-subtitle">Ingresa tus credenciales para continuar.</p>
        {error && <div className="alert error" role="alert">{error}</div>}
        <label className="login-field"><span>Usuario o correo</span><div><Icon name="user" /><input name="usuario" value={form.usuario} onChange={change} autoComplete="username" placeholder="Ej. admin" autoFocus /></div></label>
        <label className="login-field"><span>Contraseña</span><div><Icon name="lock" /><input type="password" name="contrasena" value={form.contrasena} onChange={change} autoComplete="current-password" placeholder="Escribe tu contraseña" /></div></label>
        <button type="submit" className="primary-button login-button" disabled={loading}>{loading ? 'Ingresando…' : <>Ingresar <Icon name="arrow" /></>}</button>
      </form>
    </section>
  </main>
}
