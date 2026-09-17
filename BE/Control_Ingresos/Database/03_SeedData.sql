USE [Control_Ingresos_DB];
GO

/* Datos mínimos para utilizar los endpoints en Development. */

IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_General WHERE IdEstadoGeneral = 1)
BEGIN
    INSERT dbo.Cat_Estado_General
    (
        IdEstadoGeneral, Codigo, Nombre, Descripcion, EsActivo,
        OrdenVisualizacion, FechaCreacion, UsuarioCreacion
    )
    VALUES
    (1, 'ACTIVO', N'Activo', N'Registro habilitado', 1, 1, SYSDATETIME(), 'SISTEMA');
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_General WHERE IdEstadoGeneral = 2)
BEGIN
    INSERT dbo.Cat_Estado_General
    (
        IdEstadoGeneral, Codigo, Nombre, Descripcion, EsActivo,
        OrdenVisualizacion, FechaCreacion, UsuarioCreacion
    )
    VALUES
    (2, 'INACTIVO', N'Inactivo', N'Registro deshabilitado', 0, 2, SYSDATETIME(), 'SISTEMA');
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Documento WHERE IdTipoDocumento = 1)
BEGIN
    INSERT dbo.Cat_Tipo_Documento
    (
        IdTipoDocumento, Codigo, Nombre, LongitudMaxima,
        IdEstadoGeneral, FechaCreacion, UsuarioCreacion
    )
    VALUES
    (1, 'DNI', N'Documento Nacional de Identificación', 13, 1, SYSDATETIME(), 'SISTEMA');
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Documento WHERE IdTipoDocumento = 2)
BEGIN
    INSERT dbo.Cat_Tipo_Documento
    (
        IdTipoDocumento, Codigo, Nombre, LongitudMaxima,
        IdEstadoGeneral, FechaCreacion, UsuarioCreacion
    )
    VALUES
    (2, 'PASAPORTE', N'Pasaporte', 30, 1, SYSDATETIME(), 'SISTEMA');
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Documento WHERE IdTipoDocumento = 3)
BEGIN
    INSERT dbo.Cat_Tipo_Documento
    (
        IdTipoDocumento, Codigo, Nombre, LongitudMaxima,
        IdEstadoGeneral, FechaCreacion, UsuarioCreacion
    )
    VALUES
    (3, 'OTRO', N'Otro documento', 60, 1, SYSDATETIME(), 'SISTEMA');
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Ingreso WHERE IdTipoIngreso = 1)
    INSERT dbo.Cat_Tipo_Ingreso
    (IdTipoIngreso, Codigo, Nombre, Descripcion, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (1, 'VISITA', N'Visita', N'Ingreso temporal de visitantes', 1, SYSDATETIME(), 'SISTEMA');

IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Ingreso WHERE IdTipoIngreso = 2)
    INSERT dbo.Cat_Tipo_Ingreso
    (IdTipoIngreso, Codigo, Nombre, Descripcion, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (2, 'CONTRATISTA', N'Contratista', N'Ingreso de personal contratista', 1, SYSDATETIME(), 'SISTEMA');

IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Solicitud WHERE IdEstadoSolicitud = 1)
    INSERT dbo.Cat_Estado_Solicitud
    (IdEstadoSolicitud, Codigo, Nombre, Descripcion, EsEstadoFinal, OrdenFlujo, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (1, 'BORRADOR', N'Borrador', N'Solicitud en preparación', 0, 1, 1, SYSDATETIME(), 'SISTEMA');

IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Solicitud WHERE IdEstadoSolicitud = 2)
    INSERT dbo.Cat_Estado_Solicitud
    (IdEstadoSolicitud, Codigo, Nombre, Descripcion, EsEstadoFinal, OrdenFlujo, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (2, 'ENVIADA', N'Enviada', N'Solicitud enviada para revisión', 0, 2, 1, SYSDATETIME(), 'SISTEMA');

IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = 1)
    INSERT dbo.Cat_Area
    (IdArea, Codigo, Nombre, Descripcion, RequiereAprobacion, EsAreaResponsable, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (1, 'SEGURIDAD', N'Seguridad', N'Área de seguridad física', 1, 1, 1, SYSDATETIME(), 'SISTEMA');

IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = 2)
    INSERT dbo.Cat_Area
    (IdArea, Codigo, Nombre, Descripcion, RequiereAprobacion, EsAreaResponsable, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (2, 'TI', N'Tecnología de Información', N'Área de tecnología', 1, 1, 1, SYSDATETIME(), 'SISTEMA');

IF NOT EXISTS (SELECT 1 FROM dbo.Cat_Ubicacion WHERE IdUbicacion = 1)
    INSERT dbo.Cat_Ubicacion
    (IdUbicacion, Codigo, Nombre, Direccion, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (1, 'PRINCIPAL', N'Edificio principal', N'Acceso principal', 1, SYSDATETIME(), 'SISTEMA');

IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = 'usuario.demo')
    INSERT dbo.Usuario
    (IdUsuario, NombreCompleto, Correo, Puesto, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES ('usuario.demo', N'Usuario de demostración', 'usuario.demo@empresa.local', N'Solicitante', 1, SYSDATETIME(), 'SISTEMA');
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE Codigo = 'PROV-DEMO')
BEGIN
    DECLARE @IdProveedorDemo BIGINT;
    EXEC dbo.usp_ObtenerSiguienteId 'Proveedor', @IdProveedorDemo OUTPUT;
    INSERT dbo.Proveedor
    (IdProveedor, Codigo, NombreLegal, NombreComercial, ContactoPrincipal, CorreoPrincipal, TelefonoPrincipal, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES
    (@IdProveedorDemo, 'PROV-DEMO', N'TechServices Honduras S.A.', N'TechServices Honduras', N'Ricardo Núñez', 'ricardo.nunez@techservices.hn', '2234-5678', 1, SYSDATETIME(), 'SISTEMA');
END;
GO
