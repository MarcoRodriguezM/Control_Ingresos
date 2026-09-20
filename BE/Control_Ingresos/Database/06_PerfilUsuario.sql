/* Ejecutar una vez en Control_Ingresos_DB. La API no ejecuta scripts al iniciar. */
USE [Control_Ingresos_DB];

EXEC(N'
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
');
