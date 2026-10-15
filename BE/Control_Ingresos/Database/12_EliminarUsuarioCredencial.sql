/*
    Retira la tabla auxiliar dbo.Usuario_Credencial.
    La unica fuente de contrasena de la aplicacion es dbo.Usuario.Usuario_Password.
    No crea tablas ni agrega, modifica o elimina columnas.
*/
USE [Control_Ingresos_DB];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF COL_LENGTH(N'dbo.Usuario', N'Usuario_Password') IS NULL
    THROW 50410, 'dbo.Usuario.Usuario_Password no existe; no es seguro retirar la tabla auxiliar.', 1;
GO

IF OBJECT_ID(N'dbo.Usuario_Credencial', N'U') IS NOT NULL
BEGIN
    /* Conserva cualquier contrasena que solo estuviera en la tabla auxiliar. */
    EXEC sys.sp_executesql N'
        UPDATE u
           SET u.Usuario_Password = c.Contrasena,
               u.FechaModificacion = SYSDATETIME(),
               u.UsuarioModificacion = COALESCE(c.UsuarioModificacion, c.UsuarioCreacion, ''MIGRACION_CREDENCIAL'')
        FROM dbo.Usuario AS u
        INNER JOIN dbo.Usuario_Credencial AS c ON c.IdUsuario = u.IdUsuario
        WHERE NULLIF(u.Usuario_Password, '''') IS NULL
          AND NULLIF(c.Contrasena, '''') IS NOT NULL;';

    DROP TABLE dbo.Usuario_Credencial;
END;
GO

SELECT
    CASE WHEN OBJECT_ID(N'dbo.Usuario_Credencial', N'U') IS NULL THEN 1 ELSE 0 END AS TablaEliminada;
GO
