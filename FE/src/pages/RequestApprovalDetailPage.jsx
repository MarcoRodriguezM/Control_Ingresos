import { useState } from 'react'
import { Icon } from '../components/Icon'
import { showSuccessAlert } from '../utils/alerts'
import { accessStatusClass, formatDate, formatDateTime } from '../utils/formatters'

export function RequestApprovalDetailPage({ request, options, approvalItems, loading, onBack, onDecide }) {
  const [decision, setDecision] = useState(null)
  const [comment, setComment] = useState('')
  const [saving, setSaving] = useState(false)
  const [decisionError, setDecisionError] = useState('')

  if (loading || !request) {
    return <div className="panel empty-state">Cargando detalle de la solicitud…</div>
  }

  const selected = {
    tipo: optionName(options?.tiposIngreso, request.idTipoIngreso),
    proveedor: optionName(options?.proveedores, request.idProveedor) || 'Sin proveedor',
    area: optionName(options?.areas, request.idAreaSolicitante),
    ubicacion: optionName(options?.ubicaciones, request.idUbicacion),
    usuario: optionName(options?.usuarios, request.idUsuarioSolicitante),
  }
  const approvalRows = approvalItems.filter((item) => Number(item.idSolicitud) === Number(request.idSolicitud))
  const hasPending = approvalRows.some((item) => item.codigoEstado === 'PENDIENTE')

  function beginDecision(item, codigoEstado) {
    setDecision({ item, codigoEstado })
    setComment('')
    setDecisionError('')
  }

  async function confirmDecision() {
    if (!decision) return
    const trimmedComment = comment.trim()
    if (decision.codigoEstado === 'RECHAZADA' && !trimmedComment) {
      setDecisionError('Debes indicar el motivo del rechazo.')
      return
    }

    setSaving(true)
    setDecisionError('')
    const result = await onDecide(decision.item.idSolicitudPersonaArea, decision.codigoEstado, trimmedComment)
    setSaving(false)
    if (!result?.success) {
      setDecisionError(result?.message || 'No se pudo guardar la decisión.')
      return
    }

    const isApproval = decision.codigoEstado === 'APROBADA'
    setDecision(null)
    setComment('')
    showSuccessAlert(isApproval ? 'El acceso fue aprobado.' : 'El acceso fue rechazado.')
  }

  return <>
    <div className="page-heading approval-detail-page-heading"><div><h1>Detalle de solicitud de ingreso</h1><p>{request.numeroSolicitud || 'Solicitud sin número'}</p></div><button type="button" className="secondary-button" onClick={onBack}><Icon name="back" />Volver</button></div>
    <div className="panel form-panel request-detail-panel">
      <RequestInformation request={request} selected={selected} />
      <article className="panel requests-panel">
        <div className="section-heading approval-detail-heading"><h2>Personas de la solicitud</h2><p>Revisa y decide los accesos asignados a tus áreas.</p></div>
        <div className="table-wrap"><table className="approvals-table"><thead><tr><th>Persona</th><th>Área</th><th>Vigencia</th><th>Estado</th>{hasPending && <th>Acciones</th>}</tr></thead>
          <tbody>
            {approvalRows.length === 0 && <tr><td colSpan={hasPending ? 5 : 4} className="empty-table">No hay accesos por aprobar para esta solicitud.</td></tr>}
            {approvalRows.map((item) => <tr key={item.idSolicitudPersonaArea}>
              <td><div className="approval-person"><span><strong>{item.persona || 'Sin nombre'}</strong><small>{item.empresa || item.numeroDocumento || 'Sin empresa'}</small></span></div></td>
              <td>{item.area || '—'}<span className="cell-sub">{item.ubicacion || 'Sin ubicación'}</span></td>
              <td>{formatDate(item.fechaInicio)}<span className="cell-sub">hasta {formatDate(item.fechaFin)}</span></td>
              <td><span className={`access-status ${accessStatusClass(item.codigoEstado)}`}>{item.estado || 'Sin estado'}</span>{item.fechaDecision && <span className="cell-sub">{formatDateTime(item.fechaDecision)}</span>}</td>
              {hasPending && <td>{item.codigoEstado === 'PENDIENTE' && <div className="row-actions"><button type="button" className="approve-action" onClick={() => beginDecision(item, 'APROBADA')}>Aprobar</button><button type="button" className="delete-action" onClick={() => beginDecision(item, 'RECHAZADA')}>Rechazar</button></div>}</td>}
            </tr>)}
          </tbody>
        </table></div>
      </article>
      <div className="form-footer"><button type="button" className="ghost-button" onClick={onBack}><Icon name="back" />Volver a solicitudes por aprobar</button></div>
    </div>

    {decision && <div className="approval-modal-backdrop" role="presentation" onMouseDown={() => !saving && setDecision(null)}>
      <section className={`approval-modal ${decision.codigoEstado === 'RECHAZADA' ? 'reject' : 'approve'}`} role="dialog" aria-modal="true" aria-labelledby="approval-detail-modal-title" onMouseDown={(event) => event.stopPropagation()}>
        <h2 id="approval-detail-modal-title" className="approval-modal-title">{decision.codigoEstado === 'APROBADA' ? 'Aprobar acceso' : 'Rechazar acceso'}</h2>
        <div className="decision-copy"><div><h3>{decision.item.persona}</h3><p>{decision.item.area} · {request.numeroSolicitud}</p></div></div>
        <div className="decision-form"><label htmlFor="approval-detail-comment">Comentario {decision.codigoEstado === 'RECHAZADA' && <span className="required">*</span>}</label><textarea id="approval-detail-comment" value={comment} onChange={(event) => { setComment(event.target.value); setDecisionError('') }} maxLength="1000" placeholder={decision.codigoEstado === 'RECHAZADA' ? 'Indica el motivo del rechazo' : 'Comentario opcional'} autoFocus />{decisionError && <p className="decision-error" role="alert">{decisionError}</p>}<div className="action-row"><button type="button" className="secondary-button" disabled={saving} onClick={() => setDecision(null)}>Cancelar</button><button type="button" className={`primary-button ${decision.codigoEstado === 'APROBADA' ? 'teal' : 'danger-button'}`} disabled={saving} onClick={confirmDecision}>{saving ? 'Guardando…' : decision.codigoEstado === 'APROBADA' ? 'Confirmar aprobación' : 'Confirmar rechazo'}</button></div></div>
      </section>
    </div>}
  </>
}

function RequestInformation({ request, selected }) {
  return <><SectionHeading title="Información de la solicitud" text="Datos registrados para la solicitud de ingreso." /><div className="form-grid"><Field label="Tipo de ingreso" required><ReadOnly value={selected.tipo} /></Field><Field label="Empresa / proveedor"><ReadOnly value={selected.proveedor} /></Field><Field label="Fecha de inicio" required><ReadOnly value={formatDate(request.fechaInicio)} /></Field><Field label="Fecha de finalización" required><ReadOnly value={formatDate(request.fechaFin)} /></Field><Field label="Nombre de la actividad" required full><ReadOnly value={request.nombreActividad} /></Field><Field label="Descripción general" full><ReadOnlyText value={request.descripcionActividad} /></Field><Field label="Contrato, cuando aplique"><ReadOnly value={request.numeroContrato} /></Field><Field label="Cantidad estimada de personas"><ReadOnly value={request.cantidadEstimada} /></Field><Field label="Contacto del proveedor"><ReadOnly value={request.contactoProveedor} /></Field><Field label="Correo del proveedor"><ReadOnly value={request.correoProveedor} /></Field><Field label="Área solicitante" required><ReadOnly value={selected.area} /></Field><Field label="Ubicación / instalación" required><ReadOnly value={selected.ubicacion} /></Field><Field label="Usuario solicitante" required full><ReadOnly value={selected.usuario} /></Field><Field label="Observaciones" full><ReadOnlyText value={request.observaciones} /></Field></div></>
}

function SectionHeading({ title, text }) { return <div className="section-heading"><h2>{title}</h2><p>{text}</p></div> }
function Field({ label, required, full, children }) { return <div className={`field ${full ? 'full' : ''}`}><label>{label} {required && <span className="required">*</span>}</label>{children}</div> }
function ReadOnly({ value }) { return <input value={value ?? '—'} disabled /> }
function ReadOnlyText({ value }) { return <textarea value={value ?? '—'} disabled /> }
function optionName(items, id) { return items?.find((item) => String(item.id) === String(id))?.nombre }
