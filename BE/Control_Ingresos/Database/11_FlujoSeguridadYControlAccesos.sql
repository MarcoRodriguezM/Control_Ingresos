/* Roles, flujo de estados, auditoría y registro físico de entradas/salidas. */
USE [Control_Ingresos_DB];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.Rol', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Rol
    (
        IdRol SMALLINT NOT NULL CONSTRAINT PK_Rol PRIMARY KEY,
        Codigo VARCHAR(30) NOT NULL CONSTRAINT UQ_Rol_Codigo UNIQUE,
        Nombre NVARCHAR(100) NOT NULL,
        Descripcion NVARCHAR(300) NULL,
        Activo BIT NOT NULL CONSTRAINT DF_Rol_Activo DEFAULT (1)
    );
END;
GO

MERGE dbo.Rol AS destino
USING (VALUES
    (1, 'ADMINISTRADOR', N'Administrador', N'Administración completa del sistema.'),
    (2, 'SOLICITANTE', N'Solicitante', N'Crea y administra sus propias solicitudes.'),
    (3, 'APROBADOR', N'Aprobador', N'Revisa accesos de las áreas asignadas.'),
    (4, 'RESPONSABLE', N'Responsable', N'Completa actividades asignadas.'),
    (5, 'SEGURIDAD', N'Seguridad', N'Registra entradas y salidas en portería.'),
    (6, 'AUDITOR', N'Auditor', N'Consulta el historial sin modificarlo.')
) AS fuente (IdRol, Codigo, Nombre, Descripcion)
ON destino.IdRol = fuente.IdRol
WHEN MATCHED THEN UPDATE SET Codigo=fuente.Codigo, Nombre=fuente.Nombre, Descripcion=fuente.Descripcion
WHEN NOT MATCHED THEN INSERT (IdRol,Codigo,Nombre,Descripcion) VALUES (fuente.IdRol,fuente.Codigo,fuente.Nombre,fuente.Descripcion);
GO

IF OBJECT_ID('dbo.Usuario_Rol', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Usuario_Rol
    (
        IdUsuario VARCHAR(50) NOT NULL,
        IdRol SMALLINT NOT NULL,
        FechaAsignacion DATETIME2(3) NOT NULL CONSTRAINT DF_UsuarioRol_Fecha DEFAULT SYSDATETIME(),
        UsuarioAsignacion VARCHAR(50) NULL,
        CONSTRAINT PK_Usuario_Rol PRIMARY KEY (IdUsuario, IdRol)
    );
END;
GO

INSERT dbo.Usuario_Rol (IdUsuario, IdRol, UsuarioAsignacion)
SELECT u.IdUsuario, r.IdRol, 'MIGRACION_ROLES'
FROM dbo.Usuario u CROSS JOIN dbo.Rol r
WHERE r.Codigo = 'RESPONSABLE'
  AND NOT EXISTS (SELECT 1 FROM dbo.Usuario_Rol ur WHERE ur.IdUsuario=u.IdUsuario AND ur.IdRol=r.IdRol);

INSERT dbo.Usuario_Rol (IdUsuario, IdRol, UsuarioAsignacion)
SELECT c.IdUsuario, r.IdRol, 'MIGRACION_ROLES'
FROM dbo.Usuario_Credencial c CROSS JOIN dbo.Rol r
WHERE r.Codigo = 'SOLICITANTE'
  AND NOT EXISTS (SELECT 1 FROM dbo.Usuario_Rol ur WHERE ur.IdUsuario=c.IdUsuario AND ur.IdRol=r.IdRol);

INSERT dbo.Usuario_Rol (IdUsuario, IdRol, UsuarioAsignacion)
SELECT DISTINCT ca.IdUsuarioAprobador, r.IdRol, 'MIGRACION_ROLES'
FROM dbo.Config_Aprobador_Area ca CROSS JOIN dbo.Rol r
WHERE r.Codigo='APROBADOR'
  AND EXISTS (SELECT 1 FROM dbo.Usuario u WHERE u.IdUsuario=ca.IdUsuarioAprobador)
  AND NOT EXISTS (SELECT 1 FROM dbo.Usuario_Rol ur WHERE ur.IdUsuario=ca.IdUsuarioAprobador AND ur.IdRol=r.IdRol);

INSERT dbo.Usuario_Rol (IdUsuario, IdRol, UsuarioAsignacion)
SELECT u.IdUsuario, r.IdRol, 'MIGRACION_ROLES'
FROM dbo.Usuario u CROSS JOIN dbo.Rol r
WHERE r.Codigo='ADMINISTRADOR' AND u.Puesto LIKE N'%Administrador%'
  AND NOT EXISTS (SELECT 1 FROM dbo.Usuario_Rol ur WHERE ur.IdUsuario=u.IdUsuario AND ur.IdRol=r.IdRol);

INSERT dbo.Usuario_Rol (IdUsuario, IdRol, UsuarioAsignacion)
SELECT u.IdUsuario, r.IdRol, 'MIGRACION_ROLES'
FROM dbo.Usuario u CROSS JOIN dbo.Rol r
WHERE r.Codigo='SEGURIDAD' AND (u.Puesto LIKE N'%Seguridad%' OR u.Puesto LIKE N'%Porter%')
  AND NOT EXISTS (SELECT 1 FROM dbo.Usuario_Rol ur WHERE ur.IdUsuario=u.IdUsuario AND ur.IdRol=r.IdRol);
GO

CREATE OR ALTER TRIGGER dbo.trg_Usuario_Roles_Auto ON dbo.Usuario AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.Usuario_Rol (IdUsuario,IdRol,UsuarioAsignacion)
    SELECT i.IdUsuario,r.IdRol,COALESCE(i.UsuarioModificacion,i.UsuarioCreacion,'SYSTEM')
    FROM inserted i CROSS JOIN dbo.Rol r
    WHERE r.Codigo='RESPONSABLE' AND NOT EXISTS (SELECT 1 FROM dbo.Usuario_Rol ur WHERE ur.IdUsuario=i.IdUsuario AND ur.IdRol=r.IdRol);
    INSERT dbo.Usuario_Rol (IdUsuario,IdRol,UsuarioAsignacion)
    SELECT i.IdUsuario,r.IdRol,COALESCE(i.UsuarioModificacion,i.UsuarioCreacion,'SYSTEM')
    FROM inserted i CROSS JOIN dbo.Rol r
    WHERE r.Codigo='ADMINISTRADOR' AND i.Puesto LIKE N'%Administrador%'
      AND NOT EXISTS (SELECT 1 FROM dbo.Usuario_Rol ur WHERE ur.IdUsuario=i.IdUsuario AND ur.IdRol=r.IdRol);
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Credencial_RolSolicitante ON dbo.Usuario_Credencial AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.Usuario_Rol (IdUsuario,IdRol,UsuarioAsignacion)
    SELECT i.IdUsuario,r.IdRol,COALESCE(i.UsuarioCreacion,'SYSTEM') FROM inserted i CROSS JOIN dbo.Rol r
    WHERE r.Codigo='SOLICITANTE' AND NOT EXISTS (SELECT 1 FROM dbo.Usuario_Rol ur WHERE ur.IdUsuario=i.IdUsuario AND ur.IdRol=r.IdRol);
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_ConfigAprobador_Rol ON dbo.Config_Aprobador_Area AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.Usuario_Rol (IdUsuario,IdRol,UsuarioAsignacion)
    SELECT DISTINCT i.IdUsuarioAprobador,r.IdRol,COALESCE(i.UsuarioCreacion,'SYSTEM') FROM inserted i CROSS JOIN dbo.Rol r
    WHERE r.Codigo='APROBADOR' AND i.IdUsuarioAprobador IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.Usuario_Rol ur WHERE ur.IdUsuario=i.IdUsuarioAprobador AND ur.IdRol=r.IdRol);
END;
GO

IF OBJECT_ID('dbo.Registro_Ingreso', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Registro_Ingreso
    (
        IdRegistroIngreso BIGINT NOT NULL CONSTRAINT PK_RegistroIngreso PRIMARY KEY,
        IdPersona BIGINT NOT NULL,
        IdSolicitud BIGINT NOT NULL,
        IdSolicitudPersona BIGINT NOT NULL,
        TipoMovimiento VARCHAR(10) NOT NULL,
        FechaMovimiento DATETIME2(3) NOT NULL CONSTRAINT DF_RegistroIngreso_Fecha DEFAULT SYSDATETIME(),
        IdUsuarioSeguridad VARCHAR(50) NOT NULL,
        Observaciones NVARCHAR(500) NULL,
        CONSTRAINT CK_RegistroIngreso_Tipo CHECK (TipoMovimiento IN ('ENTRADA','SALIDA'))
    );
    CREATE INDEX IX_RegistroIngreso_PersonaFecha ON dbo.Registro_Ingreso(IdPersona,FechaMovimiento DESC);
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Control_Secuencia WHERE NombreEntidad='Registro_Ingreso')
    INSERT dbo.Control_Secuencia(NombreEntidad,UltimoValor,FechaModificacion,UsuarioModificacion) VALUES('Registro_Ingreso',0,SYSDATETIME(),'script');
IF NOT EXISTS (SELECT 1 FROM dbo.Control_Secuencia WHERE NombreEntidad='Historial_Solicitud')
    INSERT dbo.Control_Secuencia(NombreEntidad,UltimoValor,FechaModificacion,UsuarioModificacion)
    SELECT 'Historial_Solicitud',ISNULL(MAX(IdHistorialSolicitud),0),SYSDATETIME(),'script' FROM dbo.Historial_Solicitud;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Historial_Solicitud_Registrar
    @IdSolicitud BIGINT,
    @TipoEvento VARCHAR(60),
    @Accion NVARCHAR(200),
    @Comentario NVARCHAR(1000)=NULL,
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdHistorial BIGINT;
    EXEC dbo.usp_ObtenerSiguienteId 'Historial_Solicitud',@IdHistorial OUTPUT;
    INSERT dbo.Historial_Solicitud(IdHistorialSolicitud,IdSolicitud,TipoEvento,Accion,Comentario,IdUsuarioAccion,FechaAccion,FechaCreacion,UsuarioCreacion)
    VALUES(@IdHistorial,@IdSolicitud,@TipoEvento,@Accion,@Comentario,@IdUsuario,SYSDATETIME(),SYSDATETIME(),@IdUsuario);
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Solicitud_EstadoInicial ON dbo.Solicitud_Ingreso AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    UPDATE s SET IdEstadoSolicitud=e.IdEstadoSolicitud
    FROM dbo.Solicitud_Ingreso s JOIN inserted i ON i.IdSolicitud=s.IdSolicitud
    CROSS JOIN (SELECT TOP(1) IdEstadoSolicitud FROM dbo.Cat_Estado_Solicitud WHERE Codigo='BORRADOR') e
    WHERE s.IdEstadoSolicitud IS NULL;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Enviar @IdSolicitud BIGINT,@IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF NOT EXISTS(SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud=@IdSolicitud) THROW 50500,'La solicitud no existe.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Solicitud_Ingreso s WHERE s.IdSolicitud=@IdSolicitud AND (s.IdUsuarioSolicitante=@IdUsuario OR EXISTS(SELECT 1 FROM dbo.Usuario_Rol ur JOIN dbo.Rol r ON r.IdRol=ur.IdRol WHERE ur.IdUsuario=@IdUsuario AND r.Codigo='ADMINISTRADOR'))) THROW 50501,'No tienes permiso para enviar esta solicitud.',1;
    IF EXISTS(SELECT 1 FROM dbo.Solicitud_Ingreso s JOIN dbo.Cat_Estado_Solicitud e ON e.IdEstadoSolicitud=s.IdEstadoSolicitud WHERE s.IdSolicitud=@IdSolicitud AND e.EsEstadoFinal=1) THROW 50502,'La solicitud ya está finalizada o cancelada.',1;

    UPDATE spa SET RequiereAprobacion=CONVERT(BIT,CASE WHEN EXISTS(SELECT 1 FROM dbo.Config_Aprobador_Area ca WHERE ca.IdArea=spa.IdArea AND ISNULL(ca.IdEstadoGeneral,1)=1 AND (ca.FechaInicio IS NULL OR ca.FechaInicio<=CONVERT(date,SYSDATETIME())) AND (ca.FechaFin IS NULL OR ca.FechaFin>=CONVERT(date,SYSDATETIME()))) THEN 1 ELSE 0 END)
    FROM dbo.Solicitud_Persona_Area spa JOIN dbo.Solicitud_Persona sp ON sp.IdSolicitudPersona=spa.IdSolicitudPersona WHERE sp.IdSolicitud=@IdSolicitud;

    DECLARE @Codigo VARCHAR(40)=CASE
      WHEN NOT EXISTS(SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud=@IdSolicitud) AND EXISTS(SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud=@IdSolicitud AND IdProveedor IS NOT NULL) THEN 'PENDIENTE_PROVEEDOR'
      WHEN NOT EXISTS(SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud=@IdSolicitud) THEN 'EN_REVISION'
      WHEN EXISTS(SELECT 1 FROM dbo.Solicitud_Persona_Area spa JOIN dbo.Solicitud_Persona sp ON sp.IdSolicitudPersona=spa.IdSolicitudPersona WHERE sp.IdSolicitud=@IdSolicitud AND spa.RequiereAprobacion=1) THEN 'PENDIENTE_APROBACIONES'
      ELSE 'LISTA_INGRESO' END;
    UPDATE s SET IdEstadoSolicitud=e.IdEstadoSolicitud,FechaModificacion=SYSDATETIME(),UsuarioModificacion=@IdUsuario,FechaEnvioProveedor=CASE WHEN @Codigo='PENDIENTE_PROVEEDOR' THEN SYSDATETIME() ELSE FechaEnvioProveedor END
    FROM dbo.Solicitud_Ingreso s JOIN dbo.Cat_Estado_Solicitud e ON e.Codigo=@Codigo WHERE s.IdSolicitud=@IdSolicitud;
    EXEC dbo.usp_Historial_Solicitud_Registrar @IdSolicitud,'ESTADO_SOLICITUD',N'Solicitud enviada al flujo',@Codigo,@IdUsuario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Estado_Recalcular @IdSolicitudPersonaArea BIGINT,@IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdSolicitud BIGINT=(SELECT sp.IdSolicitud FROM dbo.Solicitud_Persona_Area spa JOIN dbo.Solicitud_Persona sp ON sp.IdSolicitudPersona=spa.IdSolicitudPersona WHERE spa.IdSolicitudPersonaArea=@IdSolicitudPersonaArea);
    IF @IdSolicitud IS NULL RETURN;
    DECLARE @Codigo VARCHAR(40);
    IF EXISTS(SELECT 1 FROM dbo.Solicitud_Persona_Area spa JOIN dbo.Solicitud_Persona sp ON sp.IdSolicitudPersona=spa.IdSolicitudPersona OUTER APPLY(SELECT TOP(1) ea.Codigo FROM dbo.Aprobacion_Area aa JOIN dbo.Cat_Estado_Aprobacion_Area ea ON ea.IdEstadoAprobacion=aa.IdEstadoAprobacion WHERE aa.IdSolicitudPersonaArea=spa.IdSolicitudPersonaArea ORDER BY aa.FechaDecision DESC,aa.IdAprobacionArea DESC) ult WHERE sp.IdSolicitud=@IdSolicitud AND spa.RequiereAprobacion=1 AND ult.Codigo='RECHAZADA') SET @Codigo='EN_REVISION';
    ELSE IF EXISTS(SELECT 1 FROM dbo.Solicitud_Persona_Area spa JOIN dbo.Solicitud_Persona sp ON sp.IdSolicitudPersona=spa.IdSolicitudPersona OUTER APPLY(SELECT TOP(1) ea.Codigo FROM dbo.Aprobacion_Area aa JOIN dbo.Cat_Estado_Aprobacion_Area ea ON ea.IdEstadoAprobacion=aa.IdEstadoAprobacion WHERE aa.IdSolicitudPersonaArea=spa.IdSolicitudPersonaArea ORDER BY aa.FechaDecision DESC,aa.IdAprobacionArea DESC) ult WHERE sp.IdSolicitud=@IdSolicitud AND spa.RequiereAprobacion=1 AND ISNULL(ult.Codigo,'PENDIENTE')<>'APROBADA') SET @Codigo='PENDIENTE_APROBACIONES';
    ELSE SET @Codigo='LISTA_INGRESO';
    UPDATE s SET IdEstadoSolicitud=e.IdEstadoSolicitud,FechaModificacion=SYSDATETIME(),UsuarioModificacion=@IdUsuario FROM dbo.Solicitud_Ingreso s JOIN dbo.Cat_Estado_Solicitud e ON e.Codigo=@Codigo WHERE s.IdSolicitud=@IdSolicitud;
    EXEC dbo.usp_Historial_Solicitud_Registrar @IdSolicitud,'APROBACION_AREA',N'Estado consolidado después de una decisión',@Codigo,@IdUsuario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Registro_Ingreso_Registrar @IdPersona BIGINT,@TipoMovimiento VARCHAR(10),@IdUsuarioSeguridad VARCHAR(50),@Observaciones NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @TipoMovimiento=UPPER(LTRIM(RTRIM(@TipoMovimiento)));
    IF @TipoMovimiento NOT IN('ENTRADA','SALIDA') THROW 50510,'El movimiento debe ser ENTRADA o SALIDA.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Persona WHERE IdPersona=@IdPersona) THROW 50511,'La persona no existe.',1;
    DECLARE @IdSolicitud BIGINT,@IdSolicitudPersona BIGINT;
    IF @TipoMovimiento='ENTRADA'
    BEGIN
      SELECT TOP(1) @IdSolicitud=s.IdSolicitud,@IdSolicitudPersona=sp.IdSolicitudPersona FROM dbo.Solicitud_Persona sp JOIN dbo.Solicitud_Ingreso s ON s.IdSolicitud=sp.IdSolicitud JOIN dbo.Cat_Estado_Solicitud es ON es.IdEstadoSolicitud=s.IdEstadoSolicitud WHERE sp.IdPersona=@IdPersona AND es.Codigo='LISTA_INGRESO' AND CONVERT(date,SYSDATETIME()) BETWEEN s.FechaInicio AND s.FechaFin ORDER BY s.FechaInicio DESC;
      IF @IdSolicitud IS NULL THROW 50512,'La persona no tiene una autorización vigente y completamente aprobada.',1;
      IF EXISTS(SELECT 1 FROM dbo.Registro_Ingreso ri WHERE ri.IdPersona=@IdPersona AND ri.IdSolicitud=@IdSolicitud AND ri.TipoMovimiento='ENTRADA' AND NOT EXISTS(SELECT 1 FROM dbo.Registro_Ingreso rs WHERE rs.IdPersona=ri.IdPersona AND rs.IdSolicitud=ri.IdSolicitud AND rs.TipoMovimiento='SALIDA' AND rs.FechaMovimiento>ri.FechaMovimiento)) THROW 50513,'La persona ya tiene una entrada abierta.',1;
    END
    ELSE
    BEGIN
      SELECT TOP(1) @IdSolicitud=ri.IdSolicitud,@IdSolicitudPersona=ri.IdSolicitudPersona FROM dbo.Registro_Ingreso ri WHERE ri.IdPersona=@IdPersona AND ri.TipoMovimiento='ENTRADA' AND NOT EXISTS(SELECT 1 FROM dbo.Registro_Ingreso rs WHERE rs.IdPersona=ri.IdPersona AND rs.IdSolicitud=ri.IdSolicitud AND rs.TipoMovimiento='SALIDA' AND rs.FechaMovimiento>ri.FechaMovimiento) ORDER BY ri.FechaMovimiento DESC;
      IF @IdSolicitud IS NULL THROW 50514,'La persona no tiene una entrada abierta para registrar salida.',1;
    END;
    DECLARE @Id BIGINT; EXEC dbo.usp_ObtenerSiguienteId 'Registro_Ingreso',@Id OUTPUT;
    INSERT dbo.Registro_Ingreso(IdRegistroIngreso,IdPersona,IdSolicitud,IdSolicitudPersona,TipoMovimiento,FechaMovimiento,IdUsuarioSeguridad,Observaciones) VALUES(@Id,@IdPersona,@IdSolicitud,@IdSolicitudPersona,@TipoMovimiento,SYSDATETIME(),@IdUsuarioSeguridad,NULLIF(LTRIM(RTRIM(@Observaciones)),''));
    EXEC dbo.usp_Historial_Solicitud_Registrar @IdSolicitud,'CONTROL_ACCESO',N'Movimiento registrado en portería',@TipoMovimiento,@IdUsuarioSeguridad;
    SELECT @Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Registro_Ingreso_Listar AS
BEGIN
 SET NOCOUNT ON;
 SELECT TOP(200) ri.IdRegistroIngreso,ri.IdPersona,p.NumeroDocumento,p.NombreCompleto,ri.IdSolicitud,s.NumeroSolicitud,s.NombreActividad,ri.TipoMovimiento,ri.FechaMovimiento,ri.IdUsuarioSeguridad,u.NombreCompleto,ri.Observaciones
 FROM dbo.Registro_Ingreso ri JOIN dbo.Persona p ON p.IdPersona=ri.IdPersona JOIN dbo.Solicitud_Ingreso s ON s.IdSolicitud=ri.IdSolicitud LEFT JOIN dbo.Usuario u ON u.IdUsuario=ri.IdUsuarioSeguridad ORDER BY ri.FechaMovimiento DESC,ri.IdRegistroIngreso DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Autenticar @Usuario VARCHAR(254),@Contrasena VARCHAR(200)
AS
BEGIN
 SET NOCOUNT ON; IF NULLIF(LTRIM(RTRIM(@Usuario)),'') IS NULL OR NULLIF(@Contrasena,'') IS NULL RETURN;
 SELECT TOP(1) u.IdUsuario,u.NombreCompleto,u.Correo,u.Puesto,ap.IdArea,ap.Area,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Usuario_Rol ur JOIN dbo.Rol r ON r.IdRol=ur.IdRol WHERE ur.IdUsuario=u.IdUsuario AND r.Codigo='APROBADOR') THEN 1 ELSE 0 END),
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Usuario_Area ua WHERE ua.IdUsuario=u.IdUsuario AND ISNULL(ua.PuedeSolicitar,0)=1) THEN 1 ELSE 0 END),
 roles.Roles
 FROM dbo.Usuario u JOIN dbo.Usuario_Credencial c ON c.IdUsuario=u.IdUsuario LEFT JOIN dbo.Cat_Estado_General eg ON eg.IdEstadoGeneral=u.IdEstadoGeneral
 OUTER APPLY(SELECT TOP(1) ua.IdArea,a.Nombre Area FROM dbo.Usuario_Area ua LEFT JOIN dbo.Cat_Area a ON a.IdArea=ua.IdArea WHERE ua.IdUsuario=u.IdUsuario ORDER BY ISNULL(ua.EsAreaPrincipal,0) DESC,ua.IdUsuarioArea) ap
 OUTER APPLY(SELECT STRING_AGG(r.Nombre,',') Roles FROM dbo.Usuario_Rol ur JOIN dbo.Rol r ON r.IdRol=ur.IdRol WHERE ur.IdUsuario=u.IdUsuario AND r.Activo=1) roles
 WHERE (u.IdUsuario=@Usuario OR u.Correo=@Usuario) AND c.Contrasena=@Contrasena AND ISNULL(eg.EsActivo,1)=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Ingreso_Eliminar @IdSolicitud BIGINT,@Usuario VARCHAR(50)
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud=@IdSolicitud) BEGIN SELECT 0; RETURN; END;
 DECLARE @Cancelada SMALLINT=(SELECT TOP(1) IdEstadoSolicitud FROM dbo.Cat_Estado_Solicitud WHERE Codigo='CANCELADA');
 UPDATE dbo.Solicitud_Ingreso SET IdEstadoSolicitud=@Cancelada,FechaModificacion=SYSDATETIME(),UsuarioModificacion=@Usuario WHERE IdSolicitud=@IdSolicitud;
 DECLARE @Filas INT=@@ROWCOUNT;
 IF @Filas>0 EXEC dbo.usp_Historial_Solicitud_Registrar @IdSolicitud,'ESTADO_SOLICITUD',N'Solicitud cancelada',NULL,@Usuario;
 SELECT @Filas;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Rol_Asignar
    @IdUsuario VARCHAR(50),@CodigoRol VARCHAR(30),@UsuarioAsignacion VARCHAR(50)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @IdRol SMALLINT=(SELECT IdRol FROM dbo.Rol WHERE Codigo=UPPER(LTRIM(RTRIM(@CodigoRol))) AND Activo=1);
 IF NOT EXISTS(SELECT 1 FROM dbo.Usuario WHERE IdUsuario=@IdUsuario) THROW 50520,'El usuario no existe.',1;
 IF @IdRol IS NULL THROW 50521,'El rol solicitado no existe.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Usuario_Rol WHERE IdUsuario=@IdUsuario AND IdRol=@IdRol)
  INSERT dbo.Usuario_Rol(IdUsuario,IdRol,UsuarioAsignacion) VALUES(@IdUsuario,@IdRol,@UsuarioAsignacion);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Ingreso_Listar
    @IdUsuario VARCHAR(50),
    @AccesoTotal BIT=0
AS
BEGIN
 SET NOCOUNT ON;
 SELECT s.IdSolicitud,s.NumeroSolicitud,ti.Nombre,es.Nombre,s.FechaInicio,s.FechaFin,s.NombreActividad,u.NombreCompleto,CONVERT(int,COUNT(sp.IdSolicitudPersona))
 FROM dbo.Solicitud_Ingreso s
 LEFT JOIN dbo.Cat_Tipo_Ingreso ti ON ti.IdTipoIngreso=s.IdTipoIngreso
 LEFT JOIN dbo.Cat_Estado_Solicitud es ON es.IdEstadoSolicitud=s.IdEstadoSolicitud
 LEFT JOIN dbo.Usuario u ON u.IdUsuario=s.IdUsuarioSolicitante
 LEFT JOIN dbo.Solicitud_Persona sp ON sp.IdSolicitud=s.IdSolicitud
 WHERE (@AccesoTotal=1 OR s.IdUsuarioSolicitante=@IdUsuario)
   AND ISNULL(es.Codigo,'')<>'CANCELADA'
 GROUP BY s.IdSolicitud,s.NumeroSolicitud,ti.Nombre,es.Nombre,s.FechaInicio,s.FechaFin,s.NombreActividad,u.NombreCompleto,s.FechaCreacion
 ORDER BY s.FechaCreacion DESC,s.IdSolicitud DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Administracion_Listar AS
BEGIN
 SET NOCOUNT ON;
 SELECT u.IdUsuario,u.NombreCompleto,u.Correo,u.Telefono,u.Puesto,ap.IdArea,ap.Area,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Usuario_Area ua WHERE ua.IdUsuario=u.IdUsuario AND ISNULL(ua.PuedeSolicitar,0)=1 AND ISNULL(ua.IdEstadoGeneral,1)=1) THEN 1 ELSE 0 END),
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Usuario_Rol ur JOIN dbo.Rol r ON r.IdRol=ur.IdRol WHERE ur.IdUsuario=u.IdUsuario AND r.Codigo='APROBADOR') THEN 1 ELSE 0 END),
 CONVERT(bit,CASE WHEN ISNULL(u.IdEstadoGeneral,1)=1 THEN 1 ELSE 0 END),u.FechaCreacion,roles.Roles
 FROM dbo.Usuario u
 OUTER APPLY(SELECT TOP(1) ua.IdArea,a.Nombre Area FROM dbo.Usuario_Area ua LEFT JOIN dbo.Cat_Area a ON a.IdArea=ua.IdArea WHERE ua.IdUsuario=u.IdUsuario AND ISNULL(ua.IdEstadoGeneral,1)=1 ORDER BY ISNULL(ua.EsAreaPrincipal,0) DESC,ua.IdUsuarioArea) ap
 OUTER APPLY(SELECT STRING_AGG(r.Nombre,',') Roles FROM dbo.Usuario_Rol ur JOIN dbo.Rol r ON r.IdRol=ur.IdRol WHERE ur.IdUsuario=u.IdUsuario AND r.Activo=1) roles
 ORDER BY u.NombreCompleto,u.IdUsuario;
END;
GO

/*
   Diseño solicitado sin relaciones físicas:
   toda referencia se valida dentro de los procedimientos almacenados.
   Este bloque también corrige instalaciones anteriores de esta migración.
*/
DECLARE @EliminarForeignKeys NVARCHAR(MAX) = N'';
SELECT @EliminarForeignKeys = STRING_AGG(
    CONVERT(NVARCHAR(MAX),
        N'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id)) + N'.' +
        QUOTENAME(OBJECT_NAME(parent_object_id)) + N' DROP CONSTRAINT ' + QUOTENAME(name) + N';'),
    CHAR(13) + CHAR(10))
FROM sys.foreign_keys;

IF NULLIF(@EliminarForeignKeys, N'') IS NOT NULL
    EXEC sys.sp_executesql @EliminarForeignKeys;
GO
