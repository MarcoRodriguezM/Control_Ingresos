/*
  Consulta parametrizada de fotografía de empleado almacenada en Control_Ingresos_DB.
  El backend obtiene este texto y envía @COD_EMPLEADO al ejecutarlo en HTIS.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

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
