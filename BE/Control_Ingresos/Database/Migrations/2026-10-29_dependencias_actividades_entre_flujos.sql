SET XACT_ABORT ON;
GO

IF OBJECT_ID('dbo.Actividad_Flujo_Paso_Dependencia_Externa', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Actividad_Flujo_Paso_Dependencia_Externa
    (
        IdActividadFlujoPasoDependenciaExterna BIGINT NOT NULL,
        IdActividadFlujoPaso BIGINT NULL,
        IdActividadFlujoRequerido BIGINT NULL,
        ClavePasoRequerido VARCHAR(80) NULL,
        IdEstadoGeneral SMALLINT NULL,
        FechaCreacion DATETIME2(3) NULL,
        UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Actividad_Flujo_Paso_Dependencia_Externa
            PRIMARY KEY (IdActividadFlujoPasoDependenciaExterna)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Actividad_Flujo_Paso_Dependencia_Externa')
      AND name = 'IX_Actividad_Flujo_Paso_Dependencia_Externa_Paso'
)
    CREATE INDEX IX_Actividad_Flujo_Paso_Dependencia_Externa_Paso
        ON dbo.Actividad_Flujo_Paso_Dependencia_Externa(IdActividadFlujoPaso, IdEstadoGeneral)
        INCLUDE (IdActividadFlujoRequerido, ClavePasoRequerido);
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Flujo_Dependencias_Externas_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT dependencia.IdActividadFlujoPaso,
           dependencia.IdActividadFlujoRequerido,
           dependencia.ClavePasoRequerido
    FROM dbo.Actividad_Flujo_Paso_Dependencia_Externa AS dependencia
    LEFT JOIN dbo.Cat_Estado_General AS estado
        ON estado.IdEstadoGeneral = dependencia.IdEstadoGeneral
    WHERE ISNULL(estado.EsActivo, 1) = 1
    ORDER BY dependencia.IdActividadFlujoPaso,
             dependencia.IdActividadFlujoRequerido,
             dependencia.ClavePasoRequerido;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Flujo_Dependencias_Externas_Guardar
    @IdActividadFlujoVersion BIGINT,
    @FlujoJson NVARCHAR(MAX),
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ISJSON(@FlujoJson) <> 1
        THROW 50420, 'La configuracion de dependencias externas no contiene JSON valido.', 1;

    DECLARE @IdActividadFlujo BIGINT =
    (
        SELECT IdActividadFlujo
        FROM dbo.Actividad_Flujo_Version
        WHERE IdActividadFlujoVersion = @IdActividadFlujoVersion
    );
    IF @IdActividadFlujo IS NULL
        THROW 50421, 'La version del flujo no existe.', 1;

    DECLARE @Dependencias TABLE
    (
        ClavePaso VARCHAR(80) NOT NULL,
        IdActividadFlujoRequerido BIGINT NOT NULL,
        ClavePasoRequerido VARCHAR(80) NOT NULL,
        PRIMARY KEY (ClavePaso, IdActividadFlujoRequerido, ClavePasoRequerido)
    );

    INSERT @Dependencias (ClavePaso, IdActividadFlujoRequerido, ClavePasoRequerido)
    SELECT DISTINCT paso.ClavePaso,
           dependencia.IdActividadFlujo,
           dependencia.ClavePaso
    FROM OPENJSON(@FlujoJson, '$.Pasos') AS pasoJson
    CROSS APPLY OPENJSON(pasoJson.[value])
    WITH (ClavePaso VARCHAR(80) '$.ClavePaso') AS paso
    CROSS APPLY OPENJSON(COALESCE(JSON_QUERY(pasoJson.[value], '$.DependenciasExternas'), '[]'))
    WITH
    (
        IdActividadFlujo BIGINT '$.IdActividadFlujo',
        ClavePaso VARCHAR(80) '$.ClavePaso'
    ) AS dependencia
    WHERE paso.ClavePaso IS NOT NULL
      AND dependencia.IdActividadFlujo IS NOT NULL
      AND dependencia.ClavePaso IS NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM @Dependencias AS dependencia
        WHERE dependencia.IdActividadFlujoRequerido = @IdActividadFlujo
    ) THROW 50422, 'Las dependencias del mismo flujo deben configurarse como dependencias internas.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Dependencias AS dependencia
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.Actividad_Flujo_Paso AS paso
            WHERE paso.IdActividadFlujoVersion = @IdActividadFlujoVersion
              AND paso.ClavePaso = dependencia.ClavePaso
        )
    ) THROW 50423, 'Una actividad dependiente no pertenece a la version guardada.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Dependencias AS dependencia
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.Actividad_Flujo AS flujoRequerido
            INNER JOIN dbo.Actividad_Flujo_Paso AS pasoRequerido
                ON pasoRequerido.IdActividadFlujoVersion = flujoRequerido.IdActividadFlujoVersionActual
            WHERE flujoRequerido.IdActividadFlujo = dependencia.IdActividadFlujoRequerido
              AND pasoRequerido.ClavePaso = dependencia.ClavePasoRequerido
        )
    ) THROW 50424, 'Una dependencia externa ya no existe en la version actual de su flujo.', 1;

    DECLARE @Activo SMALLINT =
        (SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'ACTIVO');
    IF @Activo IS NULL
        THROW 50425, 'No existe el estado general ACTIVO.', 1;

    DECLARE @ClavePaso VARCHAR(80), @IdFlujoRequerido BIGINT,
            @ClavePasoRequerido VARCHAR(80), @IdPaso BIGINT, @Id BIGINT;
    DECLARE dependencias_externas_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT dependencia.ClavePaso,
               dependencia.IdActividadFlujoRequerido,
               dependencia.ClavePasoRequerido,
               paso.IdActividadFlujoPaso
        FROM @Dependencias AS dependencia
        INNER JOIN dbo.Actividad_Flujo_Paso AS paso
            ON paso.IdActividadFlujoVersion = @IdActividadFlujoVersion
           AND paso.ClavePaso = dependencia.ClavePaso;
    OPEN dependencias_externas_cursor;
    FETCH NEXT FROM dependencias_externas_cursor
        INTO @ClavePaso, @IdFlujoRequerido, @ClavePasoRequerido, @IdPaso;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.usp_ObtenerSiguienteId
            'Actividad_Flujo_Paso_Dependencia_Externa', @Id OUTPUT;
        INSERT dbo.Actividad_Flujo_Paso_Dependencia_Externa
        (
            IdActividadFlujoPasoDependenciaExterna,
            IdActividadFlujoPaso,
            IdActividadFlujoRequerido,
            ClavePasoRequerido,
            IdEstadoGeneral,
            FechaCreacion,
            UsuarioCreacion
        )
        VALUES
        (
            @Id, @IdPaso, @IdFlujoRequerido, @ClavePasoRequerido,
            @Activo, SYSDATETIME(), @Usuario
        );
        FETCH NEXT FROM dependencias_externas_cursor
            INTO @ClavePaso, @IdFlujoRequerido, @ClavePasoRequerido, @IdPaso;
    END;
    CLOSE dependencias_externas_cursor;
    DEALLOCATE dependencias_externas_cursor;

    DECLARE @Aristas TABLE
    (
        IdPasoOrigen BIGINT NOT NULL,
        IdPasoDestino BIGINT NOT NULL
    );
    INSERT @Aristas (IdPasoOrigen, IdPasoDestino)
    SELECT dependencia.IdActividadFlujoPaso,
           dependencia.IdActividadFlujoPasoRequerido
    FROM dbo.Actividad_Flujo_Paso_Dependencia AS dependencia
    INNER JOIN dbo.Actividad_Flujo_Paso AS pasoOrigen
        ON pasoOrigen.IdActividadFlujoPaso = dependencia.IdActividadFlujoPaso
    INNER JOIN dbo.Actividad_Flujo AS flujoOrigen
        ON flujoOrigen.IdActividadFlujoVersionActual = pasoOrigen.IdActividadFlujoVersion
    INNER JOIN dbo.Actividad_Flujo_Paso AS pasoDestino
        ON pasoDestino.IdActividadFlujoPaso = dependencia.IdActividadFlujoPasoRequerido
    LEFT JOIN dbo.Cat_Estado_General AS estado
        ON estado.IdEstadoGeneral = dependencia.IdEstadoGeneral
    WHERE ISNULL(estado.EsActivo, 1) = 1;

    INSERT @Aristas (IdPasoOrigen, IdPasoDestino)
    SELECT dependencia.IdActividadFlujoPaso,
           pasoDestino.IdActividadFlujoPaso
    FROM dbo.Actividad_Flujo_Paso_Dependencia_Externa AS dependencia
    INNER JOIN dbo.Actividad_Flujo_Paso AS pasoOrigen
        ON pasoOrigen.IdActividadFlujoPaso = dependencia.IdActividadFlujoPaso
    INNER JOIN dbo.Actividad_Flujo AS flujoOrigen
        ON flujoOrigen.IdActividadFlujoVersionActual = pasoOrigen.IdActividadFlujoVersion
    INNER JOIN dbo.Actividad_Flujo AS flujoDestino
        ON flujoDestino.IdActividadFlujo = dependencia.IdActividadFlujoRequerido
    INNER JOIN dbo.Actividad_Flujo_Paso AS pasoDestino
        ON pasoDestino.IdActividadFlujoVersion = flujoDestino.IdActividadFlujoVersionActual
       AND pasoDestino.ClavePaso = dependencia.ClavePasoRequerido
    LEFT JOIN dbo.Cat_Estado_General AS estado
        ON estado.IdEstadoGeneral = dependencia.IdEstadoGeneral
    WHERE ISNULL(estado.EsActivo, 1) = 1;

    DECLARE @TieneCiclo BIT = 0;
    ;WITH Recorrido AS
    (
        SELECT arista.IdPasoOrigen AS Origen,
               arista.IdPasoDestino AS Actual,
               CAST(CONCAT('|', arista.IdPasoOrigen, '|', arista.IdPasoDestino, '|') AS VARCHAR(MAX)) AS Ruta,
               CONVERT(BIT, CASE WHEN arista.IdPasoOrigen = arista.IdPasoDestino THEN 1 ELSE 0 END) AS TieneCiclo
        FROM @Aristas AS arista
        UNION ALL
        SELECT recorrido.Origen,
               arista.IdPasoDestino,
               CAST(CONCAT(recorrido.Ruta, arista.IdPasoDestino, '|') AS VARCHAR(MAX)),
               CONVERT(BIT, CASE WHEN recorrido.Ruta LIKE CONCAT('%|', arista.IdPasoDestino, '|%') THEN 1 ELSE 0 END)
        FROM Recorrido AS recorrido
        INNER JOIN @Aristas AS arista ON arista.IdPasoOrigen = recorrido.Actual
        WHERE recorrido.TieneCiclo = 0
    )
    SELECT TOP (1) @TieneCiclo = 1
    FROM Recorrido
    WHERE TieneCiclo = 1
    OPTION (MAXRECURSION 32767);

    IF @TieneCiclo = 1
        THROW 50426, 'La dependencia entre flujos crearia un ciclo de actividades.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Flujo_Dependencias_Resolver
    @FlujosJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    IF ISJSON(COALESCE(@FlujosJson, '[]')) <> 1
        THROW 50427, 'La seleccion de flujos no es valida.', 1;

    DECLARE @Seleccion TABLE
    (
        IdActividadFlujo BIGINT PRIMARY KEY,
        IdActividadFlujoVersion BIGINT NOT NULL
    );
    INSERT @Seleccion (IdActividadFlujo, IdActividadFlujoVersion)
    SELECT DISTINCT version.IdActividadFlujo, version.IdActividadFlujoVersion
    FROM OPENJSON(COALESCE(@FlujosJson, '[]')) AS item
    INNER JOIN dbo.Actividad_Flujo_Version AS version
        ON version.IdActividadFlujoVersion = TRY_CONVERT(BIGINT, item.[value]);

    DECLARE @Agregados INT = 1;
    WHILE @Agregados > 0
    BEGIN
        INSERT @Seleccion (IdActividadFlujo, IdActividadFlujoVersion)
        SELECT DISTINCT flujoRequerido.IdActividadFlujo,
               flujoRequerido.IdActividadFlujoVersionActual
        FROM @Seleccion AS seleccion
        INNER JOIN dbo.Actividad_Flujo_Paso AS paso
            ON paso.IdActividadFlujoVersion = seleccion.IdActividadFlujoVersion
        INNER JOIN dbo.Actividad_Flujo_Paso_Dependencia_Externa AS dependencia
            ON dependencia.IdActividadFlujoPaso = paso.IdActividadFlujoPaso
        INNER JOIN dbo.Actividad_Flujo AS flujoRequerido
            ON flujoRequerido.IdActividadFlujo = dependencia.IdActividadFlujoRequerido
        LEFT JOIN dbo.Cat_Estado_General AS estadoDependencia
            ON estadoDependencia.IdEstadoGeneral = dependencia.IdEstadoGeneral
        WHERE flujoRequerido.IdActividadFlujoVersionActual IS NOT NULL
          AND ISNULL(estadoDependencia.EsActivo, 1) = 1
          AND NOT EXISTS
              (SELECT 1 FROM @Seleccion AS existente WHERE existente.IdActividadFlujo = flujoRequerido.IdActividadFlujo);
        SET @Agregados = @@ROWCOUNT;
    END;

    SELECT seleccion.IdActividadFlujoVersion
    FROM @Seleccion AS seleccion
    ORDER BY seleccion.IdActividadFlujo;
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

    DECLARE @PendientesInternas INT =
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

    DECLARE @PendientesExternas INT =
    (
        SELECT COUNT(*)
        FROM dbo.Actividad AS actual
        INNER JOIN dbo.Actividad_Flujo_Paso_Dependencia_Externa AS dependencia
            ON dependencia.IdActividadFlujoPaso = actual.IdActividadFlujoPaso
        LEFT JOIN dbo.Cat_Estado_General AS estadoDependencia
            ON estadoDependencia.IdEstadoGeneral = dependencia.IdEstadoGeneral
        WHERE actual.IdActividad = @IdActividad
          AND ISNULL(estadoDependencia.EsActivo, 1) = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.Solicitud_Persona_Area_Flujo AS asignacionRequerida
              INNER JOIN dbo.Actividad AS requerida
                  ON requerida.IdSolicitudPersonaAreaFlujo = asignacionRequerida.IdSolicitudPersonaAreaFlujo
              INNER JOIN dbo.Actividad_Flujo_Paso AS pasoRequerido
                  ON pasoRequerido.IdActividadFlujoPaso = requerida.IdActividadFlujoPaso
                 AND pasoRequerido.ClavePaso = dependencia.ClavePasoRequerido
              INNER JOIN dbo.Cat_Estado_Actividad AS estadoRequerida
                  ON estadoRequerida.IdEstadoActividad = requerida.IdEstadoActividad
                 AND estadoRequerida.Codigo = 'APROBADA'
              LEFT JOIN dbo.Cat_Estado_General AS estadoAsignacion
                  ON estadoAsignacion.IdEstadoGeneral = asignacionRequerida.IdEstadoGeneral
              LEFT JOIN dbo.Cat_Estado_General AS estadoActividad
                  ON estadoActividad.IdEstadoGeneral = requerida.IdEstadoGeneral
              WHERE asignacionRequerida.IdSolicitudPersona = actual.IdSolicitudPersona
                AND asignacionRequerida.IdActividadFlujo = dependencia.IdActividadFlujoRequerido
                AND ISNULL(estadoAsignacion.EsActivo, 1) = 1
                AND ISNULL(estadoActividad.EsActivo, 1) = 1
          )
    );

    IF @PendientesInternas > 0 OR @PendientesExternas > 0
        THROW 50331, 'La actividad esta bloqueada por una o mas actividades requeridas pendientes.', 1;
END;
GO
