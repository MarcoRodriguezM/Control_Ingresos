import test from 'node:test'
import assert from 'node:assert/strict'
import { activityAppliesToType, flowCoversEntryTypes, includeRequiredFlowVersions } from './activityTypes.js'

const flow = (id, types, dependencies = []) => ({
  idActividadFlujo: id,
  idActividadFlujoVersion: id * 10,
  esVersionActual: true,
  tiposIngreso: types,
  pasos: [{ dependenciasExternas: dependencies.map((requiredId) => ({ idActividadFlujo: requiredId })) }],
})

const internet = flow(1, [])
const correo = flow(2, ['EMPLEADO', 'PRACTICANTE', 'SERV_PROF'], [1])
const sistemas = flow(3, ['EMPLEADO', 'SERV_PROF'], [2])
const orientacionVisita = flow(4, ['VISITA'], [1])
const ingreso = flow(5, [], [2, 3, 4])
const areas = [internet, correo, sistemas, orientacionVisita, ingreso]
  .map((item, index) => ({ idArea: index + 1, flujos: [item] }))

test('las dependencias solo incluyen flujos aplicables al tipo de ingreso', () => {
  const expectedByType = {
    EMPLEADO: [10, 20, 30, 50],
    NUEVO_EMPLEADO: [10, 20, 30, 50],
    PRACTICANTE: [10, 20, 50],
    SERV_PROF: [10, 20, 30, 50],
    VISITA: [10, 40, 50],
  }

  for (const [type, expected] of Object.entries(expectedByType)) {
    const actual = includeRequiredFlowVersions([50], areas, type).sort((a, b) => a - b)
    assert.deepEqual(actual, expected, type)
    assert.equal(activityAppliesToType(internet, type), true, type)
  }
})

test('un flujo exclusivo no aparece para los otros tipos', () => {
  assert.equal(activityAppliesToType(correo, 'VISITA'), false)
  assert.equal(activityAppliesToType(sistemas, 'PRACTICANTE'), false)
  assert.equal(activityAppliesToType(orientacionVisita, 'SERV_PROF'), false)
})

test('el editor solo permite dependencias que cubren todos los tipos del flujo', () => {
  assert.equal(flowCoversEntryTypes(internet, correo), true)
  assert.equal(flowCoversEntryTypes(correo, sistemas), true)
  assert.equal(flowCoversEntryTypes(sistemas, correo), false)
  assert.equal(flowCoversEntryTypes(orientacionVisita, correo), false)
  assert.equal(flowCoversEntryTypes(correo, ingreso), false)
  assert.equal(flowCoversEntryTypes(internet, ingreso), true)
  assert.equal(flowCoversEntryTypes(correo, { tiposIngreso: ['NUEVO_EMPLEADO'] }), true)
})
