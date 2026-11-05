SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ResultadoBloqueo INT;
    EXEC @ResultadoBloqueo = sys.sp_getapplock
        @Resource = N'Cat_Tipo_Ingreso_PROVEEDOR',
        @LockMode = N'Exclusive',
        @LockOwner = N'Transaction',
        @LockTimeout = 15000;
    IF @ResultadoBloqueo < 0
        THROW 51000, 'No se pudo bloquear el catalogo de tipos de ingreso.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Ingreso WHERE Codigo = 'PROVEEDOR')
    BEGIN
        DECLARE @UltimoId BIGINT =
            (SELECT ISNULL(MAX(CONVERT(BIGINT, IdTipoIngreso)), 0) FROM dbo.Cat_Tipo_Ingreso);

        UPDATE dbo.Control_Secuencia WITH (UPDLOCK, HOLDLOCK)
           SET UltimoValor = CASE WHEN ISNULL(UltimoValor, 0) < @UltimoId
                                  THEN @UltimoId ELSE UltimoValor END,
               FechaModificacion = SYSDATETIME(),
               UsuarioModificacion = 'SYSTEM_SEED'
         WHERE NombreEntidad = 'Cat_Tipo_Ingreso';

        IF @@ROWCOUNT = 0
            INSERT dbo.Control_Secuencia
                (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
            VALUES ('Cat_Tipo_Ingreso', @UltimoId, SYSDATETIME(), 'SYSTEM_SEED');

        DECLARE @IdTipoIngreso BIGINT;
        EXEC dbo.usp_ObtenerSiguienteId 'Cat_Tipo_Ingreso', @IdTipoIngreso OUTPUT;

        INSERT dbo.Cat_Tipo_Ingreso
            (IdTipoIngreso, Codigo, Nombre, Descripcion, IdEstadoGeneral,
             FechaCreacion, UsuarioCreacion)
        VALUES
            (CONVERT(SMALLINT, @IdTipoIngreso), 'PROVEEDOR', N'Proveedor',
             N'Ingreso de personas vinculadas a un proveedor.', 1,
             SYSDATETIME(), 'SYSTEM_SEED');
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
