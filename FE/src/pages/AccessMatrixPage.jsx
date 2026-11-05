import { useEffect, useState } from 'react'
import { controlIngresosApi } from '../services/api'

const requiredCount = (code) => code === 'POLVORIN' || code === 'REFINERIA' ? 3 : 1
const matrixHint = (code) => {
  if (code === 'POLVORIN') return 'Gerente Mina, Superintendente Mina y Supervisor Mina. Basta una de las tres aprobaciones.'
  if (code === 'REFINERIA') return 'Gerente Procesos, Supervisor Refineria y Superintendente SP. Se requieren las tres aprobaciones.'
  if (code === 'CENTRO_INTEGRACION') return 'RRHH, superintendentes, supervisores, gerentes o asistentes autorizados.'
  if (code === 'TALLER_EDI') return 'Gerente, superintendente o supervisor de area, personal EDI del taller o asistente autorizado.'
  if (['TAJO', 'BOTADEROS', 'MIRADORES', 'PAD_POZAS_1_6', 'PLANTA_ADR_LABORATORIO', 'METALURGIA', 'AGLOMERADOR', 'TRITURACION_PRIMARIA', 'TRITURACION_SECUNDARIA', 'SUBESTACION', 'TALLER_MANTENIMIENTO', 'ALMACEN', 'ASERRADERO', 'INCINERADOR', 'CENTRO_ACOPIO', 'VIVERO'].includes(code)) {
    return 'Gerente, superintendente o supervisor de area, o asistente autorizado.'
  }
  return ''
}

export function AccessMatrixPage({ onError }) {
  const [data, setData] = useState(null)
  const [selected, setSelected] = useState({})
  const [savingArea, setSavingArea] = useState(null)
  const [notice, setNotice] = useState('')

  useEffect(() => {
    let active = true
    controlIngresosApi.obtenerMatrizAccesos().then((result) => {
      if (!active) return
      setData(result)
      const next = {}
      for (const area of result.areas ?? []) {
        next[area.id] = (result.asignaciones ?? [])
          .filter((assignment) => assignment.idArea === area.id)
          .map((assignment) => assignment.idUsuario)
      }
      setSelected(next)
    }).catch((error) => { if (active) onError(error.message) })
    return () => { active = false }
  }, [onError])

  function toggle(idArea, idUsuario) {
    setSelected((current) => {
      const list = current[idArea] ?? []
      return { ...current, [idArea]: list.includes(idUsuario)
        ? list.filter((id) => id !== idUsuario) : [...list, idUsuario] }
    })
    setNotice('')
  }

  async function save(area) {
    const users = selected[area.id] ?? []
    const count = requiredCount(area.codigo)
    if (users.length < count || (count === 3 && users.length !== 3)) {
      onError(count === 3 ? 'Selecciona exactamente tres usuarios para esta area.' : 'Selecciona al menos un usuario para esta area.')
      return
    }
    setSavingArea(area.id)
    try {
      await controlIngresosApi.guardarAprobadoresArea(area.id, users)
      setNotice(`Aprobadores de ${area.nombre} guardados.`)
    } catch (error) {
      onError(error.message)
    } finally {
      setSavingArea(null)
    }
  }

  return <div className="access-matrix-page">
    <div className="page-heading"><div><p className="eyebrow">Administracion</p><h1>Matriz de accesos</h1><p>Asigna las cuentas que decidiran las solicitudes de acceso a cada area.</p></div></div>
    <div className="panel access-matrix-intro"><strong>Reglas de aprobacion</strong><p>Empleados: solo Polvorin y Refineria requieren aprobacion. Visitas, practicantes y servicios profesionales: solo Centro de Integracion. Proveedores: todas las areas de la matriz excepto Refineria, siempre con aprobacion.</p></div>
    {notice && <p className="access-matrix-notice" role="status">{notice}</p>}
    {!data && <div className="panel">Cargando matriz...</div>}
    {data?.areas?.map((area) => <section className="panel access-matrix-area" key={area.id}>
      <div className="access-matrix-area-head"><div><h2>{area.nombre}</h2><p>{matrixHint(area.codigo)}</p></div><span className="status-badge">{area.codigo === 'REFINERIA' ? '3 de 3' : area.codigo === 'POLVORIN' ? '1 de 3' : '1 aprobacion'}</span></div>
      <div className="access-matrix-users">
        {(data.usuarios ?? []).map((user) => <label key={user.idUsuario}><input type="checkbox" checked={(selected[area.id] ?? []).includes(user.idUsuario)} onChange={() => toggle(area.id, user.idUsuario)} /><span><strong>{user.nombreCompleto}</strong><small>{user.puesto || user.idUsuario}</small></span></label>)}
        {!data.usuarios?.length && <p>Primero crea usuarios con rol Aprobador.</p>}
      </div>
      <div className="access-matrix-actions"><span>{(selected[area.id] ?? []).length} usuario(s) seleccionado(s)</span><button type="button" className="primary-button" disabled={savingArea === area.id} onClick={() => save(area)}>{savingArea === area.id ? 'Guardando...' : 'Guardar aprobadores'}</button></div>
    </section>)}
  </div>
}
