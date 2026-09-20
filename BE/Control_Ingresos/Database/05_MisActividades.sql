/* Ejecutar una vez en Control_Ingresos_DB. No se copia ni ejecuta al iniciar la API. */
USE [Control_Ingresos_DB];

EXEC(N'
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
');
