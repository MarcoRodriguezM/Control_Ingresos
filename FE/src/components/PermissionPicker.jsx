import { permissionGroups } from '../utils/permissions'

export function PermissionPicker({ selected, onChange, allowed }) {
  return <div className="permission-picker">
    {permissionGroups.filter((group) => !allowed || group.items.some(([code]) => allowed.includes(code))).map((group) => <fieldset key={group.title} className="permission-group">
      <legend>{group.title}</legend>
      <div className="permission-group-options">
        {group.items.filter(([code]) => !allowed || allowed.includes(code)).map(([code, label]) => <label key={code} className="permission-option">
          <input type="checkbox" checked={selected.includes(code)} onChange={() => onChange(selected.includes(code) ? selected.filter((item) => item !== code) : [...selected, code])} />
          <span>{label}</span>
        </label>)}
      </div>
    </fieldset>)}
  </div>
}
