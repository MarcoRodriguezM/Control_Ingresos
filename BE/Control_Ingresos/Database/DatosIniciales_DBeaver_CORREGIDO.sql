/*
    Carga inicial completa para Control_Ingresos_DB.

    Compatible con:
      - SQL Server Management Studio.
      - Azure Data Studio.
      - DBeaver usando "Execute SQL Script".

    Todo el contenido se envía a SQL Server como un único lote para conservar
    el alcance de variables, tablas variables y la transacción.
*/

EXEC sys.sp_executesql N'
/*
    Base de datos: Control_Ingresos_DB
    Alcance de esta carga inicial:
      - Estados generales.
      - Tipos de ingreso.
      - Ubicaciones.
      - Áreas y aprobadores.
      - Estados de solicitud y de aprobación por área.
      - Tres usuarios de demostración.
      - Tres proveedores y tres personas por proveedor.

    Fuera de alcance:
      - Requerimientos.
      - Actividades.
      - Tickets externos.
      - Solicitudes y aprobaciones transaccionales de ejemplo.

    Características:
      - El script es idempotente por Código, IdUsuario o NumeroDocumento.
      - Sincroniza Control_Secuencia con los IDs existentes antes de reservar IDs.
      - Compatible con la tabla dbo.Usuario del esquema actual.
      - No crea relaciones físicas ni FOREIGN KEY.
      - No utiliza IDENTITY.
      - Todos los IDs numéricos nuevos se obtienen mediante
        dbo.usp_ObtenerSiguienteId.
      - La autenticación y las contraseñas no forman parte de esta carga.
*/

USE [Control_Ingresos_DB];

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N''dbo.usp_ObtenerSiguienteId'', N''P'') IS NULL
        THROW 50100, ''No existe dbo.usp_ObtenerSiguienteId.'', 1;

    DECLARE @IdGenerado BIGINT;
    DECLARE @IdEstadoGeneralActivo SMALLINT;
    DECLARE @FechaActual DATETIME2(0) = SYSDATETIME();
    DECLARE @UsuarioCarga VARCHAR(50) = ''admin'';

    /* Sincroniza el generador para evitar colisiones con IDs existentes. */
    MERGE dbo.Control_Secuencia AS Destino
    USING
    (
        SELECT ''Cat_Estado_General'' AS NombreEntidad,
               ISNULL(CONVERT(BIGINT, MAX(IdEstadoGeneral)), 0) AS UltimoValor
        FROM dbo.Cat_Estado_General
        UNION ALL SELECT ''Cat_Tipo_Ingreso'', ISNULL(CONVERT(BIGINT, MAX(IdTipoIngreso)), 0) FROM dbo.Cat_Tipo_Ingreso
        UNION ALL SELECT ''Cat_Tipo_Documento'', ISNULL(CONVERT(BIGINT, MAX(IdTipoDocumento)), 0) FROM dbo.Cat_Tipo_Documento
        UNION ALL SELECT ''Cat_Ubicacion'', ISNULL(CONVERT(BIGINT, MAX(IdUbicacion)), 0) FROM dbo.Cat_Ubicacion
        UNION ALL SELECT ''Cat_Area'', ISNULL(CONVERT(BIGINT, MAX(IdArea)), 0) FROM dbo.Cat_Area
        UNION ALL SELECT ''Cat_Estado_Solicitud'', ISNULL(CONVERT(BIGINT, MAX(IdEstadoSolicitud)), 0) FROM dbo.Cat_Estado_Solicitud
        UNION ALL SELECT ''Cat_Estado_Aprobacion_Area'', ISNULL(CONVERT(BIGINT, MAX(IdEstadoAprobacion)), 0) FROM dbo.Cat_Estado_Aprobacion_Area
        UNION ALL SELECT ''Usuario_Area'', ISNULL(MAX(IdUsuarioArea), 0) FROM dbo.Usuario_Area
        UNION ALL SELECT ''Config_Aprobador_Area'', ISNULL(MAX(IdConfigAprobador), 0) FROM dbo.Config_Aprobador_Area
        UNION ALL SELECT ''Proveedor'', ISNULL(MAX(IdProveedor), 0) FROM dbo.Proveedor
        UNION ALL SELECT ''Persona'', ISNULL(MAX(IdPersona), 0) FROM dbo.Persona
    ) AS Fuente
       ON Fuente.NombreEntidad = Destino.NombreEntidad
    WHEN MATCHED AND ISNULL(Destino.UltimoValor, 0) < Fuente.UltimoValor THEN
        UPDATE SET UltimoValor = Fuente.UltimoValor,
                   FechaModificacion = @FechaActual,
                   UsuarioModificacion = @UsuarioCarga
    WHEN NOT MATCHED THEN
        INSERT (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
        VALUES (Fuente.NombreEntidad, Fuente.UltimoValor, @FechaActual, @UsuarioCarga);

    /* ============================================================
       1. ESTADO GENERAL
       ============================================================ */

    DECLARE @EstadoGeneralSeed TABLE
    (
        IdEstadoGeneral    SMALLINT      NULL,
        Codigo             VARCHAR(30)   NULL,
        Nombre             NVARCHAR(100) NULL,
        Descripcion        NVARCHAR(300) NULL,
        EsActivo           BIT           NULL,
        OrdenVisualizacion SMALLINT      NULL
    );

    INSERT INTO @EstadoGeneralSeed
    (
        Codigo, Nombre, Descripcion, EsActivo, OrdenVisualizacion
    )
    VALUES
        (''ACTIVO'',   N''Activo'',   N''Registro disponible para su uso.'',       1, 1),
        (''INACTIVO'', N''Inactivo'', N''Registro deshabilitado para nuevos usos.'', 0, 2);

    UPDATE Seed
       SET IdEstadoGeneral = Destino.IdEstadoGeneral
    FROM @EstadoGeneralSeed AS Seed
    INNER JOIN dbo.Cat_Estado_General AS Destino
        ON Destino.Codigo = Seed.Codigo;

    DECLARE @CodigoEstadoGeneral VARCHAR(30);
    WHILE EXISTS (SELECT 1 FROM @EstadoGeneralSeed WHERE IdEstadoGeneral IS NULL)
    BEGIN
        SELECT TOP (1) @CodigoEstadoGeneral = Codigo
        FROM @EstadoGeneralSeed
        WHERE IdEstadoGeneral IS NULL
        ORDER BY Codigo;

        SET @IdGenerado = NULL;

        EXEC dbo.usp_ObtenerSiguienteId
             @NombreEntidad = ''Cat_Estado_General'',
             @IdGenerado = @IdGenerado OUTPUT;

        IF @IdGenerado > 32767
            THROW 50101, ''Se agotó el rango SMALLINT de Cat_Estado_General.'', 1;

        UPDATE @EstadoGeneralSeed
           SET IdEstadoGeneral = CONVERT(SMALLINT, @IdGenerado)
         WHERE Codigo = @CodigoEstadoGeneral;
    END;

    UPDATE Destino
       SET Nombre = Seed.Nombre,
           Descripcion = Seed.Descripcion,
           EsActivo = Seed.EsActivo,
           OrdenVisualizacion = Seed.OrdenVisualizacion,
           FechaModificacion = @FechaActual,
           UsuarioModificacion = @UsuarioCarga
    FROM dbo.Cat_Estado_General AS Destino
    INNER JOIN @EstadoGeneralSeed AS Seed
        ON Seed.IdEstadoGeneral = Destino.IdEstadoGeneral;

    INSERT INTO dbo.Cat_Estado_General
    (
        IdEstadoGeneral, Codigo, Nombre, Descripcion, EsActivo,
        OrdenVisualizacion, FechaCreacion, UsuarioCreacion,
        FechaModificacion, UsuarioModificacion
    )
    SELECT
        Seed.IdEstadoGeneral, Seed.Codigo, Seed.Nombre, Seed.Descripcion,
        Seed.EsActivo, Seed.OrdenVisualizacion, @FechaActual, @UsuarioCarga,
        NULL, NULL
    FROM @EstadoGeneralSeed AS Seed
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.Cat_Estado_General AS Destino
        WHERE Destino.IdEstadoGeneral = Seed.IdEstadoGeneral
    );

    SELECT @IdEstadoGeneralActivo = IdEstadoGeneral
    FROM dbo.Cat_Estado_General
    WHERE Codigo = ''ACTIVO'';

    IF @IdEstadoGeneralActivo IS NULL
        THROW 50102, ''No fue posible determinar el estado general ACTIVO.'', 1;

    /* ============================================================
       2. TIPOS DE INGRESO
       ============================================================ */

    DECLARE @TipoIngresoSeed TABLE
    (
        IdTipoIngreso SMALLINT      NULL,
        Codigo        VARCHAR(30)   NULL,
        Nombre        NVARCHAR(100) NULL,
        Descripcion   NVARCHAR(300) NULL
    );

    INSERT INTO @TipoIngresoSeed (Codigo, Nombre, Descripcion)
    VALUES
        (''VISITA'',      N''Visita'',                  N''Ingreso temporal de una persona visitante.''),
        (''PRACTICANTE'', N''Practicante'',             N''Ingreso de una persona en práctica profesional.''),
        (''SERV_PROF'',   N''Servicios Profesionales'', N''Ingreso de personal externo para prestar servicios profesionales.''),
        (''EMPLEADO'',    N''Empleado'',                N''Ingreso de una persona empleada de la empresa.'');

    UPDATE Seed
       SET IdTipoIngreso = Destino.IdTipoIngreso
    FROM @TipoIngresoSeed AS Seed
    INNER JOIN dbo.Cat_Tipo_Ingreso AS Destino
        ON Destino.Codigo = Seed.Codigo;

    DECLARE @CodigoTipoIngreso VARCHAR(30);
    WHILE EXISTS (SELECT 1 FROM @TipoIngresoSeed WHERE IdTipoIngreso IS NULL)
    BEGIN
        SELECT TOP (1) @CodigoTipoIngreso = Codigo
        FROM @TipoIngresoSeed
        WHERE IdTipoIngreso IS NULL
        ORDER BY Codigo;

        SET @IdGenerado = NULL;
        EXEC dbo.usp_ObtenerSiguienteId
             @NombreEntidad = ''Cat_Tipo_Ingreso'',
             @IdGenerado = @IdGenerado OUTPUT;

        IF @IdGenerado > 32767
            THROW 50103, ''Se agotó el rango SMALLINT de Cat_Tipo_Ingreso.'', 1;

        UPDATE @TipoIngresoSeed
           SET IdTipoIngreso = CONVERT(SMALLINT, @IdGenerado)
         WHERE Codigo = @CodigoTipoIngreso;
    END;

    UPDATE Destino
       SET Nombre = Seed.Nombre,
           Descripcion = Seed.Descripcion,
           IdEstadoGeneral = @IdEstadoGeneralActivo,
           FechaModificacion = @FechaActual,
           UsuarioModificacion = @UsuarioCarga
    FROM dbo.Cat_Tipo_Ingreso AS Destino
    INNER JOIN @TipoIngresoSeed AS Seed
        ON Seed.IdTipoIngreso = Destino.IdTipoIngreso;

    INSERT INTO dbo.Cat_Tipo_Ingreso
    (
        IdTipoIngreso, Codigo, Nombre, Descripcion, IdEstadoGeneral,
        FechaCreacion, UsuarioCreacion, FechaModificacion, UsuarioModificacion
    )
    SELECT
        Seed.IdTipoIngreso, Seed.Codigo, Seed.Nombre, Seed.Descripcion,
        @IdEstadoGeneralActivo, @FechaActual, @UsuarioCarga, NULL, NULL
    FROM @TipoIngresoSeed AS Seed
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Cat_Tipo_Ingreso AS Destino
        WHERE Destino.IdTipoIngreso = Seed.IdTipoIngreso
    );

    /* ============================================================
       2.1. TIPOS DE DOCUMENTO
       ============================================================ */

    DECLARE @TipoDocumentoSeed TABLE
    (
        IdTipoDocumento SMALLINT      NULL,
        Codigo          VARCHAR(20)   NULL,
        Nombre          NVARCHAR(100) NULL,
        LongitudMaxima  SMALLINT      NULL
    );

    INSERT INTO @TipoDocumentoSeed (Codigo, Nombre, LongitudMaxima)
    VALUES
        (''DNI'',       N''Documento Nacional de Identificación'', 13),
        (''PASAPORTE'', N''Pasaporte'',                             30),
        (''OTRO'',      N''Otro documento'',                        60);

    UPDATE Seed
       SET IdTipoDocumento = Destino.IdTipoDocumento
    FROM @TipoDocumentoSeed AS Seed
    INNER JOIN dbo.Cat_Tipo_Documento AS Destino
        ON Destino.Codigo = Seed.Codigo;

    DECLARE @CodigoTipoDocumento VARCHAR(20);
    WHILE EXISTS (SELECT 1 FROM @TipoDocumentoSeed WHERE IdTipoDocumento IS NULL)
    BEGIN
        SELECT TOP (1) @CodigoTipoDocumento = Codigo
        FROM @TipoDocumentoSeed
        WHERE IdTipoDocumento IS NULL
        ORDER BY Codigo;

        SET @IdGenerado = NULL;
        EXEC dbo.usp_ObtenerSiguienteId
             @NombreEntidad = ''Cat_Tipo_Documento'',
             @IdGenerado = @IdGenerado OUTPUT;

        IF @IdGenerado > 32767
            THROW 50108, ''Se agotó el rango SMALLINT de Cat_Tipo_Documento.'', 1;

        UPDATE @TipoDocumentoSeed
           SET IdTipoDocumento = CONVERT(SMALLINT, @IdGenerado)
         WHERE Codigo = @CodigoTipoDocumento;
    END;

    UPDATE Destino
       SET Nombre = Seed.Nombre,
           LongitudMaxima = Seed.LongitudMaxima,
           IdEstadoGeneral = @IdEstadoGeneralActivo,
           FechaModificacion = @FechaActual,
           UsuarioModificacion = @UsuarioCarga
    FROM dbo.Cat_Tipo_Documento AS Destino
    INNER JOIN @TipoDocumentoSeed AS Seed
        ON Seed.IdTipoDocumento = Destino.IdTipoDocumento;

    INSERT INTO dbo.Cat_Tipo_Documento
    (
        IdTipoDocumento, Codigo, Nombre, LongitudMaxima, IdEstadoGeneral,
        FechaCreacion, UsuarioCreacion, FechaModificacion, UsuarioModificacion
    )
    SELECT
        Seed.IdTipoDocumento, Seed.Codigo, Seed.Nombre, Seed.LongitudMaxima,
        @IdEstadoGeneralActivo, @FechaActual, @UsuarioCarga, NULL, NULL
    FROM @TipoDocumentoSeed AS Seed
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Cat_Tipo_Documento AS Destino
        WHERE Destino.IdTipoDocumento = Seed.IdTipoDocumento
    );

    /* ============================================================
       3. UBICACIONES
       ============================================================ */

    DECLARE @UbicacionSeed TABLE
    (
        IdUbicacion INT           NULL,
        Codigo      VARCHAR(30)   NULL,
        Nombre      NVARCHAR(150) NULL,
        Direccion   NVARCHAR(300) NULL
    );

    INSERT INTO @UbicacionSeed (Codigo, Nombre, Direccion)
    VALUES
        (''SRC'', N''Santa Rosa de Copán'', N''Santa Rosa de Copán, Copán, Honduras.''),
        (''SAM'', N''San Andrés Minas'',    N''San Andrés Minas, Copán, Honduras.'');

    UPDATE Seed
       SET IdUbicacion = Destino.IdUbicacion
    FROM @UbicacionSeed AS Seed
    INNER JOIN dbo.Cat_Ubicacion AS Destino
        ON Destino.Codigo = Seed.Codigo;

    DECLARE @CodigoUbicacion VARCHAR(30);
    WHILE EXISTS (SELECT 1 FROM @UbicacionSeed WHERE IdUbicacion IS NULL)
    BEGIN
        SELECT TOP (1) @CodigoUbicacion = Codigo
        FROM @UbicacionSeed
        WHERE IdUbicacion IS NULL
        ORDER BY Codigo;

        SET @IdGenerado = NULL;
        EXEC dbo.usp_ObtenerSiguienteId
             @NombreEntidad = ''Cat_Ubicacion'',
             @IdGenerado = @IdGenerado OUTPUT;

        IF @IdGenerado > 2147483647
            THROW 50104, ''Se agotó el rango INT de Cat_Ubicacion.'', 1;

        UPDATE @UbicacionSeed
           SET IdUbicacion = CONVERT(INT, @IdGenerado)
         WHERE Codigo = @CodigoUbicacion;
    END;

    UPDATE Destino
       SET Nombre = Seed.Nombre,
           Direccion = Seed.Direccion,
           IdEstadoGeneral = @IdEstadoGeneralActivo,
           FechaModificacion = @FechaActual,
           UsuarioModificacion = @UsuarioCarga
    FROM dbo.Cat_Ubicacion AS Destino
    INNER JOIN @UbicacionSeed AS Seed
        ON Seed.IdUbicacion = Destino.IdUbicacion;

    INSERT INTO dbo.Cat_Ubicacion
    (
        IdUbicacion, Codigo, Nombre, Direccion, IdEstadoGeneral,
        FechaCreacion, UsuarioCreacion, FechaModificacion, UsuarioModificacion
    )
    SELECT
        Seed.IdUbicacion, Seed.Codigo, Seed.Nombre, Seed.Direccion,
        @IdEstadoGeneralActivo, @FechaActual, @UsuarioCarga, NULL, NULL
    FROM @UbicacionSeed AS Seed
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Cat_Ubicacion AS Destino
        WHERE Destino.IdUbicacion = Seed.IdUbicacion
    );

    /* ============================================================
       4. ÁREAS
       ============================================================ */

    DECLARE @AreaSeed TABLE
    (
        IdArea             INT           NULL,
        Codigo             VARCHAR(30)   NULL,
        Nombre             NVARCHAR(150) NULL,
        Descripcion        NVARCHAR(300) NULL,
        RequiereAprobacion BIT           NULL,
        EsAreaResponsable  BIT           NULL
    );

    INSERT INTO @AreaSeed
    (
        Codigo, Nombre, Descripcion, RequiereAprobacion, EsAreaResponsable
    )
    VALUES
        (''INFORMATICA'',          N''Informática'',            N''Área de infraestructura y servicios tecnológicos.'', 1, 0),
        (''SERVICIOS_GENERALES'',  N''Servicios Generales'',    N''Área de servicios e instalaciones generales.'',      1, 0),
        (''SEGURIDAD_PATRIMONIAL'',N''Seguridad Patrimonial'',  N''Área responsable del control físico y patrimonial.'', 1, 0),
        (''SST'',                  N''SST'',                     N''Área de Seguridad y Salud en el Trabajo.'',           1, 0),
        (''ALMACEN'',              N''Almacén'',                 N''Área de almacenamiento y despacho.'',                 1, 0),
        (''MANTENIMIENTO'',        N''Mantenimiento'',           N''Área de mantenimiento de infraestructura y equipos.'',1, 0);

    UPDATE Seed
       SET IdArea = Destino.IdArea
    FROM @AreaSeed AS Seed
    INNER JOIN dbo.Cat_Area AS Destino
        ON Destino.Codigo = Seed.Codigo;

    DECLARE @CodigoArea VARCHAR(30);
    WHILE EXISTS (SELECT 1 FROM @AreaSeed WHERE IdArea IS NULL)
    BEGIN
        SELECT TOP (1) @CodigoArea = Codigo
        FROM @AreaSeed
        WHERE IdArea IS NULL
        ORDER BY Codigo;

        SET @IdGenerado = NULL;
        EXEC dbo.usp_ObtenerSiguienteId
             @NombreEntidad = ''Cat_Area'',
             @IdGenerado = @IdGenerado OUTPUT;

        IF @IdGenerado > 2147483647
            THROW 50105, ''Se agotó el rango INT de Cat_Area.'', 1;

        UPDATE @AreaSeed
           SET IdArea = CONVERT(INT, @IdGenerado)
         WHERE Codigo = @CodigoArea;
    END;

    UPDATE Destino
       SET Nombre = Seed.Nombre,
           Descripcion = Seed.Descripcion,
           RequiereAprobacion = Seed.RequiereAprobacion,
           EsAreaResponsable = Seed.EsAreaResponsable,
           IdEstadoGeneral = @IdEstadoGeneralActivo,
           FechaModificacion = @FechaActual,
           UsuarioModificacion = @UsuarioCarga
    FROM dbo.Cat_Area AS Destino
    INNER JOIN @AreaSeed AS Seed
        ON Seed.IdArea = Destino.IdArea;

    INSERT INTO dbo.Cat_Area
    (
        IdArea, Codigo, Nombre, Descripcion, RequiereAprobacion,
        EsAreaResponsable, IdEstadoGeneral, FechaCreacion, UsuarioCreacion,
        FechaModificacion, UsuarioModificacion
    )
    SELECT
        Seed.IdArea, Seed.Codigo, Seed.Nombre, Seed.Descripcion,
        Seed.RequiereAprobacion, Seed.EsAreaResponsable,
        @IdEstadoGeneralActivo, @FechaActual, @UsuarioCarga, NULL, NULL
    FROM @AreaSeed AS Seed
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Cat_Area AS Destino
        WHERE Destino.IdArea = Seed.IdArea
    );

    /* ============================================================
       5. ESTADOS DE SOLICITUD
       ============================================================ */

    DECLARE @EstadoSolicitudSeed TABLE
    (
        IdEstadoSolicitud SMALLINT      NULL,
        Codigo            VARCHAR(40)   NULL,
        Nombre            NVARCHAR(120) NULL,
        Descripcion       NVARCHAR(300) NULL,
        EsEstadoFinal     BIT           NULL,
        OrdenFlujo        SMALLINT      NULL
    );

    INSERT INTO @EstadoSolicitudSeed
    (
        Codigo, Nombre, Descripcion, EsEstadoFinal, OrdenFlujo
    )
    VALUES
        (''BORRADOR'',                N''Borrador'',                  N''Solicitud en preparación.'',                                0, 1),
        (''PENDIENTE_PROVEEDOR'',     N''Pendiente de proveedor'',   N''Pendiente de que el proveedor registre las personas.'',     0, 2),
        (''EN_REVISION'',             N''En revisión'',              N''Datos de personas pendientes de revisión.'',                0, 3),
        (''CONFIGURACION_ACCESOS'',   N''Configuración de accesos'', N''Asignación de áreas de acceso por persona.'',                0, 4),
        (''PENDIENTE_APROBACIONES'',  N''Pendiente de aprobaciones'',N''Existen decisiones de acceso pendientes.'',                 0, 5),
        (''LISTA_INGRESO'',           N''Lista para ingreso'',       N''Todos los accesos requeridos fueron resueltos.'',            0, 6),
        (''FINALIZADA'',              N''Finalizada'',               N''El periodo de la solicitud ha finalizado.'',                 1, 7),
        (''CANCELADA'',               N''Cancelada'',                N''La solicitud fue cancelada.'',                              1, 8);

    UPDATE Seed
       SET IdEstadoSolicitud = Destino.IdEstadoSolicitud
    FROM @EstadoSolicitudSeed AS Seed
    INNER JOIN dbo.Cat_Estado_Solicitud AS Destino
        ON Destino.Codigo = Seed.Codigo;

    DECLARE @CodigoEstadoSolicitud VARCHAR(40);
    WHILE EXISTS (SELECT 1 FROM @EstadoSolicitudSeed WHERE IdEstadoSolicitud IS NULL)
    BEGIN
        SELECT TOP (1) @CodigoEstadoSolicitud = Codigo
        FROM @EstadoSolicitudSeed
        WHERE IdEstadoSolicitud IS NULL
        ORDER BY Codigo;

        SET @IdGenerado = NULL;
        EXEC dbo.usp_ObtenerSiguienteId
             @NombreEntidad = ''Cat_Estado_Solicitud'',
             @IdGenerado = @IdGenerado OUTPUT;

        IF @IdGenerado > 32767
            THROW 50106, ''Se agotó el rango SMALLINT de Cat_Estado_Solicitud.'', 1;

        UPDATE @EstadoSolicitudSeed
           SET IdEstadoSolicitud = CONVERT(SMALLINT, @IdGenerado)
         WHERE Codigo = @CodigoEstadoSolicitud;
    END;

    UPDATE Destino
       SET Nombre = Seed.Nombre,
           Descripcion = Seed.Descripcion,
           EsEstadoFinal = Seed.EsEstadoFinal,
           OrdenFlujo = Seed.OrdenFlujo,
           IdEstadoGeneral = @IdEstadoGeneralActivo,
           FechaModificacion = @FechaActual,
           UsuarioModificacion = @UsuarioCarga
    FROM dbo.Cat_Estado_Solicitud AS Destino
    INNER JOIN @EstadoSolicitudSeed AS Seed
        ON Seed.IdEstadoSolicitud = Destino.IdEstadoSolicitud;

    INSERT INTO dbo.Cat_Estado_Solicitud
    (
        IdEstadoSolicitud, Codigo, Nombre, Descripcion, EsEstadoFinal,
        OrdenFlujo, IdEstadoGeneral, FechaCreacion, UsuarioCreacion,
        FechaModificacion, UsuarioModificacion
    )
    SELECT
        Seed.IdEstadoSolicitud, Seed.Codigo, Seed.Nombre, Seed.Descripcion,
        Seed.EsEstadoFinal, Seed.OrdenFlujo, @IdEstadoGeneralActivo,
        @FechaActual, @UsuarioCarga, NULL, NULL
    FROM @EstadoSolicitudSeed AS Seed
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Cat_Estado_Solicitud AS Destino
        WHERE Destino.IdEstadoSolicitud = Seed.IdEstadoSolicitud
    );

    /* ============================================================
       6. ESTADOS DE APROBACIÓN POR ÁREA
       ============================================================ */

    DECLARE @EstadoAprobacionSeed TABLE
    (
        IdEstadoAprobacion SMALLINT      NULL,
        Codigo             VARCHAR(30)   NULL,
        Nombre             NVARCHAR(100) NULL,
        Descripcion        NVARCHAR(300) NULL,
        EsEstadoFinal      BIT           NULL
    );

    INSERT INTO @EstadoAprobacionSeed
    (
        Codigo, Nombre, Descripcion, EsEstadoFinal
    )
    VALUES
        (''PENDIENTE'',   N''Pendiente'',              N''La aprobación todavía no ha sido resuelta.'',     0),
        (''APROBADA'',    N''Aprobada'',               N''El acceso al área fue aprobado.'',                1),
        (''RECHAZADA'',   N''Rechazada'',              N''El acceso al área fue rechazado.'',               1),
        (''NO_REQUIERE'', N''No requiere aprobación'', N''El área no necesita aprobación de supervisor.'',  1);

    UPDATE Seed
       SET IdEstadoAprobacion = Destino.IdEstadoAprobacion
    FROM @EstadoAprobacionSeed AS Seed
    INNER JOIN dbo.Cat_Estado_Aprobacion_Area AS Destino
        ON Destino.Codigo = Seed.Codigo;

    DECLARE @CodigoEstadoAprobacion VARCHAR(30);
    WHILE EXISTS (SELECT 1 FROM @EstadoAprobacionSeed WHERE IdEstadoAprobacion IS NULL)
    BEGIN
        SELECT TOP (1) @CodigoEstadoAprobacion = Codigo
        FROM @EstadoAprobacionSeed
        WHERE IdEstadoAprobacion IS NULL
        ORDER BY Codigo;

        SET @IdGenerado = NULL;
        EXEC dbo.usp_ObtenerSiguienteId
             @NombreEntidad = ''Cat_Estado_Aprobacion_Area'',
             @IdGenerado = @IdGenerado OUTPUT;

        IF @IdGenerado > 32767
            THROW 50107, ''Se agotó el rango SMALLINT de Cat_Estado_Aprobacion_Area.'', 1;

        UPDATE @EstadoAprobacionSeed
           SET IdEstadoAprobacion = CONVERT(SMALLINT, @IdGenerado)
         WHERE Codigo = @CodigoEstadoAprobacion;
    END;

    UPDATE Destino
       SET Nombre = Seed.Nombre,
           Descripcion = Seed.Descripcion,
           EsEstadoFinal = Seed.EsEstadoFinal,
           IdEstadoGeneral = @IdEstadoGeneralActivo,
           FechaModificacion = @FechaActual,
           UsuarioModificacion = @UsuarioCarga
    FROM dbo.Cat_Estado_Aprobacion_Area AS Destino
    INNER JOIN @EstadoAprobacionSeed AS Seed
        ON Seed.IdEstadoAprobacion = Destino.IdEstadoAprobacion;

    INSERT INTO dbo.Cat_Estado_Aprobacion_Area
    (
        IdEstadoAprobacion, Codigo, Nombre, Descripcion, EsEstadoFinal,
        IdEstadoGeneral, FechaCreacion, UsuarioCreacion,
        FechaModificacion, UsuarioModificacion
    )
    SELECT
        Seed.IdEstadoAprobacion, Seed.Codigo, Seed.Nombre, Seed.Descripcion,
        Seed.EsEstadoFinal, @IdEstadoGeneralActivo, @FechaActual,
        @UsuarioCarga, NULL, NULL
    FROM @EstadoAprobacionSeed AS Seed
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Cat_Estado_Aprobacion_Area AS Destino
        WHERE Destino.IdEstadoAprobacion = Seed.IdEstadoAprobacion
    );

    /* ============================================================
       7. USUARIOS DE DEMOSTRACIÓN
       ============================================================ */

    DECLARE @UsuarioSeed TABLE
    (
        IdUsuario      VARCHAR(50)   NOT NULL,
        NombreCompleto NVARCHAR(200) NULL,
        Correo         VARCHAR(254)  NULL,
        Telefono       VARCHAR(30)   NULL,
        Puesto         NVARCHAR(150) NULL
    );

    INSERT INTO @UsuarioSeed
    (
        IdUsuario, NombreCompleto, Correo, Telefono, Puesto
    )
    VALUES
        (''admin'',       N''Administrador Control de Ingresos'', ''admin@empresa.local'',       NULL, N''Administrador''),
        (''solicitante'', N''María González'',                    ''solicitante@empresa.local'', NULL, N''Solicitante''),
        (''aprobador'',   N''Carlos Pérez'',                      ''aprobador@empresa.local'',   NULL, N''Aprobador'');

    UPDATE Destino
       SET NombreCompleto = Seed.NombreCompleto,
           Correo = Seed.Correo,
           Telefono = Seed.Telefono,
           Puesto = Seed.Puesto,
           IdEstadoGeneral = @IdEstadoGeneralActivo,
           FechaModificacion = @FechaActual,
           UsuarioModificacion = @UsuarioCarga
    FROM dbo.Usuario AS Destino
    INNER JOIN @UsuarioSeed AS Seed
        ON Seed.IdUsuario = Destino.IdUsuario;

    INSERT INTO dbo.Usuario
    (
        IdUsuario, NombreCompleto, Correo, Telefono, Puesto,
        IdEstadoGeneral, FechaCreacion, UsuarioCreacion,
        FechaModificacion, UsuarioModificacion
    )
    SELECT
        Seed.IdUsuario, Seed.NombreCompleto, Seed.Correo, Seed.Telefono,
        Seed.Puesto, @IdEstadoGeneralActivo, @FechaActual, @UsuarioCarga,
        NULL, NULL
    FROM @UsuarioSeed AS Seed
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Usuario AS Destino
        WHERE Destino.IdUsuario = Seed.IdUsuario
    );

    /* ============================================================
       8. ASIGNACIÓN DE USUARIOS A ÁREAS
       ============================================================ */

    DECLARE @UsuarioAreaSeed TABLE
    (
        IdUsuarioArea   BIGINT      NULL,
        IdUsuario       VARCHAR(50) NULL,
        CodigoArea      VARCHAR(30) NULL,
        PuedeSolicitar  BIT         NULL,
        EsAreaPrincipal BIT         NULL
    );

    INSERT INTO @UsuarioAreaSeed
    (
        IdUsuario, CodigoArea, PuedeSolicitar, EsAreaPrincipal
    )
    VALUES
        (''admin'',       ''INFORMATICA'',         1, 1),
        (''solicitante'', ''SERVICIOS_GENERALES'', 1, 1),
        (''aprobador'',   ''INFORMATICA'',         0, 1);

    UPDATE Seed
       SET IdUsuarioArea = Destino.IdUsuarioArea
    FROM @UsuarioAreaSeed AS Seed
    INNER JOIN dbo.Cat_Area AS Area
        ON Area.Codigo = Seed.CodigoArea
    INNER JOIN dbo.Usuario_Area AS Destino
        ON Destino.IdUsuario = Seed.IdUsuario
       AND Destino.IdArea = Area.IdArea;

    DECLARE @UsuarioAreaUsuario VARCHAR(50);
    DECLARE @UsuarioAreaCodigoArea VARCHAR(30);
    WHILE EXISTS (SELECT 1 FROM @UsuarioAreaSeed WHERE IdUsuarioArea IS NULL)
    BEGIN
        SELECT TOP (1)
               @UsuarioAreaUsuario = IdUsuario,
               @UsuarioAreaCodigoArea = CodigoArea
        FROM @UsuarioAreaSeed
        WHERE IdUsuarioArea IS NULL
        ORDER BY IdUsuario, CodigoArea;

        SET @IdGenerado = NULL;
        EXEC dbo.usp_ObtenerSiguienteId
             @NombreEntidad = ''Usuario_Area'',
             @IdGenerado = @IdGenerado OUTPUT;

        UPDATE @UsuarioAreaSeed
           SET IdUsuarioArea = @IdGenerado
         WHERE IdUsuario = @UsuarioAreaUsuario
           AND CodigoArea = @UsuarioAreaCodigoArea;
    END;

    UPDATE Destino
       SET PuedeSolicitar = Seed.PuedeSolicitar,
           EsAreaPrincipal = Seed.EsAreaPrincipal,
           FechaInicio = CONVERT(DATE, @FechaActual),
           FechaFin = NULL,
           IdEstadoGeneral = @IdEstadoGeneralActivo,
           FechaModificacion = @FechaActual,
           UsuarioModificacion = @UsuarioCarga
    FROM dbo.Usuario_Area AS Destino
    INNER JOIN @UsuarioAreaSeed AS Seed
        ON Seed.IdUsuarioArea = Destino.IdUsuarioArea;

    INSERT INTO dbo.Usuario_Area
    (
        IdUsuarioArea, IdUsuario, IdArea, PuedeSolicitar,
        EsAreaPrincipal, FechaInicio, FechaFin, IdEstadoGeneral,
        FechaCreacion, UsuarioCreacion, FechaModificacion,
        UsuarioModificacion
    )
    SELECT
        Seed.IdUsuarioArea, Seed.IdUsuario, Area.IdArea,
        Seed.PuedeSolicitar, Seed.EsAreaPrincipal,
        CONVERT(DATE, @FechaActual), NULL, @IdEstadoGeneralActivo,
        @FechaActual, @UsuarioCarga, NULL, NULL
    FROM @UsuarioAreaSeed AS Seed
    INNER JOIN dbo.Cat_Area AS Area
        ON Area.Codigo = Seed.CodigoArea
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Usuario_Area AS Destino
        WHERE Destino.IdUsuarioArea = Seed.IdUsuarioArea
    );

    /* ============================================================
       9. APROBADOR DE DEMOSTRACIÓN PARA TODAS LAS ÁREAS
       ============================================================ */

    DECLARE @AprobadorAreaSeed TABLE
    (
        IdConfigAprobador  BIGINT      NULL,
        CodigoArea         VARCHAR(30) NULL,
        IdUsuarioAprobador VARCHAR(50) NULL,
        EsPrincipal        BIT         NULL
    );

    INSERT INTO @AprobadorAreaSeed
    (
        CodigoArea, IdUsuarioAprobador, EsPrincipal
    )
    SELECT Codigo, ''aprobador'', 1
    FROM @AreaSeed;

    UPDATE Seed
       SET IdConfigAprobador = Destino.IdConfigAprobador
    FROM @AprobadorAreaSeed AS Seed
    INNER JOIN dbo.Cat_Area AS Area
        ON Area.Codigo = Seed.CodigoArea
    INNER JOIN dbo.Config_Aprobador_Area AS Destino
        ON Destino.IdArea = Area.IdArea
       AND Destino.IdUsuarioAprobador = Seed.IdUsuarioAprobador;

    DECLARE @AprobadorCodigoArea VARCHAR(30);
    DECLARE @AprobadorUsuario VARCHAR(50);
    WHILE EXISTS (SELECT 1 FROM @AprobadorAreaSeed WHERE IdConfigAprobador IS NULL)
    BEGIN
        SELECT TOP (1)
               @AprobadorCodigoArea = CodigoArea,
               @AprobadorUsuario = IdUsuarioAprobador
        FROM @AprobadorAreaSeed
        WHERE IdConfigAprobador IS NULL
        ORDER BY CodigoArea, IdUsuarioAprobador;

        SET @IdGenerado = NULL;
        EXEC dbo.usp_ObtenerSiguienteId
             @NombreEntidad = ''Config_Aprobador_Area'',
             @IdGenerado = @IdGenerado OUTPUT;

        UPDATE @AprobadorAreaSeed
           SET IdConfigAprobador = @IdGenerado
         WHERE CodigoArea = @AprobadorCodigoArea
           AND IdUsuarioAprobador = @AprobadorUsuario;
    END;

    UPDATE Destino
       SET EsPrincipal = Seed.EsPrincipal,
           FechaInicio = CONVERT(DATE, @FechaActual),
           FechaFin = NULL,
           IdEstadoGeneral = @IdEstadoGeneralActivo,
           FechaModificacion = @FechaActual,
           UsuarioModificacion = @UsuarioCarga
    FROM dbo.Config_Aprobador_Area AS Destino
    INNER JOIN @AprobadorAreaSeed AS Seed
        ON Seed.IdConfigAprobador = Destino.IdConfigAprobador;

    INSERT INTO dbo.Config_Aprobador_Area
    (
        IdConfigAprobador, IdArea, IdUsuarioAprobador, EsPrincipal,
        FechaInicio, FechaFin, IdEstadoGeneral, FechaCreacion,
        UsuarioCreacion, FechaModificacion, UsuarioModificacion
    )
    SELECT
        Seed.IdConfigAprobador, Area.IdArea, Seed.IdUsuarioAprobador,
        Seed.EsPrincipal, CONVERT(DATE, @FechaActual), NULL,
        @IdEstadoGeneralActivo, @FechaActual, @UsuarioCarga, NULL, NULL
    FROM @AprobadorAreaSeed AS Seed
    INNER JOIN dbo.Cat_Area AS Area
        ON Area.Codigo = Seed.CodigoArea
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Config_Aprobador_Area AS Destino
        WHERE Destino.IdConfigAprobador = Seed.IdConfigAprobador
    );

    /* ============================================================
       10. PROVEEDORES DE DEMOSTRACIÓN
       ============================================================ */

    DECLARE @ProveedorSeed TABLE
    (
        IdProveedor       BIGINT        NULL,
        Codigo            VARCHAR(30)   NULL,
        NombreLegal       NVARCHAR(200) NULL,
        NombreComercial   NVARCHAR(200) NULL,
        RTN               VARCHAR(30)   NULL,
        ContactoPrincipal NVARCHAR(200) NULL,
        CorreoPrincipal   VARCHAR(254)  NULL,
        TelefonoPrincipal VARCHAR(30)   NULL
    );

    INSERT INTO @ProveedorSeed
    (
        Codigo, NombreLegal, NombreComercial, RTN, ContactoPrincipal,
        CorreoPrincipal, TelefonoPrincipal
    )
    VALUES
        (''PROV-001'', N''TechServices Honduras, S. de R.L.'', N''TechServices Honduras'',
         ''08019024567891'', N''Ricardo Núñez'', ''ricardo.nunez@techservices.test'', ''+504 2234-1001''),
        (''PROV-002'', N''Proyectos Mineros del Occidente, S.A.'', N''Proyectos Mineros del Occidente'',
         ''04019021234567'', N''Andrea Pineda'', ''andrea.pineda@pmo.test'', ''+504 2662-2002''),
        (''PROV-003'', N''Servicios Industriales Copán, S. de R.L.'', N''Servicios Industriales Copán'',
         ''04119029876543'', N''Fernando López'', ''fernando.lopez@sic.test'', ''+504 2662-3003'');

    UPDATE Seed
       SET IdProveedor = Destino.IdProveedor
    FROM @ProveedorSeed AS Seed
    INNER JOIN dbo.Proveedor AS Destino
        ON Destino.Codigo = Seed.Codigo;

    DECLARE @CodigoProveedor VARCHAR(30);
    WHILE EXISTS (SELECT 1 FROM @ProveedorSeed WHERE IdProveedor IS NULL)
    BEGIN
        SELECT TOP (1) @CodigoProveedor = Codigo
        FROM @ProveedorSeed
        WHERE IdProveedor IS NULL
        ORDER BY Codigo;

        SET @IdGenerado = NULL;
        EXEC dbo.usp_ObtenerSiguienteId
             @NombreEntidad = ''Proveedor'',
             @IdGenerado = @IdGenerado OUTPUT;

        UPDATE @ProveedorSeed
           SET IdProveedor = @IdGenerado
         WHERE Codigo = @CodigoProveedor;
    END;

    UPDATE Destino
       SET NombreLegal = Seed.NombreLegal,
           NombreComercial = Seed.NombreComercial,
           RTN = Seed.RTN,
           ContactoPrincipal = Seed.ContactoPrincipal,
           CorreoPrincipal = Seed.CorreoPrincipal,
           TelefonoPrincipal = Seed.TelefonoPrincipal,
           IdEstadoGeneral = @IdEstadoGeneralActivo,
           FechaModificacion = @FechaActual,
           UsuarioModificacion = @UsuarioCarga
    FROM dbo.Proveedor AS Destino
    INNER JOIN @ProveedorSeed AS Seed
        ON Seed.IdProveedor = Destino.IdProveedor;

    INSERT INTO dbo.Proveedor
    (
        IdProveedor, Codigo, NombreLegal, NombreComercial, RTN,
        ContactoPrincipal, CorreoPrincipal, TelefonoPrincipal,
        IdEstadoGeneral, FechaCreacion, UsuarioCreacion,
        FechaModificacion, UsuarioModificacion
    )
    SELECT
        Seed.IdProveedor, Seed.Codigo, Seed.NombreLegal,
        Seed.NombreComercial, Seed.RTN, Seed.ContactoPrincipal,
        Seed.CorreoPrincipal, Seed.TelefonoPrincipal,
        @IdEstadoGeneralActivo, @FechaActual, @UsuarioCarga, NULL, NULL
    FROM @ProveedorSeed AS Seed
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Proveedor AS Destino
        WHERE Destino.IdProveedor = Seed.IdProveedor
    );

    /* ============================================================
       11. TRES PERSONAS POR PROVEEDOR
       ============================================================ */

    DECLARE @PersonaSeed TABLE
    (
        IdPersona          BIGINT         NULL,
        CodigoProveedor    VARCHAR(30)    NULL,
        NumeroDocumento    VARCHAR(60)    NULL,
        NombreCompleto     NVARCHAR(200)  NULL,
        Telefono           VARCHAR(30)    NULL,
        Correo             VARCHAR(254)   NULL,
        CargoFuncion       NVARCHAR(150)  NULL,
        InformacionAdicional NVARCHAR(1000) NULL
    );

    INSERT INTO @PersonaSeed
    (
        CodigoProveedor, NumeroDocumento, NombreCompleto, Telefono,
        Correo, CargoFuncion, InformacionAdicional
    )
    VALUES
        (''PROV-001'', ''0801-1992-14567'', N''Juan Pérez'',      ''+504 9901-1001'', ''juan.perez@techservices.test'',    N''Técnico eléctrico'', N''Persona ficticia para pruebas.''),
        (''PROV-001'', ''0801-1995-08742'', N''Ana López'',       ''+504 9901-1002'', ''ana.lopez@techservices.test'',     N''Especialista IT'',   N''Persona ficticia para pruebas.''),
        (''PROV-001'', ''0801-1988-22031'', N''Carlos Martínez'', ''+504 9901-1003'', ''carlos.martinez@techservices.test'',N''Supervisor'',       N''Persona ficticia para pruebas.''),
        (''PROV-002'', ''0401-1990-03124'', N''Laura Mejía'',     ''+504 9902-2001'', ''laura.mejia@pmo.test'',            N''Ingeniera civil'',   N''Persona ficticia para pruebas.''),
        (''PROV-002'', ''0401-1987-12560'', N''Diego Hernández'', ''+504 9902-2002'', ''diego.hernandez@pmo.test'',        N''Inspector de seguridad'', N''Persona ficticia para pruebas.''),
        (''PROV-002'', ''0401-1996-20815'', N''Sofía Rodríguez'', ''+504 9902-2003'', ''sofia.rodriguez@pmo.test'',        N''Topógrafa'',         N''Persona ficticia para pruebas.''),
        (''PROV-003'', ''0411-1989-01987'', N''José García'',     ''+504 9903-3001'', ''jose.garcia@sic.test'',            N''Mecánico industrial'', N''Persona ficticia para pruebas.''),
        (''PROV-003'', ''0411-1993-17420'', N''Daniela Flores'',  ''+504 9903-3002'', ''daniela.flores@sic.test'',         N''Técnica en soldadura'', N''Persona ficticia para pruebas.''),
        (''PROV-003'', ''0411-1998-25136'', N''Miguel Santos'',   ''+504 9903-3003'', ''miguel.santos@sic.test'',          N''Auxiliar de almacén'', N''Persona ficticia para pruebas.'');

    UPDATE Seed
       SET IdPersona = Destino.IdPersona
    FROM @PersonaSeed AS Seed
    INNER JOIN dbo.Persona AS Destino
        ON Destino.NumeroDocumento = Seed.NumeroDocumento;

    DECLARE @NumeroDocumento VARCHAR(60);
    WHILE EXISTS (SELECT 1 FROM @PersonaSeed WHERE IdPersona IS NULL)
    BEGIN
        SELECT TOP (1) @NumeroDocumento = NumeroDocumento
        FROM @PersonaSeed
        WHERE IdPersona IS NULL
        ORDER BY NumeroDocumento;

        SET @IdGenerado = NULL;
        EXEC dbo.usp_ObtenerSiguienteId
             @NombreEntidad = ''Persona'',
             @IdGenerado = @IdGenerado OUTPUT;

        UPDATE @PersonaSeed
           SET IdPersona = @IdGenerado
         WHERE NumeroDocumento = @NumeroDocumento;
    END;

    UPDATE Destino
       SET NombreCompleto = Seed.NombreCompleto,
           Telefono = Seed.Telefono,
           Correo = Seed.Correo,
           CargoFuncion = Seed.CargoFuncion,
           IdProveedor = Proveedor.IdProveedor,
           EmpresaTexto = Proveedor.NombreComercial,
           InformacionAdicional = Seed.InformacionAdicional,
           IdEstadoGeneral = @IdEstadoGeneralActivo,
           FechaModificacion = @FechaActual,
           UsuarioModificacion = @UsuarioCarga
    FROM dbo.Persona AS Destino
    INNER JOIN @PersonaSeed AS Seed
        ON Seed.IdPersona = Destino.IdPersona
    INNER JOIN dbo.Proveedor AS Proveedor
        ON Proveedor.Codigo = Seed.CodigoProveedor;

    INSERT INTO dbo.Persona
    (
        IdPersona, IdTipoDocumento, NumeroDocumento, NombreCompleto,
        FotografiaUrl, Telefono, Correo, CargoFuncion, IdProveedor,
        EmpresaTexto, InformacionAdicional, IdEstadoGeneral,
        FechaCreacion, UsuarioCreacion, FechaModificacion,
        UsuarioModificacion
    )
    SELECT
        Seed.IdPersona, NULL, Seed.NumeroDocumento, Seed.NombreCompleto,
        NULL, Seed.Telefono, Seed.Correo, Seed.CargoFuncion,
        Proveedor.IdProveedor, Proveedor.NombreComercial,
        Seed.InformacionAdicional, @IdEstadoGeneralActivo,
        @FechaActual, @UsuarioCarga, NULL, NULL
    FROM @PersonaSeed AS Seed
    INNER JOIN dbo.Proveedor AS Proveedor
        ON Proveedor.Codigo = Seed.CodigoProveedor
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Persona AS Destino
        WHERE Destino.IdPersona = Seed.IdPersona
    );

    COMMIT TRANSACTION;

    /* Resumen de la carga para revisión manual. */
    SELECT ''Cat_Estado_General'' AS Tabla, COUNT(*) AS Registros
    FROM dbo.Cat_Estado_General
    WHERE Codigo IN (''ACTIVO'', ''INACTIVO'')
    UNION ALL
    SELECT ''Cat_Tipo_Ingreso'', COUNT(*)
    FROM dbo.Cat_Tipo_Ingreso
    WHERE Codigo IN (''VISITA'', ''PRACTICANTE'', ''SERV_PROF'', ''EMPLEADO'')
    UNION ALL
    SELECT ''Cat_Tipo_Documento'', COUNT(*)
    FROM dbo.Cat_Tipo_Documento
    WHERE Codigo IN (''DNI'', ''PASAPORTE'', ''OTRO'')
    UNION ALL
    SELECT ''Cat_Ubicacion'', COUNT(*)
    FROM dbo.Cat_Ubicacion
    WHERE Codigo IN (''SRC'', ''SAM'')
    UNION ALL
    SELECT ''Cat_Area'', COUNT(*)
    FROM dbo.Cat_Area
    WHERE Codigo IN
    (
        ''INFORMATICA'', ''SERVICIOS_GENERALES'', ''SEGURIDAD_PATRIMONIAL'',
        ''SST'', ''ALMACEN'', ''MANTENIMIENTO''
    )
    UNION ALL
    SELECT ''Cat_Estado_Solicitud'', COUNT(*)
    FROM dbo.Cat_Estado_Solicitud
    WHERE Codigo IN
    (
        ''BORRADOR'', ''PENDIENTE_PROVEEDOR'', ''EN_REVISION'',
        ''CONFIGURACION_ACCESOS'', ''PENDIENTE_APROBACIONES'',
        ''LISTA_INGRESO'', ''FINALIZADA'', ''CANCELADA''
    )
    UNION ALL
    SELECT ''Cat_Estado_Aprobacion_Area'', COUNT(*)
    FROM dbo.Cat_Estado_Aprobacion_Area
    WHERE Codigo IN (''PENDIENTE'', ''APROBADA'', ''RECHAZADA'', ''NO_REQUIERE'')
    UNION ALL
    SELECT ''Usuario'', COUNT(*)
    FROM dbo.Usuario
    WHERE IdUsuario IN (''admin'', ''solicitante'', ''aprobador'')
    UNION ALL
    SELECT ''Proveedor'', COUNT(*)
    FROM dbo.Proveedor
    WHERE Codigo IN (''PROV-001'', ''PROV-002'', ''PROV-003'')
    UNION ALL
    SELECT ''Persona'', COUNT(*)
    FROM dbo.Persona
    WHERE NumeroDocumento IN
    (
        ''0801-1992-14567'', ''0801-1995-08742'', ''0801-1988-22031'',
        ''0401-1990-03124'', ''0401-1987-12560'', ''0401-1996-20815'',
        ''0411-1989-01987'', ''0411-1993-17420'', ''0411-1998-25136''
    );
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
';



