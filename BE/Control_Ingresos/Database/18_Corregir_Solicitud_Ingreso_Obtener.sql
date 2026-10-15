USE [Control_Ingresos_DB];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

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
            WHEN ISNULL(resumen.AreasPendientes, 0) > 0 THEN N'Pendiente de aprobación'
            WHEN ISNULL(resumen.AreasRequeridas, 0) = 0 THEN N'No requiere aprobación'
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
                    COALESCE(a.Nombre, N'Área sin nombre'),
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
