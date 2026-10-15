/*
  Catálogo de estados de empleados utilizado para traducir COD_STATUS.
  La tabla dbo.Cat_Empleado_Status debe existir previamente.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

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
