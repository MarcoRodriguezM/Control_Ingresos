/*
    Repara instalaciones donde la tabla Usuario contiene Usuario_Password,
    pero no se creó Usuario_Credencial, requerida por el backend.
    El script es idempotente y no crea llaves foráneas.
*/
USE [Control_Ingresos_DB];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.Usuario_Credencial', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Usuario_Credencial
    (
        IdUsuario VARCHAR(50) NOT NULL,
        PasswordHash VARBINARY(32) NULL,
        Contrasena VARCHAR(200) NOT NULL,
        FechaCreacion DATETIME2(3) NOT NULL
            CONSTRAINT DF_Usuario_Credencial_FechaCreacion DEFAULT SYSDATETIME(),
        UsuarioCreacion VARCHAR(50) NULL,
        FechaModificacion DATETIME2(3) NULL,
        UsuarioModificacion VARCHAR(50) NULL,
        CONSTRAINT PK_Usuario_Credencial PRIMARY KEY CLUSTERED (IdUsuario)
    );
END;
GO

/* Migra exclusivamente contraseñas existentes; no genera ni reemplaza claves. */
IF COL_LENGTH(N'dbo.Usuario', N'Usuario_Password') IS NULL
    THROW 50410, 'No existe una fuente de contraseñas para migrar.', 1;

EXEC sys.sp_executesql N'
    INSERT dbo.Usuario_Credencial
    (
        IdUsuario,
        PasswordHash,
        Contrasena,
        FechaCreacion,
        UsuarioCreacion
    )
    SELECT
        u.IdUsuario,
        NULL,
        u.Usuario_Password,
        COALESCE(u.FechaCreacion, SYSDATETIME()),
        COALESCE(u.UsuarioCreacion, ''MIGRACION_CREDENCIAL'')
    FROM dbo.Usuario AS u
    WHERE NULLIF(u.Usuario_Password, '''') IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.Usuario_Credencial AS c
          WHERE c.IdUsuario = u.IdUsuario
      );';
GO

SELECT
    COUNT(*) AS CredencialesDisponibles
FROM dbo.Usuario_Credencial;
GO
