/* Ejecutar una vez en Control_Ingresos_DB. La API no ejecuta scripts al iniciar. */
USE [Control_Ingresos_DB];

EXEC(N'
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
                      THEN N''No requiere aprobación'' ELSE N''Pendiente'' END) AS EstadoAcceso,
        COALESCE(ultimaAprobacion.CodigoEstadoAcceso,
                 CASE WHEN COALESCE(spa.RequiereAprobacion, a.RequiereAprobacion, 0) = 0
                      THEN ''NO_REQUIERE'' ELSE ''PENDIENTE'' END) AS CodigoEstadoAcceso,
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
            ea.Codigo AS CodigoEstadoAcceso,
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
');
