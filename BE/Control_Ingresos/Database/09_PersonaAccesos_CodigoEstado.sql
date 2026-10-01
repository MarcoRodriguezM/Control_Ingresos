/*
    Listado y detalle de personas con accesos visibles para el usuario autenticado.
    Las definiciones activas también se encuentran en Database/StoredProcedures.sql.
*/
USE [Control_Ingresos_DB];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
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

