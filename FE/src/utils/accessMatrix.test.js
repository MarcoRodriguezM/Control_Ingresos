import test from 'node:test'
import assert from 'node:assert/strict'
import { MATRIX_AREA_CODES, areaAvailableForEntry, areaRequiresApproval, availableAreasForEntry } from './accessMatrix.js'

test('el selector de practicantes solo muestra Centro de Integracion', () => {
  const areas = [
    { id: 1, codigo: 'CENTRO_INTEGRACION' },
    { id: 2, codigo: 'TAJO' },
    { id: 3, codigo: 'REFINERIA' },
    { id: 4, codigo: 'INFORMATICA' },
  ]
  assert.deepEqual(availableAreasForEntry('PRACTICANTE', areas), [areas[0]])
})

test('empleados solo necesitan aprobacion en Polvorin y Refineria', () => {
  for (const code of MATRIX_AREA_CODES) {
    assert.equal(areaAvailableForEntry('EMPLEADO', code), true, code)
    assert.equal(areaRequiresApproval('EMPLEADO', code), ['POLVORIN', 'REFINERIA'].includes(code), code)
  }
})

test('visitas, practicantes y profesionales solo usan Centro de Integracion', () => {
  for (const type of ['VISITA', 'PRACTICANTE', 'SERV_PROF']) {
    for (const code of MATRIX_AREA_CODES) {
      assert.equal(areaAvailableForEntry(type, code), code === 'CENTRO_INTEGRACION', `${type}:${code}`)
      assert.equal(areaRequiresApproval(type, code), code === 'CENTRO_INTEGRACION', `${type}:${code}`)
    }
  }
})

test('proveedores requieren aprobacion en toda la matriz excepto Refineria', () => {
  for (const code of MATRIX_AREA_CODES) {
    assert.equal(areaAvailableForEntry('PROVEEDOR', code), code !== 'REFINERIA', code)
    assert.equal(areaRequiresApproval('PROVEEDOR', code), code !== 'REFINERIA', code)
  }
})
