import { useState } from 'react'
import { Icon } from '../components/Icon'
import { formatDateTime, initials } from '../utils/formatters'

export function EmployeeListPage({ items, statuses = [], selected, loading, photographUrl, photographLoading, onSelect }) {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('')
  const [department, setDepartment] = useState('')
  const [entryDateFrom, setEntryDateFrom] = useState('')
  const [entryDateTo, setEntryDateTo] = useState('')
  const [exitDateFrom, setExitDateFrom] = useState('')
  const [exitDateTo, setExitDateTo] = useState('')
  const statusOptions = statuses
    .map((item) => ({ value: String(item.statusId), label: item.descripcion || String(item.statusId) }))
    .sort((left, right) => left.label.localeCompare(right.label, 'es'))
  const departments = [...new Set(items.map((employee) => employee.departamento?.trim()).filter(Boolean))]
    .sort((left, right) => left.localeCompare(right, 'es'))
  const normalizedQuery = query.trim().toLocaleLowerCase('es')
  const filtered = items.filter((employee) => {
    const matchesQuery = !normalizedQuery || [
      employee.codigoEmpleado,
      employee.nombreCompleto,
      employee.nit,
      employee.correo,
      employee.departamento,
      employee.cargoNivel,
    ].some((value) => normalize(value).includes(normalizedQuery))
    const matchesStatus = !status || String(employee.codigoStatus).trim() === status
    const matchesDepartment = !department || employee.departamento?.trim() === department
    const matchesEntryDate = matchesDateRange(employee.fechaIngreso, entryDateFrom, entryDateTo)
    const matchesExitDate = matchesDateRange(employee.fechaEgreso, exitDateFrom, exitDateTo)
    return matchesQuery && matchesStatus && matchesDepartment && matchesEntryDate && matchesExitDate
  })
  const hasFilters = Boolean(query || status || department || entryDateFrom || entryDateTo || exitDateFrom || exitDateTo)

  function clearFilters() {
    setQuery('')
    setStatus('')
    setDepartment('')
    setEntryDateFrom('')
    setEntryDateTo('')
    setExitDateFrom('')
    setExitDateTo('')
  }

  return <>
    <div className="page-heading">
      <div><p className="eyebrow">Directorio de empleados</p><h1>Empleados</h1><p>Selecciona un empleado para consultar su información personal y laboral.</p></div>
    </div>

    <section className="panel employee-toolbar" aria-label="Filtros de empleados">
      <div className="employee-toolbar-main">
        <div className="employee-search"><Icon name="search" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar empleado" /></div>
        <label className="employee-filter"><span>Estado</span><select value={status} onChange={(event) => setStatus(event.target.value)}><option value="">Todos los estados</option>{statusOptions.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
        <label className="employee-filter"><span>Departamento</span><select value={department} onChange={(event) => setDepartment(event.target.value)}><option value="">Todos los departamentos</option>{departments.map((item) => <option value={item} key={item}>{item}</option>)}</select></label>
        {hasFilters && <button type="button" className="employee-clear-filters" onClick={clearFilters}><Icon name="close" />Limpiar filtros</button>}
      </div>
      <div className="employee-toolbar-ranges">
        <DateRangeFilter label="Fecha de ingreso" from={entryDateFrom} to={entryDateTo} onFromChange={setEntryDateFrom} onToChange={setEntryDateTo} />
        <DateRangeFilter label="Fecha de egreso" from={exitDateFrom} to={exitDateTo} onFromChange={setExitDateFrom} onToChange={setExitDateTo} />
      </div>
    </section>

    <div className="people-layout">
      <aside className="panel people-panel employee-list-panel">
        <div className="people-results">
          {loading && items.length === 0 && <p className="people-empty">Cargando empleados…</p>}
          {!loading && filtered.length === 0 && <p className="people-empty">No se encontraron empleados.</p>}
          {filtered.map((employee, index) => <button
            type="button"
            className={`person-row ${selected?.codigoEmpleado === employee.codigoEmpleado ? 'active' : ''}`}
            key={employee.codigoEmpleado ?? index}
            onClick={() => onSelect(employee)}
          >
            <span className="person-avatar">{initials(employee.nombreCompleto)}</span>
            <span className="person-row-copy"><strong>{employee.nombreCompleto || 'Sin nombre'}</strong><small>{employee.departamento || employee.cargoNivel || 'Departamento no indicado'}</small></span>
            <span className="employee-code">{employee.codigoEmpleado || '—'}</span>
          </button>)}
        </div>
      </aside>

      <section className="panel person-detail-panel employee-detail-panel">
        {loading && !selected && <div className="person-placeholder">Cargando información…</div>}
        {!loading && !selected && <div className="person-placeholder">Selecciona un empleado para consultar su información.</div>}
        {selected && <>
          <div className="person-profile employee-profile">
            <EmployeeAvatar employee={selected} photographUrl={photographUrl} loading={photographLoading} />
            <div><div className="profile-title"><h2>{selected.nombreCompleto || 'Empleado sin nombre'}</h2><span className="status-badge">{selected.descripcionStatus || selected.codigoStatus || 'Sin estado'}</span></div><p>{selected.cargoNivel || 'Cargo no indicado'} · {selected.departamento || 'Departamento no indicado'}</p>{photographLoading && <span className="employee-photo-state">Cargando fotografía…</span>}</div>
          </div>

          <EmployeeSection icon="tasks" title="Información laboral">
            <InfoValue label="Código de empleado" value={selected.codigoEmpleado} />
            <InfoValue label="Departamento" value={selected.departamento} />
            <InfoValue label="Cargo / nivel" value={selected.cargoNivel} />
            <InfoValue label="Estado" value={selected.descripcionStatus} />
            <InfoValue label="Código de estado" value={selected.codigoStatus} />
            <InfoValue label="Fecha de ingreso" value={formatEmployeeDate(selected.fechaIngreso)} />
            <InfoValue label="Fecha de egreso" value={formatEmployeeDate(selected.fechaEgreso)} />
            <InfoValue label="Tipo de licencia" value={selected.tipoLicencia} />
            <InfoValue label="Correo" value={selected.correo} />
          </EmployeeSection>

          <EmployeeSection icon="user" title="Información personal">
            <InfoValue label="Primer nombre" value={selected.nombre1} />
            <InfoValue label="Segundo nombre" value={selected.nombre2} />
            <InfoValue label="Primer apellido" value={selected.apellido1} />
            <InfoValue label="Segundo apellido" value={selected.apellido2} />
            <InfoValue label="NIT" value={selected.nit} />
            <InfoValue label="Nacionalidad" value={selected.codigoNacionalidad} />
            <InfoValue label="Fecha de nacimiento" value={formatEmployeeDate(selected.fechaNacimiento)} />
            <InfoValue label="Lugar de nacimiento" value={selected.lugarNacimiento} />
            <InfoValue label="Tipo de sangre" value={selected.tipoSangre} />
            <InfoValue label="Estado civil" value={selected.estadoCivil} />
            <InfoValue label="Sexo" value={selected.sexo} />
          </EmployeeSection>
        </>}
      </section>
    </div>
  </>
}

function EmployeeAvatar({ employee, photographUrl, loading }) {
  const [failedUrl, setFailedUrl] = useState('')
  const showPhotograph = photographUrl && failedUrl !== photographUrl

  return <span className={`person-avatar large employee-avatar ${loading ? 'loading' : ''}`}>
    <span>{initials(employee.nombreCompleto)}</span>
    {showPhotograph && <img src={photographUrl} alt={`Fotografía de ${employee.nombreCompleto || 'empleado'}`} onError={() => setFailedUrl(photographUrl)} />}
  </span>
}

function DateRangeFilter({ label, from, to, onFromChange, onToChange }) {
  return <fieldset className="employee-date-range">
    <legend>{label}</legend>
    <label><span>Desde</span><input type="date" value={from} max={to || undefined} onChange={(event) => onFromChange(event.target.value)} /></label>
    <label><span>Hasta</span><input type="date" value={to} min={from || undefined} onChange={(event) => onToChange(event.target.value)} /></label>
  </fieldset>
}

function EmployeeSection({ icon, title, children }) {
  return <section className="employee-detail-section">
    <div className="employee-section-heading"><Icon name={icon} /><h3>{title}</h3></div>
    <div className="employee-detail-grid">{children}</div>
  </section>
}

function InfoValue({ label, value }) {
  const displayValue = value === null || value === undefined || value === '' ? '—' : value
  return <div className="info-value"><span>{label}</span><strong>{displayValue}</strong></div>
}

function formatEmployeeDate(value) {
  return value ? formatDateTime(value) : '—'
}

function normalize(value) {
  return String(value ?? '').toLocaleLowerCase('es')
}

function dateValue(value) {
  return String(value ?? '').match(/^\d{4}-\d{2}-\d{2}/)?.[0] ?? ''
}

function matchesDateRange(value, from, to) {
  if (!from && !to) return true
  const date = dateValue(value)
  if (!date) return false
  return (!from || date >= from) && (!to || date <= to)
}
