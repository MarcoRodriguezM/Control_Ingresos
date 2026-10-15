USE [Control_Ingresos_DB];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.Empleado_Qr', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Empleado_Qr
    (
        CodigoEmpleado VARCHAR(50) NOT NULL,
        CodigoQr VARCHAR(64) NULL,
        CONSTRAINT PK_Empleado_Qr PRIMARY KEY CLUSTERED (CodigoEmpleado)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Empleado_Qr')
      AND name = 'UX_Empleado_Qr_CodigoQr'
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_Empleado_Qr_CodigoQr
        ON dbo.Empleado_Qr (CodigoQr)
        WHERE CodigoQr IS NOT NULL;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Empleado_Qr_Obtener
    @CodigoEmpleado VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @CodigoEmpleado = LTRIM(RTRIM(@CodigoEmpleado));
    IF NULLIF(@CodigoEmpleado, '') IS NULL RETURN;

    DECLARE @CodigoQr VARCHAR(64);

    BEGIN TRANSACTION;

    SELECT @CodigoQr = CodigoQr
    FROM dbo.Empleado_Qr WITH (UPDLOCK, HOLDLOCK)
    WHERE CodigoEmpleado = @CodigoEmpleado;

    IF @CodigoQr IS NULL
    BEGIN
        SET @CodigoQr = LOWER(CONVERT(VARCHAR(64), HASHBYTES
        (
            'SHA2_256',
            CONCAT(CONVERT(VARCHAR(36), NEWID()), ':', @CodigoEmpleado, ':', CONVERT(VARCHAR(33), SYSDATETIME(), 126))
        ), 2));

        IF EXISTS (SELECT 1 FROM dbo.Empleado_Qr WHERE CodigoEmpleado = @CodigoEmpleado)
        BEGIN
            UPDATE dbo.Empleado_Qr
               SET CodigoQr = @CodigoQr
             WHERE CodigoEmpleado = @CodigoEmpleado;
        END
        ELSE
        BEGIN
            INSERT dbo.Empleado_Qr (CodigoEmpleado, CodigoQr)
            VALUES (@CodigoEmpleado, @CodigoQr);
        END;
    END;

    COMMIT TRANSACTION;

    SELECT @CodigoQr AS CodigoQr;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Empleado_Qr_Consultar
    @CodigoQr VARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CodigoEmpleado
    FROM dbo.Empleado_Qr
    WHERE CodigoQr = LOWER(LTRIM(RTRIM(@CodigoQr)));
END;
GO
