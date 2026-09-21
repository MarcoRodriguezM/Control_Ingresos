/* Gestión completa de actividades: creación, asignación, finalización y aprobación. */
USE [Control_Ingresos_DB];
GO

IF COL_LENGTH('dbo.Actividad', 'IdUsuarioAprobador') IS NULL
    ALTER TABLE dbo.Actividad ADD IdUsuarioAprobador VARCHAR(50) NULL;
IF COL_LENGTH('dbo.Actividad', 'FechaDecision') IS NULL
    ALTER TABLE dbo.Actividad ADD FechaDecision DATETIME2(3) NULL;
IF COL_LENGTH('dbo.Actividad', 'ComentarioDecision') IS NULL
    ALTER TABLE dbo.Actividad ADD ComentarioDecision NVARCHAR(1000) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'PENDIENTE')
    INSERT dbo.Cat_Estado_Actividad (IdEstadoActividad, Codigo, Nombre, Descripcion, EsEstadoFinal, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (1, 'PENDIENTE', N'Pendiente', N'Actividad asignada y pendiente de ejecución.', 0, 1, SYSDATETIME(), 'script');
IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'EN_PROGRESO')
    INSERT dbo.Cat_Estado_Actividad (IdEstadoActividad, Codigo, Nombre, Descripcion, EsEstadoFinal, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (2, 'EN_PROGRESO', N'En progreso', N'Actividad en ejecución.', 0, 1, SYSDATETIME(), 'script');
IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'PENDIENTE_APROBACION')
    INSERT dbo.Cat_Estado_Actividad (IdEstadoActividad, Codigo, Nombre, Descripcion, EsEstadoFinal, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (3, 'PENDIENTE_APROBACION', N'Pendiente de aprobación', N'El responsable completó la actividad y espera revisión.', 0, 1, SYSDATETIME(), 'script');
IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'APROBADA')
    INSERT dbo.Cat_Estado_Actividad (IdEstadoActividad, Codigo, Nombre, Descripcion, EsEstadoFinal, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (4, 'APROBADA', N'Aprobada', N'Actividad completada y aprobada.', 1, 1, SYSDATETIME(), 'script');
IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'RECHAZADA')
    INSERT dbo.Cat_Estado_Actividad (IdEstadoActividad, Codigo, Nombre, Descripcion, EsEstadoFinal, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (5, 'RECHAZADA', N'Rechazada', N'La actividad requiere correcciones del responsable.', 0, 1, SYSDATETIME(), 'script');
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Administracion_Listar
AS
BEGIN
    SET NOCOUNT ON;

    SELECT a.IdActividad,
           a.IdSolicitud,
           s.NumeroSolicitud,
           a.NombreActividad,
           a.IdAreaResponsable,
           ar.Nombre AS AreaResponsable,
           a.IdUsuarioResponsable,
           u.NombreCompleto AS UsuarioResponsable,
           a.IdEstadoActividad,
           ea.Codigo AS CodigoEstado,
           ea.Nombre AS Estado,
           CONVERT(BIT, ISNULL(ea.EsEstadoFinal, 0)) AS EsEstadoFinal,
           a.FechaLimite,
           a.FechaInicio,
           a.FechaFinalizacion,
           a.Comentarios,
           CONVERT(BIT, ISNULL(a.RequiereTicketExterno, 0)) AS RequiereTicketExterno,
           a.IdUsuarioAprobador,
           a.FechaDecision,
           a.ComentarioDecision
    FROM dbo.Actividad AS a
    LEFT JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = a.IdSolicitud
    LEFT JOIN dbo.Cat_Area AS ar ON ar.IdArea = a.IdAreaResponsable
    LEFT JOIN dbo.Usuario AS u ON u.IdUsuario = a.IdUsuarioResponsable
    LEFT JOIN dbo.Cat_Estado_Actividad AS ea ON ea.IdEstadoActividad = a.IdEstadoActividad
    ORDER BY CASE WHEN ea.Codigo = 'PENDIENTE_APROBACION' THEN 0 WHEN ISNULL(ea.EsEstadoFinal, 0) = 0 THEN 1 ELSE 2 END,
             a.FechaLimite,
             a.IdActividad DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Crear
    @IdSolicitud BIGINT = NULL,
    @IdAreaResponsable INT = NULL,
    @IdUsuarioResponsable VARCHAR(50),
    @NombreActividad NVARCHAR(200),
    @FechaLimite DATETIME2(3) = NULL,
    @Comentarios NVARCHAR(1000) = NULL,
    @RequiereTicketExterno BIT = 0,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@NombreActividad)), '') IS NULL
        THROW 50200, 'El nombre de la actividad es obligatorio.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuarioResponsable AND ISNULL(IdEstadoGeneral, 1) = 1)
        THROW 50201, 'El usuario responsable no existe o está inactivo.', 1;
    IF @IdSolicitud IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud)
        THROW 50202, 'La solicitud indicada no existe.', 1;
    IF @IdAreaResponsable IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdAreaResponsable)
        THROW 50203, 'El área responsable no existe.', 1;

    DECLARE @IdEstadoActividad SMALLINT = (SELECT TOP (1) IdEstadoActividad FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'PENDIENTE');
    IF @IdEstadoActividad IS NULL THROW 50204, 'No existe el estado PENDIENTE para actividades.', 1;

    DECLARE @IdActividad BIGINT;
    EXEC dbo.usp_ObtenerSiguienteId 'Actividad', @IdActividad OUTPUT;

    INSERT dbo.Actividad
    (
        IdActividad, IdSolicitud, IdAreaResponsable, IdUsuarioResponsable,
        IdEstadoActividad, NombreActividad, FechaLimite, Comentarios,
        RequiereTicketExterno, FechaCreacion, UsuarioCreacion
    )
    VALUES
    (
        @IdActividad, @IdSolicitud, @IdAreaResponsable, @IdUsuarioResponsable,
        @IdEstadoActividad, @NombreActividad, @FechaLimite, @Comentarios,
        ISNULL(@RequiereTicketExterno, 0), SYSDATETIME(), @Usuario
    );

    SELECT @IdActividad;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Completar
    @IdActividad BIGINT,
    @IdUsuarioResponsable VARCHAR(50),
    @Comentarios NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Actividad WHERE IdActividad = @IdActividad AND IdUsuarioResponsable = @IdUsuarioResponsable)
        THROW 50210, 'La actividad no existe o no está asignada al usuario actual.', 1;

    DECLARE @CodigoActual VARCHAR(30) =
    (
        SELECT ea.Codigo
        FROM dbo.Actividad a
        LEFT JOIN dbo.Cat_Estado_Actividad ea ON ea.IdEstadoActividad = a.IdEstadoActividad
        WHERE a.IdActividad = @IdActividad
    );
    IF @CodigoActual IN ('PENDIENTE_APROBACION', 'APROBADA')
        THROW 50211, 'La actividad ya fue completada y no puede enviarse nuevamente en su estado actual.', 1;

    DECLARE @IdPendienteAprobacion SMALLINT = (SELECT TOP (1) IdEstadoActividad FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'PENDIENTE_APROBACION');
    IF @IdPendienteAprobacion IS NULL THROW 50212, 'No existe el estado PENDIENTE_APROBACION.', 1;

    UPDATE dbo.Actividad
       SET IdEstadoActividad = @IdPendienteAprobacion,
           FechaInicio = COALESCE(FechaInicio, SYSDATETIME()),
           FechaFinalizacion = SYSDATETIME(),
           Comentarios = CASE WHEN NULLIF(LTRIM(RTRIM(@Comentarios)), '') IS NULL THEN Comentarios
                              WHEN NULLIF(LTRIM(RTRIM(Comentarios)), '') IS NULL THEN @Comentarios
                              ELSE CONCAT(Comentarios, CHAR(13), CHAR(10), @Comentarios) END,
           IdUsuarioAprobador = NULL,
           FechaDecision = NULL,
           ComentarioDecision = NULL,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuarioResponsable
     WHERE IdActividad = @IdActividad;

    SELECT @IdActividad;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Decidir
    @IdActividad BIGINT,
    @IdUsuarioAprobador VARCHAR(50),
    @CodigoEstado VARCHAR(30),
    @ComentarioDecision NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @CodigoEstado = UPPER(LTRIM(RTRIM(@CodigoEstado)));
    IF @CodigoEstado NOT IN ('APROBADA', 'RECHAZADA')
        THROW 50220, 'La decisión debe ser APROBADA o RECHAZADA.', 1;
    IF @CodigoEstado = 'RECHAZADA' AND NULLIF(LTRIM(RTRIM(@ComentarioDecision)), '') IS NULL
        THROW 50221, 'Debe indicar el motivo del rechazo.', 1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Actividad a
        INNER JOIN dbo.Cat_Estado_Actividad ea ON ea.IdEstadoActividad = a.IdEstadoActividad
        WHERE a.IdActividad = @IdActividad AND ea.Codigo = 'PENDIENTE_APROBACION'
    )
        THROW 50222, 'La actividad no está pendiente de aprobación.', 1;

    DECLARE @IdEstadoActividad SMALLINT = (SELECT TOP (1) IdEstadoActividad FROM dbo.Cat_Estado_Actividad WHERE Codigo = @CodigoEstado);
    IF @IdEstadoActividad IS NULL THROW 50223, 'El estado solicitado no existe.', 1;

    UPDATE dbo.Actividad
       SET IdEstadoActividad = @IdEstadoActividad,
           IdUsuarioAprobador = @IdUsuarioAprobador,
           FechaDecision = SYSDATETIME(),
           ComentarioDecision = NULLIF(LTRIM(RTRIM(@ComentarioDecision)), ''),
           FechaFinalizacion = CASE WHEN @CodigoEstado = 'APROBADA' THEN COALESCE(FechaFinalizacion, SYSDATETIME()) ELSE NULL END,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuarioAprobador
     WHERE IdActividad = @IdActividad;

    SELECT @IdActividad;
END;
GO
