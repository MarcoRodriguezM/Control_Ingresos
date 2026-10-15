/*
  Vinculación de empleados HTIS con solicitudes.
  Control Ingresos conserva únicamente CodigoEmpleadoHtis; los datos del empleado
  se consultan en tiempo real desde la aplicación con la conexión de HTIS.
*/
USE [Control_Ingresos_DB];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;
GO

IF COL_LENGTH('dbo.Solicitud_Persona', 'CodigoEmpleadoHtis') IS NULL
BEGIN
    ALTER TABLE dbo.Solicitud_Persona
        ADD CodigoEmpleadoHtis VARCHAR(50) NULL;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Solicitud_Persona')
      AND name = 'UX_Solicitud_Persona_EmpleadoHtis'
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_Solicitud_Persona_EmpleadoHtis
        ON dbo.Solicitud_Persona (IdSolicitud, CodigoEmpleadoHtis)
        WHERE CodigoEmpleadoHtis IS NOT NULL;
END;
GO

COMMIT TRANSACTION;
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
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuarioSolicitante) THROW 50123, 'El usuario solicitante no existe.', 1;
    IF @IdTipoIngreso IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Ingreso WHERE IdTipoIngreso = @IdTipoIngreso) THROW 50124, 'El tipo de ingreso no existe.', 1;
    IF @IdProveedor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE IdProveedor = @IdProveedor) THROW 50126, 'El proveedor no existe.', 1;
    IF @IdAreaSolicitante IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdAreaSolicitante) THROW 50127, 'El área solicitante no existe.', 1;
    IF @IdUbicacion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Ubicacion WHERE IdUbicacion = @IdUbicacion) THROW 50128, 'La ubicación no existe.', 1;

    DECLARE @CodigoTipo VARCHAR(30) =
    (
        SELECT UPPER(LTRIM(RTRIM(Codigo)))
        FROM dbo.Cat_Tipo_Ingreso
        WHERE IdTipoIngreso = @IdTipoIngreso
    );

    IF @CodigoTipo IN ('EMPLEADO', 'NUEVO_EMPLEADO') SET @IdProveedor = NULL;
    IF @CodigoTipo = 'EMPLEADO'
    BEGIN
        SET @ContactoProveedor = NULL;
        SET @CorreoProveedor = NULL;
    END
    ELSE
    BEGIN
        IF NULLIF(LTRIM(RTRIM(@ContactoProveedor)), '') IS NULL THROW 50129, 'El contacto es obligatorio.', 1;
        IF NULLIF(LTRIM(RTRIM(@CorreoProveedor)), '') IS NULL OR @CorreoProveedor NOT LIKE '%_@_%._%' THROW 50119, 'El correo es obligatorio y debe tener un formato válido.', 1;
    END;

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
    IF (SELECT COUNT(*) FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud) > @CantidadEstimada THROW 50154, 'La cantidad estimada no puede ser menor que las personas agregadas.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuarioSolicitante) THROW 50146, 'El usuario solicitante no existe.', 1;
    IF @IdTipoIngreso IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Ingreso WHERE IdTipoIngreso = @IdTipoIngreso) THROW 50147, 'El tipo de ingreso no existe.', 1;
    IF @IdEstadoSolicitud IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Solicitud WHERE IdEstadoSolicitud = @IdEstadoSolicitud) THROW 50148, 'El estado de solicitud no existe.', 1;
    IF @IdProveedor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE IdProveedor = @IdProveedor) THROW 50149, 'El proveedor no existe.', 1;
    IF @IdAreaSolicitante IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdAreaSolicitante) THROW 50150, 'El área solicitante no existe.', 1;
    IF @IdUbicacion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Ubicacion WHERE IdUbicacion = @IdUbicacion) THROW 50151, 'La ubicación no existe.', 1;

    DECLARE @CodigoTipo VARCHAR(30) =
    (
        SELECT UPPER(LTRIM(RTRIM(Codigo)))
        FROM dbo.Cat_Tipo_Ingreso
        WHERE IdTipoIngreso = @IdTipoIngreso
    );

    IF @CodigoTipo IN ('EMPLEADO', 'NUEVO_EMPLEADO') SET @IdProveedor = NULL;
    IF @CodigoTipo = 'EMPLEADO'
    BEGIN
        SET @ContactoProveedor = NULL;
        SET @CorreoProveedor = NULL;
        IF EXISTS (SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud AND IdPersona IS NOT NULL)
            THROW 50155, 'La solicitud contiene personas locales y no puede cambiarse al tipo EMPLEADO.', 1;
    END
    ELSE
    BEGIN
        IF NULLIF(LTRIM(RTRIM(@ContactoProveedor)), '') IS NULL THROW 50152, 'El contacto es obligatorio.', 1;
        IF NULLIF(LTRIM(RTRIM(@CorreoProveedor)), '') IS NULL OR @CorreoProveedor NOT LIKE '%_@_%._%' THROW 50153, 'El correo es obligatorio y debe tener un formato válido.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud AND CodigoEmpleadoHtis IS NOT NULL)
            THROW 50156, 'La solicitud contiene empleados HTIS y no puede cambiarse a un tipo de personas locales.', 1;
    END;

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
    IF NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud) THROW 50130, 'La solicitud no existe.', 1;

    DECLARE @CodigoTipo VARCHAR(30) =
    (
        SELECT UPPER(LTRIM(RTRIM(tipo.Codigo)))
        FROM dbo.Solicitud_Ingreso AS solicitud
        INNER JOIN dbo.Cat_Tipo_Ingreso AS tipo ON tipo.IdTipoIngreso = solicitud.IdTipoIngreso
        WHERE solicitud.IdSolicitud = @IdSolicitud
    );

    IF @CodigoTipo = 'EMPLEADO'
    BEGIN
        IF @IdPersona IS NOT NULL OR @CodigoEmpleadoHtis IS NULL THROW 50157, 'Selecciona un empleado válido de HTIS.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud AND CodigoEmpleadoHtis = @CodigoEmpleadoHtis) THROW 50158, 'El empleado ya pertenece a la solicitud.', 1;
    END
    ELSE
    BEGIN
        IF @IdPersona IS NULL OR @CodigoEmpleadoHtis IS NOT NULL THROW 50131, 'Selecciona una persona válida de Control Ingresos.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Persona WHERE IdPersona = @IdPersona) THROW 50131, 'La persona no existe.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud AND IdPersona = @IdPersona) THROW 50132, 'La persona ya pertenece a la solicitud.', 1;
    END;

    IF @IdEstadoPersonaSolicitud IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Persona_Solicitud WHERE IdEstadoPersonaSolicitud = @IdEstadoPersonaSolicitud) THROW 50133, 'El estado del integrante no existe.', 1;
    IF @AreasJson IS NOT NULL AND ISJSON(@AreasJson) <> 1 THROW 50134, 'AreasJson no contiene JSON válido.', 1;
    IF @RequerimientosJson IS NOT NULL AND ISJSON(@RequerimientosJson) <> 1 THROW 50135, 'RequerimientosJson no contiene JSON válido.', 1;

    DECLARE @Areas TABLE (IdArea INT PRIMARY KEY);
    INSERT @Areas (IdArea)
    SELECT DISTINCT TRY_CONVERT(INT, [value])
    FROM OPENJSON(COALESCE(@AreasJson, '[]'))
    WHERE TRY_CONVERT(INT, [value]) IS NOT NULL;
    IF NOT EXISTS (SELECT 1 FROM @Areas) THROW 50140, 'Selecciona al menos un área para el integrante.', 1;
    IF EXISTS (SELECT 1 FROM @Areas AS area WHERE NOT EXISTS (SELECT 1 FROM dbo.Cat_Area AS catalogo WHERE catalogo.IdArea = area.IdArea)) THROW 50136, 'Una de las áreas no existe.', 1;

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
    IF EXISTS (SELECT 1 FROM @Requerimientos AS requerimiento WHERE NOT EXISTS (SELECT 1 FROM dbo.Cat_Requerimiento AS catalogo WHERE catalogo.IdRequerimiento = requerimiento.IdRequerimiento)) THROW 50137, 'Uno de los requerimientos no existe.', 1;
    IF EXISTS (SELECT 1 FROM @Requerimientos AS requerimiento WHERE requerimiento.IdTipoAplicacion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Aplicacion_Requerimiento AS catalogo WHERE catalogo.IdTipoAplicacion = requerimiento.IdTipoAplicacion)) THROW 50138, 'Uno de los tipos de aplicación no existe.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CantidadEstimada INT;
        SELECT @CantidadEstimada = CantidadEstimada
        FROM dbo.Solicitud_Ingreso WITH (UPDLOCK, HOLDLOCK)
        WHERE IdSolicitud = @IdSolicitud;
        IF @CantidadEstimada IS NULL OR (SELECT COUNT(*) FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud) >= @CantidadEstimada
            THROW 50141, 'Ya se alcanzó la cantidad máxima de integrantes de la solicitud.', 1;

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
        END;
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
        END;
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

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Ingreso_Obtener
    @IdSolicitud BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT IdSolicitud, NumeroSolicitud, IdTipoIngreso, IdEstadoSolicitud, FechaInicio, FechaFin,
           NombreActividad, DescripcionActividad, IdProveedor, NumeroContrato, ContactoProveedor,
           CorreoProveedor, CantidadEstimada, IdAreaSolicitante, IdUsuarioSolicitante, IdUbicacion,
           Observaciones, FechaCreacion
    FROM dbo.Solicitud_Ingreso
    WHERE IdSolicitud = @IdSolicitud;

    SELECT
        sp.IdSolicitudPersona,
        sp.IdPersona,
        COALESCE(p.NumeroDocumento, sp.CodigoEmpleadoHtis) AS NumeroDocumento,
        p.NombreCompleto,
        sp.IdEstadoPersonaSolicitud,
        sp.DatosCompletos,
        CASE
            WHEN ISNULL(resumen.AreasRechazadas, 0) > 0 THEN 'RECHAZADA'
            WHEN ISNULL(resumen.AreasPendientes, 0) > 0 THEN 'PENDIENTE'
            WHEN ISNULL(resumen.AreasRequeridas, 0) = 0 THEN 'NO_REQUIERE'
            ELSE 'APROBADA'
        END AS CodigoEstadoAprobacion,
        CASE
            WHEN ISNULL(resumen.AreasRechazadas, 0) > 0 THEN N'Rechazada'
            WHEN ISNULL(resumen.AreasPendientes, 0) > 0 THEN N'Pendiente de aprobación'
            WHEN ISNULL(resumen.AreasRequeridas, 0) = 0 THEN N'No requiere aprobación'
            ELSE N'Aprobada'
        END AS EstadoAprobacion,
        ISNULL(resumen.AreasAprobadas, 0),
        ISNULL(resumen.AreasPendientes, 0),
        ISNULL(resumen.AreasRechazadas, 0),
        rechazos.DetalleRechazos,
        sp.CodigoEmpleadoHtis
    FROM dbo.Solicitud_Persona AS sp
    LEFT JOIN dbo.Persona AS p ON p.IdPersona = sp.IdPersona
    OUTER APPLY
    (
        SELECT
            COUNT(CASE WHEN ISNULL(spa.RequiereAprobacion, 0) = 1 THEN 1 END) AS AreasRequeridas,
            COUNT(CASE WHEN ISNULL(spa.RequiereAprobacion, 0) = 1 AND ultima.Codigo = 'APROBADA' THEN 1 END) AS AreasAprobadas,
            COUNT(CASE WHEN ISNULL(spa.RequiereAprobacion, 0) = 1 AND ultima.Codigo = 'RECHAZADA' THEN 1 END) AS AreasRechazadas,
            COUNT(CASE WHEN ISNULL(spa.RequiereAprobacion, 0) = 1 AND ISNULL(ultima.Codigo, 'PENDIENTE') NOT IN ('APROBADA', 'RECHAZADA') THEN 1 END) AS AreasPendientes
        FROM dbo.Solicitud_Persona_Area AS spa
        OUTER APPLY
        (
            SELECT TOP (1) estado.Codigo
            FROM dbo.Aprobacion_Area AS aprobacion
            LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS estado ON estado.IdEstadoAprobacion = aprobacion.IdEstadoAprobacion
            WHERE aprobacion.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
            ORDER BY COALESCE(aprobacion.FechaDecision, aprobacion.FechaSolicitud, aprobacion.FechaCreacion) DESC,
                     aprobacion.IdAprobacionArea DESC
        ) AS ultima
        WHERE spa.IdSolicitudPersona = sp.IdSolicitudPersona
    ) AS resumen
    OUTER APPLY
    (
        SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), CONCAT(COALESCE(area.Nombre, N'Área sin nombre'),
            CASE WHEN NULLIF(LTRIM(RTRIM(ultima.ComentarioDecision)), N'') IS NULL THEN N'' ELSE CONCAT(N': ', ultima.ComentarioDecision) END)), N' | ') AS DetalleRechazos
        FROM dbo.Solicitud_Persona_Area AS spa
        LEFT JOIN dbo.Cat_Area AS area ON area.IdArea = spa.IdArea
        OUTER APPLY
        (
            SELECT TOP (1) estado.Codigo, aprobacion.ComentarioDecision
            FROM dbo.Aprobacion_Area AS aprobacion
            LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS estado ON estado.IdEstadoAprobacion = aprobacion.IdEstadoAprobacion
            WHERE aprobacion.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
            ORDER BY COALESCE(aprobacion.FechaDecision, aprobacion.FechaSolicitud, aprobacion.FechaCreacion) DESC,
                     aprobacion.IdAprobacionArea DESC
        ) AS ultima
        WHERE spa.IdSolicitudPersona = sp.IdSolicitudPersona AND ultima.Codigo = 'RECHAZADA'
    ) AS rechazos
    WHERE sp.IdSolicitud = @IdSolicitud
    ORDER BY COALESCE(p.NombreCompleto, sp.CodigoEmpleadoHtis), sp.IdSolicitudPersona;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Aprobacion_Area_Listar
    @IdUsuarioAprobador VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(LTRIM(RTRIM(@IdUsuarioAprobador)), '') IS NULL THROW 50160, 'El usuario aprobador es obligatorio.', 1;

    SELECT
        spa.IdSolicitudPersonaArea,
        solicitud.IdSolicitud,
        solicitud.NumeroSolicitud,
        persona.IdPersona,
        persona.NombreCompleto AS Persona,
        COALESCE(persona.NumeroDocumento, solicitudPersona.CodigoEmpleadoHtis) AS NumeroDocumento,
        CASE WHEN solicitudPersona.CodigoEmpleadoHtis IS NOT NULL THEN N'HTIS'
             ELSE COALESCE(proveedor.NombreComercial, proveedor.NombreLegal, persona.EmpresaTexto) END AS Empresa,
        area.IdArea,
        area.Nombre AS Area,
        solicitud.NombreActividad AS Actividad,
        ubicacion.Nombre AS Ubicacion,
        solicitud.FechaInicio,
        solicitud.FechaFin,
        COALESCE(ultima.FechaSolicitud, spa.FechaCreacion) AS FechaSolicitud,
        COALESCE(ultima.IdEstadoAprobacion, pendiente.IdEstadoAprobacion) AS IdEstadoAprobacion,
        COALESCE(ultima.CodigoEstado, pendiente.Codigo) AS CodigoEstado,
        COALESCE(ultima.Estado, pendiente.Nombre, N'Pendiente') AS Estado,
        ultima.FechaDecision,
        ultima.ComentarioDecision,
        solicitudPersona.CodigoEmpleadoHtis
    FROM dbo.Solicitud_Persona_Area AS spa
    INNER JOIN dbo.Solicitud_Persona AS solicitudPersona ON solicitudPersona.IdSolicitudPersona = spa.IdSolicitudPersona
    INNER JOIN dbo.Solicitud_Ingreso AS solicitud ON solicitud.IdSolicitud = solicitudPersona.IdSolicitud
    LEFT JOIN dbo.Persona AS persona ON persona.IdPersona = solicitudPersona.IdPersona
    INNER JOIN dbo.Cat_Area AS area ON area.IdArea = spa.IdArea
    INNER JOIN dbo.Config_Aprobador_Area AS configuracion
        ON configuracion.IdArea = spa.IdArea
       AND configuracion.IdUsuarioAprobador = @IdUsuarioAprobador
       AND (configuracion.FechaInicio IS NULL OR configuracion.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
       AND (configuracion.FechaFin IS NULL OR configuracion.FechaFin >= CONVERT(DATE, SYSDATETIME()))
    LEFT JOIN dbo.Cat_Ubicacion AS ubicacion ON ubicacion.IdUbicacion = solicitud.IdUbicacion
    LEFT JOIN dbo.Proveedor AS proveedor ON proveedor.IdProveedor = persona.IdProveedor
    OUTER APPLY
    (
        SELECT TOP (1)
            aprobacion.IdEstadoAprobacion,
            estado.Codigo AS CodigoEstado,
            estado.Nombre AS Estado,
            aprobacion.FechaSolicitud,
            aprobacion.FechaDecision,
            aprobacion.ComentarioDecision
        FROM dbo.Aprobacion_Area AS aprobacion
        LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS estado ON estado.IdEstadoAprobacion = aprobacion.IdEstadoAprobacion
        WHERE aprobacion.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
          AND aprobacion.IdUsuarioAprobador = @IdUsuarioAprobador
        ORDER BY COALESCE(aprobacion.FechaDecision, aprobacion.FechaSolicitud, aprobacion.FechaCreacion) DESC,
                 aprobacion.IdAprobacionArea DESC
    ) AS ultima
    OUTER APPLY
    (
        SELECT TOP (1) IdEstadoAprobacion, Codigo, Nombre
        FROM dbo.Cat_Estado_Aprobacion_Area
        WHERE Codigo = 'PENDIENTE'
    ) AS pendiente
    WHERE COALESCE(spa.RequiereAprobacion, area.RequiereAprobacion, 0) = 1
    ORDER BY CASE WHEN COALESCE(ultima.CodigoEstado, pendiente.Codigo, 'PENDIENTE') = 'PENDIENTE' THEN 0 ELSE 1 END,
             COALESCE(ultima.FechaSolicitud, spa.FechaCreacion) DESC,
             spa.IdSolicitudPersonaArea DESC;
END;
GO
