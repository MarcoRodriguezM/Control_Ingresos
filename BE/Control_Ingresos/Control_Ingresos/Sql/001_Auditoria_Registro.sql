IF OBJECT_ID(N'dbo.Auditoria_Registro', N'U') IS NULL
BEGIN
    EXEC(N'
        CREATE TABLE dbo.Auditoria_Registro
        (
            Id UNIQUEIDENTIFIER NOT NULL,
            Fecha DATETIMEOFFSET(3) NOT NULL,
            Usuario NVARCHAR(254) NOT NULL,
            NombreUsuario NVARCHAR(200) NOT NULL,
            Metodo VARCHAR(10) NOT NULL,
            Recurso NVARCHAR(300) NOT NULL,
            Referencia NVARCHAR(200) NULL,
            Estado SMALLINT NOT NULL,
            CONSTRAINT PK_Auditoria_Registro PRIMARY KEY (Id)
        );
    ');
END;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Auditoria_Registro', N'U')
      AND name = N'IX_Auditoria_Registro_Fecha'
)
BEGIN
    EXEC(N'CREATE INDEX IX_Auditoria_Registro_Fecha
        ON dbo.Auditoria_Registro (Fecha DESC, Id DESC);');
END;
