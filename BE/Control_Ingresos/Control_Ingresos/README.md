# API de Control de Ingresos

## Preparación

1. Cree y mantenga `Control_Ingresos_DB` y sus tablas de negocio directamente en SQL Server.
2. Ajuste `ConnectionStrings:ControlIngresos` en `appsettings.json` o mediante una variable de entorno:

   `ConnectionStrings__ControlIngresos=Server=...;Database=Control_Ingresos_DB;...`

3. Inicie la API con `dotnet run`.

La API consume las estructuras y los procedimientos almacenados existentes. Al iniciar, verifica
la tabla `dbo.Auditoria_Registro` y la crea si falta; no modifica las tablas de negocio.

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

## Auditoria

La pagina `/auditoria` y `GET /api/auditoria` requieren el rol `Administrador` y el permiso
`GESTIONAR_USUARIOS`. Registra las acciones de escritura autenticadas (`POST`, `PUT`, `PATCH`
y `DELETE`), incluidos sus resultados, y las entradas a pantallas enviadas explicitamente por
el frontend (`VIEW`). Todos los usuarios autenticados pueden registrar su propia navegacion;
solo los administradores con el permiso indicado pueden consultar el historial.
No se guardan contrasenas, cuerpos de peticion ni parametros de consulta. Los inicios de sesion
correctos e incorrectos tambien se registran. Las consultas automaticas (`GET`) se omiten
para evitar ruido y crecimiento innecesario de la tabla.

Los eventos se guardan en `dbo.Auditoria_Registro`. Al iniciar el backend se ejecuta el script
idempotente `Sql/001_Auditoria_Registro.sql` antes de atender solicitudes. Si existen registros
anteriores en `App_Data/audit/*.jsonl`, se importan una sola vez por identificador; los archivos
se conservan como respaldo local y ya no reciben eventos nuevos. La auditoria no puede recuperar
acciones anteriores a su activacion.
Si la instalacion anterior usaba `Audit:Directory`, mantenga esa configuracion durante el primer
inicio para importar los archivos de esa ruta.
