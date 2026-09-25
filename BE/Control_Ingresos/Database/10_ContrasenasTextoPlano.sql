/*
    Migra las credenciales al almacenamiento en texto plano solicitado.
    ADVERTENCIA: este diseño expone las contraseñas ante una filtración de la base de datos.
*/
USE [Control_Ingresos_DB];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF COL_LENGTH('dbo.Usuario_Credencial', 'Contrasena') IS NULL
BEGIN
    ALTER TABLE dbo.Usuario_Credencial
        ADD Contrasena VARCHAR(200) NULL;
END;
GO

/* La columna heredada debe aceptar NULL porque deja de utilizarse. */
ALTER TABLE dbo.Usuario_Credencial
    ALTER COLUMN PasswordHash VARBINARY(32) NULL;
GO

/*
   Las credenciales existentes fueron verificadas contra la clave de demostración.
   Solo se migra una fila si su hash realmente coincide; no se adivinan contraseñas.
*/
UPDATE credencial
SET credencial.Contrasena = 'Control2026!',
    credencial.FechaModificacion = SYSDATETIME(),
    credencial.UsuarioModificacion = 'MIGRACION_TEXTO_PLANO'
FROM dbo.Usuario_Credencial AS credencial
WHERE credencial.Contrasena IS NULL
  AND credencial.PasswordHash = HASHBYTES(
      'SHA2_256',
      CONVERT(VARBINARY(MAX), CONCAT(credencial.IdUsuario, ':', 'Control2026!'))
  );
GO

IF EXISTS (SELECT 1 FROM dbo.Usuario_Credencial WHERE Contrasena IS NULL)
BEGIN
    THROW 50400, 'Hay credenciales cuyo texto original no puede recuperarse. Asigne una contraseña antes de completar la migración.', 1;
END;
GO

ALTER TABLE dbo.Usuario_Credencial
    ALTER COLUMN Contrasena VARCHAR(200) NOT NULL;
GO

/* Elimina los hashes anteriores; desde este punto la fuente válida es Contrasena. */
UPDATE dbo.Usuario_Credencial
SET PasswordHash = NULL;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Autenticar
    @Usuario VARCHAR(254),
    @Contrasena VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@Usuario)), '') IS NULL
       OR NULLIF(@Contrasena, '') IS NULL
        RETURN;

    SELECT TOP (1)
        u.IdUsuario,
        u.NombreCompleto,
        u.Correo,
        u.Puesto,
        areaPrincipal.IdArea,
        areaPrincipal.Area,
        CONVERT(BIT, CASE WHEN EXISTS
        (
            SELECT 1
            FROM dbo.Config_Aprobador_Area AS ca
            WHERE ca.IdUsuarioAprobador = u.IdUsuario
              AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
              AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ) THEN 1 ELSE 0 END) AS EsAprobador,
        CONVERT(BIT, CASE WHEN EXISTS
        (
            SELECT 1
            FROM dbo.Usuario_Area AS ua
            WHERE ua.IdUsuario = u.IdUsuario
              AND ISNULL(ua.PuedeSolicitar, 0) = 1
              AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
              AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ) THEN 1 ELSE 0 END) AS PuedeSolicitar
    FROM dbo.Usuario AS u
    INNER JOIN dbo.Usuario_Credencial AS c ON c.IdUsuario = u.IdUsuario
    LEFT JOIN dbo.Cat_Estado_General AS eg ON eg.IdEstadoGeneral = u.IdEstadoGeneral
    OUTER APPLY
    (
        SELECT TOP (1) ua.IdArea, a.Nombre AS Area
        FROM dbo.Usuario_Area AS ua
        LEFT JOIN dbo.Cat_Area AS a ON a.IdArea = ua.IdArea
        WHERE ua.IdUsuario = u.IdUsuario
          AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
          AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ORDER BY ISNULL(ua.EsAreaPrincipal, 0) DESC, ua.IdUsuarioArea
    ) AS areaPrincipal
    WHERE (u.IdUsuario = @Usuario OR u.Correo = @Usuario)
      AND c.Contrasena = @Contrasena
      AND ISNULL(eg.EsActivo, 1) = 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Administracion_Listar
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.IdUsuario,
           u.NombreCompleto,
           u.Correo,
           u.Telefono,
           u.Puesto,
           areaPrincipal.IdArea,
           areaPrincipal.Area,
           CONVERT(BIT, CASE WHEN EXISTS
           (
               SELECT 1 FROM dbo.Usuario_Area ua
               WHERE ua.IdUsuario = u.IdUsuario
                 AND ISNULL(ua.PuedeSolicitar, 0) = 1
                 AND ISNULL(ua.IdEstadoGeneral, 1) = 1
                 AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                 AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
           ) THEN 1 ELSE 0 END) AS PuedeSolicitar,
           CONVERT(BIT, CASE WHEN EXISTS
           (
               SELECT 1 FROM dbo.Config_Aprobador_Area ca
               WHERE ca.IdUsuarioAprobador = u.IdUsuario
                 AND ISNULL(ca.IdEstadoGeneral, 1) = 1
                 AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                 AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
           ) THEN 1 ELSE 0 END) AS EsAprobador,
           CONVERT(BIT, CASE WHEN ISNULL(u.IdEstadoGeneral, 1) = 1 THEN 1 ELSE 0 END) AS Activo,
           u.FechaCreacion,
           credencial.Contrasena
    FROM dbo.Usuario u
    LEFT JOIN dbo.Usuario_Credencial credencial ON credencial.IdUsuario = u.IdUsuario
    OUTER APPLY
    (
        SELECT TOP (1) ua.IdArea, a.Nombre AS Area
        FROM dbo.Usuario_Area ua
        LEFT JOIN dbo.Cat_Area a ON a.IdArea = ua.IdArea
        WHERE ua.IdUsuario = u.IdUsuario
          AND ISNULL(ua.IdEstadoGeneral, 1) = 1
        ORDER BY ISNULL(ua.EsAreaPrincipal, 0) DESC, ua.IdUsuarioArea
    ) areaPrincipal
    ORDER BY u.NombreCompleto, u.IdUsuario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Crear
    @IdUsuario VARCHAR(50),
    @NombreCompleto NVARCHAR(200),
    @Correo VARCHAR(254) = NULL,
    @Telefono VARCHAR(30) = NULL,
    @Puesto NVARCHAR(150) = NULL,
    @Contrasena VARCHAR(200),
    @IdArea INT = NULL,
    @PuedeSolicitar BIT = 0,
    @EsAprobador BIT = 0,
    @Activo BIT = 1,
    @UsuarioCreacion VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IdUsuario = LTRIM(RTRIM(@IdUsuario));
    IF NULLIF(@IdUsuario, '') IS NULL THROW 50300, 'El identificador del usuario es obligatorio.', 1;
    IF NULLIF(LTRIM(RTRIM(@NombreCompleto)), '') IS NULL THROW 50301, 'El nombre completo es obligatorio.', 1;
    IF LEN(ISNULL(@Contrasena, '')) < 8 THROW 50302, 'La contraseña inicial debe tener al menos 8 caracteres.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuario) THROW 50303, 'Ya existe un usuario con ese identificador.', 1;
    IF @Correo IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Usuario WHERE Correo = @Correo) THROW 50304, 'Ya existe un usuario con ese correo.', 1;
    IF @IdArea IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdArea) THROW 50305, 'El área seleccionada no existe.', 1;
    IF (@PuedeSolicitar = 1 OR @EsAprobador = 1) AND @IdArea IS NULL THROW 50306, 'Debe seleccionar un área para asignar permisos.', 1;

    DECLARE @IdEstadoActivo SMALLINT = COALESCE((SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'ACTIVO'), 1);
    DECLARE @IdEstadoInactivo SMALLINT = COALESCE((SELECT TOP (1) IdEstadoGeneral FROM dbo.Cat_Estado_General WHERE Codigo = 'INACTIVO'), 2);
    DECLARE @IdEstadoGeneral SMALLINT = CASE WHEN @Activo = 1 THEN @IdEstadoActivo ELSE @IdEstadoInactivo END;

    BEGIN TRANSACTION;

    INSERT dbo.Usuario (IdUsuario, NombreCompleto, Correo, Telefono, Puesto, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (@IdUsuario, @NombreCompleto, NULLIF(LTRIM(RTRIM(@Correo)), ''), NULLIF(LTRIM(RTRIM(@Telefono)), ''), NULLIF(LTRIM(RTRIM(@Puesto)), ''), @IdEstadoGeneral, SYSDATETIME(), @UsuarioCreacion);

    INSERT dbo.Usuario_Credencial (IdUsuario, PasswordHash, Contrasena, FechaCreacion, UsuarioCreacion)
    VALUES (@IdUsuario, NULL, @Contrasena, SYSDATETIME(), @UsuarioCreacion);

    IF @IdArea IS NOT NULL
    BEGIN
        DECLARE @IdUsuarioArea BIGINT;
        EXEC dbo.usp_ObtenerSiguienteId 'Usuario_Area', @IdUsuarioArea OUTPUT;
        INSERT dbo.Usuario_Area (IdUsuarioArea, IdUsuario, IdArea, PuedeSolicitar, EsAreaPrincipal, FechaInicio, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
        VALUES (@IdUsuarioArea, @IdUsuario, @IdArea, ISNULL(@PuedeSolicitar, 0), 1, CONVERT(DATE, SYSDATETIME()), @IdEstadoGeneral, SYSDATETIME(), @UsuarioCreacion);

        IF @EsAprobador = 1
        BEGIN
            DECLARE @IdConfigAprobador BIGINT;
            EXEC dbo.usp_ObtenerSiguienteId 'Config_Aprobador_Area', @IdConfigAprobador OUTPUT;
            INSERT dbo.Config_Aprobador_Area (IdConfigAprobador, IdArea, IdUsuarioAprobador, EsPrincipal, FechaInicio, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
            VALUES (@IdConfigAprobador, @IdArea, @IdUsuario, 1, CONVERT(DATE, SYSDATETIME()), @IdEstadoGeneral, SYSDATETIME(), @UsuarioCreacion);
        END;
    END;

    COMMIT TRANSACTION;
    SELECT @IdUsuario;
END;
GO
