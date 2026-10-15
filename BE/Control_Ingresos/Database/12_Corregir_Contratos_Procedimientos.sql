SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Autenticar
    @Usuario VARCHAR(254),
    @Contrasena VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@Usuario)), '') IS NULL OR NULLIF(@Contrasena, '') IS NULL
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
              AND ISNULL(ca.IdEstadoGeneral, 1) = 1
              AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
              AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ) THEN 1 ELSE 0 END) AS EsAprobador,
        CONVERT(BIT, CASE WHEN EXISTS
        (
            SELECT 1
            FROM dbo.Usuario_Area AS ua
            WHERE ua.IdUsuario = u.IdUsuario
              AND ISNULL(ua.PuedeSolicitar, 0) = 1
              AND ISNULL(ua.IdEstadoGeneral, 1) = 1
              AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
              AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ) THEN 1 ELSE 0 END) AS PuedeSolicitar,
        roles.Roles
    FROM dbo.Usuario AS u
    LEFT JOIN dbo.Cat_Estado_General AS eg ON eg.IdEstadoGeneral = u.IdEstadoGeneral
    OUTER APPLY
    (
        SELECT TOP (1) ua.IdArea, area.Nombre AS Area
        FROM dbo.Usuario_Area AS ua
        LEFT JOIN dbo.Cat_Area AS area ON area.IdArea = ua.IdArea
        WHERE ua.IdUsuario = u.IdUsuario
          AND ISNULL(ua.IdEstadoGeneral, 1) = 1
          AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
          AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ORDER BY ISNULL(ua.EsAreaPrincipal, 0) DESC, ua.IdUsuarioArea
    ) AS areaPrincipal
    OUTER APPLY
    (
        SELECT STRING_AGG(r.Nombre, ',') AS Roles
        FROM dbo.Usuario_Rol AS ur
        INNER JOIN dbo.Rol AS r ON r.IdRol = ur.IdRol
        WHERE ur.IdUsuario = u.IdUsuario
          AND ISNULL(r.Activo, 1) = 1
    ) AS roles
    WHERE (u.IdUsuario = @Usuario OR u.Correo = @Usuario)
      AND u.Usuario_Password = @Contrasena
      AND ISNULL(eg.EsActivo, 1) = 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Administracion_Listar
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.IdUsuario,
           u.NombreCompleto,
           u.Correo,
           u.Telefono,
           u.Puesto,
           areaPrincipal.IdArea,
           areaPrincipal.Area,
           CONVERT(BIT, CASE WHEN EXISTS
           (
               SELECT 1
               FROM dbo.Usuario_Area AS ua
               WHERE ua.IdUsuario = u.IdUsuario
                 AND ISNULL(ua.PuedeSolicitar, 0) = 1
                 AND ISNULL(ua.IdEstadoGeneral, 1) = 1
                 AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                 AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
           ) THEN 1 ELSE 0 END) AS PuedeSolicitar,
           CONVERT(BIT, CASE WHEN EXISTS
           (
               SELECT 1
               FROM dbo.Config_Aprobador_Area AS ca
               WHERE ca.IdUsuarioAprobador = u.IdUsuario
                 AND ISNULL(ca.IdEstadoGeneral, 1) = 1
                 AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                 AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
           ) THEN 1 ELSE 0 END) AS EsAprobador,
           CONVERT(BIT, CASE WHEN ISNULL(u.IdEstadoGeneral, 1) = 1 THEN 1 ELSE 0 END) AS Activo,
           u.FechaCreacion,
           roles.Roles
    FROM dbo.Usuario AS u
    OUTER APPLY
    (
        SELECT TOP (1) ua.IdArea, area.Nombre AS Area
        FROM dbo.Usuario_Area AS ua
        LEFT JOIN dbo.Cat_Area AS area ON area.IdArea = ua.IdArea
        WHERE ua.IdUsuario = u.IdUsuario
          AND ISNULL(ua.IdEstadoGeneral, 1) = 1
        ORDER BY ISNULL(ua.EsAreaPrincipal, 0) DESC, ua.IdUsuarioArea
    ) AS areaPrincipal
    OUTER APPLY
    (
        SELECT STRING_AGG(r.Nombre, ',') AS Roles
        FROM dbo.Usuario_Rol AS ur
        INNER JOIN dbo.Rol AS r ON r.IdRol = ur.IdRol
        WHERE ur.IdUsuario = u.IdUsuario
          AND ISNULL(r.Activo, 1) = 1
    ) AS roles
    ORDER BY u.NombreCompleto, u.IdUsuario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Solicitud_Ingreso_Listar
    @IdUsuario VARCHAR(50),
    @AccesoTotal BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.IdSolicitud,
           s.NumeroSolicitud,
           ti.Nombre,
           es.Nombre,
           s.FechaInicio,
           s.FechaFin,
           s.NombreActividad,
           u.NombreCompleto,
           CONVERT(INT, COUNT(sp.IdSolicitudPersona))
    FROM dbo.Solicitud_Ingreso AS s
    LEFT JOIN dbo.Cat_Tipo_Ingreso AS ti ON ti.IdTipoIngreso = s.IdTipoIngreso
    LEFT JOIN dbo.Cat_Estado_Solicitud AS es ON es.IdEstadoSolicitud = s.IdEstadoSolicitud
    LEFT JOIN dbo.Usuario AS u ON u.IdUsuario = s.IdUsuarioSolicitante
    LEFT JOIN dbo.Solicitud_Persona AS sp ON sp.IdSolicitud = s.IdSolicitud
    WHERE (@AccesoTotal = 1 OR s.IdUsuarioSolicitante = @IdUsuario)
      AND ISNULL(es.Codigo, '') <> 'CANCELADA'
    GROUP BY s.IdSolicitud, s.NumeroSolicitud, ti.Nombre, es.Nombre,
             s.FechaInicio, s.FechaFin, s.NombreActividad, u.NombreCompleto, s.FechaCreacion
    ORDER BY s.FechaCreacion DESC, s.IdSolicitud DESC;
END;
GO
