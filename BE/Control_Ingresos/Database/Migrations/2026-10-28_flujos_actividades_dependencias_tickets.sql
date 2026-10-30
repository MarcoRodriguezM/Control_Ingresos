SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
    Flujos de actividades versionados.
    - Ninguna llave primaria es autonumerica.
    - No se crean llaves foraneas.
    - Todos los campos que no son llave primaria permanecen nulleables.
    - La integridad relacional se valida en procedimientos almacenados.
*/

IF OBJECT_ID('dbo.Actividad_Flujo', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Actividad_Flujo
    (
        IdActividadFlujo BIGINT NOT NULL,
        IdAreaAcceso INT NULL,
        Codigo VARCHAR(40) NULL,
        Nombre NVARCHAR(150) NULL,
        Descripcion NVARCHAR(500) NULL,
        IdActividadFlujoVersionActual BIGINT NULL,
        IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo PRIMARY KEY (IdActividadFlujo)
    );
END;
GO

IF OBJECT_ID('dbo.Actividad_Flujo_Version', 'U') IS NULL
    CREATE TABLE dbo.Actividad_Flujo_Version
    (
        IdActividadFlujoVersion BIGINT NOT NULL PRIMARY KEY, IdActividadFlujo BIGINT NULL,
        NumeroVersion INT NULL, EsPublicada BIT NULL, IdEstadoGeneral SMALLINT NULL,
        FechaPublicacion DATETIME2(3) NULL, FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL, FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL
    );
IF OBJECT_ID('dbo.Actividad_Flujo_Version_Tipo_Ingreso', 'U') IS NULL
    CREATE TABLE dbo.Actividad_Flujo_Version_Tipo_Ingreso
    (
        IdActividadFlujoVersionTipoIngreso BIGINT NOT NULL PRIMARY KEY,
        IdActividadFlujoVersion BIGINT NULL, IdTipoIngreso SMALLINT NULL,
        IdEstadoGeneral SMALLINT NULL, FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL, FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL
    );
IF OBJECT_ID('dbo.Actividad_Flujo_Paso', 'U') IS NULL
    CREATE TABLE dbo.Actividad_Flujo_Paso
    (
        IdActividadFlujoPaso BIGINT NOT NULL PRIMARY KEY, IdActividadFlujoVersion BIGINT NULL,
        IdRequerimiento INT NULL, ClavePaso VARCHAR(80) NULL, OrdenVisual INT NULL,
        NombreActividad NVARCHAR(200) NULL, IdAreaResponsable INT NULL,
        RequiereTicketExterno BIT NULL, VigenciaMeses INT NULL, FechaInicio DATE NULL,
        FechaFin DATE NULL, IdEstadoGeneral SMALLINT NULL, FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL, FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL
    );

/* La configuracion anterior se conserva como un flujo independiente por cada
   actividad configurada. Solo se ejecuta cuando el modelo nuevo esta vacio. */
IF NOT EXISTS (SELECT 1 FROM dbo.Actividad_Flujo)
BEGIN
    DECLARE @ActivoMigracion SMALLINT =
        (SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'ACTIVO');
    DECLARE @IdConfig BIGINT, @IdAreaAccesoMigracion INT, @IdRequerimientoMigracion INT,
            @IdAreaResponsableMigracion INT, @NombreMigracion NVARCHAR(150), @TicketMigracion BIT,
            @IdFlujoMigracion BIGINT, @IdVersionMigracion BIGINT, @IdPasoMigracion BIGINT,
            @IdTipoFiltro BIGINT, @IdFiltroMigracion BIGINT;

    DECLARE configuracion_anterior_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT config.IdConfigReqArea, config.IdAreaAcceso, config.IdRequerimiento,
               config.IdAreaResponsable, requerimiento.Nombre,
               CONVERT(BIT, ISNULL(requerimiento.RequiereTicketExterno, 0))
        FROM dbo.Config_Requerimiento_Area AS config
        INNER JOIN dbo.Cat_Requerimiento AS requerimiento
            ON requerimiento.IdRequerimiento = config.IdRequerimiento
        LEFT JOIN dbo.Cat_Estado_General AS estado
            ON estado.IdEstadoGeneral = config.IdEstadoGeneral
        WHERE ISNULL(estado.EsActivo, 1) = 1
        ORDER BY config.IdAreaAcceso, config.IdConfigReqArea;

    OPEN configuracion_anterior_cursor;
    FETCH NEXT FROM configuracion_anterior_cursor INTO @IdConfig, @IdAreaAccesoMigracion,
        @IdRequerimientoMigracion, @IdAreaResponsableMigracion, @NombreMigracion, @TicketMigracion;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.usp_ObtenerSiguienteId 'Actividad_Flujo', @IdFlujoMigracion OUTPUT;
        EXEC dbo.usp_ObtenerSiguienteId 'Actividad_Flujo_Version', @IdVersionMigracion OUTPUT;
        EXEC dbo.usp_ObtenerSiguienteId 'Actividad_Flujo_Paso', @IdPasoMigracion OUTPUT;

        INSERT dbo.Actividad_Flujo
        (
            IdActividadFlujo, IdAreaAcceso, Codigo, Nombre, Descripcion,
            IdActividadFlujoVersionActual, IdEstadoGeneral, FechaCreacion, UsuarioCreacion
        )
        VALUES
        (
            @IdFlujoMigracion, @IdAreaAccesoMigracion, CONCAT('LEGACY_', @IdConfig),
            COALESCE(@NombreMigracion, CONCAT(N'Flujo ', @IdConfig)),
            N'Migrado desde la configuracion anterior.', @IdVersionMigracion,
            @ActivoMigracion, SYSDATETIME(), 'MIGRACION'
        );
        INSERT dbo.Actividad_Flujo_Version
        (
            IdActividadFlujoVersion, IdActividadFlujo, NumeroVersion, EsPublicada,
            IdEstadoGeneral, FechaPublicacion, FechaCreacion, UsuarioCreacion
        )
        VALUES
        (
            @IdVersionMigracion, @IdFlujoMigracion, 1, 1,
            @ActivoMigracion, SYSDATETIME(), SYSDATETIME(), 'MIGRACION'
        );
        INSERT dbo.Actividad_Flujo_Paso
        (
            IdActividadFlujoPaso, IdActividadFlujoVersion, IdRequerimiento, ClavePaso,
            OrdenVisual, NombreActividad, IdAreaResponsable, RequiereTicketExterno,
            VigenciaMeses, IdEstadoGeneral, FechaCreacion, UsuarioCreacion
        )
        VALUES
        (
            @IdPasoMigracion, @IdVersionMigracion, @IdRequerimientoMigracion,
            CONCAT('legacy-', @IdConfig), 1, @NombreMigracion,
            @IdAreaResponsableMigracion, @TicketMigracion, 24,
            @ActivoMigracion, SYSDATETIME(), 'MIGRACION'
        );

        DECLARE tipos_migracion_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT DISTINCT filtro.IdTipoIngreso
            FROM dbo.Config_Requerimiento_Tipo_Ingreso AS filtro
            LEFT JOIN dbo.Cat_Estado_General AS estadoFiltro
                ON estadoFiltro.IdEstadoGeneral = filtro.IdEstadoGeneral
            WHERE filtro.IdRequerimiento = @IdRequerimientoMigracion
              AND ISNULL(estadoFiltro.EsActivo, 1) = 1;
        OPEN tipos_migracion_cursor;
        FETCH NEXT FROM tipos_migracion_cursor INTO @IdTipoFiltro;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_ObtenerSiguienteId 'Actividad_Flujo_Version_Tipo_Ingreso', @IdFiltroMigracion OUTPUT;
            INSERT dbo.Actividad_Flujo_Version_Tipo_Ingreso
            (
                IdActividadFlujoVersionTipoIngreso, IdActividadFlujoVersion, IdTipoIngreso,
                IdEstadoGeneral, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdFiltroMigracion, @IdVersionMigracion, @IdTipoFiltro,
                @ActivoMigracion, SYSDATETIME(), 'MIGRACION'
            );
            FETCH NEXT FROM tipos_migracion_cursor INTO @IdTipoFiltro;
        END;
        CLOSE tipos_migracion_cursor;
        DEALLOCATE tipos_migracion_cursor;

        FETCH NEXT FROM configuracion_anterior_cursor INTO @IdConfig, @IdAreaAccesoMigracion,
            @IdRequerimientoMigracion, @IdAreaResponsableMigracion, @NombreMigracion, @TicketMigracion;
    END;
    CLOSE configuracion_anterior_cursor;
    DEALLOCATE configuracion_anterior_cursor;
END;
GO

/* Precreacion idempotente para que todos los procedimientos compilen en una
   base que aun no tenga el modelo de flujos y tickets. */
IF OBJECT_ID('dbo.Actividad_Flujo_Version', 'U') IS NULL
    CREATE TABLE dbo.Actividad_Flujo_Version
    (
        IdActividadFlujoVersion BIGINT NOT NULL,
        IdActividadFlujo BIGINT NULL, NumeroVersion INT NULL, EsPublicada BIT NULL,
        IdEstadoGeneral SMALLINT NULL, FechaPublicacion DATETIME2(3) NULL,
        FechaCreacion DATETIME2(3) NULL, UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL, UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Version PRIMARY KEY (IdActividadFlujoVersion)
    );
IF OBJECT_ID('dbo.Actividad_Flujo_Version_Tipo_Ingreso', 'U') IS NULL
    CREATE TABLE dbo.Actividad_Flujo_Version_Tipo_Ingreso
    (
        IdActividadFlujoVersionTipoIngreso BIGINT NOT NULL,
        IdActividadFlujoVersion BIGINT NULL, IdTipoIngreso SMALLINT NULL,
        IdEstadoGeneral SMALLINT NULL, FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL, FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Version_Tipo_Ingreso PRIMARY KEY (IdActividadFlujoVersionTipoIngreso)
    );
IF OBJECT_ID('dbo.Actividad_Flujo_Paso', 'U') IS NULL
    CREATE TABLE dbo.Actividad_Flujo_Paso
    (
        IdActividadFlujoPaso BIGINT NOT NULL,
        IdActividadFlujoVersion BIGINT NULL, IdRequerimiento INT NULL,
        ClavePaso VARCHAR(80) NULL, OrdenVisual INT NULL, NombreActividad NVARCHAR(200) NULL,
        IdAreaResponsable INT NULL, RequiereTicketExterno BIT NULL, VigenciaMeses INT NULL,
        FechaInicio DATE NULL, FechaFin DATE NULL, IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL, UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL, UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Paso PRIMARY KEY (IdActividadFlujoPaso)
    );
IF OBJECT_ID('dbo.Actividad_Flujo_Paso_Dependencia', 'U') IS NULL
    CREATE TABLE dbo.Actividad_Flujo_Paso_Dependencia
    (
        IdActividadFlujoPasoDependencia BIGINT NOT NULL,
        IdActividadFlujoPaso BIGINT NULL, IdActividadFlujoPasoRequerido BIGINT NULL,
        IdEstadoGeneral SMALLINT NULL, FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL, FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Paso_Dependencia PRIMARY KEY (IdActividadFlujoPasoDependencia)
    );
IF OBJECT_ID('dbo.Solicitud_Persona_Area_Flujo', 'U') IS NULL
    CREATE TABLE dbo.Solicitud_Persona_Area_Flujo
    (
        IdSolicitudPersonaAreaFlujo BIGINT NOT NULL,
        IdSolicitudPersonaArea BIGINT NULL, IdActividadFlujo BIGINT NULL,
        IdActividadFlujoVersion BIGINT NULL, IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL, UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL, UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Solicitud_Persona_Area_Flujo PRIMARY KEY (IdSolicitudPersonaAreaFlujo)
    );
IF OBJECT_ID('dbo.Ticket_Externo', 'U') IS NULL
    CREATE TABLE dbo.Ticket_Externo
    (
        IdTicketExterno BIGINT NOT NULL,
        IdSolicitud BIGINT NULL, Plataforma NVARCHAR(100) NULL, NumeroTicket VARCHAR(80) NULL,
        UrlTicket NVARCHAR(500) NULL, FechaRegistro DATETIME2(3) NULL,
        IdUsuarioRegistro VARCHAR(50) NULL, IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL, UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL, UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Ticket_Externo PRIMARY KEY (IdTicketExterno)
    );
IF OBJECT_ID('dbo.Ticket_Externo_Actividad', 'U') IS NULL
    CREATE TABLE dbo.Ticket_Externo_Actividad
    (
        IdTicketExternoActividad BIGINT NOT NULL,
        IdTicketExterno BIGINT NULL, IdActividad BIGINT NULL, IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL, UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL, UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Ticket_Externo_Actividad PRIMARY KEY (IdTicketExternoActividad)
    );
IF COL_LENGTH('dbo.Actividad', 'IdSolicitudPersonaAreaFlujo') IS NULL ALTER TABLE dbo.Actividad ADD IdSolicitudPersonaAreaFlujo BIGINT NULL;
IF COL_LENGTH('dbo.Actividad', 'IdActividadFlujoVersion') IS NULL ALTER TABLE dbo.Actividad ADD IdActividadFlujoVersion BIGINT NULL;
IF COL_LENGTH('dbo.Actividad', 'IdActividadFlujoPaso') IS NULL ALTER TABLE dbo.Actividad ADD IdActividadFlujoPaso BIGINT NULL;
IF COL_LENGTH('dbo.Actividad', 'IdAreaAcceso') IS NULL ALTER TABLE dbo.Actividad ADD IdAreaAcceso INT NULL;
IF COL_LENGTH('dbo.Actividad', 'IdEstadoGeneral') IS NULL ALTER TABLE dbo.Actividad ADD IdEstadoGeneral SMALLINT NULL;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Ticket_Guardar
    @IdActividadPrincipal BIGINT,
    @IdTicketExterno BIGINT = NULL,
    @IdsActividadJson NVARCHAR(MAX) = NULL,
    @Plataforma NVARCHAR(100) = NULL,
    @NumeroTicket VARCHAR(80) = NULL,
    @UrlTicket NVARCHAR(500) = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Plataforma = NULLIF(LTRIM(RTRIM(@Plataforma)), '');
    SET @NumeroTicket = NULLIF(LTRIM(RTRIM(@NumeroTicket)), '');
    SET @UrlTicket = NULLIF(LTRIM(RTRIM(@UrlTicket)), '');
    IF @IdTicketExterno IS NULL AND (@Plataforma IS NULL OR @NumeroTicket IS NULL)
        THROW 50340, 'Indica la plataforma y el numero del ticket.', 1;

    DECLARE @Actividades TABLE (IdActividad BIGINT PRIMARY KEY);
    INSERT @Actividades VALUES (@IdActividadPrincipal);
    IF ISJSON(COALESCE(@IdsActividadJson, '[]')) = 1
        INSERT @Actividades (IdActividad)
        SELECT DISTINCT TRY_CONVERT(BIGINT, item.[value])
        FROM OPENJSON(COALESCE(@IdsActividadJson, '[]')) AS item
        WHERE TRY_CONVERT(BIGINT, item.[value]) IS NOT NULL
          AND TRY_CONVERT(BIGINT, item.[value]) <> @IdActividadPrincipal;

    DECLARE @IdSolicitud BIGINT =
    (
        SELECT actividad.IdSolicitud FROM dbo.Actividad AS actividad
        WHERE actividad.IdActividad = @IdActividadPrincipal
    );
    IF @IdSolicitud IS NULL OR NOT EXISTS
    (
        SELECT 1 FROM dbo.Solicitud_Ingreso
        WHERE IdSolicitud = @IdSolicitud AND IdUsuarioSolicitante = @Usuario
    ) THROW 50341, 'La actividad no pertenece a una solicitud del usuario actual.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Actividades AS seleccion
        LEFT JOIN dbo.Actividad AS actividad ON actividad.IdActividad = seleccion.IdActividad
        LEFT JOIN dbo.Cat_Estado_Actividad AS estado
            ON estado.IdEstadoActividad = actividad.IdEstadoActividad
        WHERE actividad.IdActividad IS NULL
           OR actividad.IdSolicitud <> @IdSolicitud
           OR ISNULL(actividad.RequiereTicketExterno, 0) = 0
           OR ISNULL(estado.EsEstadoFinal, 0) = 1
    ) THROW 50342, 'Todas las actividades deben pertenecer a la misma solicitud, requerir ticket y estar pendientes.', 1;

    DECLARE @Activo SMALLINT = (SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'ACTIVO');
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @IdTicketExterno IS NULL
        BEGIN
            EXEC dbo.usp_ObtenerSiguienteId 'Ticket_Externo', @IdTicketExterno OUTPUT;
            INSERT dbo.Ticket_Externo
            (
                IdTicketExterno, IdSolicitud, Plataforma, NumeroTicket, UrlTicket,
                FechaRegistro, IdUsuarioRegistro, IdEstadoGeneral, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdTicketExterno, @IdSolicitud, @Plataforma, @NumeroTicket, @UrlTicket,
                SYSDATETIME(), @Usuario, @Activo, SYSDATETIME(), @Usuario
            );
        END
        ELSE IF NOT EXISTS
        (
            SELECT 1 FROM dbo.Ticket_Externo
            WHERE IdTicketExterno = @IdTicketExterno AND IdSolicitud = @IdSolicitud
        ) THROW 50343, 'El ticket indicado no pertenece a la solicitud.', 1;

        DECLARE @IdActividad BIGINT, @IdEnlace BIGINT;
        DECLARE actividades_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT IdActividad FROM @Actividades;
        OPEN actividades_cursor;
        FETCH NEXT FROM actividades_cursor INTO @IdActividad;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1 FROM dbo.Ticket_Externo_Actividad
                WHERE IdTicketExterno = @IdTicketExterno AND IdActividad = @IdActividad
            )
            BEGIN
                EXEC dbo.usp_ObtenerSiguienteId 'Ticket_Externo_Actividad', @IdEnlace OUTPUT;
                INSERT dbo.Ticket_Externo_Actividad
                (
                    IdTicketExternoActividad, IdTicketExterno, IdActividad,
                    IdEstadoGeneral, FechaCreacion, UsuarioCreacion
                )
                VALUES
                (
                    @IdEnlace, @IdTicketExterno, @IdActividad,
                    @Activo, SYSDATETIME(), @Usuario
                );
            END;
            FETCH NEXT FROM actividades_cursor INTO @IdActividad;
        END;
        CLOSE actividades_cursor;
        DEALLOCATE actividades_cursor;

        COMMIT TRANSACTION;
        SELECT IdTicketExterno, Plataforma, NumeroTicket, UrlTicket, FechaRegistro, IdSolicitud
        FROM dbo.Ticket_Externo WHERE IdTicketExterno = @IdTicketExterno;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'actividades_cursor') >= 0 BEGIN CLOSE actividades_cursor; DEALLOCATE actividades_cursor; END;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
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

    EXEC dbo.usp_Actividad_Validar_Desbloqueada @IdActividad, @IdUsuarioResponsable;

    DECLARE @IdAprobada SMALLINT =
        (SELECT TOP (1) IdEstadoActividad FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'APROBADA');
    IF @IdAprobada IS NULL THROW 50350, 'No existe el estado APROBADA para las actividades.', 1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.Actividad AS actividad
        WHERE actividad.IdActividad = @IdActividad
          AND actividad.IdUsuarioResponsable = @IdUsuarioResponsable
          AND ISNULL(actividad.RequiereTicketExterno, 0) = 1
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.Ticket_Externo_Actividad AS enlace
              WHERE enlace.IdActividad = actividad.IdActividad
          )
    ) THROW 50351, 'Primero debes registrar al menos un ticket para esta actividad.', 1;

    UPDATE actividad
       SET IdEstadoActividad = @IdAprobada,
           FechaInicio = COALESCE(actividad.FechaInicio, SYSDATETIME()),
           FechaFinalizacion = SYSDATETIME(),
           Comentarios = CASE
               WHEN NULLIF(LTRIM(RTRIM(@Comentarios)), '') IS NULL THEN actividad.Comentarios
               WHEN NULLIF(LTRIM(RTRIM(actividad.Comentarios)), '') IS NULL THEN @Comentarios
               ELSE CONCAT(actividad.Comentarios, CHAR(13), CHAR(10), @Comentarios)
           END,
           IdUsuarioAprobador = @IdUsuarioResponsable,
           FechaDecision = SYSDATETIME(),
           ComentarioDecision = N'Aprobada automaticamente al registrar su realizacion.',
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuarioResponsable
    FROM dbo.Actividad AS actividad
    LEFT JOIN dbo.Cat_Estado_Actividad AS estadoActual
        ON estadoActual.IdEstadoActividad = actividad.IdEstadoActividad
    WHERE actividad.IdActividad = @IdActividad
      AND actividad.IdUsuarioResponsable = @IdUsuarioResponsable
      AND ISNULL(estadoActual.Codigo, '') <> 'APROBADA';

    IF @@ROWCOUNT = 0
        THROW 50352, 'La actividad no existe, ya fue aprobada o no esta asignada al usuario actual.', 1;
    SELECT @IdActividad;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Tickets_Listar
    @IdSolicitud BIGINT,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Solicitud_Ingreso
        WHERE IdSolicitud = @IdSolicitud AND IdUsuarioSolicitante = @Usuario
    ) THROW 50360, 'La solicitud no pertenece al usuario actual.', 1;

    SELECT actividad.IdActividad, solicitud.IdSolicitud, solicitud.FechaFin, solicitud.NumeroSolicitud,
           actividad.NombreActividad, COALESCE(persona.NombreCompleto, solicitudPersona.CodigoEmpleadoHtis),
           area.Nombre, CONVERT(BIT, ISNULL(estadoActividad.EsEstadoFinal, 0)),
           ticket.IdTicketExterno, ticket.Plataforma, ticket.NumeroTicket,
           ticket.UrlTicket, ticket.FechaRegistro, actividad.IdSolicitudPersona
    FROM dbo.Actividad AS actividad
    INNER JOIN dbo.Solicitud_Ingreso AS solicitud ON solicitud.IdSolicitud = actividad.IdSolicitud
    LEFT JOIN dbo.Solicitud_Persona AS solicitudPersona
        ON solicitudPersona.IdSolicitudPersona = actividad.IdSolicitudPersona
    LEFT JOIN dbo.Persona AS persona ON persona.IdPersona = solicitudPersona.IdPersona
    LEFT JOIN dbo.Cat_Area AS area ON area.IdArea = actividad.IdAreaResponsable
    LEFT JOIN dbo.Cat_Estado_Actividad AS estadoActividad
        ON estadoActividad.IdEstadoActividad = actividad.IdEstadoActividad
    LEFT JOIN dbo.Ticket_Externo_Actividad AS enlace ON enlace.IdActividad = actividad.IdActividad
    LEFT JOIN dbo.Ticket_Externo AS ticket ON ticket.IdTicketExterno = enlace.IdTicketExterno
    LEFT JOIN dbo.Cat_Estado_General AS estadoActividadGeneral
        ON estadoActividadGeneral.IdEstadoGeneral = actividad.IdEstadoGeneral
    WHERE solicitud.IdSolicitud = @IdSolicitud
      AND ISNULL(actividad.RequiereTicketExterno, 0) = 1
      AND ISNULL(estadoActividadGeneral.EsActivo, 1) = 1
    ORDER BY actividad.IdSolicitudPersona, actividad.IdActividad, ticket.FechaRegistro, ticket.IdTicketExterno;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Mis_Listar
    @IdUsuarioResponsable VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT actividad.IdActividad, actividad.IdSolicitud, solicitud.NumeroSolicitud,
           actividad.NombreActividad, areaResponsable.Nombre,
           estadoActividad.Codigo, estadoActividad.Nombre,
           CONVERT(BIT, ISNULL(estadoActividad.EsEstadoFinal, 0)),
           actividad.FechaLimite, actividad.FechaInicio, actividad.FechaFinalizacion,
           actividad.Comentarios, CONVERT(BIT, ISNULL(actividad.RequiereTicketExterno, 0)),
           actividad.IdSolicitudPersona, persona.NombreCompleto, persona.NumeroDocumento,
           actividad.IdAreaAcceso, areaAcceso.Nombre,
           ticket.IdTicketExterno, ticket.Plataforma, ticket.NumeroTicket,
           ticket.UrlTicket, ticket.FechaRegistro
    FROM dbo.Actividad AS actividad
    LEFT JOIN dbo.Solicitud_Ingreso AS solicitud ON solicitud.IdSolicitud = actividad.IdSolicitud
    LEFT JOIN dbo.Solicitud_Persona AS solicitudPersona
        ON solicitudPersona.IdSolicitudPersona = actividad.IdSolicitudPersona
    LEFT JOIN dbo.Persona AS persona ON persona.IdPersona = solicitudPersona.IdPersona
    LEFT JOIN dbo.Cat_Area AS areaResponsable ON areaResponsable.IdArea = actividad.IdAreaResponsable
    LEFT JOIN dbo.Cat_Area AS areaAcceso ON areaAcceso.IdArea = actividad.IdAreaAcceso
    LEFT JOIN dbo.Cat_Estado_Actividad AS estadoActividad
        ON estadoActividad.IdEstadoActividad = actividad.IdEstadoActividad
    LEFT JOIN dbo.Ticket_Externo_Actividad AS enlace ON enlace.IdActividad = actividad.IdActividad
    LEFT JOIN dbo.Ticket_Externo AS ticket ON ticket.IdTicketExterno = enlace.IdTicketExterno
    LEFT JOIN dbo.Cat_Estado_General AS estadoActividadGeneral
        ON estadoActividadGeneral.IdEstadoGeneral = actividad.IdEstadoGeneral
    WHERE actividad.IdUsuarioResponsable = @IdUsuarioResponsable
      AND ISNULL(estadoActividadGeneral.EsActivo, 1) = 1
      AND (actividad.IdSolicitud IS NULL OR solicitud.FechaFin IS NULL OR solicitud.FechaFin >= CONVERT(DATE, SYSDATETIME()))
    ORDER BY actividad.IdActividad, ticket.FechaRegistro, ticket.IdTicketExterno;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Administracion_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT actividad.IdActividad, actividad.IdSolicitud, solicitud.NumeroSolicitud,
           actividad.NombreActividad, actividad.IdAreaResponsable, areaResponsable.Nombre,
           actividad.IdUsuarioResponsable, usuarioResponsable.NombreCompleto,
           actividad.IdEstadoActividad, estadoActividad.Codigo, estadoActividad.Nombre,
           CONVERT(BIT, ISNULL(estadoActividad.EsEstadoFinal, 0)),
           actividad.FechaLimite, actividad.FechaInicio, actividad.FechaFinalizacion,
           actividad.Comentarios, CONVERT(BIT, ISNULL(actividad.RequiereTicketExterno, 0)),
           actividad.IdUsuarioAprobador, actividad.FechaDecision, actividad.ComentarioDecision,
           actividad.IdSolicitudPersona, persona.NombreCompleto, persona.NumeroDocumento,
           actividad.IdAreaAcceso, areaAcceso.Nombre,
           ticket.IdTicketExterno, ticket.Plataforma, ticket.NumeroTicket,
           ticket.UrlTicket, ticket.FechaRegistro
    FROM dbo.Actividad AS actividad
    LEFT JOIN dbo.Solicitud_Ingreso AS solicitud ON solicitud.IdSolicitud = actividad.IdSolicitud
    LEFT JOIN dbo.Solicitud_Persona AS solicitudPersona
        ON solicitudPersona.IdSolicitudPersona = actividad.IdSolicitudPersona
    LEFT JOIN dbo.Persona AS persona ON persona.IdPersona = solicitudPersona.IdPersona
    LEFT JOIN dbo.Cat_Area AS areaResponsable ON areaResponsable.IdArea = actividad.IdAreaResponsable
    LEFT JOIN dbo.Cat_Area AS areaAcceso ON areaAcceso.IdArea = actividad.IdAreaAcceso
    LEFT JOIN dbo.Usuario AS usuarioResponsable
        ON usuarioResponsable.IdUsuario = actividad.IdUsuarioResponsable
    LEFT JOIN dbo.Cat_Estado_Actividad AS estadoActividad
        ON estadoActividad.IdEstadoActividad = actividad.IdEstadoActividad
    LEFT JOIN dbo.Ticket_Externo_Actividad AS enlace ON enlace.IdActividad = actividad.IdActividad
    LEFT JOIN dbo.Ticket_Externo AS ticket ON ticket.IdTicketExterno = enlace.IdTicketExterno
    LEFT JOIN dbo.Cat_Estado_General AS estadoActividadGeneral
        ON estadoActividadGeneral.IdEstadoGeneral = actividad.IdEstadoGeneral
    WHERE ISNULL(estadoActividadGeneral.EsActivo, 1) = 1
      AND (actividad.IdSolicitud IS NULL OR solicitud.FechaFin IS NULL OR solicitud.FechaFin >= CONVERT(DATE, SYSDATETIME()))
    ORDER BY actividad.IdActividad, ticket.FechaRegistro, ticket.IdTicketExterno;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Estado_Ticket_Sincronizar
    @IdSolicitud BIGINT,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Actual VARCHAR(40) =
    (
        SELECT estado.Codigo
        FROM dbo.Solicitud_Ingreso AS solicitud WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Cat_Estado_Solicitud AS estado
            ON estado.IdEstadoSolicitud = solicitud.IdEstadoSolicitud
        WHERE solicitud.IdSolicitud = @IdSolicitud
    );
    IF @Actual IS NULL OR @Actual IN ('BORRADOR', 'PENDIENTE_PROVEEDOR', 'FINALIZADA', 'CANCELADA') RETURN;

    DECLARE @Pendientes INT =
    (
        SELECT COUNT(*)
        FROM dbo.Actividad AS actividad
        LEFT JOIN dbo.Cat_Estado_Actividad AS estadoActividad
            ON estadoActividad.IdEstadoActividad = actividad.IdEstadoActividad
        LEFT JOIN dbo.Cat_Estado_General AS estadoGeneral
            ON estadoGeneral.IdEstadoGeneral = actividad.IdEstadoGeneral
        WHERE actividad.IdSolicitud = @IdSolicitud
          AND actividad.IdSolicitudPersona IS NOT NULL
          AND ISNULL(actividad.RequiereTicketExterno, 0) = 1
          AND ISNULL(estadoActividad.EsEstadoFinal, 0) = 0
          AND ISNULL(estadoGeneral.EsActivo, 1) = 1
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.Ticket_Externo_Actividad AS enlace
              WHERE enlace.IdActividad = actividad.IdActividad
          )
    );

    DECLARE @Siguiente VARCHAR(40) = @Actual;
    IF @Pendientes > 0 SET @Siguiente = 'PENDIENTE_CREACION_TICKET';
    ELSE IF EXISTS
    (
        SELECT 1 FROM dbo.Solicitud_Persona_Area AS areaPersona
        INNER JOIN dbo.Solicitud_Persona AS solicitudPersona
            ON solicitudPersona.IdSolicitudPersona = areaPersona.IdSolicitudPersona
        INNER JOIN dbo.Cat_Estado_Aprobacion_Area AS estado
            ON estado.IdEstadoAprobacion = areaPersona.IdEstadoAprobacion
        WHERE solicitudPersona.IdSolicitud = @IdSolicitud AND estado.Codigo = 'RECHAZADA'
    ) SET @Siguiente = 'EN_REVISION';
    ELSE IF EXISTS
    (
        SELECT 1 FROM dbo.Solicitud_Persona_Area AS areaPersona
        INNER JOIN dbo.Solicitud_Persona AS solicitudPersona
            ON solicitudPersona.IdSolicitudPersona = areaPersona.IdSolicitudPersona
        LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS estado
            ON estado.IdEstadoAprobacion = areaPersona.IdEstadoAprobacion
        WHERE solicitudPersona.IdSolicitud = @IdSolicitud
          AND ISNULL(estado.Codigo, 'PENDIENTE') NOT IN ('APROBADA', 'RECHAZADA')
    ) SET @Siguiente = 'PENDIENTE_APROBACIONES';
    ELSE IF EXISTS
    (
        SELECT 1 FROM dbo.Solicitud_Persona_Area AS areaPersona
        INNER JOIN dbo.Solicitud_Persona AS solicitudPersona
            ON solicitudPersona.IdSolicitudPersona = areaPersona.IdSolicitudPersona
        WHERE solicitudPersona.IdSolicitud = @IdSolicitud
    ) SET @Siguiente = 'LISTA_INGRESO';
    ELSE SET @Siguiente = 'CONFIGURACION_ACCESOS';

    IF @Siguiente = @Actual RETURN;
    IF @Siguiente = 'PENDIENTE_CREACION_TICKET'
       AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Solicitud WHERE Codigo = @Siguiente)
    BEGIN
        DECLARE @NuevoId SMALLINT =
            (SELECT CONVERT(SMALLINT, ISNULL(MAX(IdEstadoSolicitud), 0) + 1) FROM dbo.Cat_Estado_Solicitud);
        INSERT dbo.Cat_Estado_Solicitud
        (
            IdEstadoSolicitud, Codigo, Nombre, Descripcion, EsEstadoFinal, OrdenFlujo,
            IdEstadoGeneral, FechaCreacion, UsuarioCreacion
        )
        SELECT @NuevoId, 'PENDIENTE_CREACION_TICKET', 'Pendiente de creacion de ticket',
               'Faltan tickets de actividades asignadas.', 0, 5,
               IdEstadoGeneral, SYSDATETIME(), @Usuario
        FROM dbo.Cat_Estado_Solicitud WHERE Codigo = 'PENDIENTE_APROBACIONES';
    END;

    UPDATE solicitud
       SET IdEstadoSolicitud = estado.IdEstadoSolicitud,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @Usuario
    FROM dbo.Solicitud_Ingreso AS solicitud
    INNER JOIN dbo.Cat_Estado_Solicitud AS estado ON estado.Codigo = @Siguiente
    WHERE solicitud.IdSolicitud = @IdSolicitud;
END;
GO

/* Objetos requeridos por los procedimientos que siguen. Las comprobaciones se
   repiten mas adelante para que la migracion tambien sea idempotente al
   ejecutarse parcialmente. */
IF OBJECT_ID('dbo.Actividad_Flujo_Version', 'U') IS NULL
    CREATE TABLE dbo.Actividad_Flujo_Version
    (
        IdActividadFlujoVersion BIGINT NOT NULL,
        IdActividadFlujo BIGINT NULL, NumeroVersion INT NULL, EsPublicada BIT NULL,
        IdEstadoGeneral SMALLINT NULL, FechaPublicacion DATETIME2(3) NULL,
        FechaCreacion DATETIME2(3) NULL, UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL, UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Version PRIMARY KEY (IdActividadFlujoVersion)
    );
IF OBJECT_ID('dbo.Actividad_Flujo_Version_Tipo_Ingreso', 'U') IS NULL
    CREATE TABLE dbo.Actividad_Flujo_Version_Tipo_Ingreso
    (
        IdActividadFlujoVersionTipoIngreso BIGINT NOT NULL,
        IdActividadFlujoVersion BIGINT NULL, IdTipoIngreso SMALLINT NULL,
        IdEstadoGeneral SMALLINT NULL, FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL, FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Version_Tipo_Ingreso PRIMARY KEY (IdActividadFlujoVersionTipoIngreso)
    );
IF OBJECT_ID('dbo.Actividad_Flujo_Paso', 'U') IS NULL
    CREATE TABLE dbo.Actividad_Flujo_Paso
    (
        IdActividadFlujoPaso BIGINT NOT NULL,
        IdActividadFlujoVersion BIGINT NULL, IdRequerimiento INT NULL,
        ClavePaso VARCHAR(80) NULL, OrdenVisual INT NULL, NombreActividad NVARCHAR(200) NULL,
        IdAreaResponsable INT NULL, RequiereTicketExterno BIT NULL, VigenciaMeses INT NULL,
        FechaInicio DATE NULL, FechaFin DATE NULL, IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL, UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL, UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Paso PRIMARY KEY (IdActividadFlujoPaso)
    );
IF OBJECT_ID('dbo.Actividad_Flujo_Paso_Dependencia', 'U') IS NULL
    CREATE TABLE dbo.Actividad_Flujo_Paso_Dependencia
    (
        IdActividadFlujoPasoDependencia BIGINT NOT NULL,
        IdActividadFlujoPaso BIGINT NULL, IdActividadFlujoPasoRequerido BIGINT NULL,
        IdEstadoGeneral SMALLINT NULL, FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL, FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Paso_Dependencia PRIMARY KEY (IdActividadFlujoPasoDependencia)
    );
IF OBJECT_ID('dbo.Solicitud_Persona_Area_Flujo', 'U') IS NULL
    CREATE TABLE dbo.Solicitud_Persona_Area_Flujo
    (
        IdSolicitudPersonaAreaFlujo BIGINT NOT NULL,
        IdSolicitudPersonaArea BIGINT NULL, IdActividadFlujo BIGINT NULL,
        IdActividadFlujoVersion BIGINT NULL, IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL, UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL, UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Solicitud_Persona_Area_Flujo PRIMARY KEY (IdSolicitudPersonaAreaFlujo)
    );
IF OBJECT_ID('dbo.Ticket_Externo', 'U') IS NULL
    CREATE TABLE dbo.Ticket_Externo
    (
        IdTicketExterno BIGINT NOT NULL,
        IdSolicitud BIGINT NULL, Plataforma NVARCHAR(100) NULL, NumeroTicket VARCHAR(80) NULL,
        UrlTicket NVARCHAR(500) NULL, FechaRegistro DATETIME2(3) NULL,
        IdUsuarioRegistro VARCHAR(50) NULL, IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL, UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL, UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Ticket_Externo PRIMARY KEY (IdTicketExterno)
    );
IF OBJECT_ID('dbo.Ticket_Externo_Actividad', 'U') IS NULL
    CREATE TABLE dbo.Ticket_Externo_Actividad
    (
        IdTicketExternoActividad BIGINT NOT NULL,
        IdTicketExterno BIGINT NULL, IdActividad BIGINT NULL, IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL, UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL, UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Ticket_Externo_Actividad PRIMARY KEY (IdTicketExternoActividad)
    );
IF COL_LENGTH('dbo.Actividad', 'IdSolicitudPersonaAreaFlujo') IS NULL ALTER TABLE dbo.Actividad ADD IdSolicitudPersonaAreaFlujo BIGINT NULL;
IF COL_LENGTH('dbo.Actividad', 'IdActividadFlujoVersion') IS NULL ALTER TABLE dbo.Actividad ADD IdActividadFlujoVersion BIGINT NULL;
IF COL_LENGTH('dbo.Actividad', 'IdActividadFlujoPaso') IS NULL ALTER TABLE dbo.Actividad ADD IdActividadFlujoPaso BIGINT NULL;
IF COL_LENGTH('dbo.Actividad', 'IdAreaAcceso') IS NULL ALTER TABLE dbo.Actividad ADD IdAreaAcceso INT NULL;
IF COL_LENGTH('dbo.Actividad', 'IdEstadoGeneral') IS NULL ALTER TABLE dbo.Actividad ADD IdEstadoGeneral SMALLINT NULL;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Flujo_Asignar_Generar
    @IdSolicitud BIGINT,
    @IdSolicitudPersona BIGINT,
    @FlujosJson NVARCHAR(MAX),
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ISJSON(COALESCE(@FlujosJson, '[]')) <> 1
        THROW 50320, 'La seleccion de flujos no es valida.', 1;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Solicitud_Persona
        WHERE IdSolicitudPersona = @IdSolicitudPersona AND IdSolicitud = @IdSolicitud
    ) THROW 50321, 'La persona no pertenece a la solicitud.', 1;

    DECLARE @Seleccion TABLE (IdActividadFlujoVersion BIGINT PRIMARY KEY);
    INSERT @Seleccion (IdActividadFlujoVersion)
    SELECT DISTINCT TRY_CONVERT(BIGINT, item.[value])
    FROM OPENJSON(COALESCE(@FlujosJson, '[]')) AS item
    WHERE TRY_CONVERT(BIGINT, item.[value]) IS NOT NULL;

    IF EXISTS
    (
        SELECT 1
        FROM @Seleccion AS seleccion
        LEFT JOIN dbo.Actividad_Flujo_Version AS version
            ON version.IdActividadFlujoVersion = seleccion.IdActividadFlujoVersion
        LEFT JOIN dbo.Actividad_Flujo AS flujo ON flujo.IdActividadFlujo = version.IdActividadFlujo
        WHERE version.IdActividadFlujoVersion IS NULL
           OR ISNULL(version.EsPublicada, 0) = 0
           OR
           (
               flujo.IdActividadFlujoVersionActual <> version.IdActividadFlujoVersion
               AND NOT EXISTS
               (
                   SELECT 1
                   FROM dbo.Solicitud_Persona_Area_Flujo AS asignacionExistente
                   INNER JOIN dbo.Solicitud_Persona_Area AS areaExistente
                       ON areaExistente.IdSolicitudPersonaArea = asignacionExistente.IdSolicitudPersonaArea
                   LEFT JOIN dbo.Cat_Estado_General AS estadoAsignacionExistente
                       ON estadoAsignacionExistente.IdEstadoGeneral = asignacionExistente.IdEstadoGeneral
                   WHERE areaExistente.IdSolicitudPersona = @IdSolicitudPersona
                     AND asignacionExistente.IdActividadFlujoVersion = version.IdActividadFlujoVersion
                     AND ISNULL(estadoAsignacionExistente.EsActivo, 1) = 1
               )
           )
    ) THROW 50322, 'Uno de los flujos no existe o ya no es la version publicada actual.', 1;

    IF EXISTS
    (
        SELECT version.IdActividadFlujo
        FROM @Seleccion AS seleccion
        INNER JOIN dbo.Actividad_Flujo_Version AS version
            ON version.IdActividadFlujoVersion = seleccion.IdActividadFlujoVersion
        GROUP BY version.IdActividadFlujo HAVING COUNT(*) > 1
    ) THROW 50323, 'El mismo flujo no puede asignarse dos veces a la persona.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Seleccion AS seleccion
        INNER JOIN dbo.Actividad_Flujo_Version AS version
            ON version.IdActividadFlujoVersion = seleccion.IdActividadFlujoVersion
        INNER JOIN dbo.Actividad_Flujo AS flujo ON flujo.IdActividadFlujo = version.IdActividadFlujo
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.Solicitud_Persona_Area AS areaPersona
            WHERE areaPersona.IdSolicitudPersona = @IdSolicitudPersona
              AND areaPersona.IdArea = flujo.IdAreaAcceso
        )
    ) THROW 50324, 'Uno de los flujos no pertenece a las areas asignadas a la persona.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Seleccion AS seleccion
        INNER JOIN dbo.Actividad_Flujo_Version AS version
            ON version.IdActividadFlujoVersion = seleccion.IdActividadFlujoVersion
        INNER JOIN dbo.Solicitud_Ingreso AS solicitud ON solicitud.IdSolicitud = @IdSolicitud
        WHERE EXISTS
        (
            SELECT 1 FROM dbo.Actividad_Flujo_Version_Tipo_Ingreso AS filtro
            WHERE filtro.IdActividadFlujoVersion = version.IdActividadFlujoVersion
        )
          AND NOT EXISTS
        (
            SELECT 1
            FROM dbo.Actividad_Flujo_Version_Tipo_Ingreso AS filtro
            INNER JOIN dbo.Cat_Tipo_Ingreso AS tipoFiltro
                ON tipoFiltro.IdTipoIngreso = filtro.IdTipoIngreso
            INNER JOIN dbo.Cat_Tipo_Ingreso AS tipoSolicitud
                ON tipoSolicitud.IdTipoIngreso = solicitud.IdTipoIngreso
            WHERE filtro.IdActividadFlujoVersion = version.IdActividadFlujoVersion
              AND tipoFiltro.Codigo = CASE
                  WHEN tipoSolicitud.Codigo = 'NUEVO_EMPLEADO' THEN 'EMPLEADO'
                  ELSE tipoSolicitud.Codigo
              END
        )
    ) THROW 50325, 'Uno de los flujos no aplica al tipo de ingreso de la solicitud.', 1;

    DECLARE @Activo SMALLINT = (SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'ACTIVO');
    DECLARE @Inactivo SMALLINT = (SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'INACTIVO');
    DECLARE @Pendiente SMALLINT = (SELECT TOP (1) IdEstadoActividad FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'PENDIENTE');
    DECLARE @Aprobada SMALLINT = (SELECT TOP (1) IdEstadoActividad FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'APROBADA');
    IF @Activo IS NULL OR @Inactivo IS NULL OR @Pendiente IS NULL OR @Aprobada IS NULL
        THROW 50326, 'Faltan estados requeridos para asignar actividades.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
            INNER JOIN dbo.Solicitud_Persona_Area AS areaPersona
                ON areaPersona.IdSolicitudPersonaArea = asignacion.IdSolicitudPersonaArea
            LEFT JOIN dbo.Cat_Estado_General AS estadoAsignacion
                ON estadoAsignacion.IdEstadoGeneral = asignacion.IdEstadoGeneral
            WHERE areaPersona.IdSolicitudPersona = @IdSolicitudPersona
              AND ISNULL(estadoAsignacion.EsActivo, 1) = 1
              AND NOT EXISTS
                  (SELECT 1 FROM @Seleccion AS seleccion WHERE seleccion.IdActividadFlujoVersion = asignacion.IdActividadFlujoVersion)
              AND EXISTS
              (
                  SELECT 1 FROM dbo.Actividad AS actividad
                  LEFT JOIN dbo.Cat_Estado_Actividad AS estadoActividad
                      ON estadoActividad.IdEstadoActividad = actividad.IdEstadoActividad
                  WHERE actividad.IdSolicitudPersonaAreaFlujo = asignacion.IdSolicitudPersonaAreaFlujo
                    AND
                    (
                        ISNULL(estadoActividad.EsEstadoFinal, 0) = 1
                        OR EXISTS
                        (
                            SELECT 1 FROM dbo.Ticket_Externo_Actividad AS enlace
                            WHERE enlace.IdActividad = actividad.IdActividad
                        )
                    )
              )
        ) THROW 50327, 'No se puede retirar un flujo que ya tiene actividades finalizadas o tickets.', 1;

        UPDATE actividad
           SET IdEstadoGeneral = @Inactivo,
               FechaModificacion = SYSDATETIME(),
               UsuarioModificacion = @Usuario
        FROM dbo.Actividad AS actividad
        INNER JOIN dbo.Solicitud_Persona_Area_Flujo AS asignacion
            ON asignacion.IdSolicitudPersonaAreaFlujo = actividad.IdSolicitudPersonaAreaFlujo
        INNER JOIN dbo.Solicitud_Persona_Area AS areaPersona
            ON areaPersona.IdSolicitudPersonaArea = asignacion.IdSolicitudPersonaArea
        WHERE areaPersona.IdSolicitudPersona = @IdSolicitudPersona
          AND NOT EXISTS
              (SELECT 1 FROM @Seleccion AS seleccion WHERE seleccion.IdActividadFlujoVersion = asignacion.IdActividadFlujoVersion);

        UPDATE asignacion
           SET IdEstadoGeneral = @Inactivo,
               FechaModificacion = SYSDATETIME(),
               UsuarioModificacion = @Usuario
        FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
        INNER JOIN dbo.Solicitud_Persona_Area AS areaPersona
            ON areaPersona.IdSolicitudPersonaArea = asignacion.IdSolicitudPersonaArea
        WHERE areaPersona.IdSolicitudPersona = @IdSolicitudPersona
          AND NOT EXISTS
              (SELECT 1 FROM @Seleccion AS seleccion WHERE seleccion.IdActividadFlujoVersion = asignacion.IdActividadFlujoVersion);

        DECLARE @IdVersion BIGINT, @IdFlujo BIGINT, @IdAreaAcceso INT,
                @IdSolicitudPersonaArea BIGINT, @IdAsignacion BIGINT;
        DECLARE flujos_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT version.IdActividadFlujoVersion, flujo.IdActividadFlujo, flujo.IdAreaAcceso
            FROM @Seleccion AS seleccion
            INNER JOIN dbo.Actividad_Flujo_Version AS version
                ON version.IdActividadFlujoVersion = seleccion.IdActividadFlujoVersion
            INNER JOIN dbo.Actividad_Flujo AS flujo ON flujo.IdActividadFlujo = version.IdActividadFlujo;
        OPEN flujos_cursor;
        FETCH NEXT FROM flujos_cursor INTO @IdVersion, @IdFlujo, @IdAreaAcceso;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT TOP (1) @IdSolicitudPersonaArea = IdSolicitudPersonaArea
            FROM dbo.Solicitud_Persona_Area
            WHERE IdSolicitudPersona = @IdSolicitudPersona AND IdArea = @IdAreaAcceso;

            SELECT TOP (1) @IdAsignacion = asignacion.IdSolicitudPersonaAreaFlujo
            FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
            LEFT JOIN dbo.Cat_Estado_General AS estado
                ON estado.IdEstadoGeneral = asignacion.IdEstadoGeneral
            WHERE asignacion.IdSolicitudPersonaArea = @IdSolicitudPersonaArea
              AND asignacion.IdActividadFlujo = @IdFlujo
              AND ISNULL(estado.EsActivo, 1) = 1;

            IF @IdAsignacion IS NULL
            BEGIN
                EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona_Area_Flujo', @IdAsignacion OUTPUT;
                INSERT dbo.Solicitud_Persona_Area_Flujo
                (
                    IdSolicitudPersonaAreaFlujo, IdSolicitudPersonaArea, IdActividadFlujo,
                    IdActividadFlujoVersion, IdEstadoGeneral, FechaCreacion, UsuarioCreacion
                )
                VALUES
                (
                    @IdAsignacion, @IdSolicitudPersonaArea, @IdFlujo,
                    @IdVersion, @Activo, SYSDATETIME(), @Usuario
                );
            END;

            DECLARE @IdPaso BIGINT, @IdRequerimiento INT, @NombreActividad NVARCHAR(200),
                    @IdAreaResponsable INT, @RequiereTicket BIT, @VigenciaMeses INT,
                    @FechaInicioPaso DATE, @FechaFinPaso DATE, @IdUsuarioResponsable VARCHAR(50),
                    @IdSolicitudPersonaReq BIGINT, @IdActividad BIGINT, @FechaLimite DATE,
                    @FechaAprobacionAnterior DATETIME2(3), @IdEstadoActividad SMALLINT;
            DECLARE pasos_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT paso.IdActividadFlujoPaso, paso.IdRequerimiento, paso.NombreActividad,
                       paso.IdAreaResponsable, paso.RequiereTicketExterno, paso.VigenciaMeses,
                       paso.FechaInicio, paso.FechaFin
                FROM dbo.Actividad_Flujo_Paso AS paso
                LEFT JOIN dbo.Cat_Estado_General AS estadoPaso
                    ON estadoPaso.IdEstadoGeneral = paso.IdEstadoGeneral
                WHERE paso.IdActividadFlujoVersion = @IdVersion
                  AND ISNULL(estadoPaso.EsActivo, 1) = 1
                  AND (paso.FechaInicio IS NULL OR paso.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                  AND (paso.FechaFin IS NULL OR paso.FechaFin >= CONVERT(DATE, SYSDATETIME()))
                ORDER BY paso.OrdenVisual, paso.IdActividadFlujoPaso;
            OPEN pasos_cursor;
            FETCH NEXT FROM pasos_cursor INTO @IdPaso, @IdRequerimiento, @NombreActividad,
                @IdAreaResponsable, @RequiereTicket, @VigenciaMeses, @FechaInicioPaso, @FechaFinPaso;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SELECT TOP (1) @IdUsuarioResponsable = aprobador.IdUsuarioAprobador
                FROM dbo.Config_Aprobador_Area AS aprobador
                LEFT JOIN dbo.Cat_Estado_General AS estadoAprobador
                    ON estadoAprobador.IdEstadoGeneral = aprobador.IdEstadoGeneral
                WHERE aprobador.IdArea = @IdAreaResponsable
                  AND ISNULL(estadoAprobador.EsActivo, 1) = 1
                  AND (aprobador.FechaInicio IS NULL OR aprobador.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                  AND (aprobador.FechaFin IS NULL OR aprobador.FechaFin >= CONVERT(DATE, SYSDATETIME()))
                ORDER BY ISNULL(aprobador.EsPrincipal, 0) DESC, aprobador.IdConfigAprobador;
                IF @IdUsuarioResponsable IS NULL
                    THROW 50328, 'Una de las areas responsables no tiene un aprobador activo.', 1;

                SELECT TOP (1) @IdSolicitudPersonaReq = IdSolicitudPersonaReq
                FROM dbo.Solicitud_Persona_Requerimiento
                WHERE IdSolicitudPersona = @IdSolicitudPersona AND IdRequerimiento = @IdRequerimiento;
                IF @IdSolicitudPersonaReq IS NULL
                BEGIN
                    EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona_Requerimiento', @IdSolicitudPersonaReq OUTPUT;
                    INSERT dbo.Solicitud_Persona_Requerimiento
                    (
                        IdSolicitudPersonaReq, IdSolicitudPersona, IdRequerimiento,
                        Seleccionado, ConfiguradoAutomatico, FechaCreacion, UsuarioCreacion
                    )
                    VALUES
                    (
                        @IdSolicitudPersonaReq, @IdSolicitudPersona, @IdRequerimiento,
                        1, 1, SYSDATETIME(), @Usuario
                    );
                END;

                SET @FechaAprobacionAnterior = NULL;
                SELECT TOP (1) @FechaAprobacionAnterior = actividadAnterior.FechaFinalizacion
                FROM dbo.Solicitud_Persona AS personaActual
                INNER JOIN dbo.Solicitud_Persona AS personaAnterior
                    ON personaAnterior.IdSolicitudPersona <> personaActual.IdSolicitudPersona
                   AND
                   (
                       (personaActual.IdPersona IS NOT NULL AND personaAnterior.IdPersona = personaActual.IdPersona)
                       OR
                       (NULLIF(LTRIM(RTRIM(personaActual.CodigoEmpleadoHtis)), '') IS NOT NULL
                        AND personaAnterior.CodigoEmpleadoHtis = personaActual.CodigoEmpleadoHtis)
                   )
                INNER JOIN dbo.Actividad AS actividadAnterior
                    ON actividadAnterior.IdSolicitudPersona = personaAnterior.IdSolicitudPersona
                   AND actividadAnterior.IdRequerimiento = @IdRequerimiento
                INNER JOIN dbo.Cat_Estado_Actividad AS estadoAnterior
                    ON estadoAnterior.IdEstadoActividad = actividadAnterior.IdEstadoActividad
                   AND estadoAnterior.Codigo = 'APROBADA'
                WHERE personaActual.IdSolicitudPersona = @IdSolicitudPersona
                  AND actividadAnterior.FechaFinalizacion IS NOT NULL
                  AND DATEADD(MONTH, ISNULL(@VigenciaMeses, 24), actividadAnterior.FechaFinalizacion) >= CONVERT(DATE, SYSDATETIME())
                ORDER BY actividadAnterior.FechaFinalizacion DESC;

                SET @IdEstadoActividad = CASE WHEN @FechaAprobacionAnterior IS NULL THEN @Pendiente ELSE @Aprobada END;
                SET @FechaLimite = COALESCE(@FechaFinPaso, (SELECT FechaFin FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud));

                IF NOT EXISTS
                (
                    SELECT 1 FROM dbo.Actividad
                    WHERE IdSolicitudPersonaAreaFlujo = @IdAsignacion
                      AND IdActividadFlujoPaso = @IdPaso
                )
                BEGIN
                    EXEC dbo.usp_ObtenerSiguienteId 'Actividad', @IdActividad OUTPUT;
                    INSERT dbo.Actividad
                    (
                        IdActividad, IdSolicitud, IdSolicitudPersona, IdSolicitudPersonaReq,
                        IdRequerimiento, IdAreaResponsable, IdUsuarioResponsable, IdEstadoActividad,
                        NombreActividad, FechaLimite, FechaInicio, FechaFinalizacion,
                        RequiereTicketExterno, FechaDecision, ComentarioDecision,
                        IdSolicitudPersonaAreaFlujo, IdActividadFlujoVersion,
                        IdActividadFlujoPaso, IdAreaAcceso, IdEstadoGeneral,
                        FechaCreacion, UsuarioCreacion
                    )
                    VALUES
                    (
                        @IdActividad, @IdSolicitud, @IdSolicitudPersona, @IdSolicitudPersonaReq,
                        @IdRequerimiento, @IdAreaResponsable, @IdUsuarioResponsable, @IdEstadoActividad,
                        @NombreActividad, @FechaLimite,
                        @FechaAprobacionAnterior, @FechaAprobacionAnterior,
                        @RequiereTicket,
                        CASE WHEN @FechaAprobacionAnterior IS NULL THEN NULL ELSE SYSDATETIME() END,
                        CASE WHEN @FechaAprobacionAnterior IS NULL THEN NULL ELSE N'Aprobada automaticamente por vigencia anterior.' END,
                        @IdAsignacion, @IdVersion, @IdPaso, @IdAreaAcceso, @Activo,
                        SYSDATETIME(), @Usuario
                    );
                END;

                SET @IdUsuarioResponsable = NULL;
                SET @IdSolicitudPersonaReq = NULL;
                FETCH NEXT FROM pasos_cursor INTO @IdPaso, @IdRequerimiento, @NombreActividad,
                    @IdAreaResponsable, @RequiereTicket, @VigenciaMeses, @FechaInicioPaso, @FechaFinPaso;
            END;
            CLOSE pasos_cursor;
            DEALLOCATE pasos_cursor;

            SET @IdSolicitudPersonaArea = NULL;
            SET @IdAsignacion = NULL;
            FETCH NEXT FROM flujos_cursor INTO @IdVersion, @IdFlujo, @IdAreaAcceso;
        END;
        CLOSE flujos_cursor;
        DEALLOCATE flujos_cursor;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'pasos_cursor') >= 0 BEGIN CLOSE pasos_cursor; DEALLOCATE pasos_cursor; END;
        IF CURSOR_STATUS('local', 'flujos_cursor') >= 0 BEGIN CLOSE flujos_cursor; DEALLOCATE flujos_cursor; END;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Validar_Desbloqueada
    @IdActividad BIGINT,
    @IdUsuarioResponsable VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Actividad
        WHERE IdActividad = @IdActividad AND IdUsuarioResponsable = @IdUsuarioResponsable
    ) THROW 50330, 'La actividad no existe o no esta asignada al usuario actual.', 1;

    DECLARE @Pendientes INT =
    (
        SELECT COUNT(*)
        FROM dbo.Actividad AS actual
        INNER JOIN dbo.Actividad_Flujo_Paso_Dependencia AS dependencia
            ON dependencia.IdActividadFlujoPaso = actual.IdActividadFlujoPaso
        LEFT JOIN dbo.Actividad AS requerida
            ON requerida.IdSolicitudPersonaAreaFlujo = actual.IdSolicitudPersonaAreaFlujo
           AND requerida.IdActividadFlujoPaso = dependencia.IdActividadFlujoPasoRequerido
        LEFT JOIN dbo.Cat_Estado_Actividad AS estadoRequerida
            ON estadoRequerida.IdEstadoActividad = requerida.IdEstadoActividad
        WHERE actual.IdActividad = @IdActividad
          AND ISNULL(estadoRequerida.Codigo, '') <> 'APROBADA'
    );
    IF @Pendientes > 0
        THROW 50331, 'La actividad esta bloqueada por una o mas actividades dependientes pendientes.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Accesos_Bloqueados
    @IdsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT areaPersona.IdSolicitudPersonaArea
    FROM dbo.Solicitud_Persona_Area AS areaPersona
    INNER JOIN dbo.Solicitud_Persona_Area_Flujo AS asignacion
        ON asignacion.IdSolicitudPersonaArea = areaPersona.IdSolicitudPersonaArea
    INNER JOIN dbo.Actividad AS actividad
        ON actividad.IdSolicitudPersonaAreaFlujo = asignacion.IdSolicitudPersonaAreaFlujo
    LEFT JOIN dbo.Cat_Estado_Actividad AS estadoActividad
        ON estadoActividad.IdEstadoActividad = actividad.IdEstadoActividad
    LEFT JOIN dbo.Cat_Estado_General AS estadoAsignacion
        ON estadoAsignacion.IdEstadoGeneral = asignacion.IdEstadoGeneral
    LEFT JOIN dbo.Cat_Estado_General AS estadoActividadGeneral
        ON estadoActividadGeneral.IdEstadoGeneral = actividad.IdEstadoGeneral
    WHERE areaPersona.IdSolicitudPersonaArea IN
        (SELECT TRY_CONVERT(BIGINT, item.[value]) FROM OPENJSON(COALESCE(@IdsJson, '[]')) AS item)
      AND ISNULL(estadoAsignacion.EsActivo, 1) = 1
      AND ISNULL(estadoActividadGeneral.EsActivo, 1) = 1
      AND ISNULL(estadoActividad.Codigo, '') <> 'APROBADA';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Areas_Qr_Bloqueadas
    @IdPersona BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT areaPersona.IdArea, solicitud.NumeroSolicitud
    FROM dbo.Solicitud_Persona AS solicitudPersona
    INNER JOIN dbo.Solicitud_Ingreso AS solicitud ON solicitud.IdSolicitud = solicitudPersona.IdSolicitud
    INNER JOIN dbo.Solicitud_Persona_Area AS areaPersona
        ON areaPersona.IdSolicitudPersona = solicitudPersona.IdSolicitudPersona
    INNER JOIN dbo.Solicitud_Persona_Area_Flujo AS asignacion
        ON asignacion.IdSolicitudPersonaArea = areaPersona.IdSolicitudPersonaArea
    INNER JOIN dbo.Actividad AS actividad
        ON actividad.IdSolicitudPersonaAreaFlujo = asignacion.IdSolicitudPersonaAreaFlujo
    LEFT JOIN dbo.Cat_Estado_Actividad AS estadoActividad
        ON estadoActividad.IdEstadoActividad = actividad.IdEstadoActividad
    LEFT JOIN dbo.Cat_Estado_General AS estadoAsignacion
        ON estadoAsignacion.IdEstadoGeneral = asignacion.IdEstadoGeneral
    LEFT JOIN dbo.Cat_Estado_General AS estadoActividadGeneral
        ON estadoActividadGeneral.IdEstadoGeneral = actividad.IdEstadoGeneral
    WHERE solicitudPersona.IdPersona = @IdPersona
      AND ISNULL(estadoAsignacion.EsActivo, 1) = 1
      AND ISNULL(estadoActividadGeneral.EsActivo, 1) = 1
      AND ISNULL(estadoActividad.Codigo, '') <> 'APROBADA';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Flujos_Asignados_Listar
    @IdSolicitud BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT areaPersona.IdSolicitudPersona,
           asignacion.IdActividadFlujoVersion
    FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
    INNER JOIN dbo.Solicitud_Persona_Area AS areaPersona
        ON areaPersona.IdSolicitudPersonaArea = asignacion.IdSolicitudPersonaArea
    INNER JOIN dbo.Solicitud_Persona AS solicitudPersona
        ON solicitudPersona.IdSolicitudPersona = areaPersona.IdSolicitudPersona
    LEFT JOIN dbo.Cat_Estado_General AS estado
        ON estado.IdEstadoGeneral = asignacion.IdEstadoGeneral
    WHERE solicitudPersona.IdSolicitud = @IdSolicitud
      AND ISNULL(estado.EsActivo, 1) = 1
    ORDER BY areaPersona.IdSolicitudPersona, asignacion.IdActividadFlujoVersion;
END;
GO

IF OBJECT_ID('dbo.Actividad_Flujo_Version', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Actividad_Flujo_Version
    (
        IdActividadFlujoVersion BIGINT NOT NULL,
        IdActividadFlujo BIGINT NULL,
        NumeroVersion INT NULL,
        EsPublicada BIT NULL,
        IdEstadoGeneral SMALLINT NULL,
        FechaPublicacion DATETIME2(3) NULL,
        FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Version PRIMARY KEY (IdActividadFlujoVersion)
    );
END;
GO

IF OBJECT_ID('dbo.Actividad_Flujo_Version_Tipo_Ingreso', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Actividad_Flujo_Version_Tipo_Ingreso
    (
        IdActividadFlujoVersionTipoIngreso BIGINT NOT NULL,
        IdActividadFlujoVersion BIGINT NULL,
        IdTipoIngreso SMALLINT NULL,
        IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Version_Tipo_Ingreso PRIMARY KEY (IdActividadFlujoVersionTipoIngreso)
    );
END;
GO

IF OBJECT_ID('dbo.Actividad_Flujo_Paso', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Actividad_Flujo_Paso
    (
        IdActividadFlujoPaso BIGINT NOT NULL,
        IdActividadFlujoVersion BIGINT NULL,
        IdRequerimiento INT NULL,
        ClavePaso VARCHAR(80) NULL,
        OrdenVisual INT NULL,
        NombreActividad NVARCHAR(200) NULL,
        IdAreaResponsable INT NULL,
        RequiereTicketExterno BIT NULL,
        VigenciaMeses INT NULL,
        FechaInicio DATE NULL,
        FechaFin DATE NULL,
        IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Paso PRIMARY KEY (IdActividadFlujoPaso)
    );
END;
GO

IF OBJECT_ID('dbo.Actividad_Flujo_Paso_Dependencia', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Actividad_Flujo_Paso_Dependencia
    (
        IdActividadFlujoPasoDependencia BIGINT NOT NULL,
        IdActividadFlujoPaso BIGINT NULL,
        IdActividadFlujoPasoRequerido BIGINT NULL,
        IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Paso_Dependencia PRIMARY KEY (IdActividadFlujoPasoDependencia)
    );
END;
GO

IF OBJECT_ID('dbo.Solicitud_Persona_Area_Flujo', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Solicitud_Persona_Area_Flujo
    (
        IdSolicitudPersonaAreaFlujo BIGINT NOT NULL,
        IdSolicitudPersonaArea BIGINT NULL,
        IdActividadFlujo BIGINT NULL,
        IdActividadFlujoVersion BIGINT NULL,
        IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Solicitud_Persona_Area_Flujo PRIMARY KEY (IdSolicitudPersonaAreaFlujo)
    );
END;
GO

IF OBJECT_ID('dbo.Ticket_Externo', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Ticket_Externo
    (
        IdTicketExterno BIGINT NOT NULL,
        IdSolicitud BIGINT NULL,
        Plataforma NVARCHAR(100) NULL,
        NumeroTicket VARCHAR(80) NULL,
        UrlTicket NVARCHAR(500) NULL,
        FechaRegistro DATETIME2(3) NULL,
        IdUsuarioRegistro VARCHAR(50) NULL,
        IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Ticket_Externo PRIMARY KEY (IdTicketExterno)
    );
END;
GO

IF OBJECT_ID('dbo.Ticket_Externo_Actividad', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Ticket_Externo_Actividad
    (
        IdTicketExternoActividad BIGINT NOT NULL,
        IdTicketExterno BIGINT NULL,
        IdActividad BIGINT NULL,
        IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Ticket_Externo_Actividad PRIMARY KEY (IdTicketExternoActividad)
    );
END;
GO

IF COL_LENGTH('dbo.Actividad', 'IdSolicitudPersonaAreaFlujo') IS NULL
    ALTER TABLE dbo.Actividad ADD IdSolicitudPersonaAreaFlujo BIGINT NULL;
IF COL_LENGTH('dbo.Actividad', 'IdActividadFlujoVersion') IS NULL
    ALTER TABLE dbo.Actividad ADD IdActividadFlujoVersion BIGINT NULL;
IF COL_LENGTH('dbo.Actividad', 'IdActividadFlujoPaso') IS NULL
    ALTER TABLE dbo.Actividad ADD IdActividadFlujoPaso BIGINT NULL;
IF COL_LENGTH('dbo.Actividad', 'IdAreaAcceso') IS NULL
    ALTER TABLE dbo.Actividad ADD IdAreaAcceso INT NULL;
IF COL_LENGTH('dbo.Actividad', 'IdEstadoGeneral') IS NULL
    ALTER TABLE dbo.Actividad ADD IdEstadoGeneral SMALLINT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Actividad_Flujo') AND name = 'IX_Actividad_Flujo_Area')
    CREATE INDEX IX_Actividad_Flujo_Area ON dbo.Actividad_Flujo(IdAreaAcceso, IdEstadoGeneral);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Actividad_Flujo_Paso') AND name = 'IX_Actividad_Flujo_Paso_Version')
    CREATE INDEX IX_Actividad_Flujo_Paso_Version ON dbo.Actividad_Flujo_Paso(IdActividadFlujoVersion, IdEstadoGeneral);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Actividad_Flujo_Paso_Dependencia') AND name = 'IX_Actividad_Flujo_Paso_Dependencia_Paso')
    CREATE INDEX IX_Actividad_Flujo_Paso_Dependencia_Paso ON dbo.Actividad_Flujo_Paso_Dependencia(IdActividadFlujoPaso, IdEstadoGeneral);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Solicitud_Persona_Area_Flujo') AND name = 'IX_Solicitud_Persona_Area_Flujo_Area')
    CREATE INDEX IX_Solicitud_Persona_Area_Flujo_Area ON dbo.Solicitud_Persona_Area_Flujo(IdSolicitudPersonaArea, IdEstadoGeneral);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Ticket_Externo_Actividad') AND name = 'IX_Ticket_Externo_Actividad_Actividad')
    CREATE INDEX IX_Ticket_Externo_Actividad_Actividad ON dbo.Ticket_Externo_Actividad(IdActividad, IdEstadoGeneral);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Actividad') AND name = 'IX_Actividad_Flujo_Instancia')
    CREATE INDEX IX_Actividad_Flujo_Instancia ON dbo.Actividad(IdSolicitudPersonaAreaFlujo, IdActividadFlujoPaso, IdEstadoGeneral);
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Flujo_Obtener_V2
AS
BEGIN
    SET NOCOUNT ON;

    SELECT area.IdArea, area.Codigo, area.Nombre
    FROM dbo.Cat_Area AS area
    LEFT JOIN dbo.Cat_Estado_General AS estado ON estado.IdEstadoGeneral = area.IdEstadoGeneral
    WHERE ISNULL(estado.EsActivo, 1) = 1
    ORDER BY area.Nombre, area.IdArea;

    SELECT flujo.IdActividadFlujo,
           version.IdActividadFlujoVersion,
           version.NumeroVersion,
           flujo.IdAreaAcceso,
           flujo.Codigo,
           flujo.Nombre,
           flujo.Descripcion,
           tipos.TiposIngreso
    FROM dbo.Actividad_Flujo AS flujo
    INNER JOIN dbo.Actividad_Flujo_Version AS version
        ON version.IdActividadFlujoVersion = flujo.IdActividadFlujoVersionActual
    LEFT JOIN dbo.Cat_Estado_General AS estadoFlujo ON estadoFlujo.IdEstadoGeneral = flujo.IdEstadoGeneral
    LEFT JOIN dbo.Cat_Estado_General AS estadoVersion ON estadoVersion.IdEstadoGeneral = version.IdEstadoGeneral
    OUTER APPLY
    (
        SELECT STRING_AGG(CONVERT(VARCHAR(MAX), tipo.Codigo), ',') AS TiposIngreso
        FROM dbo.Actividad_Flujo_Version_Tipo_Ingreso AS filtro
        INNER JOIN dbo.Cat_Tipo_Ingreso AS tipo ON tipo.IdTipoIngreso = filtro.IdTipoIngreso
        LEFT JOIN dbo.Cat_Estado_General AS estadoFiltro ON estadoFiltro.IdEstadoGeneral = filtro.IdEstadoGeneral
        WHERE filtro.IdActividadFlujoVersion = version.IdActividadFlujoVersion
          AND ISNULL(estadoFiltro.EsActivo, 1) = 1
    ) AS tipos
    WHERE ISNULL(estadoFlujo.EsActivo, 1) = 1
      AND ISNULL(estadoVersion.EsActivo, 1) = 1
      AND ISNULL(version.EsPublicada, 0) = 1
    ORDER BY flujo.IdAreaAcceso, flujo.Nombre, flujo.IdActividadFlujo;

    SELECT paso.IdActividadFlujoPaso,
           paso.IdActividadFlujoVersion,
           paso.IdRequerimiento,
           paso.ClavePaso,
           paso.OrdenVisual,
           paso.NombreActividad,
           paso.IdAreaResponsable,
           area.Nombre AS AreaResponsable,
           CONVERT(BIT, ISNULL(paso.RequiereTicketExterno, 0)) AS RequiereTicketExterno,
           ISNULL(paso.VigenciaMeses, 24) AS VigenciaMeses,
           paso.FechaInicio,
           paso.FechaFin,
           dependencias.IdsDependencia
    FROM dbo.Actividad_Flujo_Paso AS paso
    INNER JOIN dbo.Actividad_Flujo AS flujo
        ON flujo.IdActividadFlujoVersionActual = paso.IdActividadFlujoVersion
    LEFT JOIN dbo.Cat_Area AS area ON area.IdArea = paso.IdAreaResponsable
    LEFT JOIN dbo.Cat_Estado_General AS estadoPaso ON estadoPaso.IdEstadoGeneral = paso.IdEstadoGeneral
    OUTER APPLY
    (
        SELECT STRING_AGG(CONVERT(VARCHAR(MAX), dependencia.IdActividadFlujoPasoRequerido), ',') AS IdsDependencia
        FROM dbo.Actividad_Flujo_Paso_Dependencia AS dependencia
        LEFT JOIN dbo.Cat_Estado_General AS estadoDependencia
            ON estadoDependencia.IdEstadoGeneral = dependencia.IdEstadoGeneral
        WHERE dependencia.IdActividadFlujoPaso = paso.IdActividadFlujoPaso
          AND ISNULL(estadoDependencia.EsActivo, 1) = 1
    ) AS dependencias
    WHERE ISNULL(estadoPaso.EsActivo, 1) = 1
    ORDER BY paso.IdActividadFlujoVersion, paso.OrdenVisual, paso.IdActividadFlujoPaso;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Flujo_Guardar_V2
    @IdAreaAcceso INT,
    @IdActividadFlujo BIGINT = NULL,
    @FlujoJson NVARCHAR(MAX),
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ISJSON(COALESCE(@FlujoJson, '')) <> 1
        THROW 50300, 'La configuracion del flujo no es valida.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdAreaAcceso)
        THROW 50301, 'El area de acceso no existe.', 1;

    DECLARE @Nombre NVARCHAR(150) = NULLIF(LTRIM(RTRIM(JSON_VALUE(@FlujoJson, '$.Nombre'))), '');
    DECLARE @Codigo VARCHAR(40) = NULLIF(LTRIM(RTRIM(JSON_VALUE(@FlujoJson, '$.Codigo'))), '');
    DECLARE @Descripcion NVARCHAR(500) = NULLIF(LTRIM(RTRIM(JSON_VALUE(@FlujoJson, '$.Descripcion'))), '');
    DECLARE @TiposJson NVARCHAR(MAX) = COALESCE(JSON_QUERY(@FlujoJson, '$.TiposIngreso'), N'[]');
    DECLARE @PasosJson NVARCHAR(MAX) = COALESCE(JSON_QUERY(@FlujoJson, '$.Pasos'), N'[]');
    IF @Nombre IS NULL THROW 50302, 'El nombre del flujo es obligatorio.', 1;
    IF ISJSON(@TiposJson) <> 1 OR ISJSON(@PasosJson) <> 1
        THROW 50303, 'Los tipos de ingreso o las actividades del flujo no son validos.', 1;

    DECLARE @Pasos TABLE
    (
        ClavePaso VARCHAR(80) PRIMARY KEY,
        OrdenVisual INT NULL,
        IdRequerimiento INT NULL,
        NombreActividad NVARCHAR(200) NULL,
        IdAreaResponsable INT NULL,
        RequiereTicketExterno BIT NULL,
        VigenciaMeses INT NULL,
        FechaInicio DATE NULL,
        FechaFin DATE NULL,
        DependenciasJson NVARCHAR(MAX) NULL,
        IdPasoNuevo BIGINT NULL
    );

    INSERT @Pasos
    (
        ClavePaso, OrdenVisual, IdRequerimiento, NombreActividad, IdAreaResponsable,
        RequiereTicketExterno, VigenciaMeses, FechaInicio, FechaFin, DependenciasJson
    )
    SELECT NULLIF(LTRIM(RTRIM(JSON_VALUE(item.[value], '$.ClavePaso'))), ''),
           CONVERT(INT, item.[key]) + 1,
           TRY_CONVERT(INT, JSON_VALUE(item.[value], '$.IdRequerimiento')),
           NULLIF(LTRIM(RTRIM(JSON_VALUE(item.[value], '$.NombreActividad'))), ''),
           TRY_CONVERT(INT, JSON_VALUE(item.[value], '$.IdAreaResponsable')),
           TRY_CONVERT(BIT, JSON_VALUE(item.[value], '$.RequiereTicketExterno')),
           TRY_CONVERT(INT, JSON_VALUE(item.[value], '$.VigenciaMeses')),
           TRY_CONVERT(DATE, JSON_VALUE(item.[value], '$.FechaInicio')),
           TRY_CONVERT(DATE, JSON_VALUE(item.[value], '$.FechaFin')),
           COALESCE(JSON_QUERY(item.[value], '$.Dependencias'), N'[]')
    FROM OPENJSON(@PasosJson) AS item;

    IF EXISTS
    (
        SELECT 1 FROM @Pasos
        WHERE ClavePaso IS NULL OR NombreActividad IS NULL OR IdAreaResponsable IS NULL
           OR VigenciaMeses NOT BETWEEN 1 AND 1200
           OR (FechaInicio IS NOT NULL AND FechaFin IS NOT NULL AND FechaFin < FechaInicio)
    ) THROW 50304, 'Completa correctamente todas las actividades del flujo.', 1;
    IF EXISTS (SELECT 1 FROM @Pasos GROUP BY UPPER(NombreActividad) HAVING COUNT(*) > 1)
        THROW 50305, 'Una actividad no puede repetirse dentro del mismo flujo.', 1;
    IF EXISTS
    (
        SELECT 1 FROM @Pasos AS paso
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Cat_Area AS area WHERE area.IdArea = paso.IdAreaResponsable)
    ) THROW 50306, 'Una de las areas responsables no existe.', 1;
    IF EXISTS
    (
        SELECT 1 FROM OPENJSON(@TiposJson) AS item
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Ingreso AS tipo WHERE tipo.Codigo = item.[value])
    ) THROW 50307, 'Uno de los tipos de ingreso no existe.', 1;
    IF EXISTS
    (
        SELECT 1
        FROM @Pasos AS paso
        CROSS APPLY OPENJSON(paso.DependenciasJson) AS dependencia
        WHERE dependencia.[value] = paso.ClavePaso
           OR NOT EXISTS (SELECT 1 FROM @Pasos AS requerida WHERE requerida.ClavePaso = dependencia.[value])
    ) THROW 50308, 'Una dependencia no existe o apunta a la misma actividad.', 1;

    DECLARE @Activo SMALLINT = (SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'ACTIVO');
    IF @Activo IS NULL THROW 50309, 'No existe el estado general ACTIVO.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @IdActividadFlujo IS NULL
        BEGIN
            EXEC dbo.usp_ObtenerSiguienteId 'Actividad_Flujo', @IdActividadFlujo OUTPUT;
            INSERT dbo.Actividad_Flujo
            (
                IdActividadFlujo, IdAreaAcceso, Codigo, Nombre, Descripcion,
                IdEstadoGeneral, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdActividadFlujo, @IdAreaAcceso,
                COALESCE(@Codigo, CONCAT('FLUJO_', FORMAT(@IdActividadFlujo, '000000'))),
                @Nombre, @Descripcion, @Activo, SYSDATETIME(), @Usuario
            );
        END
        ELSE
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1 FROM dbo.Actividad_Flujo
                WHERE IdActividadFlujo = @IdActividadFlujo AND IdAreaAcceso = @IdAreaAcceso
            ) THROW 50310, 'El flujo no existe en el area seleccionada.', 1;

            UPDATE dbo.Actividad_Flujo
               SET Codigo = COALESCE(@Codigo, Codigo),
                   Nombre = @Nombre,
                   Descripcion = @Descripcion,
                   IdEstadoGeneral = @Activo,
                   FechaModificacion = SYSDATETIME(),
                   UsuarioModificacion = @Usuario
             WHERE IdActividadFlujo = @IdActividadFlujo;
        END;

        DECLARE @IdVersion BIGINT;
        DECLARE @NumeroVersion INT = ISNULL
        (
            (SELECT MAX(NumeroVersion) FROM dbo.Actividad_Flujo_Version WHERE IdActividadFlujo = @IdActividadFlujo),
            0
        ) + 1;
        EXEC dbo.usp_ObtenerSiguienteId 'Actividad_Flujo_Version', @IdVersion OUTPUT;
        INSERT dbo.Actividad_Flujo_Version
        (
            IdActividadFlujoVersion, IdActividadFlujo, NumeroVersion, EsPublicada,
            IdEstadoGeneral, FechaPublicacion, FechaCreacion, UsuarioCreacion
        )
        VALUES
        (
            @IdVersion, @IdActividadFlujo, @NumeroVersion, 1,
            @Activo, SYSDATETIME(), SYSDATETIME(), @Usuario
        );

        DECLARE @Id BIGINT;
        DECLARE @CodigoTipo VARCHAR(30);
        DECLARE tipos_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT DISTINCT CONVERT(VARCHAR(30), item.[value]) FROM OPENJSON(@TiposJson) AS item;
        OPEN tipos_cursor;
        FETCH NEXT FROM tipos_cursor INTO @CodigoTipo;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_ObtenerSiguienteId 'Actividad_Flujo_Version_Tipo_Ingreso', @Id OUTPUT;
            INSERT dbo.Actividad_Flujo_Version_Tipo_Ingreso
            (
                IdActividadFlujoVersionTipoIngreso, IdActividadFlujoVersion,
                IdTipoIngreso, IdEstadoGeneral, FechaCreacion, UsuarioCreacion
            )
            SELECT @Id, @IdVersion, tipo.IdTipoIngreso, @Activo, SYSDATETIME(), @Usuario
            FROM dbo.Cat_Tipo_Ingreso AS tipo WHERE tipo.Codigo = @CodigoTipo;
            FETCH NEXT FROM tipos_cursor INTO @CodigoTipo;
        END;
        CLOSE tipos_cursor;
        DEALLOCATE tipos_cursor;

        DECLARE @ClavePaso VARCHAR(80), @IdRequerimiento INT, @NombreActividad NVARCHAR(200),
                @IdAreaResponsable INT, @Ticket BIT, @Vigencia INT, @Inicio DATE, @Fin DATE,
                @OrdenVisual INT, @IdRequerimientoGenerado BIGINT, @IdPaso BIGINT;
        DECLARE pasos_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT ClavePaso, IdRequerimiento, NombreActividad, IdAreaResponsable,
                   RequiereTicketExterno, VigenciaMeses, FechaInicio, FechaFin, OrdenVisual
            FROM @Pasos ORDER BY OrdenVisual;
        OPEN pasos_cursor;
        FETCH NEXT FROM pasos_cursor INTO @ClavePaso, @IdRequerimiento, @NombreActividad,
            @IdAreaResponsable, @Ticket, @Vigencia, @Inicio, @Fin, @OrdenVisual;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @IdRequerimiento IS NULL OR NOT EXISTS
            (
                SELECT 1 FROM dbo.Actividad_Flujo_Paso AS anterior
                INNER JOIN dbo.Actividad_Flujo_Version AS versionAnterior
                    ON versionAnterior.IdActividadFlujoVersion = anterior.IdActividadFlujoVersion
                WHERE anterior.IdRequerimiento = @IdRequerimiento
                  AND versionAnterior.IdActividadFlujo = @IdActividadFlujo
            )
            BEGIN
                SELECT @IdRequerimientoGenerado = ISNULL(MAX(IdRequerimiento), 0) + 1
                FROM dbo.Cat_Requerimiento WITH (UPDLOCK, HOLDLOCK);
                SET @IdRequerimiento = CONVERT(INT, @IdRequerimientoGenerado);
                INSERT dbo.Cat_Requerimiento
                (
                    IdRequerimiento, Codigo, Nombre, Descripcion, IdCategoriaRequerimiento,
                    RequiereTicketExterno, IdEstadoGeneral, FechaCreacion, UsuarioCreacion
                )
                VALUES
                (
                    @IdRequerimiento, CONCAT('ACT_', FORMAT(@IdRequerimiento, '000000')),
                    @NombreActividad, CONCAT('VIGENCIA_MESES=', @Vigencia), NULL,
                    @Ticket, @Activo, SYSDATETIME(), @Usuario
                );
            END;

            EXEC dbo.usp_ObtenerSiguienteId 'Actividad_Flujo_Paso', @IdPaso OUTPUT;
            INSERT dbo.Actividad_Flujo_Paso
            (
                IdActividadFlujoPaso, IdActividadFlujoVersion, IdRequerimiento, ClavePaso,
                OrdenVisual, NombreActividad, IdAreaResponsable, RequiereTicketExterno,
                VigenciaMeses, FechaInicio, FechaFin, IdEstadoGeneral, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdPaso, @IdVersion, @IdRequerimiento, @ClavePaso,
                @OrdenVisual, @NombreActividad, @IdAreaResponsable, @Ticket,
                @Vigencia, @Inicio, @Fin, @Activo, SYSDATETIME(), @Usuario
            );
            UPDATE @Pasos SET IdPasoNuevo = @IdPaso WHERE ClavePaso = @ClavePaso;

            FETCH NEXT FROM pasos_cursor INTO @ClavePaso, @IdRequerimiento, @NombreActividad,
                @IdAreaResponsable, @Ticket, @Vigencia, @Inicio, @Fin, @OrdenVisual;
        END;
        CLOSE pasos_cursor;
        DEALLOCATE pasos_cursor;

        DECLARE @ClaveRequerida VARCHAR(80), @IdPasoActual BIGINT, @IdPasoRequerido BIGINT;
        DECLARE dependencias_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT paso.IdPasoNuevo, CONVERT(VARCHAR(80), dependencia.[value]), requerida.IdPasoNuevo
            FROM @Pasos AS paso
            CROSS APPLY OPENJSON(paso.DependenciasJson) AS dependencia
            INNER JOIN @Pasos AS requerida ON requerida.ClavePaso = dependencia.[value];
        OPEN dependencias_cursor;
        FETCH NEXT FROM dependencias_cursor INTO @IdPasoActual, @ClaveRequerida, @IdPasoRequerido;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_ObtenerSiguienteId 'Actividad_Flujo_Paso_Dependencia', @Id OUTPUT;
            INSERT dbo.Actividad_Flujo_Paso_Dependencia
            (
                IdActividadFlujoPasoDependencia, IdActividadFlujoPaso,
                IdActividadFlujoPasoRequerido, IdEstadoGeneral, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @Id, @IdPasoActual, @IdPasoRequerido, @Activo, SYSDATETIME(), @Usuario
            );
            FETCH NEXT FROM dependencias_cursor INTO @IdPasoActual, @ClaveRequerida, @IdPasoRequerido;
        END;
        CLOSE dependencias_cursor;
        DEALLOCATE dependencias_cursor;

        IF EXISTS
        (
            SELECT 1
            FROM @Pasos AS origen
            CROSS APPLY
            (
                SELECT dependencia.[value] AS ClaveRequerida
                FROM OPENJSON(origen.DependenciasJson) AS dependencia
            ) AS primerNivel
            WHERE primerNivel.ClaveRequerida = origen.ClavePaso
        ) THROW 50311, 'El flujo contiene una dependencia circular.', 1;

        SET @ClaveRequerida = NULL;
        ;WITH Recorrido AS
        (
            SELECT paso.ClavePaso AS Origen,
                   CONVERT(VARCHAR(80), dependencia.[value]) AS Actual,
                   CAST(CONCAT('|', paso.ClavePaso, '|', dependencia.[value], '|') AS VARCHAR(MAX)) AS Ruta,
                   0 AS TieneCiclo
            FROM @Pasos AS paso
            CROSS APPLY OPENJSON(paso.DependenciasJson) AS dependencia
            UNION ALL
            SELECT recorrido.Origen,
                   CONVERT(VARCHAR(80), dependencia.[value]),
                   CAST(CONCAT(recorrido.Ruta, dependencia.[value], '|') AS VARCHAR(MAX)),
                   CASE WHEN recorrido.Ruta LIKE CONCAT('%|', dependencia.[value], '|%') THEN 1 ELSE 0 END
            FROM Recorrido AS recorrido
            INNER JOIN @Pasos AS paso ON paso.ClavePaso = recorrido.Actual
            CROSS APPLY OPENJSON(paso.DependenciasJson) AS dependencia
            WHERE recorrido.TieneCiclo = 0
        )
        SELECT TOP (1) @ClaveRequerida = Actual
        FROM Recorrido WHERE TieneCiclo = 1
        OPTION (MAXRECURSION 32767);
        IF @ClaveRequerida IS NOT NULL
            THROW 50311, 'El flujo contiene una dependencia circular.', 1;

        UPDATE dbo.Actividad_Flujo
           SET IdActividadFlujoVersionActual = @IdVersion,
               FechaModificacion = SYSDATETIME(),
               UsuarioModificacion = @Usuario
         WHERE IdActividadFlujo = @IdActividadFlujo;

        COMMIT TRANSACTION;
        SELECT @IdActividadFlujo AS IdActividadFlujo, @IdVersion AS IdActividadFlujoVersion;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'dependencias_cursor') >= 0 BEGIN CLOSE dependencias_cursor; DEALLOCATE dependencias_cursor; END;
        IF CURSOR_STATUS('local', 'pasos_cursor') >= 0 BEGIN CLOSE pasos_cursor; DEALLOCATE pasos_cursor; END;
        IF CURSOR_STATUS('local', 'tipos_cursor') >= 0 BEGIN CLOSE tipos_cursor; DEALLOCATE tipos_cursor; END;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
