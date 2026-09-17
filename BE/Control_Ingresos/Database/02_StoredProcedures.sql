USE [Control_Ingresos_DB];
GO

/*
  Capa de acceso usada por la API. Como el modelo no tiene FOREIGN KEY,
  estos procedimientos validan explícitamente las relaciones lógicas.
*/

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_Listar
    @Catalogo VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Catalogo = 'estados-generales'
        SELECT CONVERT(INT, IdEstadoGeneral), Codigo, Nombre, Descripcion FROM dbo.Cat_Estado_General WHERE ISNULL(EsActivo, 1) = 1 ORDER BY OrdenVisualizacion, Nombre;
    ELSE IF @Catalogo = 'tipos-ingreso'
        SELECT CONVERT(INT, IdTipoIngreso), Codigo, Nombre, Descripcion FROM dbo.Cat_Tipo_Ingreso WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE IF @Catalogo = 'estados-solicitud'
        SELECT CONVERT(INT, IdEstadoSolicitud), Codigo, Nombre, Descripcion FROM dbo.Cat_Estado_Solicitud WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY OrdenFlujo, Nombre;
    ELSE IF @Catalogo = 'estados-persona'
        SELECT CONVERT(INT, IdEstadoPersonaSolicitud), Codigo, Nombre, Descripcion FROM dbo.Cat_Estado_Persona_Solicitud WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE IF @Catalogo = 'tipos-documento'
        SELECT CONVERT(INT, IdTipoDocumento), Codigo, Nombre, CONVERT(NVARCHAR(300), NULL) FROM dbo.Cat_Tipo_Documento WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE IF @Catalogo = 'tipos-aplicacion'
        SELECT CONVERT(INT, IdTipoAplicacion), Codigo, Nombre, Descripcion FROM dbo.Cat_Tipo_Aplicacion_Requerimiento WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE IF @Catalogo = 'areas'
        SELECT IdArea, Codigo, Nombre, Descripcion FROM dbo.Cat_Area WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE IF @Catalogo = 'ubicaciones'
        SELECT IdUbicacion, Codigo, Nombre, Direccion FROM dbo.Cat_Ubicacion WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE IF @Catalogo = 'categorias-requerimiento'
        SELECT IdCategoriaRequerimiento, Codigo, Nombre, Descripcion FROM dbo.Cat_Categoria_Requerimiento WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY OrdenVisualizacion, Nombre;
    ELSE IF @Catalogo = 'requerimientos'
        SELECT IdRequerimiento, Codigo, Nombre, Descripcion FROM dbo.Cat_Requerimiento WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE
        THROW 50100, 'Catálogo no permitido.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Aprobacion_Area_Listar
    @IdUsuarioAprobador VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@IdUsuarioAprobador)), '') IS NULL
        THROW 50160, 'El usuario aprobador es obligatorio.', 1;

    SELECT
        spa.IdSolicitudPersonaArea,
        s.IdSolicitud,
        s.NumeroSolicitud,
        p.IdPersona,
        p.NombreCompleto AS Persona,
        p.NumeroDocumento,
        COALESCE(pr.NombreComercial, pr.NombreLegal, p.EmpresaTexto) AS Empresa,
        a.IdArea,
        a.Nombre AS Area,
        s.NombreActividad AS Actividad,
        u.Nombre AS Ubicacion,
        s.FechaInicio,
        s.FechaFin,
        COALESCE(ultima.FechaSolicitud, spa.FechaCreacion) AS FechaSolicitud,
        COALESCE(ultima.IdEstadoAprobacion, pendiente.IdEstadoAprobacion) AS IdEstadoAprobacion,
        COALESCE(ultima.CodigoEstado, pendiente.Codigo) AS CodigoEstado,
        COALESCE(ultima.Estado, pendiente.Nombre, N'Pendiente') AS Estado,
        ultima.FechaDecision,
        ultima.ComentarioDecision
    FROM dbo.Solicitud_Persona_Area AS spa
    INNER JOIN dbo.Solicitud_Persona AS sp
        ON sp.IdSolicitudPersona = spa.IdSolicitudPersona
    INNER JOIN dbo.Solicitud_Ingreso AS s
        ON s.IdSolicitud = sp.IdSolicitud
    INNER JOIN dbo.Persona AS p
        ON p.IdPersona = sp.IdPersona
    INNER JOIN dbo.Cat_Area AS a
        ON a.IdArea = spa.IdArea
    INNER JOIN dbo.Config_Aprobador_Area AS ca
        ON ca.IdArea = spa.IdArea
       AND ca.IdUsuarioAprobador = @IdUsuarioAprobador
       AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
       AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
    LEFT JOIN dbo.Cat_Ubicacion AS u
        ON u.IdUbicacion = s.IdUbicacion
    LEFT JOIN dbo.Proveedor AS pr
        ON pr.IdProveedor = p.IdProveedor
    OUTER APPLY
    (
        SELECT TOP (1)
            aa.IdEstadoAprobacion,
            ea.Codigo AS CodigoEstado,
            ea.Nombre AS Estado,
            aa.FechaSolicitud,
            aa.FechaDecision,
            aa.ComentarioDecision
        FROM dbo.Aprobacion_Area AS aa
        LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS ea
            ON ea.IdEstadoAprobacion = aa.IdEstadoAprobacion
        WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
          AND aa.IdUsuarioAprobador = @IdUsuarioAprobador
        ORDER BY COALESCE(aa.FechaDecision, aa.FechaSolicitud, aa.FechaCreacion) DESC,
                 aa.IdAprobacionArea DESC
    ) AS ultima
    OUTER APPLY
    (
        SELECT TOP (1) IdEstadoAprobacion, Codigo, Nombre
        FROM dbo.Cat_Estado_Aprobacion_Area
        WHERE Codigo = 'PENDIENTE'
    ) AS pendiente
    WHERE COALESCE(spa.RequiereAprobacion, a.RequiereAprobacion, 0) = 1
    ORDER BY
        CASE WHEN COALESCE(ultima.CodigoEstado, pendiente.Codigo, 'PENDIENTE') = 'PENDIENTE' THEN 0 ELSE 1 END,
        COALESCE(ultima.FechaSolicitud, spa.FechaCreacion) DESC,
        spa.IdSolicitudPersonaArea DESC;
END;
GO

IF OBJECT_ID('dbo.Usuario_Credencial', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Usuario_Credencial
    (
        IdUsuario           VARCHAR(50)   NOT NULL,
        PasswordHash        VARBINARY(32) NOT NULL,
        FechaCreacion       DATETIME2(0)  NOT NULL,
        UsuarioCreacion     VARCHAR(50)   NULL,
        FechaModificacion   DATETIME2(0)  NULL,
        UsuarioModificacion VARCHAR(50)   NULL,
        CONSTRAINT PK_Usuario_Credencial PRIMARY KEY (IdUsuario)
    );
END;
GO

INSERT dbo.Usuario_Credencial (IdUsuario, PasswordHash, FechaCreacion, UsuarioCreacion)
SELECT u.IdUsuario,
       HASHBYTES('SHA2_256', CONVERT(VARBINARY(MAX), CONCAT(u.IdUsuario, ':Control2026!'))),
       SYSDATETIME(),
       'sistema'
FROM dbo.Usuario AS u
WHERE u.IdUsuario IN ('admin', 'solicitante', 'aprobador')
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.Usuario_Credencial AS c
      WHERE c.IdUsuario = u.IdUsuario
  );
GO

CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Autenticar
    @Usuario VARCHAR(254),
    @Contrasena VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@Usuario)), '') IS NULL
       OR NULLIF(@Contrasena, '') IS NULL
        RETURN;

    SELECT TOP (1)
        u.IdUsuario,
        u.NombreCompleto,
        u.Correo,
        u.Puesto,
        areaPrincipal.IdArea,
        areaPrincipal.Area,
        CONVERT(BIT, CASE WHEN EXISTS
        (
            SELECT 1
            FROM dbo.Config_Aprobador_Area AS ca
            WHERE ca.IdUsuarioAprobador = u.IdUsuario
              AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
              AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ) THEN 1 ELSE 0 END) AS EsAprobador,
        CONVERT(BIT, CASE WHEN EXISTS
        (
            SELECT 1
            FROM dbo.Usuario_Area AS ua
            WHERE ua.IdUsuario = u.IdUsuario
              AND ISNULL(ua.PuedeSolicitar, 0) = 1
              AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
              AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ) THEN 1 ELSE 0 END) AS PuedeSolicitar
    FROM dbo.Usuario AS u
    INNER JOIN dbo.Usuario_Credencial AS c
        ON c.IdUsuario = u.IdUsuario
    LEFT JOIN dbo.Cat_Estado_General AS eg
        ON eg.IdEstadoGeneral = u.IdEstadoGeneral
    OUTER APPLY
    (
        SELECT TOP (1) ua.IdArea, a.Nombre AS Area
        FROM dbo.Usuario_Area AS ua
        LEFT JOIN dbo.Cat_Area AS a ON a.IdArea = ua.IdArea
        WHERE ua.IdUsuario = u.IdUsuario
          AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
          AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ORDER BY ISNULL(ua.EsAreaPrincipal, 0) DESC, ua.IdUsuarioArea
    ) AS areaPrincipal
    WHERE (u.IdUsuario = @Usuario OR u.Correo = @Usuario)
      AND c.PasswordHash = HASHBYTES('SHA2_256', CONVERT(VARBINARY(MAX), CONCAT(u.IdUsuario, ':', @Contrasena)))
      AND ISNULL(eg.EsActivo, 1) = 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Aprobacion_Area_Decidir
    @IdSolicitudPersonaArea BIGINT,
    @IdUsuarioAprobador VARCHAR(50),
    @CodigoEstado VARCHAR(30),
    @ComentarioDecision NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@IdUsuarioAprobador)), '') IS NULL
        THROW 50161, 'El usuario aprobador es obligatorio.', 1;
    IF @CodigoEstado NOT IN ('APROBADA', 'RECHAZADA')
        THROW 50162, 'La decisión debe ser APROBADA o RECHAZADA.', 1;
    IF @CodigoEstado = 'RECHAZADA' AND NULLIF(LTRIM(RTRIM(@ComentarioDecision)), '') IS NULL
        THROW 50163, 'Debes indicar el motivo del rechazo.', 1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Solicitud_Persona_Area AS spa
        INNER JOIN dbo.Config_Aprobador_Area AS ca
            ON ca.IdArea = spa.IdArea
           AND ca.IdUsuarioAprobador = @IdUsuarioAprobador
           AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
           AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        WHERE spa.IdSolicitudPersonaArea = @IdSolicitudPersonaArea
    )
        THROW 50164, 'El acceso no existe o no está asignado a este aprobador.', 1;

    DECLARE @IdEstadoAprobacion SMALLINT;
    SELECT @IdEstadoAprobacion = IdEstadoAprobacion
    FROM dbo.Cat_Estado_Aprobacion_Area
    WHERE Codigo = @CodigoEstado;

    IF @IdEstadoAprobacion IS NULL
        THROW 50165, 'El estado de aprobación no está configurado.', 1;

    DECLARE @IdAprobacionArea BIGINT;
    DECLARE @NumeroReenvio SMALLINT =
    (
        SELECT CONVERT(SMALLINT, COUNT_BIG(*))
        FROM dbo.Aprobacion_Area
        WHERE IdSolicitudPersonaArea = @IdSolicitudPersonaArea
          AND IdUsuarioAprobador = @IdUsuarioAprobador
    );

    MERGE dbo.Control_Secuencia WITH (HOLDLOCK) AS destino
    USING
    (
        SELECT 'Aprobacion_Area' AS NombreEntidad,
               ISNULL(MAX(IdAprobacionArea), 0) AS UltimoValor
        FROM dbo.Aprobacion_Area
    ) AS fuente
       ON fuente.NombreEntidad = destino.NombreEntidad
    WHEN MATCHED AND ISNULL(destino.UltimoValor, 0) < fuente.UltimoValor THEN
        UPDATE SET UltimoValor = fuente.UltimoValor,
                   FechaModificacion = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (NombreEntidad, UltimoValor, FechaModificacion)
        VALUES (fuente.NombreEntidad, fuente.UltimoValor, SYSDATETIME());

    EXEC dbo.usp_ObtenerSiguienteId 'Aprobacion_Area', @IdAprobacionArea OUTPUT;

    INSERT dbo.Aprobacion_Area
    (
        IdAprobacionArea, IdSolicitudPersonaArea, IdUsuarioAprobador,
        IdEstadoAprobacion, FechaSolicitud, FechaDecision,
        ComentarioDecision, NumeroReenvio, FechaCreacion, UsuarioCreacion
    )
    VALUES
    (
        @IdAprobacionArea, @IdSolicitudPersonaArea, @IdUsuarioAprobador,
        @IdEstadoAprobacion, SYSDATETIME(), SYSDATETIME(),
        NULLIF(LTRIM(RTRIM(@ComentarioDecision)), ''), @NumeroReenvio,
        SYSDATETIME(), @IdUsuarioAprobador
    );

    SELECT @IdAprobacionArea;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Proveedor_Crear
    @Codigo VARCHAR(30) = NULL,
    @NombreLegal NVARCHAR(200),
    @NombreComercial NVARCHAR(200) = NULL,
    @RTN VARCHAR(30) = NULL,
    @ContactoPrincipal NVARCHAR(200) = NULL,
    @CorreoPrincipal VARCHAR(254) = NULL,
    @TelefonoPrincipal VARCHAR(30) = NULL,
    @IdEstadoGeneral SMALLINT = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@NombreLegal)), '') IS NULL THROW 50101, 'NombreLegal es obligatorio.', 1;
    IF NULLIF(LTRIM(RTRIM(@Usuario)), '') IS NULL THROW 50102, 'Usuario es obligatorio.', 1;
    IF @IdEstadoGeneral IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_General WHERE IdEstadoGeneral = @IdEstadoGeneral)
        THROW 50103, 'El estado general no existe.', 1;
    IF @RTN IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Proveedor WHERE RTN = @RTN)
        THROW 50104, 'Ya existe un proveedor con ese RTN.', 1;

    DECLARE @IdProveedor BIGINT;
    EXEC dbo.usp_ObtenerSiguienteId 'Proveedor', @IdProveedor OUTPUT;
    INSERT dbo.Proveedor (IdProveedor, Codigo, NombreLegal, NombreComercial, RTN, ContactoPrincipal, CorreoPrincipal, TelefonoPrincipal, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (@IdProveedor, @Codigo, @NombreLegal, @NombreComercial, @RTN, @ContactoPrincipal, @CorreoPrincipal, @TelefonoPrincipal, @IdEstadoGeneral, SYSDATETIME(), @Usuario);
    SELECT @IdProveedor;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Persona_Crear
    @IdTipoDocumento SMALLINT = NULL,
    @NumeroDocumento VARCHAR(60),
    @NombreCompleto NVARCHAR(200),
    @FotografiaUrl NVARCHAR(500) = NULL,
    @Telefono VARCHAR(30) = NULL,
    @Correo VARCHAR(254) = NULL,
    @CargoFuncion NVARCHAR(150) = NULL,
    @IdProveedor BIGINT = NULL,
    @EmpresaTexto NVARCHAR(200) = NULL,
    @InformacionAdicional NVARCHAR(1000) = NULL,
    @IdEstadoGeneral SMALLINT = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@NumeroDocumento)), '') IS NULL THROW 50110, 'NumeroDocumento es obligatorio.', 1;
    IF NULLIF(LTRIM(RTRIM(@NombreCompleto)), '') IS NULL THROW 50111, 'NombreCompleto es obligatorio.', 1;
    IF @IdTipoDocumento IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Documento WHERE IdTipoDocumento = @IdTipoDocumento)
        THROW 50112, 'El tipo de documento no existe.', 1;
    IF @IdProveedor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE IdProveedor = @IdProveedor)
        THROW 50113, 'El proveedor no existe.', 1;
    IF @IdEstadoGeneral IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_General WHERE IdEstadoGeneral = @IdEstadoGeneral)
        THROW 50114, 'El estado general no existe.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Persona WHERE NumeroDocumento = @NumeroDocumento AND (IdTipoDocumento = @IdTipoDocumento OR (IdTipoDocumento IS NULL AND @IdTipoDocumento IS NULL)))
        THROW 50115, 'Ya existe una persona con ese tipo y número de documento.', 1;

    DECLARE @IdPersona BIGINT;
    EXEC dbo.usp_ObtenerSiguienteId 'Persona', @IdPersona OUTPUT;
    INSERT dbo.Persona (IdPersona, IdTipoDocumento, NumeroDocumento, NombreCompleto, FotografiaUrl, Telefono, Correo, CargoFuncion, IdProveedor, EmpresaTexto, InformacionAdicional, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (@IdPersona, @IdTipoDocumento, @NumeroDocumento, @NombreCompleto, @FotografiaUrl, @Telefono, @Correo, @CargoFuncion, @IdProveedor, @EmpresaTexto, @InformacionAdicional, @IdEstadoGeneral, SYSDATETIME(), @Usuario);
    SELECT @IdPersona;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Ingreso_Crear
    @IdTipoIngreso SMALLINT = NULL,
    @IdEstadoSolicitud SMALLINT = NULL,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL,
    @NombreActividad NVARCHAR(200),
    @DescripcionActividad NVARCHAR(1000) = NULL,
    @IdProveedor BIGINT = NULL,
    @NumeroContrato VARCHAR(60) = NULL,
    @ContactoProveedor NVARCHAR(200) = NULL,
    @CorreoProveedor VARCHAR(254) = NULL,
    @CantidadEstimada INT = NULL,
    @IdAreaSolicitante INT = NULL,
    @IdUsuarioSolicitante VARCHAR(50),
    @IdUbicacion INT = NULL,
    @Observaciones NVARCHAR(1000) = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@NombreActividad)), '') IS NULL THROW 50120, 'NombreActividad es obligatorio.', 1;
    IF @FechaInicio IS NOT NULL AND @FechaFin IS NOT NULL AND @FechaFin < @FechaInicio THROW 50121, 'El rango de fechas no es válido.', 1;
    IF @CantidadEstimada IS NOT NULL AND @CantidadEstimada < 0 THROW 50122, 'CantidadEstimada no puede ser negativa.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuarioSolicitante) THROW 50123, 'El usuario solicitante no existe.', 1;
    IF @IdTipoIngreso IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Ingreso WHERE IdTipoIngreso = @IdTipoIngreso) THROW 50124, 'El tipo de ingreso no existe.', 1;
    IF @IdEstadoSolicitud IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Solicitud WHERE IdEstadoSolicitud = @IdEstadoSolicitud) THROW 50125, 'El estado de solicitud no existe.', 1;
    IF @IdProveedor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE IdProveedor = @IdProveedor) THROW 50126, 'El proveedor no existe.', 1;
    IF @IdAreaSolicitante IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdAreaSolicitante) THROW 50127, 'El área solicitante no existe.', 1;
    IF @IdUbicacion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Ubicacion WHERE IdUbicacion = @IdUbicacion) THROW 50128, 'La ubicación no existe.', 1;

    DECLARE @IdSolicitud BIGINT, @NumeroSolicitud VARCHAR(30);
    EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Ingreso', @IdSolicitud OUTPUT;
    SET @NumeroSolicitud = CONCAT('SOL-', RIGHT(REPLICATE('0', 10) + CONVERT(VARCHAR(20), @IdSolicitud), 10));
    INSERT dbo.Solicitud_Ingreso (IdSolicitud, NumeroSolicitud, IdTipoIngreso, IdEstadoSolicitud, FechaInicio, FechaFin, NombreActividad, DescripcionActividad, IdProveedor, NumeroContrato, ContactoProveedor, CorreoProveedor, CantidadEstimada, IdAreaSolicitante, IdUsuarioSolicitante, IdUbicacion, Observaciones, FechaCreacion, UsuarioCreacion)
    VALUES (@IdSolicitud, @NumeroSolicitud, @IdTipoIngreso, @IdEstadoSolicitud, @FechaInicio, @FechaFin, @NombreActividad, @DescripcionActividad, @IdProveedor, @NumeroContrato, @ContactoProveedor, @CorreoProveedor, @CantidadEstimada, @IdAreaSolicitante, @IdUsuarioSolicitante, @IdUbicacion, @Observaciones, SYSDATETIME(), @Usuario);
    SELECT @IdSolicitud AS IdSolicitud, @NumeroSolicitud AS NumeroSolicitud;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Persona_Agregar
    @IdSolicitud BIGINT,
    @IdPersona BIGINT,
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
    IF NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud) THROW 50130, 'La solicitud no existe.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Persona WHERE IdPersona = @IdPersona) THROW 50131, 'La persona no existe.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud AND IdPersona = @IdPersona) THROW 50132, 'La persona ya pertenece a la solicitud.', 1;
    IF @IdEstadoPersonaSolicitud IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Persona_Solicitud WHERE IdEstadoPersonaSolicitud = @IdEstadoPersonaSolicitud) THROW 50133, 'El estado de persona no existe.', 1;
    IF @AreasJson IS NOT NULL AND ISJSON(@AreasJson) <> 1 THROW 50134, 'AreasJson no contiene JSON válido.', 1;
    IF @RequerimientosJson IS NOT NULL AND ISJSON(@RequerimientosJson) <> 1 THROW 50135, 'RequerimientosJson no contiene JSON válido.', 1;

    DECLARE @Areas TABLE (IdArea INT PRIMARY KEY);
    INSERT @Areas (IdArea) SELECT DISTINCT TRY_CONVERT(INT, [value]) FROM OPENJSON(COALESCE(@AreasJson, '[]')) WHERE TRY_CONVERT(INT, [value]) IS NOT NULL;
    IF EXISTS (SELECT 1 FROM @Areas a WHERE NOT EXISTS (SELECT 1 FROM dbo.Cat_Area c WHERE c.IdArea = a.IdArea)) THROW 50136, 'Una de las áreas no existe.', 1;

    DECLARE @Requerimientos TABLE (IdRequerimiento INT PRIMARY KEY, IdTipoAplicacion SMALLINT NULL, Seleccionado BIT NULL, ConfiguradoAutomatico BIT NULL, Observaciones NVARCHAR(500) NULL);
    INSERT @Requerimientos SELECT IdRequerimiento, IdTipoAplicacion, Seleccionado, ConfiguradoAutomatico, Observaciones
    FROM OPENJSON(COALESCE(@RequerimientosJson, '[]')) WITH (IdRequerimiento INT '$.IdRequerimiento', IdTipoAplicacion SMALLINT '$.IdTipoAplicacion', Seleccionado BIT '$.Seleccionado', ConfiguradoAutomatico BIT '$.ConfiguradoAutomatico', Observaciones NVARCHAR(500) '$.Observaciones');
    IF EXISTS (SELECT 1 FROM @Requerimientos r WHERE NOT EXISTS (SELECT 1 FROM dbo.Cat_Requerimiento c WHERE c.IdRequerimiento = r.IdRequerimiento)) THROW 50137, 'Uno de los requerimientos no existe.', 1;
    IF EXISTS (SELECT 1 FROM @Requerimientos r WHERE r.IdTipoAplicacion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Aplicacion_Requerimiento c WHERE c.IdTipoAplicacion = r.IdTipoAplicacion)) THROW 50138, 'Uno de los tipos de aplicación no existe.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @IdSolicitudPersona BIGINT;
        EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona', @IdSolicitudPersona OUTPUT;
        INSERT dbo.Solicitud_Persona (IdSolicitudPersona, IdSolicitud, IdPersona, IdEstadoPersonaSolicitud, DatosCompletos, ObservacionesRevision, FechaCreacion, UsuarioCreacion)
        VALUES (@IdSolicitudPersona, @IdSolicitud, @IdPersona, @IdEstadoPersonaSolicitud, @DatosCompletos, @ObservacionesRevision, SYSDATETIME(), @Usuario);

        DECLARE @IdArea INT, @IdDetalle BIGINT;
        DECLARE areas_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT IdArea FROM @Areas;
        OPEN areas_cursor; FETCH NEXT FROM areas_cursor INTO @IdArea;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona_Area', @IdDetalle OUTPUT;
            INSERT dbo.Solicitud_Persona_Area (IdSolicitudPersonaArea, IdSolicitudPersona, IdArea, FechaCreacion, UsuarioCreacion)
            VALUES (@IdDetalle, @IdSolicitudPersona, @IdArea, SYSDATETIME(), @Usuario);
            FETCH NEXT FROM areas_cursor INTO @IdArea;
        END
        CLOSE areas_cursor; DEALLOCATE areas_cursor;

        DECLARE @IdReq INT, @IdTipoAplicacion SMALLINT, @Seleccionado BIT, @Configurado BIT, @Obs NVARCHAR(500);
        DECLARE req_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT IdRequerimiento, IdTipoAplicacion, Seleccionado, ConfiguradoAutomatico, Observaciones FROM @Requerimientos;
        OPEN req_cursor; FETCH NEXT FROM req_cursor INTO @IdReq, @IdTipoAplicacion, @Seleccionado, @Configurado, @Obs;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona_Requerimiento', @IdDetalle OUTPUT;
            INSERT dbo.Solicitud_Persona_Requerimiento (IdSolicitudPersonaReq, IdSolicitudPersona, IdRequerimiento, IdTipoAplicacion, Seleccionado, ConfiguradoAutomatico, Observaciones, FechaCreacion, UsuarioCreacion)
            VALUES (@IdDetalle, @IdSolicitudPersona, @IdReq, @IdTipoAplicacion, @Seleccionado, @Configurado, @Obs, SYSDATETIME(), @Usuario);
            FETCH NEXT FROM req_cursor INTO @IdReq, @IdTipoAplicacion, @Seleccionado, @Configurado, @Obs;
        END
        CLOSE req_cursor; DEALLOCATE req_cursor;
        COMMIT TRANSACTION;
        SELECT @IdSolicitudPersona;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Ingreso_Actualizar
    @IdSolicitud BIGINT,
    @IdTipoIngreso SMALLINT = NULL,
    @IdEstadoSolicitud SMALLINT = NULL,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL,
    @NombreActividad NVARCHAR(200),
    @DescripcionActividad NVARCHAR(1000) = NULL,
    @IdProveedor BIGINT = NULL,
    @NumeroContrato VARCHAR(60) = NULL,
    @ContactoProveedor NVARCHAR(200) = NULL,
    @CorreoProveedor VARCHAR(254) = NULL,
    @CantidadEstimada INT = NULL,
    @IdAreaSolicitante INT = NULL,
    @IdUsuarioSolicitante VARCHAR(50),
    @IdUbicacion INT = NULL,
    @Observaciones NVARCHAR(1000) = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud) BEGIN SELECT 0; RETURN; END;
    IF NULLIF(LTRIM(RTRIM(@NombreActividad)), '') IS NULL THROW 50142, 'NombreActividad es obligatorio.', 1;
    IF NULLIF(LTRIM(RTRIM(@Usuario)), '') IS NULL THROW 50143, 'Usuario es obligatorio.', 1;
    IF @FechaInicio IS NOT NULL AND @FechaFin IS NOT NULL AND @FechaFin < @FechaInicio THROW 50144, 'El rango de fechas no es válido.', 1;
    IF @CantidadEstimada IS NOT NULL AND @CantidadEstimada < 0 THROW 50145, 'CantidadEstimada no puede ser negativa.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuarioSolicitante) THROW 50146, 'El usuario solicitante no existe.', 1;
    IF @IdTipoIngreso IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Ingreso WHERE IdTipoIngreso = @IdTipoIngreso) THROW 50147, 'El tipo de ingreso no existe.', 1;
    IF @IdEstadoSolicitud IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Solicitud WHERE IdEstadoSolicitud = @IdEstadoSolicitud) THROW 50148, 'El estado de solicitud no existe.', 1;
    IF @IdProveedor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE IdProveedor = @IdProveedor) THROW 50149, 'El proveedor no existe.', 1;
    IF @IdAreaSolicitante IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdAreaSolicitante) THROW 50150, 'El área solicitante no existe.', 1;
    IF @IdUbicacion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Ubicacion WHERE IdUbicacion = @IdUbicacion) THROW 50151, 'La ubicación no existe.', 1;

    UPDATE dbo.Solicitud_Ingreso
       SET IdTipoIngreso = @IdTipoIngreso,
           IdEstadoSolicitud = @IdEstadoSolicitud,
           FechaInicio = @FechaInicio,
           FechaFin = @FechaFin,
           NombreActividad = @NombreActividad,
           DescripcionActividad = @DescripcionActividad,
           IdProveedor = @IdProveedor,
           NumeroContrato = @NumeroContrato,
           ContactoProveedor = @ContactoProveedor,
           CorreoProveedor = @CorreoProveedor,
           CantidadEstimada = @CantidadEstimada,
           IdAreaSolicitante = @IdAreaSolicitante,
           IdUsuarioSolicitante = @IdUsuarioSolicitante,
           IdUbicacion = @IdUbicacion,
           Observaciones = @Observaciones,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @Usuario
     WHERE IdSolicitud = @IdSolicitud;
    SELECT @@ROWCOUNT;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Ingreso_Eliminar
    @IdSolicitud BIGINT,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@Usuario)), '') IS NULL THROW 50152, 'Usuario es obligatorio.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud) BEGIN SELECT 0; RETURN; END;
    IF EXISTS (SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud)
       OR EXISTS (SELECT 1 FROM dbo.Actividad WHERE IdSolicitud = @IdSolicitud)
       OR EXISTS (SELECT 1 FROM dbo.Historial_Solicitud WHERE IdSolicitud = @IdSolicitud)
        THROW 50153, 'No se puede eliminar la solicitud porque ya tiene información relacionada.', 1;

    DELETE FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud;
    SELECT @@ROWCOUNT;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Ingreso_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT s.IdSolicitud, s.NumeroSolicitud, ti.Nombre, es.Nombre, s.FechaInicio, s.FechaFin, s.NombreActividad,
           u.NombreCompleto, CONVERT(INT, COUNT(sp.IdSolicitudPersona))
    FROM dbo.Solicitud_Ingreso s
    LEFT JOIN dbo.Cat_Tipo_Ingreso ti ON ti.IdTipoIngreso = s.IdTipoIngreso
    LEFT JOIN dbo.Cat_Estado_Solicitud es ON es.IdEstadoSolicitud = s.IdEstadoSolicitud
    LEFT JOIN dbo.Usuario u ON u.IdUsuario = s.IdUsuarioSolicitante
    LEFT JOIN dbo.Solicitud_Persona sp ON sp.IdSolicitud = s.IdSolicitud
    GROUP BY s.IdSolicitud, s.NumeroSolicitud, ti.Nombre, es.Nombre, s.FechaInicio, s.FechaFin, s.NombreActividad, u.NombreCompleto, s.FechaCreacion
    ORDER BY s.FechaCreacion DESC, s.IdSolicitud DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Formulario_Datos
AS
BEGIN
    SET NOCOUNT ON;

    SELECT IdTipoIngreso, Codigo, Nombre
    FROM dbo.Cat_Tipo_Ingreso
    WHERE ISNULL(IdEstadoGeneral, 1) = 1
    ORDER BY Nombre;

    SELECT IdEstadoSolicitud, Codigo, Nombre
    FROM dbo.Cat_Estado_Solicitud
    WHERE ISNULL(IdEstadoGeneral, 1) = 1
    ORDER BY OrdenFlujo, Nombre;

    SELECT IdArea, Codigo, Nombre
    FROM dbo.Cat_Area
    WHERE ISNULL(IdEstadoGeneral, 1) = 1
    ORDER BY Nombre;

    SELECT IdUbicacion, Codigo, Nombre
    FROM dbo.Cat_Ubicacion
    WHERE ISNULL(IdEstadoGeneral, 1) = 1
    ORDER BY Nombre;

    SELECT IdProveedor, Codigo, COALESCE(NombreComercial, NombreLegal)
    FROM dbo.Proveedor
    WHERE ISNULL(IdEstadoGeneral, 1) = 1
    ORDER BY COALESCE(NombreComercial, NombreLegal);

    SELECT IdUsuario, CONVERT(VARCHAR(30), NULL), NombreCompleto
    FROM dbo.Usuario
    WHERE ISNULL(IdEstadoGeneral, 1) = 1
    ORDER BY NombreCompleto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Ingreso_Obtener
    @IdSolicitud BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdSolicitud, NumeroSolicitud, IdTipoIngreso, IdEstadoSolicitud, FechaInicio, FechaFin, NombreActividad,
           DescripcionActividad, IdProveedor, NumeroContrato, ContactoProveedor, CorreoProveedor, CantidadEstimada,
           IdAreaSolicitante, IdUsuarioSolicitante, IdUbicacion, Observaciones, FechaCreacion
    FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud;

    SELECT sp.IdSolicitudPersona, sp.IdPersona, p.NumeroDocumento, p.NombreCompleto,
           sp.IdEstadoPersonaSolicitud, sp.DatosCompletos
    FROM dbo.Solicitud_Persona sp
    LEFT JOIN dbo.Persona p ON p.IdPersona = sp.IdPersona
    WHERE sp.IdSolicitud = @IdSolicitud
    ORDER BY p.NombreCompleto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Persona_Listar
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.IdPersona,
        p.NumeroDocumento,
        p.NombreCompleto,
        p.CargoFuncion,
        COALESCE(pr.NombreComercial, pr.NombreLegal, p.EmpresaTexto) AS Empresa,
        eg.Nombre AS Estado,
        CONVERT(INT, COUNT(DISTINCT spa.IdSolicitudPersonaArea)) AS CantidadAccesos
    FROM dbo.Persona AS p
    LEFT JOIN dbo.Proveedor AS pr ON pr.IdProveedor = p.IdProveedor
    LEFT JOIN dbo.Cat_Estado_General AS eg ON eg.IdEstadoGeneral = p.IdEstadoGeneral
    LEFT JOIN dbo.Solicitud_Persona AS sp ON sp.IdPersona = p.IdPersona
    LEFT JOIN dbo.Solicitud_Persona_Area AS spa ON spa.IdSolicitudPersona = sp.IdSolicitudPersona
    GROUP BY p.IdPersona, p.NumeroDocumento, p.NombreCompleto, p.CargoFuncion,
             pr.NombreComercial, pr.NombreLegal, p.EmpresaTexto, eg.Nombre
    ORDER BY p.NombreCompleto, p.IdPersona;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Persona_Accesos_Obtener
    @IdPersona BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.IdPersona,
        p.NumeroDocumento,
        p.NombreCompleto,
        p.FotografiaUrl,
        p.Telefono,
        p.Correo,
        p.CargoFuncion,
        COALESCE(pr.NombreComercial, pr.NombreLegal, p.EmpresaTexto) AS Empresa,
        eg.Nombre AS Estado
    FROM dbo.Persona AS p
    LEFT JOIN dbo.Proveedor AS pr ON pr.IdProveedor = p.IdProveedor
    LEFT JOIN dbo.Cat_Estado_General AS eg ON eg.IdEstadoGeneral = p.IdEstadoGeneral
    WHERE p.IdPersona = @IdPersona;

    SELECT
        spa.IdSolicitudPersonaArea,
        s.IdSolicitud,
        s.NumeroSolicitud,
        s.NombreActividad,
        a.IdArea,
        a.Nombre AS Area,
        u.Nombre AS Ubicacion,
        s.FechaInicio,
        s.FechaFin,
        COALESCE(spa.RequiereAprobacion, a.RequiereAprobacion) AS RequiereAprobacion,
        COALESCE(ultimaAprobacion.EstadoAcceso,
                 CASE WHEN COALESCE(spa.RequiereAprobacion, a.RequiereAprobacion, 0) = 0
                      THEN N'No requiere aprobación' ELSE N'Pendiente' END) AS EstadoAcceso,
        ultimaAprobacion.FechaDecision,
        ultimaAprobacion.ComentarioDecision
    FROM dbo.Solicitud_Persona AS sp
    INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = sp.IdSolicitud
    INNER JOIN dbo.Solicitud_Persona_Area AS spa ON spa.IdSolicitudPersona = sp.IdSolicitudPersona
    LEFT JOIN dbo.Cat_Area AS a ON a.IdArea = spa.IdArea
    LEFT JOIN dbo.Cat_Ubicacion AS u ON u.IdUbicacion = s.IdUbicacion
    OUTER APPLY
    (
        SELECT TOP (1)
            ea.Nombre AS EstadoAcceso,
            aa.FechaDecision,
            aa.ComentarioDecision
        FROM dbo.Aprobacion_Area AS aa
        LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS ea
            ON ea.IdEstadoAprobacion = aa.IdEstadoAprobacion
        WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
        ORDER BY COALESCE(aa.FechaDecision, aa.FechaSolicitud, aa.FechaCreacion) DESC,
                 aa.IdAprobacionArea DESC
    ) AS ultimaAprobacion
    WHERE sp.IdPersona = @IdPersona
    ORDER BY s.FechaInicio DESC, a.Nombre;
END;
GO
