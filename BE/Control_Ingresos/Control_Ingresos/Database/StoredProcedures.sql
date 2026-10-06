/*
    Archivo maestro de procedimientos almacenados de Control_Ingresos_DB.
    Es idempotente: cada definición usa CREATE OR ALTER PROCEDURE.
    El backend lee este recurso al iniciar e instala únicamente procedimientos faltantes.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- dbo.OBTENER_CONSULTA_EMPLEADOS
CREATE OR ALTER PROCEDURE dbo.OBTENER_CONSULTA_EMPLEADOS
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CAST
    (
        N'
        SELECT
        E.COD_EMPLEADO,
        E.NOMBRE_COMPLETO,
        NOMBRE1,
        NOMBRE2,
        APELLIDO1,
        APELLIDO2,
        E.TIPO_SANGRE,
        C.NIT,
        E.COD_NACIONALIDAD,
        FECHA_NACIMIENTO,
        LUGAR_NACIMIENTO,
        C.COD_STATUS,
        E.EDO_CIVIL,
        E.SEXO,
        C.FECHA_INGRESO,
        C.FECHA_EGRESO,
        E_MAIL AS CORREO,
        E.TIPO_LICENCIA,
        (SELECT DESCRIPCION_N2 FROM [ORG_NIVELES] N WHERE N.CODIGO_NIVEL = C.CODIGO_NIVEL) DEPARTAMENTO,
        (SELECT DESCRIPCION_N3 FROM [ORG_NIVELES] N WHERE N.CODIGO_NIVEL = C.CODIGO_NIVEL) CARGO_NIVEL

        FROM EMPL_EMPLEADO E

        LEFT JOIN [ORG_NIVELES_PLAZA] P ON E.COD_EMPLEADO = P.COD_EMPLEADO
        LEFT JOIN EMPL_EMPLEADO_EMPR C ON C.COD_EMPLEADO = E.COD_EMPLEADO;'
        AS NVARCHAR(MAX)
    ) AS CONSULTA_SQL;
END;
GO

-- dbo.OBTENER_FOTO_EMPLEADO
CREATE OR ALTER PROCEDURE dbo.OBTENER_FOTO_EMPLEADO
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CAST
    (
        N'
        SELECT
        E.COD_EMPLEADO,
        EMPF.FOTOGRAFIA

        FROM EMPL_EMPLEADO E

        LEFT JOIN [EMPL_FOTOS] EMPF ON EMPF.COD_EMPLEADO = E.COD_EMPLEADO

        WHERE E.COD_EMPLEADO = @COD_EMPLEADO;'
        AS NVARCHAR(MAX)
    ) AS CONSULTA_SQL_FOTO;
END;
GO

-- dbo.usp_Empleado_Status_Listar
CREATE OR ALTER PROCEDURE dbo.usp_Empleado_Status_Listar
AS
BEGIN
    SET NOCOUNT ON;

    SELECT STATUS_ID,
           DESCRIPCION
    FROM dbo.Cat_Empleado_Status
    ORDER BY STATUS_ID;
END;
GO

-- dbo.usp_Actividad_Administracion_Listar
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

-- dbo.usp_Actividad_Completar
CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Completar
    @IdActividad BIGINT,
    @IdUsuarioResponsable VARCHAR(50),
    @Comentarios NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Actividad WHERE IdActividad = @IdActividad AND IdUsuarioResponsable = @IdUsuarioResponsable)
        THROW 50210, 'La actividad no existe o no estÃ¡ asignada al usuario actual.', 1;

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

-- dbo.usp_Actividad_Crear
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
        THROW 50201, 'El usuario responsable no existe o estÃ¡ inactivo.', 1;
    IF @IdSolicitud IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud)
        THROW 50202, 'La solicitud indicada no existe.', 1;
    IF @IdAreaResponsable IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdAreaResponsable)
        THROW 50203, 'El Ã¡rea responsable no existe.', 1;

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

-- dbo.usp_Actividad_Decidir
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
        THROW 50220, 'La decisiÃ³n debe ser APROBADA o RECHAZADA.', 1;
    IF @CodigoEstado = 'RECHAZADA' AND NULLIF(LTRIM(RTRIM(@ComentarioDecision)), '') IS NULL
        THROW 50221, 'Debe indicar el motivo del rechazo.', 1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Actividad a
        INNER JOIN dbo.Cat_Estado_Actividad ea ON ea.IdEstadoActividad = a.IdEstadoActividad
        WHERE a.IdActividad = @IdActividad AND ea.Codigo = 'PENDIENTE_APROBACION'
    )
        THROW 50222, 'La actividad no estÃ¡ pendiente de aprobaciÃ³n.', 1;

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

-- dbo.usp_Actividad_Mis_Listar
CREATE OR ALTER PROCEDURE dbo.usp_Actividad_Mis_Listar
    @IdUsuarioResponsable VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT a.IdActividad,
           a.IdSolicitud,
           s.NumeroSolicitud,
           a.NombreActividad,
           ar.Nombre AS AreaResponsable,
           ea.Codigo AS CodigoEstado,
           ea.Nombre AS Estado,
           CONVERT(BIT, ISNULL(ea.EsEstadoFinal, 0)) AS EsEstadoFinal,
           a.FechaLimite,
           a.FechaInicio,
           a.FechaFinalizacion,
           a.Comentarios,
           CONVERT(BIT, ISNULL(a.RequiereTicketExterno, 0)) AS RequiereTicketExterno
    FROM dbo.Actividad AS a
    LEFT JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = a.IdSolicitud
    LEFT JOIN dbo.Cat_Area AS ar ON ar.IdArea = a.IdAreaResponsable
    LEFT JOIN dbo.Cat_Estado_Actividad AS ea ON ea.IdEstadoActividad = a.IdEstadoActividad
    WHERE a.IdUsuarioResponsable = @IdUsuarioResponsable
    ORDER BY CASE WHEN ISNULL(ea.EsEstadoFinal, 0) = 0 THEN 0 ELSE 1 END,
             CASE WHEN a.FechaLimite IS NULL THEN 1 ELSE 0 END,
             a.FechaLimite,
             a.IdActividad DESC;
END;
GO

-- dbo.usp_Aprobacion_Area_Decidir
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

-- dbo.usp_Aprobacion_Area_Listar
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

-- dbo.usp_Catalogo_Listar
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

-- dbo.usp_Historial_Solicitud_Registrar
CREATE OR ALTER PROCEDURE dbo.usp_Historial_Solicitud_Registrar
    @IdSolicitud BIGINT,
    @TipoEvento VARCHAR(60),
    @Accion NVARCHAR(200),
    @Comentario NVARCHAR(1000)=NULL,
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdHistorial BIGINT;
    EXEC dbo.usp_ObtenerSiguienteId 'Historial_Solicitud',@IdHistorial OUTPUT;
    INSERT dbo.Historial_Solicitud(IdHistorialSolicitud,IdSolicitud,TipoEvento,Accion,Comentario,IdUsuarioAccion,FechaAccion,FechaCreacion,UsuarioCreacion)
    VALUES(@IdHistorial,@IdSolicitud,@TipoEvento,@Accion,@Comentario,@IdUsuario,SYSDATETIME(),SYSDATETIME(),@IdUsuario);
END;
GO

-- dbo.usp_ObtenerSiguienteId
CREATE OR ALTER PROCEDURE dbo.usp_ObtenerSiguienteId
    @NombreEntidad VARCHAR(100),
    @IdGenerado    BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@NombreEntidad)), '') IS NULL
        THROW 50001, 'El nombre de la entidad es obligatorio.', 1;

    BEGIN TRANSACTION;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Control_Secuencia WITH (UPDLOCK, HOLDLOCK)
        WHERE NombreEntidad = @NombreEntidad
    )
    BEGIN
        INSERT INTO dbo.Control_Secuencia
        (
            NombreEntidad,
            UltimoValor,
            FechaModificacion,
            UsuarioModificacion
        )
        VALUES
        (
            @NombreEntidad,
            0,
            SYSDATETIME(),
            NULL
        );
    END;

    UPDATE dbo.Control_Secuencia WITH (UPDLOCK, HOLDLOCK)
       SET UltimoValor = ISNULL(UltimoValor, 0) + 1,
           FechaModificacion = SYSDATETIME()
     WHERE NombreEntidad = @NombreEntidad;

    SELECT @IdGenerado = UltimoValor
    FROM dbo.Control_Secuencia
    WHERE NombreEntidad = @NombreEntidad;

    COMMIT TRANSACTION;
END;
GO

-- dbo.usp_Persona_Accesos_Listar
CREATE OR ALTER PROCEDURE dbo.usp_Persona_Accesos_Listar
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AccesoTotal BIT = 0;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Usuario_Rol AS ur
        INNER JOIN dbo.Rol AS r ON r.IdRol = ur.IdRol
        WHERE ur.IdUsuario = @IdUsuario
          AND UPPER(r.Codigo) IN ('ADMINISTRADOR', 'SEGURIDAD', 'AUDITOR')
    )
    BEGIN
        SET @AccesoTotal = 1;
    END;

    SELECT
        p.IdPersona,
        p.NumeroDocumento,
        p.NombreCompleto,
        p.CargoFuncion,
        COALESCE(pr.NombreComercial, pr.NombreLegal, p.EmpresaTexto) AS Empresa,
        eg.Nombre AS Estado,
        CONVERT(INT, COUNT(DISTINCT spa.IdSolicitudPersonaArea)) AS CantidadAccesos
    FROM dbo.Persona AS p
    INNER JOIN dbo.Solicitud_Persona AS sp ON sp.IdPersona = p.IdPersona
    INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = sp.IdSolicitud
    LEFT JOIN dbo.Solicitud_Persona_Area AS spa ON spa.IdSolicitudPersona = sp.IdSolicitudPersona
    LEFT JOIN dbo.Proveedor AS pr ON pr.IdProveedor = p.IdProveedor
    LEFT JOIN dbo.Cat_Estado_General AS eg ON eg.IdEstadoGeneral = p.IdEstadoGeneral
    WHERE @AccesoTotal = 1
       OR s.IdUsuarioSolicitante = @IdUsuario
       OR EXISTS
          (
              SELECT 1
              FROM dbo.Config_Aprobador_Area AS caa
              WHERE caa.IdUsuarioAprobador = @IdUsuario
                AND caa.IdArea = spa.IdArea
                AND ISNULL(caa.IdEstadoGeneral, 1) = 1
                AND (caa.FechaInicio IS NULL OR caa.FechaInicio <= GETDATE())
                AND (caa.FechaFin IS NULL OR caa.FechaFin >= GETDATE())
          )
    GROUP BY
        p.IdPersona,
        p.NumeroDocumento,
        p.NombreCompleto,
        p.CargoFuncion,
        pr.NombreComercial,
        pr.NombreLegal,
        p.EmpresaTexto,
        eg.Nombre
    ORDER BY p.NombreCompleto, p.IdPersona;
END;
GO

-- dbo.usp_Persona_Fotografia_Actualizar
CREATE OR ALTER PROCEDURE dbo.usp_Persona_Fotografia_Actualizar
    @IdPersona BIGINT,
    @FotografiaUrl NVARCHAR(500),
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Persona WHERE IdPersona = @IdPersona)
        THROW 50404, 'La persona no existe.', 1;

    IF NULLIF(LTRIM(RTRIM(@FotografiaUrl)), '') IS NULL
        THROW 50405, 'La URL de la fotografía es obligatoria.', 1;

    UPDATE dbo.Persona
    SET FotografiaUrl = LTRIM(RTRIM(@FotografiaUrl)),
        FechaModificacion = SYSDATETIME(),
        UsuarioModificacion = @Usuario
    WHERE IdPersona = @IdPersona;

    SELECT @@ROWCOUNT;
END;
GO

-- dbo.usp_Persona_Accesos_Obtener
CREATE OR ALTER PROCEDURE dbo.usp_Persona_Accesos_Obtener
    @IdPersona BIGINT,
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AccesoTotal BIT = 0;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Usuario_Rol AS ur
        INNER JOIN dbo.Rol AS r ON r.IdRol = ur.IdRol
        WHERE ur.IdUsuario = @IdUsuario
          AND UPPER(r.Codigo) IN ('ADMINISTRADOR', 'SEGURIDAD', 'AUDITOR')
    )
    BEGIN
        SET @AccesoTotal = 1;
    END;

    IF @AccesoTotal = 0
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Solicitud_Persona AS sp
           INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = sp.IdSolicitud
           LEFT JOIN dbo.Solicitud_Persona_Area AS spa
               ON spa.IdSolicitudPersona = sp.IdSolicitudPersona
           WHERE sp.IdPersona = @IdPersona
             AND
             (
                 s.IdUsuarioSolicitante = @IdUsuario
                 OR EXISTS
                    (
                        SELECT 1
                        FROM dbo.Config_Aprobador_Area AS caa
                        WHERE caa.IdUsuarioAprobador = @IdUsuario
                          AND caa.IdArea = spa.IdArea
                          AND ISNULL(caa.IdEstadoGeneral, 1) = 1
                          AND (caa.FechaInicio IS NULL OR caa.FechaInicio <= GETDATE())
                          AND (caa.FechaFin IS NULL OR caa.FechaFin >= GETDATE())
                    )
             )
       )
    BEGIN
        RETURN;
    END;

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
        COALESCE
        (
            ultimaAprobacion.EstadoAcceso,
            CASE
                WHEN COALESCE(spa.RequiereAprobacion, a.RequiereAprobacion, 0) = 0
                    THEN N'No requiere aprobaciÃ³n'
                ELSE N'Pendiente'
            END
        ) AS EstadoAcceso,
        COALESCE
        (
            ultimaAprobacion.CodigoEstadoAcceso,
            CASE
                WHEN COALESCE(spa.RequiereAprobacion, a.RequiereAprobacion, 0) = 0
                    THEN 'NO_REQUIERE'
                ELSE 'PENDIENTE'
            END
        ) AS CodigoEstadoAcceso,
        ultimaAprobacion.FechaDecision,
        ultimaAprobacion.ComentarioDecision
    FROM dbo.Solicitud_Persona AS sp
    INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = sp.IdSolicitud
    INNER JOIN dbo.Solicitud_Persona_Area AS spa
        ON spa.IdSolicitudPersona = sp.IdSolicitudPersona
    LEFT JOIN dbo.Cat_Area AS a ON a.IdArea = spa.IdArea
    LEFT JOIN dbo.Cat_Ubicacion AS u ON u.IdUbicacion = s.IdUbicacion
    OUTER APPLY
    (
        SELECT TOP (1)
            ea.Nombre AS EstadoAcceso,
            ea.Codigo AS CodigoEstadoAcceso,
            aa.FechaDecision,
            aa.ComentarioDecision
        FROM dbo.Aprobacion_Area AS aa
        LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS ea
            ON ea.IdEstadoAprobacion = aa.IdEstadoAprobacion
        WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
        ORDER BY
            COALESCE(aa.FechaDecision, aa.FechaSolicitud, aa.FechaCreacion) DESC,
            aa.IdAprobacionArea DESC
    ) AS ultimaAprobacion
    WHERE sp.IdPersona = @IdPersona
      AND
      (
          @AccesoTotal = 1
          OR s.IdUsuarioSolicitante = @IdUsuario
          OR EXISTS
             (
                 SELECT 1
                 FROM dbo.Config_Aprobador_Area AS caa
                 WHERE caa.IdUsuarioAprobador = @IdUsuario
                   AND caa.IdArea = spa.IdArea
                   AND ISNULL(caa.IdEstadoGeneral, 1) = 1
                   AND (caa.FechaInicio IS NULL OR caa.FechaInicio <= GETDATE())
                   AND (caa.FechaFin IS NULL OR caa.FechaFin >= GETDATE())
             )
      )
    ORDER BY s.FechaInicio DESC, a.Nombre;
END;
GO

-- dbo.usp_Persona_Crear
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

-- dbo.usp_Persona_Listar
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

-- dbo.usp_Persona_Qr_Consultar
CREATE OR ALTER PROCEDURE dbo.usp_Persona_Qr_Consultar
    @CodigoQr VARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdPersona BIGINT =
    (
        SELECT IdPersona
        FROM dbo.Persona
        WHERE CodigoQr = LOWER(LTRIM(RTRIM(@CodigoQr)))
    );

    IF @IdPersona IS NULL RETURN;

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
        a.IdArea,
        a.Codigo,
        a.Nombre AS Area,
        CASE
            WHEN asignacion.IdSolicitudPersonaArea IS NULL THEN 'NO_ASIGNADA'
            WHEN asignacion.CodigoAprobacion = 'RECHAZADA' THEN 'RECHAZADA'
            WHEN ISNULL(asignacion.RequiereAprobacion, 0) = 1
             AND ISNULL(asignacion.CodigoAprobacion, 'PENDIENTE') <> 'APROBADA' THEN 'PENDIENTE'
            WHEN CONVERT(DATE, GETDATE()) NOT BETWEEN asignacion.FechaInicio AND asignacion.FechaFin THEN 'NO_VIGENTE'
            WHEN asignacion.CodigoEstadoSolicitud <> 'LISTA_INGRESO' THEN 'SOLICITUD_NO_HABILITADA'
            ELSE 'AUTORIZADA'
        END AS CodigoAcceso,
        CASE
            WHEN asignacion.IdSolicitudPersonaArea IS NULL THEN N'No asignada'
            WHEN asignacion.CodigoAprobacion = 'RECHAZADA' THEN N'Rechazada'
            WHEN ISNULL(asignacion.RequiereAprobacion, 0) = 1
             AND ISNULL(asignacion.CodigoAprobacion, 'PENDIENTE') <> 'APROBADA' THEN N'Pendiente de aprobación'
            WHEN CONVERT(DATE, GETDATE()) NOT BETWEEN asignacion.FechaInicio AND asignacion.FechaFin THEN N'Fuera de vigencia'
            WHEN asignacion.CodigoEstadoSolicitud <> 'LISTA_INGRESO' THEN N'Solicitud aún no habilitada'
            ELSE N'Acceso autorizado'
        END AS EstadoAcceso,
        CONVERT(BIT, CASE
            WHEN asignacion.IdSolicitudPersonaArea IS NOT NULL
             AND ISNULL(asignacion.CodigoAprobacion,
                 CASE WHEN ISNULL(asignacion.RequiereAprobacion, 0) = 0 THEN 'APROBADA' ELSE 'PENDIENTE' END) = 'APROBADA'
             AND CONVERT(DATE, GETDATE()) BETWEEN asignacion.FechaInicio AND asignacion.FechaFin
             AND asignacion.CodigoEstadoSolicitud = 'LISTA_INGRESO'
            THEN 1 ELSE 0 END) AS TieneAcceso,
        asignacion.NumeroSolicitud,
        asignacion.NombreActividad,
        asignacion.Ubicacion,
        asignacion.FechaInicio,
        asignacion.FechaFin,
        asignacion.ComentarioDecision
    FROM dbo.Cat_Area AS a
    OUTER APPLY
    (
        SELECT TOP (1)
            spa.IdSolicitudPersonaArea,
            COALESCE(spa.RequiereAprobacion, a.RequiereAprobacion, 0) AS RequiereAprobacion,
            s.NumeroSolicitud,
            s.NombreActividad,
            u.Nombre AS Ubicacion,
            s.FechaInicio,
            s.FechaFin,
            es.Codigo AS CodigoEstadoSolicitud,
            ultima.Codigo AS CodigoAprobacion,
            ultima.ComentarioDecision
        FROM dbo.Solicitud_Persona AS sp
        INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = sp.IdSolicitud
        INNER JOIN dbo.Solicitud_Persona_Area AS spa ON spa.IdSolicitudPersona = sp.IdSolicitudPersona
        LEFT JOIN dbo.Cat_Ubicacion AS u ON u.IdUbicacion = s.IdUbicacion
        LEFT JOIN dbo.Cat_Estado_Solicitud AS es ON es.IdEstadoSolicitud = s.IdEstadoSolicitud
        OUTER APPLY
        (
            SELECT TOP (1)
                ea.Codigo,
                aa.ComentarioDecision
            FROM dbo.Aprobacion_Area AS aa
            LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS ea
                ON ea.IdEstadoAprobacion = aa.IdEstadoAprobacion
            WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
            ORDER BY COALESCE(aa.FechaDecision, aa.FechaSolicitud, aa.FechaCreacion) DESC,
                     aa.IdAprobacionArea DESC
        ) AS ultima
        WHERE sp.IdPersona = @IdPersona
          AND spa.IdArea = a.IdArea
        ORDER BY
            CASE WHEN CONVERT(DATE, GETDATE()) BETWEEN s.FechaInicio AND s.FechaFin THEN 0 ELSE 1 END,
            s.FechaFin DESC,
            s.IdSolicitud DESC
    ) AS asignacion
    WHERE ISNULL(a.IdEstadoGeneral, 1) = 1
    ORDER BY a.Nombre;
END;
GO

-- dbo.usp_Persona_Qr_Obtener
CREATE OR ALTER PROCEDURE dbo.usp_Persona_Qr_Obtener
    @IdPersona BIGINT,
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AccesoTotal BIT = 0;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Usuario_Rol AS ur
        INNER JOIN dbo.Rol AS r ON r.IdRol = ur.IdRol
        WHERE ur.IdUsuario = @IdUsuario
          AND UPPER(r.Codigo) IN ('ADMINISTRADOR', 'SEGURIDAD', 'AUDITOR')
    )
        SET @AccesoTotal = 1;

    IF @AccesoTotal = 0
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Solicitud_Persona AS sp
           INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = sp.IdSolicitud
           LEFT JOIN dbo.Solicitud_Persona_Area AS spa ON spa.IdSolicitudPersona = sp.IdSolicitudPersona
           WHERE sp.IdPersona = @IdPersona
             AND
             (
                 s.IdUsuarioSolicitante = @IdUsuario
                 OR EXISTS
                    (
                        SELECT 1
                        FROM dbo.Config_Aprobador_Area AS caa
                        WHERE caa.IdUsuarioAprobador = @IdUsuario
                          AND caa.IdArea = spa.IdArea
                          AND ISNULL(caa.IdEstadoGeneral, 1) = 1
                          AND (caa.FechaInicio IS NULL OR caa.FechaInicio <= GETDATE())
                          AND (caa.FechaFin IS NULL OR caa.FechaFin >= GETDATE())
                    )
             )
       )
        RETURN;

    UPDATE dbo.Persona
       SET CodigoQr = LOWER(CONVERT(VARCHAR(64), HASHBYTES
           (
               'SHA2_256',
               CONCAT(CONVERT(VARCHAR(36), NEWID()), ':', IdPersona, ':', CONVERT(VARCHAR(33), SYSDATETIME(), 126))
           ), 2))
     WHERE IdPersona = @IdPersona
       AND CodigoQr IS NULL;

    SELECT CodigoQr
    FROM dbo.Persona
    WHERE IdPersona = @IdPersona;
END;
GO

-- dbo.usp_Proveedor_Crear
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

-- dbo.usp_Registro_Ingreso_Listar
CREATE OR ALTER PROCEDURE dbo.usp_Registro_Ingreso_Listar AS
BEGIN
 SET NOCOUNT ON;
 SELECT TOP(200) ri.IdRegistroIngreso,ri.IdPersona,p.NumeroDocumento,p.NombreCompleto,ri.IdSolicitud,s.NumeroSolicitud,s.NombreActividad,ri.TipoMovimiento,ri.FechaMovimiento,ri.IdUsuarioSeguridad,u.NombreCompleto,ri.Observaciones
 FROM dbo.Registro_Ingreso ri JOIN dbo.Persona p ON p.IdPersona=ri.IdPersona JOIN dbo.Solicitud_Ingreso s ON s.IdSolicitud=ri.IdSolicitud LEFT JOIN dbo.Usuario u ON u.IdUsuario=ri.IdUsuarioSeguridad ORDER BY ri.FechaMovimiento DESC,ri.IdRegistroIngreso DESC;
END;
GO

-- dbo.usp_Registro_Ingreso_Registrar
CREATE OR ALTER PROCEDURE dbo.usp_Registro_Ingreso_Registrar
    @IdPersona BIGINT,
    @TipoMovimiento VARCHAR(10),
    @IdUsuarioSeguridad VARCHAR(50),
    @Observaciones NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @TipoMovimiento = UPPER(LTRIM(RTRIM(@TipoMovimiento)));

    IF @TipoMovimiento NOT IN ('ENTRADA', 'SALIDA')
        THROW 50510, 'El movimiento debe ser ENTRADA o SALIDA.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Persona WHERE IdPersona = @IdPersona)
        THROW 50511, 'La persona no existe.', 1;

    DECLARE @IdSolicitud BIGINT, @IdSolicitudPersona BIGINT;

    IF @TipoMovimiento = 'ENTRADA'
    BEGIN
        SELECT TOP (1)
            @IdSolicitud = s.IdSolicitud,
            @IdSolicitudPersona = sp.IdSolicitudPersona
        FROM dbo.Solicitud_Persona AS sp
        INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = sp.IdSolicitud
        INNER JOIN dbo.Cat_Estado_Solicitud AS es ON es.IdEstadoSolicitud = s.IdEstadoSolicitud
        WHERE sp.IdPersona = @IdPersona
          AND es.Codigo = 'LISTA_INGRESO'
          AND CONVERT(DATE, SYSDATETIME()) BETWEEN s.FechaInicio AND s.FechaFin
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.Solicitud_Persona_Area AS spa
              OUTER APPLY
              (
                  SELECT TOP (1) ea.Codigo
                  FROM dbo.Aprobacion_Area AS aa
                  LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS ea
                      ON ea.IdEstadoAprobacion = aa.IdEstadoAprobacion
                  WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
                  ORDER BY COALESCE(aa.FechaDecision, aa.FechaSolicitud, aa.FechaCreacion) DESC,
                           aa.IdAprobacionArea DESC
              ) AS ultima
              WHERE spa.IdSolicitudPersona = sp.IdSolicitudPersona
                AND ISNULL(spa.RequiereAprobacion, 0) = 1
                AND ISNULL(ultima.Codigo, 'PENDIENTE') <> 'APROBADA'
          )
        ORDER BY s.FechaInicio DESC, s.IdSolicitud DESC;

        IF @IdSolicitud IS NULL
            THROW 50512, 'La persona no tiene una autorizaciÃ³n vigente y completamente aprobada.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Registro_Ingreso AS ri
            WHERE ri.IdPersona = @IdPersona
              AND ri.IdSolicitud = @IdSolicitud
              AND ri.TipoMovimiento = 'ENTRADA'
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM dbo.Registro_Ingreso AS rs
                  WHERE rs.IdPersona = ri.IdPersona
                    AND rs.IdSolicitud = ri.IdSolicitud
                    AND rs.TipoMovimiento = 'SALIDA'
                    AND rs.FechaMovimiento > ri.FechaMovimiento
              )
        )
            THROW 50513, 'La persona ya tiene una entrada abierta.', 1;
    END
    ELSE
    BEGIN
        SELECT TOP (1)
            @IdSolicitud = ri.IdSolicitud,
            @IdSolicitudPersona = ri.IdSolicitudPersona
        FROM dbo.Registro_Ingreso AS ri
        WHERE ri.IdPersona = @IdPersona
          AND ri.TipoMovimiento = 'ENTRADA'
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.Registro_Ingreso AS rs
              WHERE rs.IdPersona = ri.IdPersona
                AND rs.IdSolicitud = ri.IdSolicitud
                AND rs.TipoMovimiento = 'SALIDA'
                AND rs.FechaMovimiento > ri.FechaMovimiento
          )
        ORDER BY ri.FechaMovimiento DESC;

        IF @IdSolicitud IS NULL
            THROW 50514, 'La persona no tiene una entrada abierta para registrar salida.', 1;
    END;

    DECLARE @Id BIGINT;
    EXEC dbo.usp_ObtenerSiguienteId 'Registro_Ingreso', @Id OUTPUT;

    INSERT dbo.Registro_Ingreso
    (
        IdRegistroIngreso, IdPersona, IdSolicitud, IdSolicitudPersona,
        TipoMovimiento, FechaMovimiento, IdUsuarioSeguridad, Observaciones
    )
    VALUES
    (
        @Id, @IdPersona, @IdSolicitud, @IdSolicitudPersona,
        @TipoMovimiento, SYSDATETIME(), @IdUsuarioSeguridad,
        NULLIF(LTRIM(RTRIM(@Observaciones)), '')
    );

    EXEC dbo.usp_Historial_Solicitud_Registrar
        @IdSolicitud,
        'CONTROL_ACCESO',
        N'Movimiento registrado en porterÃ­a',
        @TipoMovimiento,
        @IdUsuarioSeguridad;

    SELECT @Id;
END;
GO

-- dbo.usp_Solicitud_Enviar
-- dbo.usp_Solicitud_Persona_Area_ReenviarAprobacion
CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Persona_Area_ReenviarAprobacion
    @IdSolicitudPersonaArea BIGINT,
    @IdUsuarioSolicitante VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IdSolicitud BIGINT,
            @IdArea INT;

    SELECT
        @IdSolicitud = sp.IdSolicitud,
        @IdArea = spa.IdArea
    FROM dbo.Solicitud_Persona_Area AS spa
    INNER JOIN dbo.Solicitud_Persona AS sp
        ON sp.IdSolicitudPersona = spa.IdSolicitudPersona
    WHERE spa.IdSolicitudPersonaArea = @IdSolicitudPersonaArea;

    IF @IdSolicitud IS NULL
        THROW 50530, 'El acceso de la persona no existe.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Solicitud_Ingreso AS s
        WHERE s.IdSolicitud = @IdSolicitud
          AND
          (
              s.IdUsuarioSolicitante = @IdUsuarioSolicitante
              OR EXISTS
                 (
                     SELECT 1
                     FROM dbo.Usuario_Rol AS ur
                     INNER JOIN dbo.Rol AS r ON r.IdRol = ur.IdRol
                     WHERE ur.IdUsuario = @IdUsuarioSolicitante
                       AND r.Codigo = 'ADMINISTRADOR'
                 )
          )
    )
        THROW 50531, 'No tienes permiso para reenviar esta aprobación.', 1;

    DECLARE @IdEstadoPendiente SMALLINT =
    (
        SELECT IdEstadoAprobacion
        FROM dbo.Cat_Estado_Aprobacion_Area
        WHERE Codigo = 'PENDIENTE'
    );

    IF @IdEstadoPendiente IS NULL
        THROW 50532, 'El estado PENDIENTE no está configurado.', 1;

    DECLARE @Aprobadores TABLE
    (
        Fila INT IDENTITY(1,1) PRIMARY KEY,
        IdUsuarioAprobador VARCHAR(50) NOT NULL
    );

    INSERT @Aprobadores (IdUsuarioAprobador)
    SELECT DISTINCT caa.IdUsuarioAprobador
    FROM dbo.Config_Aprobador_Area AS caa
    WHERE caa.IdArea = @IdArea
      AND caa.IdUsuarioAprobador IS NOT NULL
      AND ISNULL(caa.IdEstadoGeneral, 1) = 1
      AND (caa.FechaInicio IS NULL OR caa.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
      AND (caa.FechaFin IS NULL OR caa.FechaFin >= CONVERT(DATE, SYSDATETIME()));

    IF NOT EXISTS (SELECT 1 FROM @Aprobadores)
        THROW 50533, 'El área no tiene aprobadores activos configurados.', 1;

    BEGIN TRANSACTION;

    DECLARE @Fila INT = 1,
            @Total INT = (SELECT COUNT(*) FROM @Aprobadores),
            @IdUsuarioAprobador VARCHAR(50),
            @IdAprobacionArea BIGINT,
            @NumeroReenvio SMALLINT;

    WHILE @Fila <= @Total
    BEGIN
        SELECT @IdUsuarioAprobador = IdUsuarioAprobador
        FROM @Aprobadores
        WHERE Fila = @Fila;

        SELECT @NumeroReenvio = CONVERT(SMALLINT, COUNT_BIG(*))
        FROM dbo.Aprobacion_Area
        WHERE IdSolicitudPersonaArea = @IdSolicitudPersonaArea
          AND IdUsuarioAprobador = @IdUsuarioAprobador;

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
            @IdEstadoPendiente, SYSDATETIME(), NULL,
            NULL, @NumeroReenvio, SYSDATETIME(), @IdUsuarioSolicitante
        );

        SET @Fila += 1;
    END;

    EXEC dbo.usp_Solicitud_Estado_Recalcular
        @IdSolicitudPersonaArea,
        @IdUsuarioSolicitante;

    COMMIT TRANSACTION;
END;
GO

-- dbo.usp_Solicitud_Enviar
CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Enviar @IdSolicitud BIGINT,@IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF NOT EXISTS(SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud=@IdSolicitud) THROW 50500,'La solicitud no existe.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Solicitud_Ingreso s WHERE s.IdSolicitud=@IdSolicitud AND (s.IdUsuarioSolicitante=@IdUsuario OR EXISTS(SELECT 1 FROM dbo.Usuario_Rol ur JOIN dbo.Rol r ON r.IdRol=ur.IdRol WHERE ur.IdUsuario=@IdUsuario AND r.Codigo='ADMINISTRADOR'))) THROW 50501,'No tienes permiso para enviar esta solicitud.',1;
    IF EXISTS(SELECT 1 FROM dbo.Solicitud_Ingreso s JOIN dbo.Cat_Estado_Solicitud e ON e.IdEstadoSolicitud=s.IdEstadoSolicitud WHERE s.IdSolicitud=@IdSolicitud AND e.EsEstadoFinal=1) THROW 50502,'La solicitud ya estÃ¡ finalizada o cancelada.',1;

    UPDATE spa SET RequiereAprobacion=CONVERT(BIT,CASE WHEN EXISTS(SELECT 1 FROM dbo.Config_Aprobador_Area ca WHERE ca.IdArea=spa.IdArea AND ISNULL(ca.IdEstadoGeneral,1)=1 AND (ca.FechaInicio IS NULL OR ca.FechaInicio<=CONVERT(date,SYSDATETIME())) AND (ca.FechaFin IS NULL OR ca.FechaFin>=CONVERT(date,SYSDATETIME()))) THEN 1 ELSE 0 END)
    FROM dbo.Solicitud_Persona_Area spa JOIN dbo.Solicitud_Persona sp ON sp.IdSolicitudPersona=spa.IdSolicitudPersona WHERE sp.IdSolicitud=@IdSolicitud;

    DECLARE @Codigo VARCHAR(40)=CASE
      WHEN NOT EXISTS(SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud=@IdSolicitud) AND EXISTS(SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud=@IdSolicitud AND IdProveedor IS NOT NULL) THEN 'PENDIENTE_PROVEEDOR'
      WHEN NOT EXISTS(SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud=@IdSolicitud) THEN 'EN_REVISION'
      WHEN EXISTS(SELECT 1 FROM dbo.Solicitud_Persona_Area spa JOIN dbo.Solicitud_Persona sp ON sp.IdSolicitudPersona=spa.IdSolicitudPersona WHERE sp.IdSolicitud=@IdSolicitud AND spa.RequiereAprobacion=1) THEN 'PENDIENTE_APROBACIONES'
      ELSE 'LISTA_INGRESO' END;
    UPDATE s SET IdEstadoSolicitud=e.IdEstadoSolicitud,FechaModificacion=SYSDATETIME(),UsuarioModificacion=@IdUsuario,FechaEnvioProveedor=CASE WHEN @Codigo='PENDIENTE_PROVEEDOR' THEN SYSDATETIME() ELSE FechaEnvioProveedor END
    FROM dbo.Solicitud_Ingreso s JOIN dbo.Cat_Estado_Solicitud e ON e.Codigo=@Codigo WHERE s.IdSolicitud=@IdSolicitud;
    EXEC dbo.usp_Historial_Solicitud_Registrar @IdSolicitud,'ESTADO_SOLICITUD',N'Solicitud enviada al flujo',@Codigo,@IdUsuario;
END;
GO

-- dbo.usp_Solicitud_Estado_Recalcular
CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Estado_Recalcular
    @IdSolicitudPersonaArea BIGINT,
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdSolicitud BIGINT =
    (
        SELECT sp.IdSolicitud
        FROM dbo.Solicitud_Persona_Area AS spa
        INNER JOIN dbo.Solicitud_Persona AS sp
            ON sp.IdSolicitudPersona = spa.IdSolicitudPersona
        WHERE spa.IdSolicitudPersonaArea = @IdSolicitudPersonaArea
    );

    IF @IdSolicitud IS NULL RETURN;

    DECLARE @Codigo VARCHAR(40);

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Solicitud_Persona_Area AS spa
        INNER JOIN dbo.Solicitud_Persona AS sp
            ON sp.IdSolicitudPersona = spa.IdSolicitudPersona
        OUTER APPLY
        (
            SELECT TOP (1) ea.Codigo
            FROM dbo.Aprobacion_Area AS aa
            LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS ea
                ON ea.IdEstadoAprobacion = aa.IdEstadoAprobacion
            WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
            ORDER BY COALESCE(aa.FechaDecision, aa.FechaSolicitud, aa.FechaCreacion) DESC,
                     aa.IdAprobacionArea DESC
        ) AS ultima
        WHERE sp.IdSolicitud = @IdSolicitud
          AND ISNULL(spa.RequiereAprobacion, 0) = 1
          AND ISNULL(ultima.Codigo, 'PENDIENTE') NOT IN ('APROBADA', 'RECHAZADA')
    )
        SET @Codigo = 'PENDIENTE_APROBACIONES';
    ELSE
        SET @Codigo = 'LISTA_INGRESO';

    UPDATE s
       SET IdEstadoSolicitud = e.IdEstadoSolicitud,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuario
    FROM dbo.Solicitud_Ingreso AS s
    INNER JOIN dbo.Cat_Estado_Solicitud AS e ON e.Codigo = @Codigo
    WHERE s.IdSolicitud = @IdSolicitud;

    EXEC dbo.usp_Historial_Solicitud_Registrar
        @IdSolicitud,
        'APROBACION_AREA',
        N'Estado consolidado despuÃ©s de una decisiÃ³n',
        @Codigo,
        @IdUsuario;
END;
GO

-- dbo.usp_Solicitud_Formulario_Datos
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

-- dbo.usp_Solicitud_Ingreso_Actualizar
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
    @CantidadEstimada INT,
    @IdAreaSolicitante INT = NULL,
    @IdUsuarioSolicitante VARCHAR(50),
    @IdUbicacion INT = NULL,
    @Observaciones NVARCHAR(1000) = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud)
    BEGIN
        SELECT 0;
        RETURN;
    END;

    IF NULLIF(LTRIM(RTRIM(@NombreActividad)), '') IS NULL
        THROW 50142, 'NombreActividad es obligatorio.', 1;
    IF NULLIF(LTRIM(RTRIM(@Usuario)), '') IS NULL
        THROW 50143, 'Usuario es obligatorio.', 1;
    IF @FechaInicio IS NOT NULL AND @FechaFin IS NOT NULL AND @FechaFin < @FechaInicio
        THROW 50144, 'El rango de fechas no es vÃ¡lido.', 1;
    IF @CantidadEstimada IS NULL OR @CantidadEstimada < 1
        THROW 50145, 'La cantidad estimada debe ser como mÃ­nimo una persona.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuarioSolicitante)
        THROW 50146, 'El usuario solicitante no existe.', 1;
    IF @IdTipoIngreso IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Ingreso WHERE IdTipoIngreso = @IdTipoIngreso)
        THROW 50147, 'El tipo de ingreso no existe.', 1;
    IF @IdEstadoSolicitud IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Solicitud WHERE IdEstadoSolicitud = @IdEstadoSolicitud)
        THROW 50148, 'El estado de solicitud no existe.', 1;
    IF @IdProveedor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE IdProveedor = @IdProveedor)
        THROW 50149, 'El proveedor no existe.', 1;
    IF @IdAreaSolicitante IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdAreaSolicitante)
        THROW 50150, 'El Ã¡rea solicitante no existe.', 1;
    IF @IdUbicacion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Ubicacion WHERE IdUbicacion = @IdUbicacion)
        THROW 50151, 'La ubicaciÃ³n no existe.', 1;

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

-- dbo.usp_Solicitud_Ingreso_Crear
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
    @CantidadEstimada INT,
    @IdAreaSolicitante INT = NULL,
    @IdUsuarioSolicitante VARCHAR(50),
    @IdUbicacion INT = NULL,
    @Observaciones NVARCHAR(1000) = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@NombreActividad)), '') IS NULL
        THROW 50120, 'NombreActividad es obligatorio.', 1;
    IF @FechaInicio IS NOT NULL AND @FechaFin IS NOT NULL AND @FechaFin < @FechaInicio
        THROW 50121, 'El rango de fechas no es vÃ¡lido.', 1;
    IF @CantidadEstimada IS NULL OR @CantidadEstimada < 1
        THROW 50122, 'La cantidad estimada debe ser como mÃ­nimo una persona.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuarioSolicitante)
        THROW 50123, 'El usuario solicitante no existe.', 1;
    IF @IdTipoIngreso IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Ingreso WHERE IdTipoIngreso = @IdTipoIngreso)
        THROW 50124, 'El tipo de ingreso no existe.', 1;
    IF @IdEstadoSolicitud IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Solicitud WHERE IdEstadoSolicitud = @IdEstadoSolicitud)
        THROW 50125, 'El estado de solicitud no existe.', 1;
    IF @IdProveedor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE IdProveedor = @IdProveedor)
        THROW 50126, 'El proveedor no existe.', 1;
    IF @IdAreaSolicitante IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdAreaSolicitante)
        THROW 50127, 'El Ã¡rea solicitante no existe.', 1;
    IF @IdUbicacion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Ubicacion WHERE IdUbicacion = @IdUbicacion)
        THROW 50128, 'La ubicaciÃ³n no existe.', 1;

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

-- dbo.usp_Solicitud_Ingreso_Eliminar
CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Ingreso_Eliminar @IdSolicitud BIGINT,@Usuario VARCHAR(50)
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud=@IdSolicitud) BEGIN SELECT 0; RETURN; END;
 DECLARE @Cancelada SMALLINT=(SELECT TOP(1) IdEstadoSolicitud FROM dbo.Cat_Estado_Solicitud WHERE Codigo='CANCELADA');
 UPDATE dbo.Solicitud_Ingreso SET IdEstadoSolicitud=@Cancelada,FechaModificacion=SYSDATETIME(),UsuarioModificacion=@Usuario WHERE IdSolicitud=@IdSolicitud;
 DECLARE @Filas INT=@@ROWCOUNT;
 IF @Filas>0 EXEC dbo.usp_Historial_Solicitud_Registrar @IdSolicitud,'ESTADO_SOLICITUD',N'Solicitud cancelada',NULL,@Usuario;
 SELECT @Filas;
END;
GO

-- dbo.usp_Solicitud_Ingreso_Listar
CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Ingreso_Listar
    @IdUsuario VARCHAR(50),
    @AccesoTotal BIT=0
AS
BEGIN
 SET NOCOUNT ON;
 SELECT s.IdSolicitud,s.NumeroSolicitud,ti.Nombre,es.Nombre,s.FechaInicio,s.FechaFin,s.NombreActividad,u.NombreCompleto,CONVERT(int,COUNT(sp.IdSolicitudPersona))
 FROM dbo.Solicitud_Ingreso s
 LEFT JOIN dbo.Cat_Tipo_Ingreso ti ON ti.IdTipoIngreso=s.IdTipoIngreso
 LEFT JOIN dbo.Cat_Estado_Solicitud es ON es.IdEstadoSolicitud=s.IdEstadoSolicitud
 LEFT JOIN dbo.Usuario u ON u.IdUsuario=s.IdUsuarioSolicitante
 LEFT JOIN dbo.Solicitud_Persona sp ON sp.IdSolicitud=s.IdSolicitud
 WHERE (@AccesoTotal=1 OR s.IdUsuarioSolicitante=@IdUsuario)
   AND ISNULL(es.Codigo,'')<>'CANCELADA'
 GROUP BY s.IdSolicitud,s.NumeroSolicitud,ti.Nombre,es.Nombre,s.FechaInicio,s.FechaFin,s.NombreActividad,u.NombreCompleto,s.FechaCreacion
 ORDER BY s.FechaCreacion DESC,s.IdSolicitud DESC;
END;
GO

-- dbo.usp_Solicitud_Ingreso_Obtener
CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Ingreso_Obtener
    @IdSolicitud BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdSolicitud,
        NumeroSolicitud,
        IdTipoIngreso,
        IdEstadoSolicitud,
        FechaInicio,
        FechaFin,
        NombreActividad,
        DescripcionActividad,
        IdProveedor,
        NumeroContrato,
        ContactoProveedor,
        CorreoProveedor,
        CantidadEstimada,
        IdAreaSolicitante,
        IdUsuarioSolicitante,
        IdUbicacion,
        Observaciones,
        FechaCreacion
    FROM dbo.Solicitud_Ingreso
    WHERE IdSolicitud = @IdSolicitud;

    SELECT
        sp.IdSolicitudPersona,
        sp.IdPersona,
        p.NumeroDocumento,
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
            WHEN ISNULL(resumen.AreasPendientes, 0) > 0 THEN N'Pendiente de aprobaciÃ³n'
            WHEN ISNULL(resumen.AreasRequeridas, 0) = 0 THEN N'No requiere aprobaciÃ³n'
            ELSE N'Aprobada'
        END AS EstadoAprobacion,
        ISNULL(resumen.AreasAprobadas, 0) AS AreasAprobadas,
        ISNULL(resumen.AreasPendientes, 0) AS AreasPendientes,
        ISNULL(resumen.AreasRechazadas, 0) AS AreasRechazadas,
        rechazos.DetalleRechazos
    FROM dbo.Solicitud_Persona AS sp
    LEFT JOIN dbo.Persona AS p ON p.IdPersona = sp.IdPersona
    OUTER APPLY
    (
        SELECT
            COUNT(CASE WHEN ISNULL(spa.RequiereAprobacion, 0) = 1 THEN 1 END) AS AreasRequeridas,
            COUNT(CASE WHEN ISNULL(spa.RequiereAprobacion, 0) = 1 AND ultima.Codigo = 'APROBADA' THEN 1 END) AS AreasAprobadas,
            COUNT(CASE WHEN ISNULL(spa.RequiereAprobacion, 0) = 1 AND ultima.Codigo = 'RECHAZADA' THEN 1 END) AS AreasRechazadas,
            COUNT
            (
                CASE
                    WHEN ISNULL(spa.RequiereAprobacion, 0) = 1
                     AND ISNULL(ultima.Codigo, 'PENDIENTE') NOT IN ('APROBADA', 'RECHAZADA')
                    THEN 1
                END
            ) AS AreasPendientes
        FROM dbo.Solicitud_Persona_Area AS spa
        OUTER APPLY
        (
            SELECT TOP (1) ea.Codigo
            FROM dbo.Aprobacion_Area AS aa
            LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS ea
                ON ea.IdEstadoAprobacion = aa.IdEstadoAprobacion
            WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
            ORDER BY COALESCE(aa.FechaDecision, aa.FechaSolicitud, aa.FechaCreacion) DESC,
                     aa.IdAprobacionArea DESC
        ) AS ultima
        WHERE spa.IdSolicitudPersona = sp.IdSolicitudPersona
    ) AS resumen
    OUTER APPLY
    (
        SELECT STRING_AGG
        (
            CONVERT
            (
                NVARCHAR(MAX),
                CONCAT
                (
                    COALESCE(a.Nombre, N'Ãrea sin nombre'),
                    CASE
                        WHEN NULLIF(LTRIM(RTRIM(ultima.ComentarioDecision)), N'') IS NULL THEN N''
                        ELSE CONCAT(N': ', ultima.ComentarioDecision)
                    END
                )
            ),
            N' | '
        ) AS DetalleRechazos
        FROM dbo.Solicitud_Persona_Area AS spa
        LEFT JOIN dbo.Cat_Area AS a ON a.IdArea = spa.IdArea
        OUTER APPLY
        (
            SELECT TOP (1)
                ea.Codigo,
                aa.ComentarioDecision
            FROM dbo.Aprobacion_Area AS aa
            LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS ea
                ON ea.IdEstadoAprobacion = aa.IdEstadoAprobacion
            WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
            ORDER BY COALESCE(aa.FechaDecision, aa.FechaSolicitud, aa.FechaCreacion) DESC,
                     aa.IdAprobacionArea DESC
        ) AS ultima
        WHERE spa.IdSolicitudPersona = sp.IdSolicitudPersona
          AND ultima.Codigo = 'RECHAZADA'
    ) AS rechazos
    WHERE sp.IdSolicitud = @IdSolicitud
    ORDER BY p.NombreCompleto, sp.IdSolicitudPersona;
END;
GO

-- dbo.usp_Solicitud_Persona_Agregar
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

-- dbo.usp_Usuario_Actualizar
CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Actualizar
    @IdUsuario VARCHAR(50),
    @NombreCompleto NVARCHAR(200),
    @Correo VARCHAR(254) = NULL,
    @Telefono VARCHAR(30) = NULL,
    @Puesto NVARCHAR(150) = NULL,
    @IdArea INT = NULL,
    @PuedeSolicitar BIT = 0,
    @EsAprobador BIT = 0,
    @EsSeguridad BIT = 0,
    @EsGuardia BIT = 0,
    @Activo BIT = 1,
    @UsuarioModificacion VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IdUsuario = LTRIM(RTRIM(@IdUsuario));
    SET @NombreCompleto = LTRIM(RTRIM(@NombreCompleto));
    SET @Correo = NULLIF(LTRIM(RTRIM(@Correo)), '');
    SET @Telefono = NULLIF(LTRIM(RTRIM(@Telefono)), '');
    SET @Puesto = NULLIF(LTRIM(RTRIM(@Puesto)), '');

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuario)
    BEGIN
        SELECT 0;
        RETURN;
    END;

    IF NULLIF(@NombreCompleto, '') IS NULL
        THROW 50600, 'El nombre completo es obligatorio.', 1;
    IF @Correo IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Usuario WHERE Correo = @Correo AND IdUsuario <> @IdUsuario)
        THROW 50601, 'Ya existe otro usuario con ese correo.', 1;
    IF @IdArea IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdArea)
        THROW 50602, 'El Ã¡rea seleccionada no existe.', 1;
    IF (@PuedeSolicitar = 1 OR @EsAprobador = 1) AND @IdArea IS NULL
        THROW 50603, 'Debe seleccionar un Ã¡rea para asignar permisos.', 1;

    DECLARE @IdEstadoActivo SMALLINT = COALESCE((SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'ACTIVO'), 1);
    DECLARE @IdEstadoInactivo SMALLINT = COALESCE((SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'INACTIVO'), 2);
    DECLARE @IdEstadoGeneral SMALLINT = CASE WHEN @Activo = 1 THEN @IdEstadoActivo ELSE @IdEstadoInactivo END;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Usuario
           SET NombreCompleto = @NombreCompleto,
               Correo = @Correo,
               Telefono = @Telefono,
               Puesto = @Puesto,
               IdEstadoGeneral = @IdEstadoGeneral,
               FechaModificacion = SYSDATETIME(),
               UsuarioModificacion = @UsuarioModificacion
         WHERE IdUsuario = @IdUsuario;

        UPDATE dbo.Usuario_Area
           SET EsAreaPrincipal = 0,
               PuedeSolicitar = 0,
               FechaModificacion = SYSDATETIME(),
               UsuarioModificacion = @UsuarioModificacion
         WHERE IdUsuario = @IdUsuario;

        IF @IdArea IS NULL
        BEGIN
            UPDATE dbo.Usuario_Area
               SET IdEstadoGeneral = @IdEstadoInactivo,
                   FechaFin = COALESCE(FechaFin, CONVERT(DATE, SYSDATETIME())),
                   FechaModificacion = SYSDATETIME(),
                   UsuarioModificacion = @UsuarioModificacion
             WHERE IdUsuario = @IdUsuario;
        END;

        IF @IdArea IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Usuario_Area WHERE IdUsuario = @IdUsuario AND IdArea = @IdArea)
            BEGIN
                UPDATE dbo.Usuario_Area
                   SET PuedeSolicitar = ISNULL(@PuedeSolicitar, 0),
                       EsAreaPrincipal = 1,
                       FechaFin = NULL,
                       IdEstadoGeneral = @IdEstadoGeneral,
                       FechaModificacion = SYSDATETIME(),
                       UsuarioModificacion = @UsuarioModificacion
                 WHERE IdUsuario = @IdUsuario
                   AND IdArea = @IdArea;
            END
            ELSE
            BEGIN
                DECLARE @IdUsuarioArea BIGINT;
                EXEC dbo.usp_ObtenerSiguienteId 'Usuario_Area', @IdUsuarioArea OUTPUT;
                INSERT dbo.Usuario_Area
                (
                    IdUsuarioArea, IdUsuario, IdArea, PuedeSolicitar, EsAreaPrincipal,
                    FechaInicio, IdEstadoGeneral, FechaCreacion, UsuarioCreacion
                )
                VALUES
                (
                    @IdUsuarioArea, @IdUsuario, @IdArea, ISNULL(@PuedeSolicitar, 0), 1,
                    CONVERT(DATE, SYSDATETIME()), @IdEstadoGeneral, SYSDATETIME(), @UsuarioModificacion
                );
            END;
        END;

        UPDATE dbo.Config_Aprobador_Area
           SET EsPrincipal = 0,
               IdEstadoGeneral = @IdEstadoInactivo,
               FechaFin = COALESCE(FechaFin, CONVERT(DATE, SYSDATETIME())),
               FechaModificacion = SYSDATETIME(),
               UsuarioModificacion = @UsuarioModificacion
         WHERE IdUsuarioAprobador = @IdUsuario;

        IF @EsAprobador = 1 AND @IdArea IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Config_Aprobador_Area WHERE IdUsuarioAprobador = @IdUsuario AND IdArea = @IdArea)
            BEGIN
                UPDATE dbo.Config_Aprobador_Area
                   SET EsPrincipal = 1,
                       FechaFin = NULL,
                       IdEstadoGeneral = @IdEstadoGeneral,
                       FechaModificacion = SYSDATETIME(),
                       UsuarioModificacion = @UsuarioModificacion
                 WHERE IdUsuarioAprobador = @IdUsuario
                   AND IdArea = @IdArea;
            END
            ELSE
            BEGIN
                DECLARE @IdConfigAprobador BIGINT;
                EXEC dbo.usp_ObtenerSiguienteId 'Config_Aprobador_Area', @IdConfigAprobador OUTPUT;
                INSERT dbo.Config_Aprobador_Area
                (
                    IdConfigAprobador, IdArea, IdUsuarioAprobador, EsPrincipal,
                    FechaInicio, IdEstadoGeneral, FechaCreacion, UsuarioCreacion
                )
                VALUES
                (
                    @IdConfigAprobador, @IdArea, @IdUsuario, 1,
                    CONVERT(DATE, SYSDATETIME()), @IdEstadoGeneral, SYSDATETIME(), @UsuarioModificacion
                );
            END;
        END;

        IF @EsGuardia = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Codigo = 'GUARDIA')
        BEGIN
            DECLARE @NuevoIdRolGuardia SMALLINT =
                (SELECT CONVERT(SMALLINT, ISNULL(MAX(IdRol), 0) + 1) FROM dbo.Rol WITH (UPDLOCK, HOLDLOCK));
            INSERT dbo.Rol (IdRol, Codigo, Nombre, Descripcion, Activo)
            VALUES (@NuevoIdRolGuardia, 'GUARDIA', N'Guardia', N'Solo escanea códigos QR y consulta los resultados.', 1);
        END;

        DECLARE @IdRolAprobador SMALLINT = (SELECT TOP (1) IdRol FROM dbo.Rol WHERE Codigo = 'APROBADOR');
        DECLARE @IdRolSeguridad SMALLINT = (SELECT TOP (1) IdRol FROM dbo.Rol WHERE Codigo = 'SEGURIDAD');
        DECLARE @IdRolGuardia SMALLINT = (SELECT TOP (1) IdRol FROM dbo.Rol WHERE Codigo = 'GUARDIA');
        DECLARE @IdRolSolicitante SMALLINT = (SELECT TOP (1) IdRol FROM dbo.Rol WHERE Codigo = 'SOLICITANTE');

        IF @PuedeSolicitar = 1 AND @IdRolSolicitante IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.Usuario_Rol WHERE IdUsuario = @IdUsuario AND IdRol = @IdRolSolicitante)
            INSERT dbo.Usuario_Rol (IdUsuario, IdRol, FechaAsignacion, UsuarioAsignacion)
            VALUES (@IdUsuario, @IdRolSolicitante, SYSDATETIME(), @UsuarioModificacion);
        ELSE IF @PuedeSolicitar = 0 AND @IdRolSolicitante IS NOT NULL
            DELETE FROM dbo.Usuario_Rol WHERE IdUsuario = @IdUsuario AND IdRol = @IdRolSolicitante;

        IF @EsAprobador = 1 AND @IdRolAprobador IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.Usuario_Rol WHERE IdUsuario = @IdUsuario AND IdRol = @IdRolAprobador)
            INSERT dbo.Usuario_Rol (IdUsuario, IdRol, FechaAsignacion, UsuarioAsignacion)
            VALUES (@IdUsuario, @IdRolAprobador, SYSDATETIME(), @UsuarioModificacion);
        ELSE IF @EsAprobador = 0 AND @IdRolAprobador IS NOT NULL
            DELETE FROM dbo.Usuario_Rol WHERE IdUsuario = @IdUsuario AND IdRol = @IdRolAprobador;

        IF @EsSeguridad = 1 AND @IdRolSeguridad IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.Usuario_Rol WHERE IdUsuario = @IdUsuario AND IdRol = @IdRolSeguridad)
            INSERT dbo.Usuario_Rol (IdUsuario, IdRol, FechaAsignacion, UsuarioAsignacion)
            VALUES (@IdUsuario, @IdRolSeguridad, SYSDATETIME(), @UsuarioModificacion);
        ELSE IF @EsSeguridad = 0 AND @IdRolSeguridad IS NOT NULL
            DELETE FROM dbo.Usuario_Rol WHERE IdUsuario = @IdUsuario AND IdRol = @IdRolSeguridad;

        IF @EsGuardia = 1 AND @IdRolGuardia IS NOT NULL
        BEGIN
            DELETE ur
            FROM dbo.Usuario_Rol AS ur
            INNER JOIN dbo.Rol AS r ON r.IdRol = ur.IdRol
            WHERE ur.IdUsuario = @IdUsuario
              AND r.Codigo IN ('SOLICITANTE', 'APROBADOR', 'RESPONSABLE', 'SEGURIDAD');

            IF NOT EXISTS (SELECT 1 FROM dbo.Usuario_Rol WHERE IdUsuario = @IdUsuario AND IdRol = @IdRolGuardia)
                INSERT dbo.Usuario_Rol (IdUsuario, IdRol, FechaAsignacion, UsuarioAsignacion)
                VALUES (@IdUsuario, @IdRolGuardia, SYSDATETIME(), @UsuarioModificacion);
        END
        ELSE IF @IdRolGuardia IS NOT NULL
            DELETE FROM dbo.Usuario_Rol WHERE IdUsuario = @IdUsuario AND IdRol = @IdRolGuardia;

        COMMIT TRANSACTION;
        SELECT 1;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- dbo.usp_Usuario_Administracion_Listar
CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Administracion_Listar AS
BEGIN
 SET NOCOUNT ON;
 SELECT u.IdUsuario,u.NombreCompleto,u.Correo,u.Telefono,u.Puesto,ap.IdArea,ap.Area,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Usuario_Area ua WHERE ua.IdUsuario=u.IdUsuario AND ISNULL(ua.PuedeSolicitar,0)=1 AND ISNULL(ua.IdEstadoGeneral,1)=1) THEN 1 ELSE 0 END),
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Usuario_Rol ur JOIN dbo.Rol r ON r.IdRol=ur.IdRol WHERE ur.IdUsuario=u.IdUsuario AND r.Codigo='APROBADOR') THEN 1 ELSE 0 END),
 CONVERT(bit,CASE WHEN ISNULL(u.IdEstadoGeneral,1)=1 THEN 1 ELSE 0 END),u.FechaCreacion,roles.Roles
 FROM dbo.Usuario u
 OUTER APPLY(SELECT TOP(1) ua.IdArea,a.Nombre Area FROM dbo.Usuario_Area ua LEFT JOIN dbo.Cat_Area a ON a.IdArea=ua.IdArea WHERE ua.IdUsuario=u.IdUsuario AND ISNULL(ua.IdEstadoGeneral,1)=1 ORDER BY ISNULL(ua.EsAreaPrincipal,0) DESC,ua.IdUsuarioArea) ap
 OUTER APPLY(SELECT STRING_AGG(r.Nombre,',') Roles FROM dbo.Usuario_Rol ur JOIN dbo.Rol r ON r.IdRol=ur.IdRol WHERE ur.IdUsuario=u.IdUsuario AND r.Activo=1) roles
 ORDER BY u.NombreCompleto,u.IdUsuario;
END;
GO

-- dbo.usp_Usuario_Administracion_Obtener
CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Administracion_Obtener
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.IdUsuario,
        u.NombreCompleto,
        u.Correo,
        u.Telefono,
        u.Puesto,
        eg.Nombre AS Estado,
        CONVERT(BIT, CASE WHEN ISNULL(u.IdEstadoGeneral, 1) = 1 THEN 1 ELSE 0 END) AS Activo,
        u.FechaCreacion,
        u.UsuarioCreacion,
        u.FechaModificacion,
        u.UsuarioModificacion,
        roles.Roles
    FROM dbo.Usuario AS u
    LEFT JOIN dbo.Cat_Estado_General AS eg ON eg.IdEstadoGeneral = u.IdEstadoGeneral
    OUTER APPLY
    (
        SELECT STRING_AGG(r.Nombre, ',') AS Roles
        FROM dbo.Usuario_Rol AS ur
        INNER JOIN dbo.Rol AS r ON r.IdRol = ur.IdRol
        WHERE ur.IdUsuario = u.IdUsuario
          AND ISNULL(r.Activo, 1) = 1
    ) AS roles
    WHERE u.IdUsuario = @IdUsuario;

    SELECT
        a.IdArea,
        a.Codigo,
        a.Nombre,
        CONVERT(BIT, ISNULL(ua.PuedeSolicitar, 0)) AS PuedeSolicitar,
        CONVERT(BIT, ISNULL(ua.EsAreaPrincipal, 0)) AS EsAreaPrincipal,
        CONVERT(BIT, CASE WHEN ca.IdConfigAprobador IS NULL THEN 0 ELSE 1 END) AS EsAprobador,
        CONVERT(BIT, ISNULL(ca.EsPrincipal, 0)) AS EsAprobadorPrincipal,
        COALESCE(ua.FechaInicio, ca.FechaInicio) AS FechaInicio,
        COALESCE(ua.FechaFin, ca.FechaFin) AS FechaFin,
        CONVERT
        (
            BIT,
            CASE
                WHEN ISNULL(ua.IdEstadoGeneral, 0) = 1 OR ISNULL(ca.IdEstadoGeneral, 0) = 1 THEN 1
                ELSE 0
            END
        ) AS Activo
    FROM dbo.Cat_Area AS a
    OUTER APPLY
    (
        SELECT TOP (1)
            x.IdUsuarioArea,
            x.PuedeSolicitar,
            x.EsAreaPrincipal,
            x.FechaInicio,
            x.FechaFin,
            x.IdEstadoGeneral
        FROM dbo.Usuario_Area AS x
        WHERE x.IdUsuario = @IdUsuario
          AND x.IdArea = a.IdArea
        ORDER BY ISNULL(x.IdEstadoGeneral, 1) DESC,
                 ISNULL(x.EsAreaPrincipal, 0) DESC,
                 x.IdUsuarioArea DESC
    ) AS ua
    OUTER APPLY
    (
        SELECT TOP (1)
            x.IdConfigAprobador,
            x.EsPrincipal,
            x.FechaInicio,
            x.FechaFin,
            x.IdEstadoGeneral
        FROM dbo.Config_Aprobador_Area AS x
        WHERE x.IdUsuarioAprobador = @IdUsuario
          AND x.IdArea = a.IdArea
        ORDER BY ISNULL(x.IdEstadoGeneral, 1) DESC,
                 ISNULL(x.EsPrincipal, 0) DESC,
                 x.IdConfigAprobador DESC
    ) AS ca
    WHERE ua.IdUsuarioArea IS NOT NULL
       OR ca.IdConfigAprobador IS NOT NULL
    ORDER BY ISNULL(ua.EsAreaPrincipal, 0) DESC, a.Nombre, a.IdArea;
END;
GO

-- dbo.usp_Usuario_Autenticar
CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Autenticar @Usuario VARCHAR(254),@Contrasena VARCHAR(200)
AS
BEGIN
 SET NOCOUNT ON; IF NULLIF(LTRIM(RTRIM(@Usuario)),'') IS NULL OR NULLIF(@Contrasena,'') IS NULL RETURN;
 SELECT TOP(1) u.IdUsuario,u.NombreCompleto,u.Correo,u.Puesto,ap.IdArea,ap.Area,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Usuario_Rol ur JOIN dbo.Rol r ON r.IdRol=ur.IdRol WHERE ur.IdUsuario=u.IdUsuario AND r.Codigo='APROBADOR') THEN 1 ELSE 0 END),
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Usuario_Area ua WHERE ua.IdUsuario=u.IdUsuario AND ISNULL(ua.PuedeSolicitar,0)=1) THEN 1 ELSE 0 END),
 roles.Roles
 FROM dbo.Usuario u JOIN dbo.Usuario_Credencial c ON c.IdUsuario=u.IdUsuario LEFT JOIN dbo.Cat_Estado_General eg ON eg.IdEstadoGeneral=u.IdEstadoGeneral
 OUTER APPLY(SELECT TOP(1) ua.IdArea,a.Nombre Area FROM dbo.Usuario_Area ua LEFT JOIN dbo.Cat_Area a ON a.IdArea=ua.IdArea WHERE ua.IdUsuario=u.IdUsuario ORDER BY ISNULL(ua.EsAreaPrincipal,0) DESC,ua.IdUsuarioArea) ap
 OUTER APPLY(SELECT STRING_AGG(r.Nombre,',') Roles FROM dbo.Usuario_Rol ur JOIN dbo.Rol r ON r.IdRol=ur.IdRol WHERE ur.IdUsuario=u.IdUsuario AND r.Activo=1) roles
 WHERE (u.IdUsuario=@Usuario OR u.Correo=@Usuario) AND c.Contrasena=@Contrasena AND ISNULL(eg.EsActivo,1)=1;
END;
GO

-- dbo.usp_Usuario_Crear
CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Crear
    @IdUsuario VARCHAR(50),
    @NombreCompleto NVARCHAR(200),
    @Correo VARCHAR(254) = NULL,
    @Telefono VARCHAR(30) = NULL,
    @Puesto NVARCHAR(150) = NULL,
    @Contrasena VARCHAR(200),
    @IdArea INT = NULL,
    @PuedeSolicitar BIT = 0,
    @EsAprobador BIT = 0,
    @Activo BIT = 1,
    @UsuarioCreacion VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IdUsuario = LTRIM(RTRIM(@IdUsuario));
    IF NULLIF(@IdUsuario, '') IS NULL THROW 50300, 'El identificador del usuario es obligatorio.', 1;
    IF NULLIF(LTRIM(RTRIM(@NombreCompleto)), '') IS NULL THROW 50301, 'El nombre completo es obligatorio.', 1;
    IF LEN(ISNULL(@Contrasena, '')) < 8 THROW 50302, 'La contraseÃ±a inicial debe tener al menos 8 caracteres.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuario) THROW 50303, 'Ya existe un usuario con ese identificador.', 1;
    IF @Correo IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Usuario WHERE Correo = @Correo) THROW 50304, 'Ya existe un usuario con ese correo.', 1;
    IF @IdArea IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdArea) THROW 50305, 'El Ã¡rea seleccionada no existe.', 1;
    IF (@PuedeSolicitar = 1 OR @EsAprobador = 1) AND @IdArea IS NULL THROW 50306, 'Debe seleccionar un Ã¡rea para asignar permisos.', 1;

    DECLARE @IdEstadoActivo SMALLINT = COALESCE((SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'ACTIVO'), 1);
    DECLARE @IdEstadoInactivo SMALLINT = COALESCE((SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'INACTIVO'), 2);
    DECLARE @IdEstadoGeneral SMALLINT = CASE WHEN @Activo = 1 THEN @IdEstadoActivo ELSE @IdEstadoInactivo END;

    BEGIN TRANSACTION;

    INSERT dbo.Usuario (IdUsuario, NombreCompleto, Correo, Telefono, Puesto, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (@IdUsuario, @NombreCompleto, NULLIF(LTRIM(RTRIM(@Correo)), ''), NULLIF(LTRIM(RTRIM(@Telefono)), ''), NULLIF(LTRIM(RTRIM(@Puesto)), ''), @IdEstadoGeneral, SYSDATETIME(), @UsuarioCreacion);

    INSERT dbo.Usuario_Credencial (IdUsuario, PasswordHash, Contrasena, FechaCreacion, UsuarioCreacion)
    VALUES (@IdUsuario, NULL, @Contrasena, SYSDATETIME(), @UsuarioCreacion);

    IF @IdArea IS NOT NULL
    BEGIN
        DECLARE @IdUsuarioArea BIGINT;
        EXEC dbo.usp_ObtenerSiguienteId 'Usuario_Area', @IdUsuarioArea OUTPUT;
        INSERT dbo.Usuario_Area (IdUsuarioArea, IdUsuario, IdArea, PuedeSolicitar, EsAreaPrincipal, FechaInicio, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
        VALUES (@IdUsuarioArea, @IdUsuario, @IdArea, ISNULL(@PuedeSolicitar, 0), 1, CONVERT(DATE, SYSDATETIME()), @IdEstadoGeneral, SYSDATETIME(), @UsuarioCreacion);

        IF @EsAprobador = 1
        BEGIN
            DECLARE @IdConfigAprobador BIGINT;
            EXEC dbo.usp_ObtenerSiguienteId 'Config_Aprobador_Area', @IdConfigAprobador OUTPUT;
            INSERT dbo.Config_Aprobador_Area (IdConfigAprobador, IdArea, IdUsuarioAprobador, EsPrincipal, FechaInicio, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
            VALUES (@IdConfigAprobador, @IdArea, @IdUsuario, 1, CONVERT(DATE, SYSDATETIME()), @IdEstadoGeneral, SYSDATETIME(), @UsuarioCreacion);
        END;
    END;

    COMMIT TRANSACTION;
    SELECT @IdUsuario;
END;
GO

-- dbo.usp_Usuario_Perfil_Obtener
CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Perfil_Obtener
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.IdUsuario,
           u.NombreCompleto,
           u.Correo,
           u.Telefono,
           u.Puesto,
           CONVERT(BIT, CASE WHEN EXISTS (
               SELECT 1 FROM dbo.Config_Aprobador_Area AS ca
               WHERE ca.IdUsuarioAprobador = u.IdUsuario
                 AND ISNULL(ca.IdEstadoGeneral, 1) = 1
                 AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                 AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
           ) THEN 1 ELSE 0 END) AS EsAprobador,
           CONVERT(BIT, CASE WHEN EXISTS (
               SELECT 1 FROM dbo.Usuario_Area AS ua
               WHERE ua.IdUsuario = u.IdUsuario
                 AND ISNULL(ua.PuedeSolicitar, 0) = 1
                 AND ISNULL(ua.IdEstadoGeneral, 1) = 1
                 AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                 AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
           ) THEN 1 ELSE 0 END) AS PuedeSolicitar
    FROM dbo.Usuario AS u
    WHERE u.IdUsuario = @IdUsuario;

    SELECT x.IdArea,
           a.Nombre,
           CONVERT(BIT, MAX(x.EsAreaPrincipal)) AS EsAreaPrincipal,
           CONVERT(BIT, MAX(x.PuedeSolicitar)) AS PuedeSolicitar,
           CONVERT(BIT, MAX(x.EsAprobador)) AS EsAprobador,
           CONVERT(BIT, MAX(x.EsAprobadorPrincipal)) AS EsAprobadorPrincipal
    FROM (
        SELECT ua.IdArea,
               CONVERT(INT, ISNULL(ua.EsAreaPrincipal, 0)) AS EsAreaPrincipal,
               CONVERT(INT, ISNULL(ua.PuedeSolicitar, 0)) AS PuedeSolicitar,
               0 AS EsAprobador,
               0 AS EsAprobadorPrincipal
        FROM dbo.Usuario_Area AS ua
        WHERE ua.IdUsuario = @IdUsuario
          AND ISNULL(ua.IdEstadoGeneral, 1) = 1
          AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
          AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))

        UNION ALL

        SELECT ca.IdArea,
               0,
               0,
               1,
               CONVERT(INT, ISNULL(ca.EsPrincipal, 0))
        FROM dbo.Config_Aprobador_Area AS ca
        WHERE ca.IdUsuarioAprobador = @IdUsuario
          AND ISNULL(ca.IdEstadoGeneral, 1) = 1
          AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
          AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
    ) AS x
    LEFT JOIN dbo.Cat_Area AS a ON a.IdArea = x.IdArea
    WHERE x.IdArea IS NOT NULL
    GROUP BY x.IdArea, a.Nombre
    ORDER BY MAX(x.EsAreaPrincipal) DESC, a.Nombre;

    SELECT s.IdSolicitud,
           s.NumeroSolicitud,
           ti.Nombre AS TipoIngreso,
           es.Nombre AS Estado,
           s.FechaInicio,
           s.FechaFin,
           s.NombreActividad,
           s.IdUsuarioSolicitante,
           CONVERT(INT, COUNT(sp.IdSolicitudPersona)) AS CantidadPersonas
    FROM dbo.Solicitud_Ingreso AS s
    LEFT JOIN dbo.Cat_Tipo_Ingreso AS ti ON ti.IdTipoIngreso = s.IdTipoIngreso
    LEFT JOIN dbo.Cat_Estado_Solicitud AS es ON es.IdEstadoSolicitud = s.IdEstadoSolicitud
    LEFT JOIN dbo.Solicitud_Persona AS sp ON sp.IdSolicitud = s.IdSolicitud
    WHERE s.IdUsuarioSolicitante = @IdUsuario
    GROUP BY s.IdSolicitud, s.NumeroSolicitud, ti.Nombre, es.Nombre,
             s.FechaInicio, s.FechaFin, s.NombreActividad,
             s.IdUsuarioSolicitante, s.FechaCreacion
    ORDER BY s.FechaCreacion DESC, s.IdSolicitud DESC;
END;
GO

-- dbo.usp_Usuario_Rol_Asignar
CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Rol_Asignar
    @IdUsuario VARCHAR(50),@CodigoRol VARCHAR(30),@UsuarioAsignacion VARCHAR(50)
AS
BEGIN
 SET NOCOUNT ON;
 SET @CodigoRol=UPPER(LTRIM(RTRIM(@CodigoRol)));
 IF NOT EXISTS(SELECT 1 FROM dbo.Usuario WHERE IdUsuario=@IdUsuario) THROW 50520,'El usuario no existe.',1;
 IF @CodigoRol='GUARDIA' AND NOT EXISTS(SELECT 1 FROM dbo.Rol WHERE Codigo='GUARDIA')
 BEGIN
  DECLARE @NuevoIdRol SMALLINT=(SELECT CONVERT(SMALLINT,ISNULL(MAX(IdRol),0)+1) FROM dbo.Rol WITH(UPDLOCK,HOLDLOCK));
  INSERT dbo.Rol(IdRol,Codigo,Nombre,Descripcion,Activo)
  VALUES(@NuevoIdRol,'GUARDIA',N'Guardia',N'Solo escanea códigos QR y consulta los resultados.',1);
 END;
 DECLARE @IdRol SMALLINT=(SELECT IdRol FROM dbo.Rol WHERE Codigo=@CodigoRol AND Activo=1);
 IF @IdRol IS NULL THROW 50521,'El rol solicitado no existe.',1;
 IF @CodigoRol='GUARDIA'
  DELETE ur FROM dbo.Usuario_Rol ur INNER JOIN dbo.Rol r ON r.IdRol=ur.IdRol
  WHERE ur.IdUsuario=@IdUsuario AND r.Codigo IN('SOLICITANTE','APROBADOR','RESPONSABLE','SEGURIDAD');
 IF NOT EXISTS(SELECT 1 FROM dbo.Usuario_Rol WHERE IdUsuario=@IdUsuario AND IdRol=@IdRol)
  INSERT dbo.Usuario_Rol(IdUsuario,IdRol,UsuarioAsignacion) VALUES(@IdUsuario,@IdRol,@UsuarioAsignacion);
END;
GO

