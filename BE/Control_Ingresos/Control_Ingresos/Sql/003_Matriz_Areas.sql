SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @Areas TABLE (Codigo VARCHAR(30) PRIMARY KEY, Nombre NVARCHAR(150));
INSERT @Areas (Codigo, Nombre) VALUES
('CENTRO_INTEGRACION', N'Centro de Integracion'),
('TAJO', N'Tajo'),
('BOTADEROS', N'Botaderos'),
('MIRADORES', N'Miradores'),
('TALLER_EDI', N'Taller EDI'),
('PAD_POZAS_1_6', N'PAD y Pozas 1 a 6'),
('PLANTA_ADR_LABORATORIO', N'Planta ADR y Laboratorio'),
('METALURGIA', N'Metalurgia'),
('AGLOMERADOR', N'Aglomerador'),
('TRITURACION_PRIMARIA', N'Trituracion Primaria'),
('TRITURACION_SECUNDARIA', N'Trituracion Secundaria'),
('SUBESTACION', N'Subestacion'),
('TALLER_MANTENIMIENTO', N'Taller Mantenimiento'),
('ALMACEN', N'Almacen'),
('ASERRADERO', N'Aserradero'),
('INCINERADOR', N'Incinerador'),
('CENTRO_ACOPIO', N'Centro de Acopio'),
('VIVERO', N'Vivero'),
('POLVORIN', N'Polvorin'),
('REFINERIA', N'Refineria');

DECLARE @Ultimo BIGINT = (SELECT ISNULL(MAX(CONVERT(BIGINT, IdArea)), 0) FROM dbo.Cat_Area);
UPDATE dbo.Control_Secuencia WITH (UPDLOCK, HOLDLOCK)
   SET UltimoValor = CASE WHEN ISNULL(UltimoValor, 0) < @Ultimo THEN @Ultimo ELSE UltimoValor END
 WHERE NombreEntidad = 'Cat_Area';
IF @@ROWCOUNT = 0
    INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
    VALUES ('Cat_Area', @Ultimo, SYSDATETIME(), 'SYSTEM_SEED');

DECLARE @Codigo VARCHAR(30), @Nombre NVARCHAR(150), @Id BIGINT;
DECLARE areas_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT Codigo, Nombre FROM @Areas ORDER BY Codigo;
OPEN areas_cursor;
FETCH NEXT FROM areas_cursor INTO @Codigo, @Nombre;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE Codigo = @Codigo)
    BEGIN
        EXEC dbo.usp_ObtenerSiguienteId 'Cat_Area', @Id OUTPUT;
        INSERT dbo.Cat_Area
            (IdArea, Codigo, Nombre, Descripcion, RequiereAprobacion,
             EsAreaResponsable, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
        VALUES
            (CONVERT(INT, @Id), @Codigo, @Nombre, N'Area de acceso de la matriz.', 0,
             0, 1, SYSDATETIME(), 'SYSTEM_SEED');
    END;
    FETCH NEXT FROM areas_cursor INTO @Codigo, @Nombre;
END;
CLOSE areas_cursor;
DEALLOCATE areas_cursor;

COMMIT TRANSACTION;
