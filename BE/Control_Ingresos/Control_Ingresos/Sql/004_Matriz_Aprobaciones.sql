CREATE OR ALTER FUNCTION dbo.fn_Matriz_Area_Permitida
(
    @Tipo VARCHAR(30), @Area VARCHAR(30)
)
RETURNS BIT
AS
BEGIN
    DECLARE @Permitida BIT = 0;
    IF @Area IN
    (
        'CENTRO_INTEGRACION', 'TAJO', 'BOTADEROS', 'MIRADORES', 'TALLER_EDI',
        'PAD_POZAS_1_6', 'PLANTA_ADR_LABORATORIO', 'METALURGIA', 'AGLOMERADOR',
        'TRITURACION_PRIMARIA', 'TRITURACION_SECUNDARIA', 'SUBESTACION',
        'TALLER_MANTENIMIENTO', 'ALMACEN', 'ASERRADERO', 'INCINERADOR',
        'CENTRO_ACOPIO', 'VIVERO', 'POLVORIN', 'REFINERIA'
    )
    AND
    (
        @Tipo IN ('EMPLEADO', 'NUEVO_EMPLEADO')
        OR (@Tipo = 'PROVEEDOR' AND @Area <> 'REFINERIA')
        OR (@Tipo IN ('VISITA', 'PRACTICANTE', 'SERV_PROF') AND @Area = 'CENTRO_INTEGRACION')
    ) SET @Permitida = 1;
    RETURN @Permitida;
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_Matriz_Area_RequiereAprobacion
(
    @Tipo VARCHAR(30), @Area VARCHAR(30)
)
RETURNS BIT
AS
BEGIN
    DECLARE @Requiere BIT = 0;
    IF dbo.fn_Matriz_Area_Permitida(@Tipo, @Area) = 1
       AND
       (
           (@Tipo IN ('EMPLEADO', 'NUEVO_EMPLEADO') AND @Area IN ('POLVORIN', 'REFINERIA'))
           OR @Tipo IN ('PROVEEDOR', 'VISITA', 'PRACTICANTE', 'SERV_PROF')
       ) SET @Requiere = 1;
    RETURN @Requiere;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Matriz_Solicitud_Persona_Area
ON dbo.Solicitud_Persona_Area
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    IF UPDATE(IdArea) OR UPDATE(IdSolicitudPersona)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM inserted AS i
            LEFT JOIN deleted AS d ON d.IdSolicitudPersonaArea = i.IdSolicitudPersonaArea
            INNER JOIN dbo.Solicitud_Persona AS sp ON sp.IdSolicitudPersona = i.IdSolicitudPersona
            INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = sp.IdSolicitud
            INNER JOIN dbo.Cat_Tipo_Ingreso AS ti ON ti.IdTipoIngreso = s.IdTipoIngreso
            INNER JOIN dbo.Cat_Area AS a ON a.IdArea = i.IdArea
            WHERE (d.IdSolicitudPersonaArea IS NULL OR d.IdArea <> i.IdArea)
              AND dbo.fn_Matriz_Area_Permitida(ti.Codigo, a.Codigo) = 0
        ) THROW 50710, 'El area no esta permitida para este tipo de ingreso.', 1;
    END;

    DECLARE @Pendiente SMALLINT =
        (SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'PENDIENTE');
    DECLARE @NoRequiere SMALLINT =
        (SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'NO_REQUIERE');

    UPDATE spa
       SET RequiereAprobacion = politica.Requiere,
           IdEstadoAprobacion = CASE WHEN politica.Requiere = 1 THEN @Pendiente ELSE @NoRequiere END
    FROM dbo.Solicitud_Persona_Area AS spa
    INNER JOIN inserted AS i ON i.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
    INNER JOIN dbo.Solicitud_Persona AS sp ON sp.IdSolicitudPersona = spa.IdSolicitudPersona
    INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = sp.IdSolicitud
    INNER JOIN dbo.Cat_Tipo_Ingreso AS ti ON ti.IdTipoIngreso = s.IdTipoIngreso
    INNER JOIN dbo.Cat_Area AS a ON a.IdArea = spa.IdArea
    CROSS APPLY (SELECT dbo.fn_Matriz_Area_RequiereAprobacion(ti.Codigo, a.Codigo) AS Requiere) AS politica
    WHERE a.Codigo IN
    (
        'CENTRO_INTEGRACION', 'TAJO', 'BOTADEROS', 'MIRADORES', 'TALLER_EDI',
        'PAD_POZAS_1_6', 'PLANTA_ADR_LABORATORIO', 'METALURGIA', 'AGLOMERADOR',
        'TRITURACION_PRIMARIA', 'TRITURACION_SECUNDARIA', 'SUBESTACION',
        'TALLER_MANTENIMIENTO', 'ALMACEN', 'ASERRADERO', 'INCINERADOR',
        'CENTRO_ACOPIO', 'VIVERO', 'POLVORIN', 'REFINERIA'
    )
      AND ISNULL(spa.RequiereAprobacion, 0) <> politica.Requiere;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Matriz_Aprobacion_Decidir
    @IdSolicitudPersonaArea BIGINT,
    @IdUsuarioAprobador VARCHAR(50),
    @CodigoEstado VARCHAR(30),
    @ComentarioDecision NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Solicitud_Persona_Area AS spa
        INNER JOIN dbo.Cat_Area AS a ON a.IdArea = spa.IdArea
        WHERE spa.IdSolicitudPersonaArea = @IdSolicitudPersonaArea
          AND a.Codigo IN
          (
              'CENTRO_INTEGRACION', 'TAJO', 'BOTADEROS', 'MIRADORES', 'TALLER_EDI',
              'PAD_POZAS_1_6', 'PLANTA_ADR_LABORATORIO', 'METALURGIA', 'AGLOMERADOR',
              'TRITURACION_PRIMARIA', 'TRITURACION_SECUNDARIA', 'SUBESTACION',
              'TALLER_MANTENIMIENTO', 'ALMACEN', 'ASERRADERO', 'INCINERADOR',
              'CENTRO_ACOPIO', 'VIVERO', 'POLVORIN', 'REFINERIA'
          )
    )
    BEGIN
        EXEC dbo.usp_Aprobacion_Area_Decidir @IdSolicitudPersonaArea,
            @IdUsuarioAprobador, @CodigoEstado, @ComentarioDecision;
        RETURN;
    END;

    IF @CodigoEstado NOT IN ('APROBADA', 'RECHAZADA')
        THROW 50711, 'La decision debe ser APROBADA o RECHAZADA.', 1;
    IF @CodigoEstado = 'RECHAZADA' AND NULLIF(LTRIM(RTRIM(@ComentarioDecision)), N'') IS NULL
        THROW 50712, 'Indica el motivo del rechazo.', 1;

    DECLARE @Pendiente SMALLINT =
        (SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'PENDIENTE');
    DECLARE @Aprobada SMALLINT =
        (SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'APROBADA');
    DECLARE @Rechazada SMALLINT =
        (SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'RECHAZADA');
    DECLARE @EstadoActual SMALLINT;
    BEGIN TRANSACTION;

    SELECT @EstadoActual = IdEstadoAprobacion
    FROM dbo.Solicitud_Persona_Area WITH (UPDLOCK, HOLDLOCK)
    WHERE IdSolicitudPersonaArea = @IdSolicitudPersonaArea AND RequiereAprobacion = 1;
    IF @EstadoActual IS NULL OR @EstadoActual <> @Pendiente
        THROW 50713, 'El acceso no esta pendiente de aprobacion.', 1;

    DECLARE @TotalAprobadores INT;
    SELECT @TotalAprobadores = COUNT(DISTINCT IdUsuarioAprobador)
    FROM dbo.Config_Aprobador_Area AS ca
    INNER JOIN dbo.Usuario AS u ON u.IdUsuario = ca.IdUsuarioAprobador AND ISNULL(u.IdEstadoGeneral, 1) = 1
    WHERE ca.IdArea = (SELECT IdArea FROM dbo.Solicitud_Persona_Area WHERE IdSolicitudPersonaArea = @IdSolicitudPersonaArea)
      AND ca.IdUsuarioAprobador IS NOT NULL AND ISNULL(ca.IdEstadoGeneral, 1) = 1
      AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
      AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()));
    DECLARE @CodigoArea VARCHAR(30), @CodigoTipo VARCHAR(30);
    SELECT @CodigoArea = a.Codigo, @CodigoTipo = ti.Codigo
    FROM dbo.Solicitud_Persona_Area AS spa
    INNER JOIN dbo.Cat_Area AS a ON a.IdArea = spa.IdArea
    INNER JOIN dbo.Solicitud_Persona AS sp ON sp.IdSolicitudPersona = spa.IdSolicitudPersona
    INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = sp.IdSolicitud
    INNER JOIN dbo.Cat_Tipo_Ingreso AS ti ON ti.IdTipoIngreso = s.IdTipoIngreso
    WHERE spa.IdSolicitudPersonaArea = @IdSolicitudPersonaArea;
    DECLARE @VotosNecesarios INT = CASE WHEN @CodigoArea = 'REFINERIA'
        AND @CodigoTipo IN ('EMPLEADO', 'NUEVO_EMPLEADO') THEN 3 ELSE 1 END;
    IF (@CodigoArea IN ('POLVORIN', 'REFINERIA') AND @TotalAprobadores <> 3)
        OR (@CodigoArea NOT IN ('POLVORIN', 'REFINERIA') AND @TotalAprobadores < 1)
        THROW 50714, 'El area no tiene la cantidad requerida de aprobadores asignados.', 1;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Config_Aprobador_Area
        WHERE IdArea = (SELECT IdArea FROM dbo.Solicitud_Persona_Area WHERE IdSolicitudPersonaArea = @IdSolicitudPersonaArea)
          AND IdUsuarioAprobador = @IdUsuarioAprobador
          AND ISNULL(IdEstadoGeneral, 1) = 1
          AND (FechaInicio IS NULL OR FechaInicio <= CONVERT(DATE, SYSDATETIME()))
          AND (FechaFin IS NULL OR FechaFin >= CONVERT(DATE, SYSDATETIME()))
    ) THROW 50715, 'El usuario no esta asignado al area.', 1;

    DECLARE @NumeroReenvio SMALLINT =
    (
        SELECT CONVERT(SMALLINT, COUNT_BIG(*))
        FROM dbo.Rechazo_Area AS r
        INNER JOIN dbo.Aprobacion_Area AS aa ON aa.IdAprobacionArea = r.IdAprobacionArea
        WHERE aa.IdSolicitudPersonaArea = @IdSolicitudPersonaArea
    );
    IF EXISTS
    (
        SELECT 1 FROM dbo.Aprobacion_Area
        WHERE IdSolicitudPersonaArea = @IdSolicitudPersonaArea
          AND IdUsuarioAprobador = @IdUsuarioAprobador
          AND NumeroReenvio = @NumeroReenvio
    ) THROW 50716, 'Este usuario ya decidio en el envio actual.', 1;

    DECLARE @IdAprobacion BIGINT;
    UPDATE dbo.Control_Secuencia WITH (UPDLOCK, HOLDLOCK)
       SET UltimoValor = CASE WHEN UltimoValor < (SELECT ISNULL(MAX(IdAprobacionArea), 0) FROM dbo.Aprobacion_Area)
                              THEN (SELECT ISNULL(MAX(IdAprobacionArea), 0) FROM dbo.Aprobacion_Area)
                              ELSE UltimoValor END
     WHERE NombreEntidad = 'Aprobacion_Area';
    EXEC dbo.usp_ObtenerSiguienteId 'Aprobacion_Area', @IdAprobacion OUTPUT;
    INSERT dbo.Aprobacion_Area
        (IdAprobacionArea, IdSolicitudPersonaArea, IdUsuarioAprobador,
         IdEstadoAprobacion, FechaSolicitud, FechaDecision, ComentarioDecision,
         NumeroReenvio, FechaCreacion, UsuarioCreacion)
    VALUES
        (@IdAprobacion, @IdSolicitudPersonaArea, @IdUsuarioAprobador,
         CASE WHEN @CodigoEstado = 'APROBADA' THEN @Aprobada ELSE @Rechazada END,
         SYSDATETIME(), SYSDATETIME(), NULLIF(LTRIM(RTRIM(@ComentarioDecision)), N''),
         @NumeroReenvio, SYSDATETIME(), @IdUsuarioAprobador);

    IF @CodigoEstado = 'RECHAZADA'
    BEGIN
        DECLARE @IdRechazo BIGINT;
        UPDATE dbo.Control_Secuencia WITH (UPDLOCK, HOLDLOCK)
           SET UltimoValor = CASE WHEN UltimoValor < (SELECT ISNULL(MAX(IdRechazoArea), 0) FROM dbo.Rechazo_Area)
                                  THEN (SELECT ISNULL(MAX(IdRechazoArea), 0) FROM dbo.Rechazo_Area)
                                  ELSE UltimoValor END
         WHERE NombreEntidad = 'Rechazo_Area';
        EXEC dbo.usp_ObtenerSiguienteId 'Rechazo_Area', @IdRechazo OUTPUT;
        INSERT dbo.Rechazo_Area
            (IdRechazoArea, IdAprobacionArea, IdUsuarioRechazo, Motivo,
             FechaRechazo, FechaCreacion, UsuarioCreacion)
        VALUES
            (@IdRechazo, @IdAprobacion, @IdUsuarioAprobador, @ComentarioDecision,
             SYSDATETIME(), SYSDATETIME(), @IdUsuarioAprobador);
        UPDATE dbo.Solicitud_Persona_Area
           SET IdEstadoAprobacion = @Rechazada,
               FechaModificacion = SYSDATETIME(), UsuarioModificacion = @IdUsuarioAprobador
         WHERE IdSolicitudPersonaArea = @IdSolicitudPersonaArea;
    END
    ELSE IF
    (
        SELECT COUNT(DISTINCT aa.IdUsuarioAprobador)
        FROM dbo.Aprobacion_Area AS aa
        INNER JOIN dbo.Config_Aprobador_Area AS ca
            ON ca.IdUsuarioAprobador = aa.IdUsuarioAprobador
           AND ca.IdArea = (SELECT IdArea FROM dbo.Solicitud_Persona_Area WHERE IdSolicitudPersonaArea = @IdSolicitudPersonaArea)
           AND ISNULL(ca.IdEstadoGeneral, 1) = 1
           AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
           AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        WHERE aa.IdSolicitudPersonaArea = @IdSolicitudPersonaArea
          AND aa.NumeroReenvio = @NumeroReenvio
          AND aa.IdEstadoAprobacion = @Aprobada
    ) >= @VotosNecesarios
    BEGIN
        UPDATE dbo.Solicitud_Persona_Area
           SET IdEstadoAprobacion = @Aprobada,
               FechaModificacion = SYSDATETIME(), UsuarioModificacion = @IdUsuarioAprobador
         WHERE IdSolicitudPersonaArea = @IdSolicitudPersonaArea;
    END;

    EXEC dbo.usp_Solicitud_Estado_Recalcular @IdSolicitudPersonaArea, @IdUsuarioAprobador;
    COMMIT TRANSACTION;
    SELECT @IdAprobacion;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Matriz_Aprobaciones_Votadas
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT spa.IdSolicitudPersonaArea
    FROM dbo.Solicitud_Persona_Area AS spa
    INNER JOIN dbo.Cat_Area AS a ON a.IdArea = spa.IdArea AND a.Codigo = 'REFINERIA'
    INNER JOIN dbo.Cat_Estado_Aprobacion_Area AS estado
        ON estado.IdEstadoAprobacion = spa.IdEstadoAprobacion AND estado.Codigo = 'PENDIENTE'
    WHERE EXISTS
    (
        SELECT 1 FROM dbo.Aprobacion_Area AS aa
        WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
          AND aa.IdUsuarioAprobador = @IdUsuario
          AND aa.NumeroReenvio =
          (
              SELECT CONVERT(SMALLINT, COUNT_BIG(*))
              FROM dbo.Rechazo_Area AS r
              INNER JOIN dbo.Aprobacion_Area AS rechazada ON rechazada.IdAprobacionArea = r.IdAprobacionArea
              WHERE rechazada.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
          )
    );
END;
GO

