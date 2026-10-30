SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID('dbo.Actividad_Flujo_Version_Tipo_Automatico', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Actividad_Flujo_Version_Tipo_Automatico
    (
        IdActividadFlujoVersionTipoAutomatico BIGINT NOT NULL,
        IdActividadFlujoVersion BIGINT NULL,
        IdTipoIngreso SMALLINT NULL,
        IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Version_Tipo_Automatico
            PRIMARY KEY (IdActividadFlujoVersionTipoAutomatico)
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Listado_Estados_Obtener
    @Usuario VARCHAR(50),
    @Ids VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT solicitud.IdSolicitud,
           CONVERT(BIT, CASE WHEN solicitud.IdUsuarioSolicitante = @Usuario THEN 1 ELSE 0 END),
           (
               SELECT COUNT(*)
               FROM dbo.Actividad AS actividad
               LEFT JOIN dbo.Cat_Estado_Actividad AS estadoActividad
                   ON estadoActividad.IdEstadoActividad = actividad.IdEstadoActividad
               LEFT JOIN dbo.Cat_Estado_General AS estadoGeneral
                   ON estadoGeneral.IdEstadoGeneral = actividad.IdEstadoGeneral
               WHERE actividad.IdSolicitud = solicitud.IdSolicitud
                 AND actividad.IdSolicitudPersona IS NOT NULL
                 AND ISNULL(actividad.RequiereTicketExterno, 0) = 1
                 AND ISNULL(estadoActividad.EsEstadoFinal, 0) = 0
                 AND ISNULL(estadoGeneral.EsActivo, 1) = 1
                 AND solicitud.FechaFin >= CONVERT(DATE, SYSDATETIME())
                 AND NOT EXISTS
                    (SELECT 1 FROM dbo.Ticket_Externo_Actividad WHERE IdActividad = actividad.IdActividad)
                 AND NOT EXISTS
                    (SELECT 1 FROM dbo.Actividad_Ticket_Externo WHERE IdActividad = actividad.IdActividad)
                 AND
                 (
                     actividad.IdSolicitudPersonaAreaFlujo IS NOT NULL
                     OR EXISTS
                     (
                         SELECT 1 FROM dbo.Solicitud_Persona_Area AS areaPersona
                         INNER JOIN dbo.Config_Requerimiento_Area AS configuracion
                             ON configuracion.IdAreaAcceso = areaPersona.IdArea
                         WHERE areaPersona.IdSolicitudPersona = actividad.IdSolicitudPersona
                           AND configuracion.IdRequerimiento = actividad.IdRequerimiento
                     )
                 )
           ) AS TicketsPendientes,
           estadoSolicitud.Codigo,
           CONVERT(BIT, CASE WHEN EXISTS
           (
               SELECT 1 FROM dbo.Solicitud_Persona_Area AS areaPersona
               INNER JOIN dbo.Solicitud_Persona AS persona
                   ON persona.IdSolicitudPersona = areaPersona.IdSolicitudPersona
               INNER JOIN dbo.Cat_Estado_Aprobacion_Area AS estadoArea
                   ON estadoArea.IdEstadoAprobacion = areaPersona.IdEstadoAprobacion
               WHERE persona.IdSolicitud = solicitud.IdSolicitud AND estadoArea.Codigo = 'RECHAZADA'
           ) THEN 1 ELSE 0 END),
           CONVERT(BIT, CASE WHEN EXISTS
           (
               SELECT 1 FROM dbo.Solicitud_Persona_Area AS areaPersona
               INNER JOIN dbo.Solicitud_Persona AS persona
                   ON persona.IdSolicitudPersona = areaPersona.IdSolicitudPersona
               LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS estadoArea
                   ON estadoArea.IdEstadoAprobacion = areaPersona.IdEstadoAprobacion
               WHERE persona.IdSolicitud = solicitud.IdSolicitud
                 AND ISNULL(estadoArea.Codigo, 'PENDIENTE') NOT IN ('APROBADA', 'RECHAZADA')
           ) THEN 1 ELSE 0 END),
           CONVERT(BIT, CASE WHEN EXISTS
           (
               SELECT 1 FROM dbo.Solicitud_Persona_Area AS areaPersona
               INNER JOIN dbo.Solicitud_Persona AS persona
                   ON persona.IdSolicitudPersona = areaPersona.IdSolicitudPersona
               WHERE persona.IdSolicitud = solicitud.IdSolicitud
           ) THEN 1 ELSE 0 END)
    FROM dbo.Solicitud_Ingreso AS solicitud
    LEFT JOIN dbo.Cat_Estado_Solicitud AS estadoSolicitud
        ON estadoSolicitud.IdEstadoSolicitud = solicitud.IdEstadoSolicitud
    WHERE solicitud.IdSolicitud IN
        (SELECT TRY_CONVERT(BIGINT, value) FROM STRING_SPLIT(@Ids, ','));
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Estado_Codigo_Obtener
    @IdSolicitud BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT estado.Codigo
    FROM dbo.Solicitud_Ingreso AS solicitud
    INNER JOIN dbo.Cat_Estado_Solicitud AS estado
        ON estado.IdEstadoSolicitud = solicitud.IdEstadoSolicitud
    WHERE solicitud.IdSolicitud = @IdSolicitud;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Seguimiento_Obtener
    @IdSolicitud BIGINT,
    @Usuario VARCHAR(50),
    @AccesoTotal BIT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CONVERT(BIT, CASE WHEN EXISTS
    (
        SELECT 1 FROM dbo.Solicitud_Ingreso
        WHERE IdSolicitud = @IdSolicitud
          AND (@AccesoTotal = 1 OR IdUsuarioSolicitante = @Usuario)
    ) THEN 1 ELSE 0 END) AS TieneAcceso;

    SELECT areaPersona.IdSolicitudPersonaArea, personaSolicitud.IdSolicitudPersona,
           COALESCE(persona.NombreCompleto, personaSolicitud.CodigoEmpleadoHtis), persona.NumeroDocumento,
           area.Nombre, estado.Codigo, estado.Nombre,
           CASE WHEN estado.Codigo = 'RECHAZADA' THEN ultima.ComentarioDecision ELSE NULL END,
           CASE WHEN estado.Codigo IN ('APROBADA', 'RECHAZADA') THEN ultima.FechaDecision END,
           CASE WHEN estado.Codigo IN ('APROBADA', 'RECHAZADA') THEN ultima.UsuarioDecision END
    FROM dbo.Solicitud_Persona_Area AS areaPersona
    INNER JOIN dbo.Solicitud_Persona AS personaSolicitud
        ON personaSolicitud.IdSolicitudPersona = areaPersona.IdSolicitudPersona
    LEFT JOIN dbo.Persona AS persona ON persona.IdPersona = personaSolicitud.IdPersona
    LEFT JOIN dbo.Cat_Area AS area ON area.IdArea = areaPersona.IdArea
    LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS estado
        ON estado.IdEstadoAprobacion = areaPersona.IdEstadoAprobacion
    OUTER APPLY
    (
        SELECT TOP (1) aprobacion.ComentarioDecision, aprobacion.FechaDecision,
               COALESCE(usuario.NombreCompleto, aprobacion.IdUsuarioAprobador) AS UsuarioDecision
        FROM dbo.Aprobacion_Area AS aprobacion
        LEFT JOIN dbo.Usuario AS usuario ON usuario.IdUsuario = aprobacion.IdUsuarioAprobador
        WHERE aprobacion.IdSolicitudPersonaArea = areaPersona.IdSolicitudPersonaArea
        ORDER BY aprobacion.IdAprobacionArea DESC
    ) AS ultima
    WHERE personaSolicitud.IdSolicitud = @IdSolicitud
    ORDER BY personaSolicitud.IdSolicitudPersona, area.Nombre;

    SELECT actividad.IdActividad, actividad.IdSolicitudPersona,
           COALESCE(persona.NombreCompleto, personaSolicitud.CodigoEmpleadoHtis), area.Nombre,
           actividad.NombreActividad, estado.Codigo, estado.Nombre,
           CONVERT(BIT, ISNULL(actividad.RequiereTicketExterno, 0)), tickets.NumerosTicket,
           actividad.FechaFinalizacion,
           COALESCE(usuarioActividad.NombreCompleto, actividad.IdUsuarioAprobador),
           actividad.ComentarioDecision, actividad.FechaDecision,
           CONVERT(BIT, ISNULL(estado.EsEstadoFinal, 0)),
           CONVERT(BIT, CASE WHEN ISNULL(actividad.RequiereTicketExterno, 0) = 1
               AND ISNULL(estado.EsEstadoFinal, 0) = 0
               AND solicitud.FechaFin >= CONVERT(DATE, SYSDATETIME())
               AND tickets.Cantidad = 0
               AND
               (
                   actividad.IdSolicitudPersonaAreaFlujo IS NOT NULL
                   OR EXISTS
                   (
                       SELECT 1 FROM dbo.Solicitud_Persona_Area AS areaPersona
                       INNER JOIN dbo.Config_Requerimiento_Area AS configuracion
                           ON configuracion.IdAreaAcceso = areaPersona.IdArea
                       WHERE areaPersona.IdSolicitudPersona = actividad.IdSolicitudPersona
                         AND configuracion.IdRequerimiento = actividad.IdRequerimiento
                   )
               )
               THEN 1 ELSE 0 END)
    FROM dbo.Actividad AS actividad
    INNER JOIN dbo.Solicitud_Ingreso AS solicitud ON solicitud.IdSolicitud = actividad.IdSolicitud
    LEFT JOIN dbo.Solicitud_Persona AS personaSolicitud
        ON personaSolicitud.IdSolicitudPersona = actividad.IdSolicitudPersona
    LEFT JOIN dbo.Persona AS persona ON persona.IdPersona = personaSolicitud.IdPersona
    LEFT JOIN dbo.Cat_Area AS area ON area.IdArea = actividad.IdAreaResponsable
    LEFT JOIN dbo.Cat_Estado_Actividad AS estado
        ON estado.IdEstadoActividad = actividad.IdEstadoActividad
    LEFT JOIN dbo.Cat_Estado_General AS estadoGeneral
        ON estadoGeneral.IdEstadoGeneral = actividad.IdEstadoGeneral
    LEFT JOIN dbo.Usuario AS usuarioActividad
        ON usuarioActividad.IdUsuario = actividad.IdUsuarioAprobador
    OUTER APPLY
    (
        SELECT COUNT(*) AS Cantidad,
               STRING_AGG(CONVERT(NVARCHAR(MAX), origen.NumeroTicket), N', ') AS NumerosTicket
        FROM
        (
            SELECT ticket.NumeroTicket
            FROM dbo.Ticket_Externo_Actividad AS enlace
            INNER JOIN dbo.Ticket_Externo AS ticket
                ON ticket.IdTicketExterno = enlace.IdTicketExterno
            WHERE enlace.IdActividad = actividad.IdActividad
            UNION ALL
            SELECT ticketAnterior.NumeroTicket
            FROM dbo.Actividad_Ticket_Externo AS ticketAnterior
            WHERE ticketAnterior.IdActividad = actividad.IdActividad
        ) AS origen
    ) AS tickets
    WHERE actividad.IdSolicitud = @IdSolicitud
      AND ISNULL(estadoGeneral.EsActivo, 1) = 1
    ORDER BY actividad.IdSolicitudPersona, actividad.IdActividad;

    SELECT aprobacion.IdSolicitudPersonaArea,
           COALESCE(persona.NombreCompleto, personaSolicitud.CodigoEmpleadoHtis), area.Nombre,
           COALESCE(estado.Codigo,
               CASE WHEN rechazo.IdRechazoArea IS NULL THEN 'APROBADA' ELSE 'RECHAZADA' END),
           aprobacion.ComentarioDecision, aprobacion.FechaDecision,
           COALESCE(usuarioDecision.NombreCompleto, aprobacion.IdUsuarioAprobador)
    FROM dbo.Aprobacion_Area AS aprobacion
    INNER JOIN dbo.Solicitud_Persona_Area AS areaPersona
        ON areaPersona.IdSolicitudPersonaArea = aprobacion.IdSolicitudPersonaArea
    INNER JOIN dbo.Solicitud_Persona AS personaSolicitud
        ON personaSolicitud.IdSolicitudPersona = areaPersona.IdSolicitudPersona
    LEFT JOIN dbo.Persona AS persona ON persona.IdPersona = personaSolicitud.IdPersona
    LEFT JOIN dbo.Cat_Area AS area ON area.IdArea = areaPersona.IdArea
    LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS estado
        ON estado.IdEstadoAprobacion = aprobacion.IdEstadoAprobacion
    OUTER APPLY
        (SELECT TOP (1) IdRechazoArea FROM dbo.Rechazo_Area WHERE IdAprobacionArea = aprobacion.IdAprobacionArea) AS rechazo
    LEFT JOIN dbo.Usuario AS usuarioDecision ON usuarioDecision.IdUsuario = aprobacion.IdUsuarioAprobador
    WHERE personaSolicitud.IdSolicitud = @IdSolicitud
    ORDER BY aprobacion.IdAprobacionArea DESC;

    SELECT TRY_CONVERT(BIGINT, JSON_VALUE(historial.DatosAdicionalesJson, '$.idSolicitudPersonaArea')),
           historial.Comentario, COALESCE(usuario.NombreCompleto, historial.IdUsuarioAccion),
           historial.FechaAccion
    FROM dbo.Historial_Solicitud AS historial
    LEFT JOIN dbo.Usuario AS usuario ON usuario.IdUsuario = historial.IdUsuarioAccion
    WHERE historial.IdSolicitud = @IdSolicitud AND historial.TipoEvento = 'REENVIO_APROBACION'
    ORDER BY historial.FechaAccion DESC, historial.IdHistorialSolicitud DESC;
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
           actividad.NombreActividad, COALESCE(persona.NombreCompleto, personaSolicitud.CodigoEmpleadoHtis),
           area.Nombre, CONVERT(BIT, ISNULL(estadoActividad.EsEstadoFinal, 0)),
           actividad.IdSolicitudPersona
    FROM dbo.Actividad AS actividad
    INNER JOIN dbo.Solicitud_Ingreso AS solicitud ON solicitud.IdSolicitud = actividad.IdSolicitud
    LEFT JOIN dbo.Solicitud_Persona AS personaSolicitud
        ON personaSolicitud.IdSolicitudPersona = actividad.IdSolicitudPersona
    LEFT JOIN dbo.Persona AS persona ON persona.IdPersona = personaSolicitud.IdPersona
    LEFT JOIN dbo.Cat_Area AS area ON area.IdArea = actividad.IdAreaResponsable
    LEFT JOIN dbo.Cat_Estado_Actividad AS estadoActividad
        ON estadoActividad.IdEstadoActividad = actividad.IdEstadoActividad
    LEFT JOIN dbo.Cat_Estado_General AS estadoGeneral
        ON estadoGeneral.IdEstadoGeneral = actividad.IdEstadoGeneral
    WHERE solicitud.IdSolicitud = @IdSolicitud
      AND ISNULL(actividad.RequiereTicketExterno, 0) = 1
      AND ISNULL(estadoGeneral.EsActivo, 1) = 1
    ORDER BY actividad.IdSolicitudPersona, actividad.IdActividad;

    SELECT enlace.IdActividad, ticket.IdTicketExterno, ticket.Plataforma,
           ticket.NumeroTicket, ticket.UrlTicket, ticket.FechaRegistro
    FROM dbo.Ticket_Externo_Actividad AS enlace
    INNER JOIN dbo.Ticket_Externo AS ticket ON ticket.IdTicketExterno = enlace.IdTicketExterno
    INNER JOIN dbo.Actividad AS actividad ON actividad.IdActividad = enlace.IdActividad
    WHERE actividad.IdSolicitud = @IdSolicitud
    UNION ALL
    SELECT anterior.IdActividad, anterior.IdActividadTicket, anterior.Plataforma,
           anterior.NumeroTicket, anterior.UrlTicket, anterior.FechaRegistro
    FROM dbo.Actividad_Ticket_Externo AS anterior
    INNER JOIN dbo.Actividad AS actividad ON actividad.IdActividad = anterior.IdActividad
    WHERE actividad.IdSolicitud = @IdSolicitud
    ORDER BY IdActividad, FechaRegistro, IdTicketExterno;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Persona_Area_Solicitud_Obtener
    @IdSolicitudPersonaArea BIGINT,
    @UsuarioSolicitante VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT personaSolicitud.IdSolicitud, personaSolicitud.IdSolicitudPersona
    FROM dbo.Solicitud_Persona_Area AS areaPersona
    INNER JOIN dbo.Solicitud_Persona AS personaSolicitud
        ON personaSolicitud.IdSolicitudPersona = areaPersona.IdSolicitudPersona
    INNER JOIN dbo.Solicitud_Ingreso AS solicitud
        ON solicitud.IdSolicitud = personaSolicitud.IdSolicitud
    WHERE areaPersona.IdSolicitudPersonaArea = @IdSolicitudPersonaArea
      AND (@UsuarioSolicitante IS NULL OR solicitud.IdUsuarioSolicitante = @UsuarioSolicitante);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Historial_Solicitud_Reenvio_Agregar
    @IdSolicitud BIGINT,
    @IdSolicitudPersona BIGINT,
    @IdSolicitudPersonaArea BIGINT,
    @Justificacion NVARCHAR(1000),
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdHistorial BIGINT;
    EXEC dbo.usp_ObtenerSiguienteId 'Historial_Solicitud', @IdHistorial OUTPUT;
    INSERT dbo.Historial_Solicitud
    (
        IdHistorialSolicitud, IdSolicitud, IdSolicitudPersona, TipoEvento, Accion,
        Comentario, IdUsuarioAccion, FechaAccion, DatosAdicionalesJson,
        FechaCreacion, UsuarioCreacion
    )
    VALUES
    (
        @IdHistorial, @IdSolicitud, @IdSolicitudPersona, 'REENVIO_APROBACION',
        'Solicitud de nueva aprobacion de area', @Justificacion, @Usuario,
        SYSDATETIME(),
        CONCAT('{"idSolicitudPersonaArea":', CONVERT(VARCHAR(30), @IdSolicitudPersonaArea), '}'),
        SYSDATETIME(), @Usuario
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Flujo_Automaticos_Guardar
    @IdActividadFlujoVersion BIGINT,
    @TiposJson NVARCHAR(MAX),
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ISJSON(COALESCE(@TiposJson, '[]')) <> 1
        THROW 50400, 'La seleccion automatica de tipos de ingreso no es valida.', 1;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Actividad_Flujo_Version
        WHERE IdActividadFlujoVersion = @IdActividadFlujoVersion
    ) THROW 50401, 'La version del flujo no existe.', 1;
    IF EXISTS
    (
        SELECT 1 FROM OPENJSON(COALESCE(@TiposJson, '[]')) AS item
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.Cat_Tipo_Ingreso AS tipo
            WHERE tipo.Codigo = CONVERT(VARCHAR(30), item.[value])
        )
    ) THROW 50402, 'Uno de los tipos automaticos no existe.', 1;
    IF EXISTS
    (
        SELECT 1 FROM OPENJSON(COALESCE(@TiposJson, '[]')) AS item
        WHERE EXISTS
        (
            SELECT 1 FROM dbo.Actividad_Flujo_Version_Tipo_Ingreso
            WHERE IdActividadFlujoVersion = @IdActividadFlujoVersion
        )
          AND NOT EXISTS
        (
            SELECT 1
            FROM dbo.Actividad_Flujo_Version_Tipo_Ingreso AS filtro
            INNER JOIN dbo.Cat_Tipo_Ingreso AS tipo ON tipo.IdTipoIngreso = filtro.IdTipoIngreso
            WHERE filtro.IdActividadFlujoVersion = @IdActividadFlujoVersion
              AND tipo.Codigo = CONVERT(VARCHAR(30), item.[value])
        )
    ) THROW 50403, 'Un tipo automatico tambien debe estar habilitado para el flujo.', 1;

    DECLARE @Activo SMALLINT =
        (SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'ACTIVO');

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE dbo.Actividad_Flujo_Version_Tipo_Automatico
        WHERE IdActividadFlujoVersion = @IdActividadFlujoVersion;

        DECLARE @CodigoTipo VARCHAR(30), @Id BIGINT;
        DECLARE tipos_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT DISTINCT CONVERT(VARCHAR(30), item.[value])
            FROM OPENJSON(COALESCE(@TiposJson, '[]')) AS item;
        OPEN tipos_cursor;
        FETCH NEXT FROM tipos_cursor INTO @CodigoTipo;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_ObtenerSiguienteId
                'Actividad_Flujo_Version_Tipo_Automatico', @Id OUTPUT;
            INSERT dbo.Actividad_Flujo_Version_Tipo_Automatico
            (
                IdActividadFlujoVersionTipoAutomatico, IdActividadFlujoVersion,
                IdTipoIngreso, IdEstadoGeneral, FechaCreacion, UsuarioCreacion
            )
            SELECT @Id, @IdActividadFlujoVersion, tipo.IdTipoIngreso,
                   @Activo, SYSDATETIME(), @Usuario
            FROM dbo.Cat_Tipo_Ingreso AS tipo
            WHERE tipo.Codigo = @CodigoTipo;
            FETCH NEXT FROM tipos_cursor INTO @CodigoTipo;
        END;
        CLOSE tipos_cursor;
        DEALLOCATE tipos_cursor;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'tipos_cursor') >= 0
        BEGIN
            CLOSE tipos_cursor;
            DEALLOCATE tipos_cursor;
        END;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Flujo_Automaticos_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT automatico.IdActividadFlujoVersion, tipo.Codigo
    FROM dbo.Actividad_Flujo_Version_Tipo_Automatico AS automatico
    INNER JOIN dbo.Cat_Tipo_Ingreso AS tipo ON tipo.IdTipoIngreso = automatico.IdTipoIngreso
    LEFT JOIN dbo.Cat_Estado_General AS estado ON estado.IdEstadoGeneral = automatico.IdEstadoGeneral
    WHERE ISNULL(estado.EsActivo, 1) = 1
    ORDER BY automatico.IdActividadFlujoVersion, tipo.Codigo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Flujo_Automaticos_Resolver
    @IdSolicitud BIGINT,
    @IdSolicitudPersona BIGINT,
    @FlujosJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    IF ISJSON(COALESCE(@FlujosJson, '[]')) <> 1
        THROW 50404, 'La seleccion de flujos no es valida.', 1;

    DECLARE @Tipo VARCHAR(30), @FechaSolicitud DATETIME2(3);
    SELECT @Tipo = CASE WHEN tipo.Codigo = 'NUEVO_EMPLEADO' THEN 'EMPLEADO' ELSE tipo.Codigo END,
           @FechaSolicitud = solicitud.FechaCreacion
    FROM dbo.Solicitud_Ingreso AS solicitud
    INNER JOIN dbo.Cat_Tipo_Ingreso AS tipo ON tipo.IdTipoIngreso = solicitud.IdTipoIngreso
    INNER JOIN dbo.Solicitud_Persona AS persona
        ON persona.IdSolicitud = solicitud.IdSolicitud
       AND persona.IdSolicitudPersona = @IdSolicitudPersona
    WHERE solicitud.IdSolicitud = @IdSolicitud;

    IF @Tipo IS NULL THROW 50405, 'La persona o el tipo de ingreso de la solicitud no existe.', 1;

    SELECT DISTINCT version.IdActividadFlujoVersion
    FROM dbo.Actividad_Flujo AS flujo
    INNER JOIN dbo.Actividad_Flujo_Version AS version
        ON version.IdActividadFlujoVersion = flujo.IdActividadFlujoVersionActual
    INNER JOIN dbo.Solicitud_Persona_Area AS areaPersona
        ON areaPersona.IdSolicitudPersona = @IdSolicitudPersona
       AND areaPersona.IdArea = flujo.IdAreaAcceso
    INNER JOIN dbo.Actividad_Flujo_Version_Tipo_Automatico AS automatico
        ON automatico.IdActividadFlujoVersion = version.IdActividadFlujoVersion
    INNER JOIN dbo.Cat_Tipo_Ingreso AS tipo ON tipo.IdTipoIngreso = automatico.IdTipoIngreso
    LEFT JOIN dbo.Cat_Estado_General AS estadoAutomatico
        ON estadoAutomatico.IdEstadoGeneral = automatico.IdEstadoGeneral
    WHERE tipo.Codigo = @Tipo
      AND ISNULL(version.EsPublicada, 0) = 1
      AND version.FechaPublicacion <= COALESCE(@FechaSolicitud, SYSDATETIME())
      AND ISNULL(estadoAutomatico.EsActivo, 1) = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM OPENJSON(COALESCE(@FlujosJson, '[]')) AS item
          INNER JOIN dbo.Actividad_Flujo_Version AS seleccion
              ON seleccion.IdActividadFlujoVersion = TRY_CONVERT(BIGINT, item.[value])
          WHERE seleccion.IdActividadFlujo = flujo.IdActividadFlujo
      );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Flujo_Historicos_Obtener
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH VersionHistorica AS
    (
        SELECT DISTINCT version.IdActividadFlujoVersion
        FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
        INNER JOIN dbo.Actividad_Flujo_Version AS version
            ON version.IdActividadFlujoVersion = asignacion.IdActividadFlujoVersion
        INNER JOIN dbo.Actividad_Flujo AS flujo ON flujo.IdActividadFlujo = version.IdActividadFlujo
        LEFT JOIN dbo.Cat_Estado_General AS estadoAsignacion
            ON estadoAsignacion.IdEstadoGeneral = asignacion.IdEstadoGeneral
        WHERE version.IdActividadFlujoVersion <> flujo.IdActividadFlujoVersionActual
          AND ISNULL(estadoAsignacion.EsActivo, 1) = 1
    )
    SELECT flujo.IdActividadFlujo, version.IdActividadFlujoVersion, version.NumeroVersion,
           flujo.IdAreaAcceso, flujo.Codigo, flujo.Nombre, flujo.Descripcion, tipos.TiposIngreso
    FROM VersionHistorica AS historica
    INNER JOIN dbo.Actividad_Flujo_Version AS version
        ON version.IdActividadFlujoVersion = historica.IdActividadFlujoVersion
    INNER JOIN dbo.Actividad_Flujo AS flujo ON flujo.IdActividadFlujo = version.IdActividadFlujo
    OUTER APPLY
    (
        SELECT STRING_AGG(CONVERT(VARCHAR(MAX), tipo.Codigo), ',') AS TiposIngreso
        FROM dbo.Actividad_Flujo_Version_Tipo_Ingreso AS filtro
        INNER JOIN dbo.Cat_Tipo_Ingreso AS tipo ON tipo.IdTipoIngreso = filtro.IdTipoIngreso
        WHERE filtro.IdActividadFlujoVersion = version.IdActividadFlujoVersion
    ) AS tipos
    ORDER BY flujo.IdAreaAcceso, flujo.Nombre, version.NumeroVersion;

    ;WITH VersionHistorica AS
    (
        SELECT DISTINCT version.IdActividadFlujoVersion
        FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
        INNER JOIN dbo.Actividad_Flujo_Version AS version
            ON version.IdActividadFlujoVersion = asignacion.IdActividadFlujoVersion
        INNER JOIN dbo.Actividad_Flujo AS flujo ON flujo.IdActividadFlujo = version.IdActividadFlujo
        LEFT JOIN dbo.Cat_Estado_General AS estadoAsignacion
            ON estadoAsignacion.IdEstadoGeneral = asignacion.IdEstadoGeneral
        WHERE version.IdActividadFlujoVersion <> flujo.IdActividadFlujoVersionActual
          AND ISNULL(estadoAsignacion.EsActivo, 1) = 1
    )
    SELECT paso.IdActividadFlujoPaso, paso.IdActividadFlujoVersion, paso.IdRequerimiento,
           paso.ClavePaso, paso.OrdenVisual, paso.NombreActividad, paso.IdAreaResponsable,
           area.Nombre, CONVERT(BIT, ISNULL(paso.RequiereTicketExterno, 0)),
           ISNULL(paso.VigenciaMeses, 24), paso.FechaInicio, paso.FechaFin,
           dependencias.IdsDependencia
    FROM dbo.Actividad_Flujo_Paso AS paso
    INNER JOIN VersionHistorica AS historica
        ON historica.IdActividadFlujoVersion = paso.IdActividadFlujoVersion
    LEFT JOIN dbo.Cat_Area AS area ON area.IdArea = paso.IdAreaResponsable
    OUTER APPLY
    (
        SELECT STRING_AGG(CONVERT(VARCHAR(MAX), dependencia.IdActividadFlujoPasoRequerido), ',')
            AS IdsDependencia
        FROM dbo.Actividad_Flujo_Paso_Dependencia AS dependencia
        WHERE dependencia.IdActividadFlujoPaso = paso.IdActividadFlujoPaso
    ) AS dependencias
    ORDER BY paso.IdActividadFlujoVersion, paso.OrdenVisual, paso.IdActividadFlujoPaso;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Persona_Areas_Asignar
    @IdSolicitud BIGINT,
    @IdSolicitudPersona BIGINT,
    @AreasJson NVARCHAR(MAX),
    @RequerimientosJson NVARCHAR(MAX) = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF ISJSON(COALESCE(@AreasJson, '')) <> 1
        THROW 50800, 'La lista de areas no es valida.', 1;
    IF NOT EXISTS (SELECT 1 FROM OPENJSON(@AreasJson))
        THROW 50801, 'Selecciona al menos un area para la persona.', 1;
    IF ISJSON(COALESCE(@RequerimientosJson, '[]')) <> 1
        THROW 50806, 'La lista de actividades no es valida.', 1;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Solicitud_Persona
        WHERE IdSolicitudPersona = @IdSolicitudPersona AND IdSolicitud = @IdSolicitud
    ) THROW 50802, 'La persona no pertenece a la solicitud.', 1;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Solicitud_Ingreso AS solicitud
        WHERE solicitud.IdSolicitud = @IdSolicitud
          AND
          (
              solicitud.IdUsuarioSolicitante = @Usuario
              OR EXISTS
              (
                  SELECT 1 FROM dbo.Usuario_Rol AS usuarioRol
                  INNER JOIN dbo.Rol AS rol ON rol.IdRol = usuarioRol.IdRol
                  WHERE usuarioRol.IdUsuario = @Usuario AND rol.Codigo = 'ADMINISTRADOR'
              )
          )
    ) THROW 50803, 'No tienes permiso para asignar areas a esta solicitud.', 1;
    IF EXISTS
    (
        SELECT 1 FROM OPENJSON(@AreasJson) AS item
        WHERE TRY_CONVERT(INT, item.[value]) IS NULL
           OR NOT EXISTS
              (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = TRY_CONVERT(INT, item.[value]))
    ) THROW 50804, 'Una de las areas seleccionadas no existe.', 1;
    IF EXISTS
    (
        SELECT 1 FROM dbo.Aprobacion_Area AS aprobacion
        INNER JOIN dbo.Solicitud_Persona_Area AS areaPersona
            ON areaPersona.IdSolicitudPersonaArea = aprobacion.IdSolicitudPersonaArea
        WHERE areaPersona.IdSolicitudPersona = @IdSolicitudPersona
    ) THROW 50805, 'No puedes cambiar areas porque el proceso de aprobacion ya inicio.', 1;
    IF EXISTS
    (
        SELECT 1 FROM dbo.Actividad AS actividad
        LEFT JOIN dbo.Cat_Estado_Actividad AS estado
            ON estado.IdEstadoActividad = actividad.IdEstadoActividad
        WHERE actividad.IdSolicitudPersona = @IdSolicitudPersona
          AND
          (
              ISNULL(estado.EsEstadoFinal, 0) = 1
              OR EXISTS
                 (SELECT 1 FROM dbo.Actividad_Ticket_Externo WHERE IdActividad = actividad.IdActividad)
              OR EXISTS
                 (SELECT 1 FROM dbo.Ticket_Externo_Actividad WHERE IdActividad = actividad.IdActividad)
          )
    ) THROW 50807, 'No puedes cambiar areas porque ya existen actividades finalizadas o tickets.', 1;

    DECLARE @Areas TABLE (IdArea INT PRIMARY KEY);
    INSERT @Areas (IdArea)
    SELECT DISTINCT TRY_CONVERT(INT, item.[value]) FROM OPENJSON(@AreasJson) AS item;

    DECLARE @Req TABLE
    (
        IdRequerimiento INT PRIMARY KEY,
        IdTipoAplicacion SMALLINT NULL,
        Seleccionado BIT NULL,
        ConfiguradoAutomatico BIT NULL,
        Observaciones NVARCHAR(500) NULL
    );
    INSERT @Req
    SELECT IdRequerimiento, IdTipoAplicacion, Seleccionado, ConfiguradoAutomatico, Observaciones
    FROM OPENJSON(COALESCE(@RequerimientosJson, '[]'))
    WITH
    (
        IdRequerimiento INT '$.IdRequerimiento',
        IdTipoAplicacion SMALLINT '$.IdTipoAplicacion',
        Seleccionado BIT '$.Seleccionado',
        ConfiguradoAutomatico BIT '$.ConfiguradoAutomatico',
        Observaciones NVARCHAR(500) '$.Observaciones'
    );
    IF EXISTS
    (
        SELECT 1 FROM @Req AS requisito
        WHERE NOT EXISTS
            (SELECT 1 FROM dbo.Cat_Requerimiento WHERE IdRequerimiento = requisito.IdRequerimiento)
    ) THROW 50808, 'Una de las actividades seleccionadas no existe.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE actividad
        FROM dbo.Actividad AS actividad
        LEFT JOIN dbo.Solicitud_Persona_Area_Flujo AS asignacion
            ON asignacion.IdSolicitudPersonaAreaFlujo = actividad.IdSolicitudPersonaAreaFlujo
        LEFT JOIN dbo.Solicitud_Persona_Area AS areaPersona
            ON areaPersona.IdSolicitudPersonaArea = asignacion.IdSolicitudPersonaArea
        WHERE actividad.IdSolicitudPersona = @IdSolicitudPersona
          AND
          (
              (areaPersona.IdSolicitudPersonaArea IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM @Areas WHERE IdArea = areaPersona.IdArea))
              OR
              (actividad.IdAreaAcceso IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM @Areas WHERE IdArea = actividad.IdAreaAcceso))
          );

        DELETE asignacion
        FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
        INNER JOIN dbo.Solicitud_Persona_Area AS areaPersona
            ON areaPersona.IdSolicitudPersonaArea = asignacion.IdSolicitudPersonaArea
        WHERE areaPersona.IdSolicitudPersona = @IdSolicitudPersona
          AND NOT EXISTS (SELECT 1 FROM @Areas WHERE IdArea = areaPersona.IdArea);

        DELETE areaPersona
        FROM dbo.Solicitud_Persona_Area AS areaPersona
        WHERE areaPersona.IdSolicitudPersona = @IdSolicitudPersona
          AND NOT EXISTS (SELECT 1 FROM @Areas WHERE IdArea = areaPersona.IdArea);

        DECLARE @IdArea INT, @IdDetalle BIGINT;
        DECLARE areas_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT IdArea FROM @Areas AS area
            WHERE NOT EXISTS
            (
                SELECT 1 FROM dbo.Solicitud_Persona_Area
                WHERE IdSolicitudPersona = @IdSolicitudPersona AND IdArea = area.IdArea
            );
        OPEN areas_cursor;
        FETCH NEXT FROM areas_cursor INTO @IdArea;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona_Area', @IdDetalle OUTPUT;
            INSERT dbo.Solicitud_Persona_Area
            (
                IdSolicitudPersonaArea, IdSolicitudPersona, IdArea,
                RequiereAprobacion, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdDetalle, @IdSolicitudPersona, @IdArea,
                1, SYSDATETIME(), @Usuario
            );
            FETCH NEXT FROM areas_cursor INTO @IdArea;
        END;
        CLOSE areas_cursor;
        DEALLOCATE areas_cursor;

        UPDATE existente
           SET IdTipoAplicacion = requisito.IdTipoAplicacion,
               Seleccionado = requisito.Seleccionado,
               ConfiguradoAutomatico = requisito.ConfiguradoAutomatico,
               Observaciones = requisito.Observaciones,
               FechaModificacion = SYSDATETIME(),
               UsuarioModificacion = @Usuario
        FROM dbo.Solicitud_Persona_Requerimiento AS existente
        INNER JOIN @Req AS requisito ON requisito.IdRequerimiento = existente.IdRequerimiento
        WHERE existente.IdSolicitudPersona = @IdSolicitudPersona;

        DECLARE @IdReq INT, @IdTipo SMALLINT, @Sel BIT, @Auto BIT, @Obs NVARCHAR(500);
        DECLARE req_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT requisito.IdRequerimiento, requisito.IdTipoAplicacion, requisito.Seleccionado,
                   requisito.ConfiguradoAutomatico, requisito.Observaciones
            FROM @Req AS requisito
            WHERE NOT EXISTS
            (
                SELECT 1 FROM dbo.Solicitud_Persona_Requerimiento
                WHERE IdSolicitudPersona = @IdSolicitudPersona
                  AND IdRequerimiento = requisito.IdRequerimiento
            );
        OPEN req_cursor;
        FETCH NEXT FROM req_cursor INTO @IdReq, @IdTipo, @Sel, @Auto, @Obs;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona_Requerimiento', @IdDetalle OUTPUT;
            INSERT dbo.Solicitud_Persona_Requerimiento
            (
                IdSolicitudPersonaReq, IdSolicitudPersona, IdRequerimiento,
                IdTipoAplicacion, Seleccionado, ConfiguradoAutomatico,
                Observaciones, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdDetalle, @IdSolicitudPersona, @IdReq,
                @IdTipo, @Sel, @Auto, @Obs, SYSDATETIME(), @Usuario
            );
            FETCH NEXT FROM req_cursor INTO @IdReq, @IdTipo, @Sel, @Auto, @Obs;
        END;
        CLOSE req_cursor;
        DEALLOCATE req_cursor;

        UPDATE dbo.Solicitud_Ingreso
           SET FechaModificacion = SYSDATETIME(), UsuarioModificacion = @Usuario
        WHERE IdSolicitud = @IdSolicitud;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'req_cursor') >= 0 BEGIN CLOSE req_cursor; DEALLOCATE req_cursor; END;
        IF CURSOR_STATUS('local', 'areas_cursor') >= 0 BEGIN CLOSE areas_cursor; DEALLOCATE areas_cursor; END;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
