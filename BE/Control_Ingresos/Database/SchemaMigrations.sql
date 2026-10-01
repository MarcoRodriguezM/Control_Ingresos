/*
    Migraciones estructurales posteriores al esquema base.
    Este archivo no contiene procedimientos almacenados; las definiciones activas
    están consolidadas en Control_Ingresos/Database/StoredProcedures.sql.
*/
USE [Control_Ingresos_DB];
GO

/* Identificador opaco usado por el flujo QR. */
IF COL_LENGTH('dbo.Persona', 'CodigoQr') IS NULL
BEGIN
    ALTER TABLE dbo.Persona ADD CodigoQr VARCHAR(64) NULL;
END;
GO

UPDATE dbo.Persona
   SET CodigoQr = LOWER(CONVERT(VARCHAR(64), HASHBYTES
       (
           'SHA2_256',
           CONCAT(CONVERT(VARCHAR(36), NEWID()), ':', IdPersona, ':', CONVERT(VARCHAR(33), SYSDATETIME(), 126))
       ), 2))
 WHERE CodigoQr IS NULL;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Persona')
      AND name = 'UX_Persona_CodigoQr'
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_Persona_CodigoQr
        ON dbo.Persona (CodigoQr)
        WHERE CodigoQr IS NOT NULL;
END;
GO

/* Nombre visible final del estado consolidado. */
UPDATE dbo.Cat_Estado_Solicitud
   SET Nombre = N'Listo para ingresar'
 WHERE Codigo = 'LISTA_INGRESO';
GO
