# API de Control de Ingresos

## Preparación

1. Cree y mantenga `Control_Ingresos_DB`, sus tablas y procedimientos directamente en SQL Server.
2. Ajuste `ConnectionStrings:ControlIngresos` en `appsettings.json` o mediante una variable de entorno:

   `ConnectionStrings__ControlIngresos=Server=...;Database=Control_Ingresos_DB;...`

3. Inicie la API con `dotnet run`.

La URL HTTP de desarrollo es `http://localhost:5250`. Al ejecutar en Development:

- Scalar está disponible en `http://localhost:5250/scalar/v1`.
- El documento OpenAPI se publica en `http://localhost:5250/openapi/v1.json`.

## Endpoints iniciales

- `GET /api/catalogos/{catalogo}`
- `POST /api/proveedores`
- `POST /api/personas`
- `GET /api/solicitudes`
- `GET /api/solicitudes/formulario-datos`
- `GET /api/solicitudes/{id}`
- `POST /api/solicitudes`
- `PUT /api/solicitudes/{id}`
- `DELETE /api/solicitudes/{id}?usuario={idUsuario}`
- `POST /api/solicitudes/{id}/personas`

Todos los endpoints de escritura invocan procedimientos almacenados. Las relaciones lógicas se validan dentro de SQL Server antes de insertar.

## Ejemplo de solicitud

```json
{
  "idTipoIngreso": 1,
  "idEstadoSolicitud": 1,
  "fechaInicio": "2026-09-15",
  "fechaFin": "2026-09-16",
  "nombreActividad": "Mantenimiento preventivo",
  "idProveedor": 1,
  "cantidadEstimada": 2,
  "idAreaSolicitante": 1,
  "idUsuarioSolicitante": "usuario.directorio",
  "idUbicacion": 1,
  "usuario": "usuario.directorio"
}
```

Para asociar una persona ya registrada:

```json
{
  "idPersona": 1,
  "idEstadoPersonaSolicitud": 1,
  "datosCompletos": true,
  "areas": [1, 2],
  "requerimientos": [
    {
      "idRequerimiento": 1,
      "idTipoAplicacion": 1,
      "seleccionado": true,
      "configuradoAutomatico": false
    }
  ],
  "usuario": "usuario.directorio"
}
```
