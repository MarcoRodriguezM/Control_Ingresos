SET XACT_ABORT ON;
GO

IF COL_LENGTH('dbo.Actividad_Flujo_Paso', 'FreshserviceWorkspaceId') IS NULL
    ALTER TABLE dbo.Actividad_Flujo_Paso ADD FreshserviceWorkspaceId INT NULL;
IF COL_LENGTH('dbo.Actividad_Flujo_Paso', 'FreshserviceServicioDisplayId') IS NULL
    ALTER TABLE dbo.Actividad_Flujo_Paso ADD FreshserviceServicioDisplayId BIGINT NULL;
IF COL_LENGTH('dbo.Actividad_Flujo_Paso', 'FreshserviceUrlFormularioRespaldo') IS NULL
    ALTER TABLE dbo.Actividad_Flujo_Paso ADD FreshserviceUrlFormularioRespaldo NVARCHAR(500) NULL;
IF COL_LENGTH('dbo.Actividad_Flujo_Paso', 'FreshserviceLookupsJson') IS NULL
    ALTER TABLE dbo.Actividad_Flujo_Paso ADD FreshserviceLookupsJson NVARCHAR(MAX) NULL;
IF COL_LENGTH('dbo.Actividad_Flujo_Paso', 'RequiereConsultaSingular') IS NULL
    ALTER TABLE dbo.Actividad_Flujo_Paso ADD RequiereConsultaSingular BIT NULL;
IF COL_LENGTH('dbo.Actividad_Flujo_Paso', 'SingularCapacitacionNombre') IS NULL
    ALTER TABLE dbo.Actividad_Flujo_Paso ADD SingularCapacitacionNombre NVARCHAR(200) NULL;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Flujo_Obtener
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
           paso.FreshserviceWorkspaceId,
           paso.FreshserviceServicioDisplayId,
           paso.FreshserviceUrlFormularioRespaldo,
           paso.FreshserviceLookupsJson,
           CONVERT(BIT, ISNULL(paso.RequiereConsultaSingular, 0)) AS RequiereConsultaSingular,
           paso.SingularCapacitacionNombre,
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

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Flujo_Guardar
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
        FreshserviceWorkspaceId INT NULL,
        FreshserviceServicioDisplayId BIGINT NULL,
        FreshserviceUrlFormularioRespaldo NVARCHAR(500) NULL,
        FreshserviceLookupsJson NVARCHAR(MAX) NULL,
        RequiereConsultaSingular BIT NULL,
        SingularCapacitacionNombre NVARCHAR(200) NULL,
        VigenciaMeses INT NULL,
        FechaInicio DATE NULL,
        FechaFin DATE NULL,
        DependenciasJson NVARCHAR(MAX) NULL,
        IdPasoNuevo BIGINT NULL
    );

    INSERT @Pasos
    (
        ClavePaso, OrdenVisual, IdRequerimiento, NombreActividad, IdAreaResponsable,
        RequiereTicketExterno, FreshserviceWorkspaceId, FreshserviceServicioDisplayId,
        FreshserviceUrlFormularioRespaldo, FreshserviceLookupsJson,
        RequiereConsultaSingular, SingularCapacitacionNombre,
        VigenciaMeses, FechaInicio, FechaFin, DependenciasJson
    )
    SELECT NULLIF(LTRIM(RTRIM(JSON_VALUE(item.[value], '$.ClavePaso'))), ''),
           CONVERT(INT, item.[key]) + 1,
           TRY_CONVERT(INT, JSON_VALUE(item.[value], '$.IdRequerimiento')),
           NULLIF(LTRIM(RTRIM(JSON_VALUE(item.[value], '$.NombreActividad'))), ''),
           TRY_CONVERT(INT, JSON_VALUE(item.[value], '$.IdAreaResponsable')),
           TRY_CONVERT(BIT, JSON_VALUE(item.[value], '$.RequiereTicketExterno')),
           TRY_CONVERT(INT, JSON_VALUE(item.[value], '$.FreshserviceWorkspaceId')),
           TRY_CONVERT(BIGINT, JSON_VALUE(item.[value], '$.FreshserviceServicioDisplayId')),
           NULLIF(LTRIM(RTRIM(JSON_VALUE(item.[value], '$.FreshserviceUrlFormularioRespaldo'))), ''),
           JSON_QUERY(item.[value], '$.FreshserviceLookups'),
           TRY_CONVERT(BIT, JSON_VALUE(item.[value], '$.RequiereConsultaSingular')),
           NULLIF(LTRIM(RTRIM(JSON_VALUE(item.[value], '$.SingularCapacitacionNombre'))), ''),
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
    IF EXISTS
    (
        SELECT 1 FROM @Pasos
        WHERE ISNULL(RequiereTicketExterno, 0) = 1
          AND (FreshserviceWorkspaceId IS NULL OR FreshserviceWorkspaceId <= 0
            OR FreshserviceServicioDisplayId IS NULL OR FreshserviceServicioDisplayId <= 0
            OR FreshserviceUrlFormularioRespaldo IS NULL
            OR FreshserviceUrlFormularioRespaldo NOT LIKE 'https://%.freshservice.com/%')
    ) THROW 50312, 'Configura el workspace, el servicio y la URL HTTPS de respaldo de Freshservice.', 1;
    IF EXISTS
    (
        SELECT 1 FROM @Pasos
        WHERE FreshserviceLookupsJson IS NOT NULL AND ISJSON(FreshserviceLookupsJson) <> 1
    ) THROW 50313, 'La configuracion de lookups de Freshservice no es valida.', 1;
    IF EXISTS
    (
        SELECT 1
        FROM @Pasos AS paso
        CROSS APPLY OPENJSON(COALESCE(paso.FreshserviceLookupsJson, N'[]')) AS lookup
        WHERE NULLIF(LTRIM(RTRIM(JSON_VALUE(lookup.[value], '$.CampoApi'))), '') IS NULL
           OR JSON_VALUE(lookup.[value], '$.Origen') NOT IN
              ('FRESHSERVICE_LOCATIONS', 'FRESHSERVICE_DEPARTMENTS', 'FRESHSERVICE_REQUESTERS',
               'FRESHSERVICE_AGENT_GROUPS', 'FRESHSERVICE_ASSETS')
    ) THROW 50314, 'Uno de los lookups de Freshservice no tiene un campo u origen permitido.', 1;
    IF EXISTS
    (
        SELECT 1
        FROM @Pasos AS paso
        CROSS APPLY OPENJSON(COALESCE(paso.FreshserviceLookupsJson, N'[]')) AS lookup
        GROUP BY paso.ClavePaso, UPPER(JSON_VALUE(lookup.[value], '$.CampoApi'))
        HAVING COUNT(*) > 1
    ) THROW 50315, 'Un campo lookup de Freshservice no puede configurarse mas de una vez.', 1;
    IF EXISTS
    (
        SELECT 1 FROM @Pasos
        WHERE ISNULL(RequiereConsultaSingular, 0) = 1
          AND SingularCapacitacionNombre IS NULL
    ) THROW 50316, 'Configura la capacitacion que debe consultarse en Singular.', 1;

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
                @IdAreaResponsable INT, @Ticket BIT, @WorkspaceId INT, @ServicioDisplayId BIGINT,
                @UrlFormularioRespaldo NVARCHAR(500), @LookupsJson NVARCHAR(MAX),
                @ConsultaSingular BIT, @CapacitacionSingular NVARCHAR(200),
                @Vigencia INT, @Inicio DATE, @Fin DATE, @OrdenVisual INT,
                @IdRequerimientoGenerado BIGINT, @IdPaso BIGINT;
        DECLARE pasos_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT ClavePaso, IdRequerimiento, NombreActividad, IdAreaResponsable,
                   RequiereTicketExterno, FreshserviceWorkspaceId, FreshserviceServicioDisplayId,
                   FreshserviceUrlFormularioRespaldo, FreshserviceLookupsJson,
                   RequiereConsultaSingular, SingularCapacitacionNombre,
                   VigenciaMeses, FechaInicio, FechaFin, OrdenVisual
            FROM @Pasos ORDER BY OrdenVisual;
        OPEN pasos_cursor;
        FETCH NEXT FROM pasos_cursor INTO @ClavePaso, @IdRequerimiento, @NombreActividad,
            @IdAreaResponsable, @Ticket, @WorkspaceId, @ServicioDisplayId,
            @UrlFormularioRespaldo, @LookupsJson, @ConsultaSingular, @CapacitacionSingular,
            @Vigencia, @Inicio, @Fin, @OrdenVisual;
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
                FreshserviceWorkspaceId, FreshserviceServicioDisplayId,
                FreshserviceUrlFormularioRespaldo, FreshserviceLookupsJson,
                RequiereConsultaSingular, SingularCapacitacionNombre,
                VigenciaMeses, FechaInicio, FechaFin, IdEstadoGeneral, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdPaso, @IdVersion, @IdRequerimiento, @ClavePaso,
                @OrdenVisual, @NombreActividad, @IdAreaResponsable, @Ticket,
                CASE WHEN ISNULL(@Ticket, 0) = 1 THEN @WorkspaceId END,
                CASE WHEN ISNULL(@Ticket, 0) = 1 THEN @ServicioDisplayId END,
                CASE WHEN ISNULL(@Ticket, 0) = 1 THEN @UrlFormularioRespaldo END,
                CASE WHEN ISNULL(@Ticket, 0) = 1 THEN @LookupsJson END,
                @ConsultaSingular,
                CASE WHEN ISNULL(@ConsultaSingular, 0) = 1 THEN @CapacitacionSingular END,
                @Vigencia, @Inicio, @Fin, @Activo, SYSDATETIME(), @Usuario
            );
            UPDATE @Pasos SET IdPasoNuevo = @IdPaso WHERE ClavePaso = @ClavePaso;

            FETCH NEXT FROM pasos_cursor INTO @ClavePaso, @IdRequerimiento, @NombreActividad,
                @IdAreaResponsable, @Ticket, @WorkspaceId, @ServicioDisplayId,
                @UrlFormularioRespaldo, @LookupsJson, @ConsultaSingular, @CapacitacionSingular,
                @Vigencia, @Inicio, @Fin, @OrdenVisual;
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
           paso.FreshserviceWorkspaceId, paso.FreshserviceServicioDisplayId,
           paso.FreshserviceUrlFormularioRespaldo, paso.FreshserviceLookupsJson,
           CONVERT(BIT, ISNULL(paso.RequiereConsultaSingular, 0)), paso.SingularCapacitacionNombre,
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

IF OBJECT_ID('dbo.usp_Actividad_Flujo_Obtener_V2', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Actividad_Flujo_Obtener_V2;
IF OBJECT_ID('dbo.usp_Actividad_Flujo_Guardar_V2', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Actividad_Flujo_Guardar_V2;
GO
