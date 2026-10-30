SET XACT_ABORT ON;
GO

/*
    Los flujos se asignan a la persona de la solicitud y no al acceso solicitado.
    IdSolicitudPersonaArea se conserva para leer asignaciones creadas antes de esta migracion.
*/
IF COL_LENGTH('dbo.Solicitud_Persona_Area_Flujo', 'IdSolicitudPersona') IS NULL
    ALTER TABLE dbo.Solicitud_Persona_Area_Flujo ADD IdSolicitudPersona BIGINT NULL;
GO

UPDATE asignacion
   SET IdSolicitudPersona = areaPersona.IdSolicitudPersona
FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
INNER JOIN dbo.Solicitud_Persona_Area AS areaPersona
    ON areaPersona.IdSolicitudPersonaArea = asignacion.IdSolicitudPersonaArea
WHERE asignacion.IdSolicitudPersona IS NULL;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Solicitud_Persona_Area_Flujo')
      AND name = 'IX_Solicitud_Persona_Area_Flujo_Persona'
)
    CREATE INDEX IX_Solicitud_Persona_Area_Flujo_Persona
        ON dbo.Solicitud_Persona_Area_Flujo(IdSolicitudPersona, IdEstadoGeneral)
        INCLUDE (IdActividadFlujo, IdActividadFlujoVersion);
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Integrante_Agregar
    @IdSolicitud BIGINT,
    @IdPersona BIGINT = NULL,
    @CodigoEmpleadoHtis VARCHAR(50) = NULL,
    @IdEstadoPersonaSolicitud SMALLINT = NULL,
    @DatosCompletos BIT = NULL,
    @ObservacionesRevision NVARCHAR(1000) = NULL,
    @AreasJson NVARCHAR(MAX) = NULL,
    @RequerimientosJson NVARCHAR(MAX) = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @CodigoEmpleadoHtis = NULLIF(LTRIM(RTRIM(@CodigoEmpleadoHtis)), '');
    IF NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud)
        THROW 50130, 'La solicitud no existe.', 1;

    DECLARE @CodigoTipo VARCHAR(30) =
    (
        SELECT UPPER(LTRIM(RTRIM(tipo.Codigo)))
        FROM dbo.Solicitud_Ingreso AS solicitud
        INNER JOIN dbo.Cat_Tipo_Ingreso AS tipo ON tipo.IdTipoIngreso = solicitud.IdTipoIngreso
        WHERE solicitud.IdSolicitud = @IdSolicitud
    );

    IF @CodigoTipo = 'EMPLEADO'
    BEGIN
        IF @IdPersona IS NOT NULL OR @CodigoEmpleadoHtis IS NULL
            THROW 50157, 'Selecciona un empleado valido de HTIS.', 1;
        IF EXISTS
        (
            SELECT 1 FROM dbo.Solicitud_Persona
            WHERE IdSolicitud = @IdSolicitud AND CodigoEmpleadoHtis = @CodigoEmpleadoHtis
        ) THROW 50158, 'El empleado ya pertenece a la solicitud.', 1;
    END
    ELSE
    BEGIN
        IF @IdPersona IS NULL OR @CodigoEmpleadoHtis IS NOT NULL
            THROW 50131, 'Selecciona una persona valida de Control Ingresos.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Persona WHERE IdPersona = @IdPersona)
            THROW 50131, 'La persona no existe.', 1;
        IF EXISTS
        (
            SELECT 1 FROM dbo.Solicitud_Persona
            WHERE IdSolicitud = @IdSolicitud AND IdPersona = @IdPersona
        ) THROW 50132, 'La persona ya pertenece a la solicitud.', 1;
    END;

    IF @IdEstadoPersonaSolicitud IS NOT NULL
       AND NOT EXISTS
           (SELECT 1 FROM dbo.Cat_Estado_Persona_Solicitud WHERE IdEstadoPersonaSolicitud = @IdEstadoPersonaSolicitud)
        THROW 50133, 'El estado del integrante no existe.', 1;
    IF @AreasJson IS NOT NULL AND ISJSON(@AreasJson) <> 1
        THROW 50134, 'AreasJson no contiene JSON valido.', 1;
    IF @RequerimientosJson IS NOT NULL AND ISJSON(@RequerimientosJson) <> 1
        THROW 50135, 'RequerimientosJson no contiene JSON valido.', 1;

    DECLARE @Areas TABLE (IdArea INT PRIMARY KEY);
    INSERT @Areas (IdArea)
    SELECT DISTINCT TRY_CONVERT(INT, [value])
    FROM OPENJSON(COALESCE(@AreasJson, '[]'))
    WHERE TRY_CONVERT(INT, [value]) IS NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM @Areas AS area
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Cat_Area AS catalogo WHERE catalogo.IdArea = area.IdArea)
    ) THROW 50136, 'Una de las areas no existe.', 1;

    DECLARE @Requerimientos TABLE
    (
        IdRequerimiento INT PRIMARY KEY,
        IdTipoAplicacion SMALLINT NULL,
        Seleccionado BIT NULL,
        ConfiguradoAutomatico BIT NULL,
        Observaciones NVARCHAR(500) NULL
    );
    INSERT @Requerimientos
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
        SELECT 1 FROM @Requerimientos AS requerimiento
        WHERE NOT EXISTS
            (SELECT 1 FROM dbo.Cat_Requerimiento AS catalogo WHERE catalogo.IdRequerimiento = requerimiento.IdRequerimiento)
    ) THROW 50137, 'Uno de los requerimientos no existe.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Requerimientos AS requerimiento
        WHERE requerimiento.IdTipoAplicacion IS NOT NULL
          AND NOT EXISTS
              (SELECT 1 FROM dbo.Cat_Tipo_Aplicacion_Requerimiento AS catalogo WHERE catalogo.IdTipoAplicacion = requerimiento.IdTipoAplicacion)
    ) THROW 50138, 'Uno de los tipos de aplicacion no existe.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CantidadEstimada INT;
        SELECT @CantidadEstimada = CantidadEstimada
        FROM dbo.Solicitud_Ingreso WITH (UPDLOCK, HOLDLOCK)
        WHERE IdSolicitud = @IdSolicitud;
        IF @CantidadEstimada IS NULL
           OR (SELECT COUNT(*) FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud) >= @CantidadEstimada
            THROW 50141, 'Ya se alcanzo la cantidad maxima de integrantes de la solicitud.', 1;

        DECLARE @IdSolicitudPersona BIGINT;
        EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona', @IdSolicitudPersona OUTPUT;
        INSERT dbo.Solicitud_Persona
        (
            IdSolicitudPersona, IdSolicitud, IdPersona, CodigoEmpleadoHtis,
            IdEstadoPersonaSolicitud, DatosCompletos, ObservacionesRevision,
            FechaCreacion, UsuarioCreacion
        )
        VALUES
        (
            @IdSolicitudPersona, @IdSolicitud, @IdPersona, @CodigoEmpleadoHtis,
            @IdEstadoPersonaSolicitud, @DatosCompletos, @ObservacionesRevision,
            SYSDATETIME(), @Usuario
        );

        DECLARE @IdEstadoPendiente SMALLINT =
            (SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'PENDIENTE');
        DECLARE @IdEstadoNoRequiere SMALLINT =
            (SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'NO_REQUIERE');
        IF EXISTS (SELECT 1 FROM @Areas)
           AND (@IdEstadoPendiente IS NULL OR @IdEstadoNoRequiere IS NULL)
            THROW 50139, 'No estan configurados los estados de aprobacion requeridos.', 1;

        DECLARE @IdArea INT, @IdDetalle BIGINT, @RequiereAprobacion BIT;
        DECLARE areas_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT IdArea FROM @Areas;
        OPEN areas_cursor;
        FETCH NEXT FROM areas_cursor INTO @IdArea;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @RequiereAprobacion = COALESCE(RequiereAprobacion, 0)
            FROM dbo.Cat_Area WHERE IdArea = @IdArea;
            EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona_Area', @IdDetalle OUTPUT;
            INSERT dbo.Solicitud_Persona_Area
            (
                IdSolicitudPersonaArea, IdSolicitudPersona, IdArea, RequiereAprobacion,
                IdEstadoAprobacion, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdDetalle, @IdSolicitudPersona, @IdArea, @RequiereAprobacion,
                CASE WHEN @RequiereAprobacion = 1 THEN @IdEstadoPendiente ELSE @IdEstadoNoRequiere END,
                SYSDATETIME(), @Usuario
            );
            FETCH NEXT FROM areas_cursor INTO @IdArea;
        END;
        CLOSE areas_cursor;
        DEALLOCATE areas_cursor;

        DECLARE @IdReq INT, @IdTipoAplicacion SMALLINT, @Seleccionado BIT,
                @Configurado BIT, @Obs NVARCHAR(500);
        DECLARE req_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT IdRequerimiento, IdTipoAplicacion, Seleccionado, ConfiguradoAutomatico, Observaciones
            FROM @Requerimientos;
        OPEN req_cursor;
        FETCH NEXT FROM req_cursor INTO @IdReq, @IdTipoAplicacion, @Seleccionado, @Configurado, @Obs;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona_Requerimiento', @IdDetalle OUTPUT;
            INSERT dbo.Solicitud_Persona_Requerimiento
            (
                IdSolicitudPersonaReq, IdSolicitudPersona, IdRequerimiento, IdTipoAplicacion,
                Seleccionado, ConfiguradoAutomatico, Observaciones, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdDetalle, @IdSolicitudPersona, @IdReq, @IdTipoAplicacion,
                @Seleccionado, @Configurado, @Obs, SYSDATETIME(), @Usuario
            );
            FETCH NEXT FROM req_cursor INTO @IdReq, @IdTipoAplicacion, @Seleccionado, @Configurado, @Obs;
        END;
        CLOSE req_cursor;
        DEALLOCATE req_cursor;

        COMMIT TRANSACTION;
        SELECT @IdSolicitudPersona;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'req_cursor') >= 0 BEGIN CLOSE req_cursor; DEALLOCATE req_cursor; END;
        IF CURSOR_STATUS('local', 'areas_cursor') >= 0 BEGIN CLOSE areas_cursor; DEALLOCATE areas_cursor; END;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Empleado_Agregar
    @IdSolicitud BIGINT,
    @CodigoEmpleado VARCHAR(50),
    @NombreCompleto NVARCHAR(200),
    @Correo VARCHAR(254) = NULL,
    @CargoFuncion NVARCHAR(150) = NULL,
    @AreasJson NVARCHAR(MAX),
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @CodigoEmpleado = LTRIM(RTRIM(@CodigoEmpleado));
    IF NULLIF(@CodigoEmpleado, '') IS NULL
        THROW 50700, 'El codigo del empleado es obligatorio.', 1;
    IF NULLIF(LTRIM(RTRIM(@NombreCompleto)), '') IS NULL
        THROW 50701, 'El nombre del empleado es obligatorio.', 1;
    IF ISJSON(COALESCE(@AreasJson, '')) <> 1
        THROW 50702, 'La seleccion de areas no es valida.', 1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Solicitud_Ingreso AS solicitud
        INNER JOIN dbo.Cat_Tipo_Ingreso AS tipo ON tipo.IdTipoIngreso = solicitud.IdTipoIngreso
        WHERE solicitud.IdSolicitud = @IdSolicitud AND tipo.Codigo = 'EMPLEADO'
    ) THROW 50703, 'La solicitud no corresponde al tipo Empleado.', 1;

    DECLARE @IdPersona BIGINT =
    (
        SELECT TOP (1) IdPersona
        FROM dbo.Persona
        WHERE NumeroDocumento = @CodigoEmpleado AND IdProveedor IS NULL
        ORDER BY IdPersona
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @IdPersona IS NULL
        BEGIN
            DECLARE @IdEstadoActivo SMALLINT =
                (SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'ACTIVO');
            EXEC dbo.usp_ObtenerSiguienteId 'Persona', @IdPersona OUTPUT;
            INSERT dbo.Persona
            (
                IdPersona, IdTipoDocumento, NumeroDocumento, NombreCompleto, Correo,
                CargoFuncion, IdProveedor, EmpresaTexto, InformacionAdicional,
                IdEstadoGeneral, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdPersona, NULL, @CodigoEmpleado, @NombreCompleto, @Correo,
                @CargoFuncion, NULL, N'Empleado interno', N'Registro vinculado al directorio de empleados',
                @IdEstadoActivo, SYSDATETIME(), @Usuario
            );
        END
        ELSE
        BEGIN
            UPDATE dbo.Persona
               SET NombreCompleto = @NombreCompleto,
                   Correo = COALESCE(@Correo, Correo),
                   CargoFuncion = COALESCE(@CargoFuncion, CargoFuncion),
                   EmpresaTexto = N'Empleado interno',
                   FechaModificacion = SYSDATETIME(),
                   UsuarioModificacion = @Usuario
             WHERE IdPersona = @IdPersona;
        END;

        DECLARE @Resultado TABLE (IdSolicitudPersona BIGINT);
        INSERT @Resultado (IdSolicitudPersona)
        EXEC dbo.usp_Solicitud_Persona_Agregar
            @IdSolicitud = @IdSolicitud,
            @IdPersona = @IdPersona,
            @IdEstadoPersonaSolicitud = NULL,
            @DatosCompletos = 1,
            @ObservacionesRevision = NULL,
            @AreasJson = @AreasJson,
            @RequerimientosJson = NULL,
            @Usuario = @Usuario;

        DECLARE @IdSolicitudPersona BIGINT =
            (SELECT TOP (1) IdSolicitudPersona FROM @Resultado);

        COMMIT TRANSACTION;
        SELECT @IdSolicitudPersona;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
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
        SELECT 1
        FROM dbo.Solicitud_Persona AS solicitudPersona
        WHERE solicitudPersona.IdSolicitud = @IdSolicitud
          AND
          (
              EXISTS
                  (SELECT 1 FROM dbo.Solicitud_Persona_Area AS areaPersona WHERE areaPersona.IdSolicitudPersona = solicitudPersona.IdSolicitudPersona)
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
                  LEFT JOIN dbo.Cat_Estado_General AS estadoAsignacion
                      ON estadoAsignacion.IdEstadoGeneral = asignacion.IdEstadoGeneral
                  WHERE asignacion.IdSolicitudPersona = solicitudPersona.IdSolicitudPersona
                    AND ISNULL(estadoAsignacion.EsActivo, 1) = 1
              )
          )
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
               SELECT 1
               FROM dbo.Solicitud_Persona AS persona
               WHERE persona.IdSolicitud = solicitud.IdSolicitud
                 AND
                 (
                     EXISTS
                         (SELECT 1 FROM dbo.Solicitud_Persona_Area AS areaPersona WHERE areaPersona.IdSolicitudPersona = persona.IdSolicitudPersona)
                     OR EXISTS
                     (
                         SELECT 1
                         FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
                         LEFT JOIN dbo.Cat_Estado_General AS estadoAsignacion
                             ON estadoAsignacion.IdEstadoGeneral = asignacion.IdEstadoGeneral
                         WHERE asignacion.IdSolicitudPersona = persona.IdSolicitudPersona
                           AND ISNULL(estadoAsignacion.EsActivo, 1) = 1
                     )
                 )
           ) THEN 1 ELSE 0 END)
    FROM dbo.Solicitud_Ingreso AS solicitud
    LEFT JOIN dbo.Cat_Estado_Solicitud AS estadoSolicitud
        ON estadoSolicitud.IdEstadoSolicitud = solicitud.IdEstadoSolicitud
    WHERE solicitud.IdSolicitud IN
        (SELECT TRY_CONVERT(BIGINT, value) FROM STRING_SPLIT(@Ids, ','));
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

    IF @Tipo IS NULL
        THROW 50405, 'La persona o el tipo de ingreso de la solicitud no existe.', 1;

    SELECT DISTINCT version.IdActividadFlujoVersion
    FROM dbo.Actividad_Flujo AS flujo
    INNER JOIN dbo.Actividad_Flujo_Version AS version
        ON version.IdActividadFlujoVersion = flujo.IdActividadFlujoVersionActual
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

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Accesos_Bloqueados
    @IdsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT areaConsultada.IdSolicitudPersonaArea
    FROM dbo.Solicitud_Persona_Area AS areaConsultada
    WHERE areaConsultada.IdSolicitudPersonaArea IN
        (SELECT TRY_CONVERT(BIGINT, item.[value]) FROM OPENJSON(COALESCE(@IdsJson, '[]')) AS item)
      AND EXISTS
      (
          SELECT 1
          FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
          INNER JOIN dbo.Actividad AS actividad
              ON actividad.IdSolicitudPersonaAreaFlujo = asignacion.IdSolicitudPersonaAreaFlujo
          LEFT JOIN dbo.Cat_Estado_Actividad AS estadoActividad
              ON estadoActividad.IdEstadoActividad = actividad.IdEstadoActividad
          LEFT JOIN dbo.Cat_Estado_General AS estadoAsignacion
              ON estadoAsignacion.IdEstadoGeneral = asignacion.IdEstadoGeneral
          LEFT JOIN dbo.Cat_Estado_General AS estadoActividadGeneral
              ON estadoActividadGeneral.IdEstadoGeneral = actividad.IdEstadoGeneral
          WHERE asignacion.IdSolicitudPersona = areaConsultada.IdSolicitudPersona
            AND ISNULL(estadoAsignacion.EsActivo, 1) = 1
            AND ISNULL(estadoActividadGeneral.EsActivo, 1) = 1
            AND ISNULL(estadoActividad.Codigo, '') <> 'APROBADA'
      );
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
    WHERE solicitudPersona.IdPersona = @IdPersona
      AND EXISTS
      (
          SELECT 1
          FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
          INNER JOIN dbo.Actividad AS actividad
              ON actividad.IdSolicitudPersonaAreaFlujo = asignacion.IdSolicitudPersonaAreaFlujo
          LEFT JOIN dbo.Cat_Estado_Actividad AS estadoActividad
              ON estadoActividad.IdEstadoActividad = actividad.IdEstadoActividad
          LEFT JOIN dbo.Cat_Estado_General AS estadoAsignacion
              ON estadoAsignacion.IdEstadoGeneral = asignacion.IdEstadoGeneral
          LEFT JOIN dbo.Cat_Estado_General AS estadoActividadGeneral
              ON estadoActividadGeneral.IdEstadoGeneral = actividad.IdEstadoGeneral
          WHERE asignacion.IdSolicitudPersona = solicitudPersona.IdSolicitudPersona
            AND ISNULL(estadoAsignacion.EsActivo, 1) = 1
            AND ISNULL(estadoActividadGeneral.EsActivo, 1) = 1
            AND ISNULL(estadoActividad.Codigo, '') <> 'APROBADA'
      );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Flujos_Asignados_Listar
    @IdSolicitud BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT asignacion.IdSolicitudPersona,
           asignacion.IdActividadFlujoVersion
    FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
    INNER JOIN dbo.Solicitud_Persona AS solicitudPersona
        ON solicitudPersona.IdSolicitudPersona = asignacion.IdSolicitudPersona
    LEFT JOIN dbo.Cat_Estado_General AS estado
        ON estado.IdEstadoGeneral = asignacion.IdEstadoGeneral
    WHERE solicitudPersona.IdSolicitud = @IdSolicitud
      AND ISNULL(estado.EsActivo, 1) = 1
    ORDER BY asignacion.IdSolicitudPersona, asignacion.IdActividadFlujoVersion;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Enviar
    @IdSolicitud BIGINT,
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud)
        THROW 50500, 'La solicitud no existe.', 1;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Solicitud_Ingreso AS solicitud
        WHERE solicitud.IdSolicitud = @IdSolicitud
          AND
          (
              solicitud.IdUsuarioSolicitante = @IdUsuario
              OR EXISTS
              (
                  SELECT 1 FROM dbo.Usuario_Rol AS usuarioRol
                  INNER JOIN dbo.Rol AS rol ON rol.IdRol = usuarioRol.IdRol
                  WHERE usuarioRol.IdUsuario = @IdUsuario AND rol.Codigo = 'ADMINISTRADOR'
              )
          )
    ) THROW 50501, 'No tienes permiso para enviar esta solicitud.', 1;
    IF EXISTS
    (
        SELECT 1
        FROM dbo.Solicitud_Ingreso AS solicitud
        INNER JOIN dbo.Cat_Estado_Solicitud AS estado
            ON estado.IdEstadoSolicitud = solicitud.IdEstadoSolicitud
        WHERE solicitud.IdSolicitud = @IdSolicitud AND estado.EsEstadoFinal = 1
    ) THROW 50502, 'La solicitud ya esta finalizada o cancelada.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Solicitud_Persona AS persona
        WHERE persona.IdSolicitud = @IdSolicitud
          AND NOT EXISTS
              (SELECT 1 FROM dbo.Solicitud_Persona_Area AS area WHERE area.IdSolicitudPersona = persona.IdSolicitudPersona)
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
              LEFT JOIN dbo.Cat_Estado_General AS estado
                  ON estado.IdEstadoGeneral = asignacion.IdEstadoGeneral
              WHERE asignacion.IdSolicitudPersona = persona.IdSolicitudPersona
                AND ISNULL(estado.EsActivo, 1) = 1
          )
    ) THROW 50503, 'Asigna al menos un area o un flujo a cada persona antes de enviar la solicitud.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Solicitud_Persona_Area AS areaPersona
        INNER JOIN dbo.Solicitud_Persona AS persona
            ON persona.IdSolicitudPersona = areaPersona.IdSolicitudPersona
        WHERE persona.IdSolicitud = @IdSolicitud
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.Config_Aprobador_Area AS aprobador
              WHERE aprobador.IdArea = areaPersona.IdArea
                AND aprobador.IdUsuarioAprobador IS NOT NULL
                AND ISNULL(aprobador.IdEstadoGeneral, 1) = 1
                AND (aprobador.FechaInicio IS NULL OR aprobador.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                AND (aprobador.FechaFin IS NULL OR aprobador.FechaFin >= CONVERT(DATE, SYSDATETIME()))
          )
    ) THROW 50504, 'Todas las areas deben tener al menos un aprobador activo antes de enviar la solicitud.', 1;

    UPDATE areaPersona
       SET RequiereAprobacion = CONVERT(BIT, 1)
    FROM dbo.Solicitud_Persona_Area AS areaPersona
    INNER JOIN dbo.Solicitud_Persona AS persona
        ON persona.IdSolicitudPersona = areaPersona.IdSolicitudPersona
    WHERE persona.IdSolicitud = @IdSolicitud;

    DECLARE @Codigo VARCHAR(40) = CASE
        WHEN NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud)
             AND EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud AND IdProveedor IS NOT NULL)
            THEN 'PENDIENTE_PROVEEDOR'
        WHEN NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud)
            THEN 'EN_REVISION'
        ELSE 'PENDIENTE_APROBACIONES'
    END;
    UPDATE solicitud
       SET IdEstadoSolicitud = estado.IdEstadoSolicitud,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuario,
           FechaEnvioProveedor = CASE WHEN @Codigo = 'PENDIENTE_PROVEEDOR' THEN SYSDATETIME() ELSE FechaEnvioProveedor END
    FROM dbo.Solicitud_Ingreso AS solicitud
    INNER JOIN dbo.Cat_Estado_Solicitud AS estado ON estado.Codigo = @Codigo
    WHERE solicitud.IdSolicitud = @IdSolicitud;

    EXEC dbo.usp_Historial_Solicitud_Registrar
        @IdSolicitud, 'ESTADO_SOLICITUD', N'Solicitud enviada al flujo', @Codigo, @IdUsuario;
END;
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
                   LEFT JOIN dbo.Cat_Estado_General AS estadoAsignacionExistente
                       ON estadoAsignacionExistente.IdEstadoGeneral = asignacionExistente.IdEstadoGeneral
                   WHERE asignacionExistente.IdSolicitudPersona = @IdSolicitudPersona
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
        GROUP BY version.IdActividadFlujo
        HAVING COUNT(*) > 1
    ) THROW 50323, 'El mismo flujo no puede asignarse dos veces a la persona.', 1;

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

    DECLARE @Activo SMALLINT =
        (SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'ACTIVO');
    DECLARE @Inactivo SMALLINT =
        (SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'INACTIVO');
    DECLARE @Pendiente SMALLINT =
        (SELECT TOP (1) IdEstadoActividad FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'PENDIENTE');
    DECLARE @Aprobada SMALLINT =
        (SELECT TOP (1) IdEstadoActividad FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'APROBADA');
    IF @Activo IS NULL OR @Inactivo IS NULL OR @Pendiente IS NULL OR @Aprobada IS NULL
        THROW 50326, 'Faltan estados requeridos para asignar actividades.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
            LEFT JOIN dbo.Cat_Estado_General AS estadoAsignacion
                ON estadoAsignacion.IdEstadoGeneral = asignacion.IdEstadoGeneral
            WHERE asignacion.IdSolicitudPersona = @IdSolicitudPersona
              AND ISNULL(estadoAsignacion.EsActivo, 1) = 1
              AND NOT EXISTS
                  (SELECT 1 FROM @Seleccion AS seleccion WHERE seleccion.IdActividadFlujoVersion = asignacion.IdActividadFlujoVersion)
              AND EXISTS
              (
                  SELECT 1
                  FROM dbo.Actividad AS actividad
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
                        OR EXISTS
                        (
                            SELECT 1 FROM dbo.Actividad_Ticket_Externo AS enlaceAnterior
                            WHERE enlaceAnterior.IdActividad = actividad.IdActividad
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
        WHERE asignacion.IdSolicitudPersona = @IdSolicitudPersona
          AND NOT EXISTS
              (SELECT 1 FROM @Seleccion AS seleccion WHERE seleccion.IdActividadFlujoVersion = asignacion.IdActividadFlujoVersion);

        UPDATE asignacion
           SET IdEstadoGeneral = @Inactivo,
               FechaModificacion = SYSDATETIME(),
               UsuarioModificacion = @Usuario
        FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
        WHERE asignacion.IdSolicitudPersona = @IdSolicitudPersona
          AND NOT EXISTS
              (SELECT 1 FROM @Seleccion AS seleccion WHERE seleccion.IdActividadFlujoVersion = asignacion.IdActividadFlujoVersion);

        DECLARE @IdVersion BIGINT, @IdFlujo BIGINT, @IdAreaAcceso INT, @IdAsignacion BIGINT;
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
            SET @IdAsignacion = NULL;
            SELECT TOP (1) @IdAsignacion = asignacion.IdSolicitudPersonaAreaFlujo
            FROM dbo.Solicitud_Persona_Area_Flujo AS asignacion
            LEFT JOIN dbo.Cat_Estado_General AS estado
                ON estado.IdEstadoGeneral = asignacion.IdEstadoGeneral
            WHERE asignacion.IdSolicitudPersona = @IdSolicitudPersona
              AND asignacion.IdActividadFlujo = @IdFlujo
              AND ISNULL(estado.EsActivo, 1) = 1;

            IF @IdAsignacion IS NULL
            BEGIN
                EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona_Area_Flujo', @IdAsignacion OUTPUT;
                INSERT dbo.Solicitud_Persona_Area_Flujo
                (
                    IdSolicitudPersonaAreaFlujo, IdSolicitudPersonaArea, IdSolicitudPersona,
                    IdActividadFlujo, IdActividadFlujoVersion, IdEstadoGeneral,
                    FechaCreacion, UsuarioCreacion
                )
                VALUES
                (
                    @IdAsignacion, NULL, @IdSolicitudPersona,
                    @IdFlujo, @IdVersion, @Activo, SYSDATETIME(), @Usuario
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
                SET @IdUsuarioResponsable = NULL;
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

                SET @IdSolicitudPersonaReq = NULL;
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
                SET @FechaLimite = COALESCE
                (
                    @FechaFinPaso,
                    (SELECT FechaFin FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud)
                );

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

                FETCH NEXT FROM pasos_cursor INTO @IdPaso, @IdRequerimiento, @NombreActividad,
                    @IdAreaResponsable, @RequiereTicket, @VigenciaMeses, @FechaInicioPaso, @FechaFinPaso;
            END;
            CLOSE pasos_cursor;
            DEALLOCATE pasos_cursor;

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

        DELETE areaPersona
        FROM dbo.Solicitud_Persona_Area AS areaPersona
        WHERE areaPersona.IdSolicitudPersona = @IdSolicitudPersona
          AND NOT EXISTS (SELECT 1 FROM @Areas WHERE IdArea = areaPersona.IdArea);

        DECLARE @IdEstadoPendiente SMALLINT =
            (SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'PENDIENTE');
        DECLARE @IdEstadoNoRequiere SMALLINT =
            (SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'NO_REQUIERE');
        DECLARE @IdArea INT, @IdDetalle BIGINT, @RequiereAprobacion BIT;
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
            SELECT @RequiereAprobacion = COALESCE(RequiereAprobacion, 0)
            FROM dbo.Cat_Area WHERE IdArea = @IdArea;
            EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona_Area', @IdDetalle OUTPUT;
            INSERT dbo.Solicitud_Persona_Area
            (
                IdSolicitudPersonaArea, IdSolicitudPersona, IdArea,
                RequiereAprobacion, IdEstadoAprobacion, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdDetalle, @IdSolicitudPersona, @IdArea, @RequiereAprobacion,
                CASE WHEN @RequiereAprobacion = 1 THEN @IdEstadoPendiente ELSE @IdEstadoNoRequiere END,
                SYSDATETIME(), @Usuario
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
