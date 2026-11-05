DECLARE @Definicion NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.usp_Usuario_Actualizar'));
DECLARE @Anterior NVARCHAR(MAX) = N'WHERE IdUsuarioAprobador = @IdUsuario;';
DECLARE @Nueva NVARCHAR(MAX) =
    N'WHERE IdUsuarioAprobador = @IdUsuario AND (ISNULL(EsPrincipal, 0) = 1 OR @EsAprobador = 0);';

IF @Definicion IS NULL
    THROW 50740, 'No se encontro el procedimiento de usuarios.', 1;

IF CHARINDEX(@Nueva, @Definicion) = 0
BEGIN
    IF CHARINDEX(@Anterior, @Definicion) = 0
        THROW 50741, 'El procedimiento de usuarios tiene una version inesperada.', 1;
    SET @Definicion = REPLACE(@Definicion, @Anterior, @Nueva);
    SET @Definicion = REPLACE(@Definicion, N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE');
    SET @Definicion = REPLACE(@Definicion, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE');
    EXEC sys.sp_executesql @Definicion;
END;
