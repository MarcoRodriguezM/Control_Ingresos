/*
  Ajustes de validación y visibilidad por área.
  Ejecutar en la base configurada en appsettings. No requiere recrear tablas.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Persona_Accesos_Listar
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AreasCompetentes TABLE (IdArea INT PRIMARY KEY);

    INSERT @AreasCompetentes (IdArea)
    SELECT ua.IdArea
    FROM dbo.Usuario_Area AS ua
    WHERE ua.IdUsuario = @IdUsuario
      AND ua.IdArea IS NOT NULL
      AND ISNULL(ua.IdEstadoGeneral, 1) = 1
      AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
      AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
    UNION
    SELECT ca.IdArea
    FROM dbo.Config_Aprobador_Area AS ca
    WHERE ca.IdUsuarioAprobador = @IdUsuario
      AND ca.IdArea IS NOT NULL
      AND ISNULL(ca.IdEstadoGeneral, 1) = 1
      AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
      AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()));

    SELECT p.IdPersona,
           p.NumeroDocumento,
           p.NombreCompleto,
           p.CargoFuncion,
           COALESCE(pr.NombreComercial, pr.NombreLegal, p.EmpresaTexto) AS Empresa,
           eg.Nombre AS Estado,
           CONVERT(INT, COUNT(DISTINCT spa.IdSolicitudPersonaArea)) AS CantidadAccesos
    FROM dbo.Persona AS p
    LEFT JOIN dbo.Proveedor AS pr ON pr.IdProveedor = p.IdProveedor
    LEFT JOIN dbo.Cat_Estado_General AS eg ON eg.IdEstadoGeneral = p.IdEstadoGeneral
    INNER JOIN dbo.Solicitud_Persona AS sp ON sp.IdPersona = p.IdPersona
    INNER JOIN dbo.Solicitud_Persona_Area AS spa ON spa.IdSolicitudPersona = sp.IdSolicitudPersona
    INNER JOIN @AreasCompetentes AS areaCompetente ON areaCompetente.IdArea = spa.IdArea
    GROUP BY p.IdPersona, p.NumeroDocumento, p.NombreCompleto, p.CargoFuncion,
             pr.NombreComercial, pr.NombreLegal, p.EmpresaTexto, eg.Nombre
    ORDER BY p.NombreCompleto, p.IdPersona;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Persona_Accesos_Obtener
    @IdPersona BIGINT,
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AreasCompetentes TABLE (IdArea INT PRIMARY KEY);

    INSERT @AreasCompetentes (IdArea)
    SELECT ua.IdArea
    FROM dbo.Usuario_Area AS ua
    WHERE ua.IdUsuario = @IdUsuario
      AND ua.IdArea IS NOT NULL
      AND ISNULL(ua.IdEstadoGeneral, 1) = 1
      AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
      AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
    UNION
    SELECT ca.IdArea
    FROM dbo.Config_Aprobador_Area AS ca
    WHERE ca.IdUsuarioAprobador = @IdUsuario
      AND ca.IdArea IS NOT NULL
      AND ISNULL(ca.IdEstadoGeneral, 1) = 1
      AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
      AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()));

    SELECT p.IdPersona,
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
    WHERE p.IdPersona = @IdPersona
      AND EXISTS
      (
          SELECT 1
          FROM dbo.Solicitud_Persona AS sp
          INNER JOIN dbo.Solicitud_Persona_Area AS spa ON spa.IdSolicitudPersona = sp.IdSolicitudPersona
          INNER JOIN @AreasCompetentes AS areaCompetente ON areaCompetente.IdArea = spa.IdArea
          WHERE sp.IdPersona = p.IdPersona
      );

    SELECT spa.IdSolicitudPersonaArea,
           s.IdSolicitud,
           s.NumeroSolicitud,
           s.NombreActividad,
           a.IdArea,
           a.Nombre AS Area,
           u.Nombre AS Ubicacion,
           s.FechaInicio,
           s.FechaFin,
           COALESCE(spa.RequiereAprobacion, a.RequiereAprobacion) AS RequiereAprobacion,
           estado.Nombre AS EstadoAcceso,
           estado.Codigo AS CodigoEstadoAcceso,
           CASE WHEN estado.Codigo IN ('APROBADA', 'RECHAZADA') THEN ultimaAccion.FechaDecision END AS FechaDecision,
           CASE WHEN estado.Codigo = 'RECHAZADA' THEN ultimoRechazo.Motivo
                WHEN estado.Codigo = 'APROBADA' THEN ultimaAccion.ComentarioDecision END AS ComentarioDecision
    FROM dbo.Solicitud_Persona AS sp
    INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = sp.IdSolicitud
    INNER JOIN dbo.Solicitud_Persona_Area AS spa ON spa.IdSolicitudPersona = sp.IdSolicitudPersona
    INNER JOIN @AreasCompetentes AS areaCompetente ON areaCompetente.IdArea = spa.IdArea
    LEFT JOIN dbo.Cat_Area AS a ON a.IdArea = spa.IdArea
    LEFT JOIN dbo.Cat_Ubicacion AS u ON u.IdUbicacion = s.IdUbicacion
    LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS estado ON estado.IdEstadoAprobacion = spa.IdEstadoAprobacion
    OUTER APPLY
    (
        SELECT TOP (1) aa.FechaDecision, aa.ComentarioDecision
        FROM dbo.Aprobacion_Area AS aa
        WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
        ORDER BY COALESCE(aa.FechaDecision, aa.FechaSolicitud, aa.FechaCreacion) DESC,
                 aa.IdAprobacionArea DESC
    ) AS ultimaAccion
    OUTER APPLY
    (
        SELECT TOP (1) r.Motivo
        FROM dbo.Rechazo_Area AS r
        INNER JOIN dbo.Aprobacion_Area AS aa ON aa.IdAprobacionArea = r.IdAprobacionArea
        WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
        ORDER BY COALESCE(r.FechaRechazo, r.FechaCreacion) DESC, r.IdRechazoArea DESC
    ) AS ultimoRechazo
    WHERE sp.IdPersona = @IdPersona
    ORDER BY s.FechaInicio DESC, a.Nombre;
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
    IF @CantidadEstimada IS NULL OR @CantidadEstimada < 1 THROW 50122, 'CantidadEstimada debe ser mayor que cero.', 1;
    IF NULLIF(LTRIM(RTRIM(@ContactoProveedor)), '') IS NULL THROW 50129, 'El contacto es obligatorio.', 1;
    IF NULLIF(LTRIM(RTRIM(@CorreoProveedor)), '') IS NULL OR @CorreoProveedor NOT LIKE '%_@_%._%' THROW 50119, 'El correo es obligatorio y debe tener un formato válido.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuarioSolicitante) THROW 50123, 'El usuario solicitante no existe.', 1;
    IF @IdTipoIngreso IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Ingreso WHERE IdTipoIngreso = @IdTipoIngreso) THROW 50124, 'El tipo de ingreso no existe.', 1;
    IF @IdProveedor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE IdProveedor = @IdProveedor) THROW 50126, 'El proveedor no existe.', 1;
    IF @IdAreaSolicitante IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdAreaSolicitante) THROW 50127, 'El área solicitante no existe.', 1;
    IF @IdUbicacion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Ubicacion WHERE IdUbicacion = @IdUbicacion) THROW 50128, 'La ubicación no existe.', 1;

    SET @IdEstadoSolicitud = (SELECT TOP (1) IdEstadoSolicitud FROM dbo.Cat_Estado_Solicitud WHERE Codigo = 'BORRADOR');
    IF @IdEstadoSolicitud IS NULL THROW 50118, 'No existe el estado BORRADOR.', 1;

    DECLARE @IdSolicitud BIGINT, @NumeroSolicitud VARCHAR(30);
    EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Ingreso', @IdSolicitud OUTPUT;
    SET @NumeroSolicitud = CONCAT('SOL-', RIGHT(REPLICATE('0', 10) + CONVERT(VARCHAR(20), @IdSolicitud), 10));

    INSERT dbo.Solicitud_Ingreso
    (
        IdSolicitud, NumeroSolicitud, IdTipoIngreso, IdEstadoSolicitud, FechaInicio, FechaFin,
        NombreActividad, DescripcionActividad, IdProveedor, NumeroContrato, ContactoProveedor,
        CorreoProveedor, CantidadEstimada, IdAreaSolicitante, IdUsuarioSolicitante, IdUbicacion,
        Observaciones, FechaCreacion, UsuarioCreacion
    )
    VALUES
    (
        @IdSolicitud, @NumeroSolicitud, @IdTipoIngreso, @IdEstadoSolicitud, @FechaInicio, @FechaFin,
        @NombreActividad, @DescripcionActividad, @IdProveedor, @NumeroContrato, @ContactoProveedor,
        @CorreoProveedor, @CantidadEstimada, @IdAreaSolicitante, @IdUsuarioSolicitante, @IdUbicacion,
        @Observaciones, SYSDATETIME(), @Usuario
    );

    SELECT @IdSolicitud AS IdSolicitud, @NumeroSolicitud AS NumeroSolicitud;
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
    IF @CantidadEstimada IS NULL OR @CantidadEstimada < 1 THROW 50145, 'CantidadEstimada debe ser mayor que cero.', 1;
    IF NULLIF(LTRIM(RTRIM(@ContactoProveedor)), '') IS NULL THROW 50152, 'El contacto es obligatorio.', 1;
    IF NULLIF(LTRIM(RTRIM(@CorreoProveedor)), '') IS NULL OR @CorreoProveedor NOT LIKE '%_@_%._%' THROW 50153, 'El correo es obligatorio y debe tener un formato válido.', 1;
    IF (SELECT COUNT(*) FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud) > @CantidadEstimada THROW 50154, 'La cantidad estimada no puede ser menor que las personas agregadas.', 1;
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
    INSERT @Areas (IdArea)
    SELECT DISTINCT TRY_CONVERT(INT, [value])
    FROM OPENJSON(COALESCE(@AreasJson, '[]'))
    WHERE TRY_CONVERT(INT, [value]) IS NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM @Areas) THROW 50140, 'Selecciona al menos un área para la persona.', 1;
    IF EXISTS (SELECT 1 FROM @Areas a WHERE NOT EXISTS (SELECT 1 FROM dbo.Cat_Area c WHERE c.IdArea = a.IdArea)) THROW 50136, 'Una de las áreas no existe.', 1;

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

    IF EXISTS (SELECT 1 FROM @Requerimientos r WHERE NOT EXISTS (SELECT 1 FROM dbo.Cat_Requerimiento c WHERE c.IdRequerimiento = r.IdRequerimiento)) THROW 50137, 'Uno de los requerimientos no existe.', 1;
    IF EXISTS (SELECT 1 FROM @Requerimientos r WHERE r.IdTipoAplicacion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Aplicacion_Requerimiento c WHERE c.IdTipoAplicacion = r.IdTipoAplicacion)) THROW 50138, 'Uno de los tipos de aplicación no existe.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CantidadEstimada INT;
        SELECT @CantidadEstimada = CantidadEstimada
        FROM dbo.Solicitud_Ingreso WITH (UPDLOCK, HOLDLOCK)
        WHERE IdSolicitud = @IdSolicitud;

        IF @CantidadEstimada IS NULL OR (SELECT COUNT(*) FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud) >= @CantidadEstimada
            THROW 50141, 'Ya se alcanzó la cantidad máxima de personas de la solicitud.', 1;

        DECLARE @IdSolicitudPersona BIGINT;
        EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona', @IdSolicitudPersona OUTPUT;
        INSERT dbo.Solicitud_Persona
        (
            IdSolicitudPersona, IdSolicitud, IdPersona, IdEstadoPersonaSolicitud, DatosCompletos,
            ObservacionesRevision, FechaCreacion, UsuarioCreacion
        )
        VALUES
        (
            @IdSolicitudPersona, @IdSolicitud, @IdPersona, @IdEstadoPersonaSolicitud, @DatosCompletos,
            @ObservacionesRevision, SYSDATETIME(), @Usuario
        );

        DECLARE @IdEstadoPendiente SMALLINT = (SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'PENDIENTE');
        DECLARE @IdEstadoNoRequiere SMALLINT = (SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'NO_REQUIERE');
        IF @IdEstadoPendiente IS NULL OR @IdEstadoNoRequiere IS NULL THROW 50139, 'No están configurados los estados de aprobación requeridos.', 1;

        DECLARE @IdArea INT, @IdDetalle BIGINT, @RequiereAprobacion BIT;
        DECLARE areas_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT IdArea FROM @Areas;
        OPEN areas_cursor;
        FETCH NEXT FROM areas_cursor INTO @IdArea;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @RequiereAprobacion = COALESCE(RequiereAprobacion, 0) FROM dbo.Cat_Area WHERE IdArea = @IdArea;
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
        END
        CLOSE areas_cursor;
        DEALLOCATE areas_cursor;

        DECLARE @IdReq INT, @IdTipoAplicacion SMALLINT, @Seleccionado BIT, @Configurado BIT, @Obs NVARCHAR(500);
        DECLARE req_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT IdRequerimiento, IdTipoAplicacion, Seleccionado, ConfiguradoAutomatico, Observaciones FROM @Requerimientos;
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
        END
        CLOSE req_cursor;
        DEALLOCATE req_cursor;

        COMMIT TRANSACTION;
        SELECT @IdSolicitudPersona;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Enviar
    @IdSolicitud BIGINT,
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud) THROW 50500, 'La solicitud no existe.', 1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Solicitud_Ingreso AS solicitud
        WHERE solicitud.IdSolicitud = @IdSolicitud
          AND
          (
              solicitud.IdUsuarioSolicitante = @IdUsuario
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.Usuario_Rol AS usuarioRol
                  INNER JOIN dbo.Rol AS rol ON rol.IdRol = usuarioRol.IdRol
                  WHERE usuarioRol.IdUsuario = @IdUsuario
                    AND rol.Codigo = 'ADMINISTRADOR'
              )
          )
    ) THROW 50501, 'No tienes permiso para enviar esta solicitud.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Solicitud_Ingreso AS solicitud
        INNER JOIN dbo.Cat_Estado_Solicitud AS estado ON estado.IdEstadoSolicitud = solicitud.IdEstadoSolicitud
        WHERE solicitud.IdSolicitud = @IdSolicitud
          AND estado.Codigo = 'BORRADOR'
    ) THROW 50502, 'Solo se puede enviar una solicitud en estado BORRADOR.', 1;

    DECLARE @CantidadEstimada INT, @CantidadRegistrada INT, @IdProveedor BIGINT;
    SELECT @CantidadEstimada = solicitud.CantidadEstimada,
           @IdProveedor = solicitud.IdProveedor
    FROM dbo.Solicitud_Ingreso AS solicitud
    WHERE solicitud.IdSolicitud = @IdSolicitud;
    SELECT @CantidadRegistrada = COUNT(*) FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud;

    IF @CantidadEstimada IS NULL OR @CantidadEstimada < 1 THROW 50504, 'La cantidad estimada debe ser mayor que cero.', 1;
    IF @CantidadRegistrada <> @CantidadEstimada AND NOT (@CantidadRegistrada = 0 AND @IdProveedor IS NOT NULL)
        THROW 50505, 'Debes completar la cantidad estimada de personas antes de enviar la solicitud.', 1;

    DECLARE @IdPendiente SMALLINT = (SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'PENDIENTE');
    DECLARE @IdNoRequiere SMALLINT = (SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'NO_REQUIERE');
    IF @IdPendiente IS NULL OR @IdNoRequiere IS NULL THROW 50503, 'No están configurados los estados de aprobación requeridos.', 1;

    UPDATE acceso
       SET RequiereAprobacion = calculo.RequiereAprobacion,
           IdEstadoAprobacion = CASE WHEN calculo.RequiereAprobacion = 1 THEN @IdPendiente ELSE @IdNoRequiere END,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuario
    FROM dbo.Solicitud_Persona_Area AS acceso
    INNER JOIN dbo.Solicitud_Persona AS personaSolicitud ON personaSolicitud.IdSolicitudPersona = acceso.IdSolicitudPersona
    CROSS APPLY
    (
        SELECT CONVERT(BIT, CASE WHEN EXISTS
        (
            SELECT 1
            FROM dbo.Config_Aprobador_Area AS configuracion
            WHERE configuracion.IdArea = acceso.IdArea
              AND ISNULL(configuracion.IdEstadoGeneral, 1) = 1
              AND (configuracion.FechaInicio IS NULL OR configuracion.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
              AND (configuracion.FechaFin IS NULL OR configuracion.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ) THEN 1 ELSE 0 END) AS RequiereAprobacion
    ) AS calculo
    WHERE personaSolicitud.IdSolicitud = @IdSolicitud;

    DECLARE @CodigoEstado VARCHAR(40) = CASE
        WHEN @CantidadRegistrada = 0 AND @IdProveedor IS NOT NULL THEN 'PENDIENTE_PROVEEDOR'
        WHEN EXISTS
        (
            SELECT 1
            FROM dbo.Solicitud_Persona_Area AS acceso
            INNER JOIN dbo.Solicitud_Persona AS personaSolicitud ON personaSolicitud.IdSolicitudPersona = acceso.IdSolicitudPersona
            WHERE personaSolicitud.IdSolicitud = @IdSolicitud
              AND acceso.RequiereAprobacion = 1
        ) THEN 'PENDIENTE_APROBACIONES'
        ELSE 'LISTA_INGRESO'
    END;

    UPDATE solicitud
       SET IdEstadoSolicitud = estado.IdEstadoSolicitud,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuario,
           FechaEnvioProveedor = CASE WHEN @CodigoEstado = 'PENDIENTE_PROVEEDOR' THEN SYSDATETIME() ELSE FechaEnvioProveedor END
    FROM dbo.Solicitud_Ingreso AS solicitud
    INNER JOIN dbo.Cat_Estado_Solicitud AS estado ON estado.Codigo = @CodigoEstado
    WHERE solicitud.IdSolicitud = @IdSolicitud;

    EXEC dbo.usp_Historial_Solicitud_Registrar
        @IdSolicitud, 'ESTADO_SOLICITUD', N'Solicitud enviada al flujo', @CodigoEstado, @IdUsuario;
END;
GO

COMMIT TRANSACTION;
GO
