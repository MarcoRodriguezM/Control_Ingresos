/*
  Base consolidada de Control de Ingresos.
  - Script para una instalacion nueva.
  - No elimina una base existente automaticamente.
  - Sin IDENTITY ni llaves foraneas; las relaciones son logicas.
  - Las contrasenas se conservan en texto plano por decision expresa del propietario.
  - No contiene datos transaccionales de solicitudes, personas, aprobaciones o ingresos.
*/
USE [master];
GO

IF DB_ID(N'Control_Ingresos_DB') IS NOT NULL
    THROW 51000, 'La base Control_Ingresos_DB ya existe. El script no la elimina automaticamente.', 1;
GO

CREATE DATABASE [Control_Ingresos_DB];
GO

USE [Control_Ingresos_DB];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

CREATE TABLE [dbo].[Actividad](
	[IdActividad] [bigint] NOT NULL,
	[IdSolicitud] [bigint] NULL,
	[IdSolicitudPersona] [bigint] NULL,
	[IdSolicitudPersonaReq] [bigint] NULL,
	[IdRequerimiento] [int] NULL,
	[IdAreaResponsable] [int] NULL,
	[IdUsuarioResponsable] [varchar](50) NULL,
	[IdEstadoActividad] [smallint] NULL,
	[NombreActividad] [nvarchar](200) NULL,
	[FechaLimite] [datetime2](0) NULL,
	[FechaInicio] [datetime2](0) NULL,
	[FechaFinalizacion] [datetime2](0) NULL,
	[Comentarios] [nvarchar](1000) NULL,
	[RequiereTicketExterno] [bit] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
	[IdUsuarioAprobador] [varchar](50) NULL,
	[FechaDecision] [datetime2](3) NULL,
	[ComentarioDecision] [nvarchar](1000) NULL,
 CONSTRAINT [PK_Actividad] PRIMARY KEY CLUSTERED 
(
	[IdActividad] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Actividad_Ticket_Externo](
	[IdActividadTicket] [bigint] NOT NULL,
	[IdActividad] [bigint] NULL,
	[Plataforma] [nvarchar](100) NULL,
	[NumeroTicket] [varchar](80) NULL,
	[UrlTicket] [nvarchar](500) NULL,
	[FechaRegistro] [datetime2](0) NULL,
	[IdUsuarioRegistro] [varchar](50) NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Actividad_Ticket_Externo] PRIMARY KEY CLUSTERED 
(
	[IdActividadTicket] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Aprobacion_Area](
	[IdAprobacionArea] [bigint] NOT NULL,
	[IdSolicitudPersonaArea] [bigint] NULL,
	[IdUsuarioAprobador] [varchar](50) NULL,
	[FechaSolicitud] [datetime2](0) NULL,
	[FechaDecision] [datetime2](0) NULL,
	[ComentarioDecision] [nvarchar](1000) NULL,
	[NumeroReenvio] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Aprobacion_Area] PRIMARY KEY CLUSTERED 
(
	[IdAprobacionArea] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Cat_Area](
	[IdArea] [int] NOT NULL,
	[Codigo] [varchar](30) NULL,
	[Nombre] [nvarchar](150) NULL,
	[Descripcion] [nvarchar](300) NULL,
	[RequiereAprobacion] [bit] NULL,
	[EsAreaResponsable] [bit] NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Cat_Area] PRIMARY KEY CLUSTERED 
(
	[IdArea] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Cat_Categoria_Requerimiento](
	[IdCategoriaRequerimiento] [int] NOT NULL,
	[Codigo] [varchar](30) NULL,
	[Nombre] [nvarchar](100) NULL,
	[Descripcion] [nvarchar](300) NULL,
	[OrdenVisualizacion] [smallint] NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Cat_Categoria_Requerimiento] PRIMARY KEY CLUSTERED 
(
	[IdCategoriaRequerimiento] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Cat_Estado_Actividad](
	[IdEstadoActividad] [smallint] NOT NULL,
	[Codigo] [varchar](30) NULL,
	[Nombre] [nvarchar](100) NULL,
	[Descripcion] [nvarchar](300) NULL,
	[EsEstadoFinal] [bit] NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Cat_Estado_Actividad] PRIMARY KEY CLUSTERED 
(
	[IdEstadoActividad] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Cat_Estado_Aprobacion_Area](
	[IdEstadoAprobacion] [smallint] NOT NULL,
	[Codigo] [varchar](30) NULL,
	[Nombre] [nvarchar](100) NULL,
	[Descripcion] [nvarchar](300) NULL,
	[EsEstadoFinal] [bit] NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Cat_Estado_Aprobacion_Area] PRIMARY KEY CLUSTERED 
(
	[IdEstadoAprobacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Cat_Estado_General](
	[IdEstadoGeneral] [smallint] NOT NULL,
	[Codigo] [varchar](30) NULL,
	[Nombre] [nvarchar](100) NULL,
	[Descripcion] [nvarchar](300) NULL,
	[EsActivo] [bit] NULL,
	[OrdenVisualizacion] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Cat_Estado_General] PRIMARY KEY CLUSTERED 
(
	[IdEstadoGeneral] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Cat_Estado_Persona_Solicitud](
	[IdEstadoPersonaSolicitud] [smallint] NOT NULL,
	[Codigo] [varchar](30) NULL,
	[Nombre] [nvarchar](100) NULL,
	[Descripcion] [nvarchar](300) NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Cat_Estado_Persona_Solicitud] PRIMARY KEY CLUSTERED 
(
	[IdEstadoPersonaSolicitud] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Cat_Estado_Solicitud](
	[IdEstadoSolicitud] [smallint] NOT NULL,
	[Codigo] [varchar](40) NULL,
	[Nombre] [nvarchar](120) NULL,
	[Descripcion] [nvarchar](300) NULL,
	[EsEstadoFinal] [bit] NULL,
	[OrdenFlujo] [smallint] NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Cat_Estado_Solicitud] PRIMARY KEY CLUSTERED 
(
	[IdEstadoSolicitud] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Cat_Requerimiento](
	[IdRequerimiento] [int] NOT NULL,
	[Codigo] [varchar](40) NULL,
	[Nombre] [nvarchar](150) NULL,
	[Descripcion] [nvarchar](500) NULL,
	[IdCategoriaRequerimiento] [int] NULL,
	[RequiereTicketExterno] [bit] NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Cat_Requerimiento] PRIMARY KEY CLUSTERED 
(
	[IdRequerimiento] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Cat_Tipo_Aplicacion_Requerimiento](
	[IdTipoAplicacion] [smallint] NOT NULL,
	[Codigo] [varchar](30) NULL,
	[Nombre] [nvarchar](100) NULL,
	[Descripcion] [nvarchar](300) NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Cat_Tipo_Aplicacion_Requerimiento] PRIMARY KEY CLUSTERED 
(
	[IdTipoAplicacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Cat_Tipo_Documento](
	[IdTipoDocumento] [smallint] NOT NULL,
	[Codigo] [varchar](20) NULL,
	[Nombre] [nvarchar](100) NULL,
	[LongitudMaxima] [smallint] NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Cat_Tipo_Documento] PRIMARY KEY CLUSTERED 
(
	[IdTipoDocumento] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Cat_Tipo_Ingreso](
	[IdTipoIngreso] [smallint] NOT NULL,
	[Codigo] [varchar](30) NULL,
	[Nombre] [nvarchar](100) NULL,
	[Descripcion] [nvarchar](300) NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Cat_Tipo_Ingreso] PRIMARY KEY CLUSTERED 
(
	[IdTipoIngreso] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Cat_Ubicacion](
	[IdUbicacion] [int] NOT NULL,
	[Codigo] [varchar](30) NULL,
	[Nombre] [nvarchar](150) NULL,
	[Direccion] [nvarchar](300) NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Cat_Ubicacion] PRIMARY KEY CLUSTERED 
(
	[IdUbicacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Config_Aprobador_Area](
	[IdConfigAprobador] [bigint] NOT NULL,
	[IdArea] [int] NULL,
	[IdUsuarioAprobador] [varchar](50) NULL,
	[EsPrincipal] [bit] NULL,
	[FechaInicio] [date] NULL,
	[FechaFin] [date] NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Config_Aprobador_Area] PRIMARY KEY CLUSTERED 
(
	[IdConfigAprobador] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Config_Requerimiento_Area](
	[IdConfigReqArea] [bigint] NOT NULL,
	[IdRequerimiento] [int] NULL,
	[IdAreaAcceso] [int] NULL,
	[IdAreaResponsable] [int] NULL,
	[IdTipoAplicacion] [smallint] NULL,
	[RequiereTicketExterno] [bit] NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Config_Requerimiento_Area] PRIMARY KEY CLUSTERED 
(
	[IdConfigReqArea] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Config_Requerimiento_Tipo_Ingreso](
	[IdConfigReqTipoIngreso] [bigint] NOT NULL,
	[IdRequerimiento] [int] NULL,
	[IdTipoIngreso] [smallint] NULL,
	[IdTipoAplicacion] [smallint] NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Config_Requerimiento_Tipo_Ingreso] PRIMARY KEY CLUSTERED 
(
	[IdConfigReqTipoIngreso] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Control_Secuencia](
	[NombreEntidad] [varchar](100) NOT NULL,
	[UltimoValor] [bigint] NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Control_Secuencia] PRIMARY KEY CLUSTERED 
(
	[NombreEntidad] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Historial_Solicitud](
	[IdHistorialSolicitud] [bigint] NOT NULL,
	[IdSolicitud] [bigint] NULL,
	[IdSolicitudPersona] [bigint] NULL,
	[IdAprobacionArea] [bigint] NULL,
	[IdActividad] [bigint] NULL,
	[TipoEvento] [varchar](60) NULL,
	[Accion] [nvarchar](200) NULL,
	[Comentario] [nvarchar](1000) NULL,
	[IdUsuarioAccion] [varchar](50) NULL,
	[FechaAccion] [datetime2](0) NULL,
	[DatosAdicionalesJson] [nvarchar](max) NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Historial_Solicitud] PRIMARY KEY CLUSTERED 
(
	[IdHistorialSolicitud] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE TABLE [dbo].[Persona](
	[IdPersona] [bigint] NOT NULL,
	[IdTipoDocumento] [smallint] NULL,
	[NumeroDocumento] [varchar](60) NULL,
	[NombreCompleto] [nvarchar](200) NULL,
	[FotografiaUrl] [nvarchar](500) NULL,
	[Telefono] [varchar](30) NULL,
	[Correo] [varchar](254) NULL,
	[CargoFuncion] [nvarchar](150) NULL,
	[IdProveedor] [bigint] NULL,
	[EmpresaTexto] [nvarchar](200) NULL,
	[InformacionAdicional] [nvarchar](1000) NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Persona] PRIMARY KEY CLUSTERED 
(
	[IdPersona] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Proveedor](
	[IdProveedor] [bigint] NOT NULL,
	[Codigo] [varchar](30) NULL,
	[NombreLegal] [nvarchar](200) NULL,
	[NombreComercial] [nvarchar](200) NULL,
	[RTN] [varchar](30) NULL,
	[ContactoPrincipal] [nvarchar](200) NULL,
	[CorreoPrincipal] [varchar](254) NULL,
	[TelefonoPrincipal] [varchar](30) NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Proveedor] PRIMARY KEY CLUSTERED 
(
	[IdProveedor] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Rechazo_Area](
	[IdRechazoArea] [bigint] NOT NULL,
	[IdAprobacionArea] [bigint] NULL,
	[IdUsuarioRechazo] [varchar](50) NULL,
	[Motivo] [nvarchar](1000) NULL,
	[FechaRechazo] [datetime2](0) NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Rechazo_Area] PRIMARY KEY CLUSTERED 
(
	[IdRechazoArea] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Registro_Ingreso](
	[IdRegistroIngreso] [bigint] NOT NULL,
	[IdPersona] [bigint] NULL,
	[IdSolicitud] [bigint] NULL,
	[IdSolicitudPersona] [bigint] NULL,
	[TipoMovimiento] [varchar](10) NULL,
	[FechaMovimiento] [datetime2](3) NULL,
	[IdUsuarioSeguridad] [varchar](50) NULL,
	[Observaciones] [nvarchar](500) NULL,
 CONSTRAINT [PK_RegistroIngreso] PRIMARY KEY CLUSTERED 
(
	[IdRegistroIngreso] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Rol](
	[IdRol] [smallint] NOT NULL,
	[Codigo] [varchar](30) NULL,
	[Nombre] [nvarchar](100) NULL,
	[Descripcion] [nvarchar](300) NULL,
	[Activo] [bit] NULL,
 CONSTRAINT [PK_Rol] PRIMARY KEY CLUSTERED 
(
	[IdRol] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Solicitud_Ingreso](
	[IdSolicitud] [bigint] NOT NULL,
	[NumeroSolicitud] [varchar](30) NULL,
	[IdTipoIngreso] [smallint] NULL,
	[IdEstadoSolicitud] [smallint] NULL,
	[FechaInicio] [date] NULL,
	[FechaFin] [date] NULL,
	[NombreActividad] [nvarchar](200) NULL,
	[DescripcionActividad] [nvarchar](1000) NULL,
	[IdProveedor] [bigint] NULL,
	[NumeroContrato] [varchar](60) NULL,
	[ContactoProveedor] [nvarchar](200) NULL,
	[CorreoProveedor] [varchar](254) NULL,
	[CantidadEstimada] [int] NULL,
	[IdAreaSolicitante] [int] NULL,
	[IdUsuarioSolicitante] [varchar](50) NULL,
	[IdUbicacion] [int] NULL,
	[Observaciones] [nvarchar](1000) NULL,
	[FechaEnvioProveedor] [datetime2](0) NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Solicitud_Ingreso] PRIMARY KEY CLUSTERED 
(
	[IdSolicitud] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Solicitud_Persona](
	[IdSolicitudPersona] [bigint] NOT NULL,
	[IdSolicitud] [bigint] NULL,
	[IdPersona] [bigint] NULL,
	[IdEstadoPersonaSolicitud] [smallint] NULL,
	[DatosCompletos] [bit] NULL,
	[ObservacionesRevision] [nvarchar](1000) NULL,
	[FechaEnvioRevision] [datetime2](0) NULL,
	[FechaAprobacionDatos] [datetime2](0) NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Solicitud_Persona] PRIMARY KEY CLUSTERED 
(
	[IdSolicitudPersona] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Solicitud_Persona_Area](
	[IdSolicitudPersonaArea] [bigint] NOT NULL,
	[IdSolicitudPersona] [bigint] NULL,
	[IdArea] [int] NULL,
	[RequiereAprobacion] [bit] NULL,
	[Observaciones] [nvarchar](500) NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
	[IdEstadoAprobacion] [smallint] NULL,
 CONSTRAINT [PK_Solicitud_Persona_Area] PRIMARY KEY CLUSTERED 
(
	[IdSolicitudPersonaArea] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Solicitud_Persona_Requerimiento](
	[IdSolicitudPersonaReq] [bigint] NOT NULL,
	[IdSolicitudPersona] [bigint] NULL,
	[IdRequerimiento] [int] NULL,
	[IdTipoAplicacion] [smallint] NULL,
	[Seleccionado] [bit] NULL,
	[ConfiguradoAutomatico] [bit] NULL,
	[Observaciones] [nvarchar](500) NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Solicitud_Persona_Requerimiento] PRIMARY KEY CLUSTERED 
(
	[IdSolicitudPersonaReq] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Usuario](
	[IdUsuario] [varchar](50) NOT NULL,
	[NombreCompleto] [nvarchar](200) NULL,
	[Correo] [varchar](254) NULL,
	[Usuario_Password] [varchar](200) NULL,
	[Telefono] [varchar](30) NULL,
	[Puesto] [nvarchar](150) NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Usuario] PRIMARY KEY CLUSTERED 
(
	[IdUsuario] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Usuario_Area](
	[IdUsuarioArea] [bigint] NOT NULL,
	[IdUsuario] [varchar](50) NULL,
	[IdArea] [int] NULL,
	[PuedeSolicitar] [bit] NULL,
	[EsAreaPrincipal] [bit] NULL,
	[FechaInicio] [date] NULL,
	[FechaFin] [date] NULL,
	[IdEstadoGeneral] [smallint] NULL,
	[FechaCreacion] [datetime2](0) NULL,
	[UsuarioCreacion] [varchar](50) NULL,
	[FechaModificacion] [datetime2](0) NULL,
	[UsuarioModificacion] [varchar](50) NULL,
 CONSTRAINT [PK_Usuario_Area] PRIMARY KEY CLUSTERED 
(
	[IdUsuarioArea] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Usuario_Rol](
	[IdUsuario] [varchar](50) NOT NULL,
	[IdRol] [smallint] NOT NULL,
	[FechaAsignacion] [datetime2](3) NULL,
	[UsuarioAsignacion] [varchar](50) NULL,
 CONSTRAINT [PK_Usuario_Rol] PRIMARY KEY CLUSTERED 
(
	[IdUsuario] ASC,
	[IdRol] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/* Datos base: catalogos, configuracion y usuarios. */
BEGIN TRANSACTION;

INSERT [dbo].[Cat_Area] ([IdArea], [Codigo], [Nombre], [Descripcion], [RequiereAprobacion], [EsAreaResponsable], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (1, N'INFORMATICA', N'Informática', N'Área de infraestructura y servicios tecnológicos.', 1, 0, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Area] ([IdArea], [Codigo], [Nombre], [Descripcion], [RequiereAprobacion], [EsAreaResponsable], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (2, N'SERVICIOS_GENERALES', N'Servicios Generales', N'Área de servicios e instalaciones generales.', 1, 0, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Area] ([IdArea], [Codigo], [Nombre], [Descripcion], [RequiereAprobacion], [EsAreaResponsable], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (3, N'SEGURIDAD_PATRIMONIAL', N'Seguridad Patrimonial', N'Área responsable del control físico y patrimonial.', 1, 0, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Area] ([IdArea], [Codigo], [Nombre], [Descripcion], [RequiereAprobacion], [EsAreaResponsable], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (4, N'SST', N'SST', N'Área de Seguridad y Salud en el Trabajo.', 1, 0, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Area] ([IdArea], [Codigo], [Nombre], [Descripcion], [RequiereAprobacion], [EsAreaResponsable], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (5, N'ALMACEN', N'Almacén', N'Área de almacenamiento y despacho.', 1, 0, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Area] ([IdArea], [Codigo], [Nombre], [Descripcion], [RequiereAprobacion], [EsAreaResponsable], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (6, N'MANTENIMIENTO', N'Mantenimiento', N'Área de mantenimiento de infraestructura y equipos.', 1, 0, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')

INSERT [dbo].[Cat_Estado_Actividad] ([IdEstadoActividad], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (1, N'PENDIENTE', N'Pendiente', N'Actividad asignada y pendiente de ejecución.', 0, 1, CAST(N'2026-09-21T10:16:29.0000000' AS DateTime2), N'script', NULL, NULL)
INSERT [dbo].[Cat_Estado_Actividad] ([IdEstadoActividad], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (2, N'EN_PROGRESO', N'En progreso', N'Actividad en ejecución.', 0, 1, CAST(N'2026-09-21T10:16:29.0000000' AS DateTime2), N'script', NULL, NULL)
INSERT [dbo].[Cat_Estado_Actividad] ([IdEstadoActividad], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (3, N'PENDIENTE_APROBACION', N'Pendiente de aprobación', N'El responsable completó la actividad y espera revisión.', 0, 1, CAST(N'2026-09-21T10:16:29.0000000' AS DateTime2), N'script', NULL, NULL)
INSERT [dbo].[Cat_Estado_Actividad] ([IdEstadoActividad], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (4, N'APROBADA', N'Aprobada', N'Actividad completada y aprobada.', 1, 1, CAST(N'2026-09-21T10:16:29.0000000' AS DateTime2), N'script', NULL, NULL)
INSERT [dbo].[Cat_Estado_Actividad] ([IdEstadoActividad], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (5, N'RECHAZADA', N'Rechazada', N'La actividad requiere correcciones del responsable.', 0, 1, CAST(N'2026-09-21T10:16:29.0000000' AS DateTime2), N'script', NULL, NULL)

INSERT [dbo].[Cat_Estado_Aprobacion_Area] ([IdEstadoAprobacion], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (1, N'PENDIENTE', N'Pendiente', N'La aprobación todavía no ha sido resuelta.', 0, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Estado_Aprobacion_Area] ([IdEstadoAprobacion], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (2, N'APROBADA', N'Aprobada', N'El acceso al área fue aprobado.', 1, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Estado_Aprobacion_Area] ([IdEstadoAprobacion], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (3, N'RECHAZADA', N'Rechazada', N'El acceso al área fue rechazado.', 1, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Estado_Aprobacion_Area] ([IdEstadoAprobacion], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (4, N'NO_REQUIERE', N'No requiere aprobación', N'El área no necesita aprobación de supervisor.', 1, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')

INSERT [dbo].[Cat_Estado_General] ([IdEstadoGeneral], [Codigo], [Nombre], [Descripcion], [EsActivo], [OrdenVisualizacion], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (1, N'ACTIVO', N'Activo', N'Registro disponible para su uso.', 1, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Estado_General] ([IdEstadoGeneral], [Codigo], [Nombre], [Descripcion], [EsActivo], [OrdenVisualizacion], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (2, N'INACTIVO', N'Inactivo', N'Registro deshabilitado para nuevos usos.', 0, 2, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')

INSERT [dbo].[Cat_Estado_Solicitud] ([IdEstadoSolicitud], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [OrdenFlujo], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (1, N'BORRADOR', N'Borrador', N'Solicitud en preparación.', 0, 1, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Estado_Solicitud] ([IdEstadoSolicitud], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [OrdenFlujo], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (2, N'PENDIENTE_PROVEEDOR', N'Pendiente de proveedor', N'Pendiente de que el proveedor registre las personas.', 0, 2, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Estado_Solicitud] ([IdEstadoSolicitud], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [OrdenFlujo], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (3, N'EN_REVISION', N'En revisión', N'Datos de personas pendientes de revisión.', 0, 3, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Estado_Solicitud] ([IdEstadoSolicitud], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [OrdenFlujo], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (4, N'CONFIGURACION_ACCESOS', N'Configuración de accesos', N'Asignación de áreas de acceso por persona.', 0, 4, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Estado_Solicitud] ([IdEstadoSolicitud], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [OrdenFlujo], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (5, N'PENDIENTE_APROBACIONES', N'Pendiente de aprobaciones', N'Existen decisiones de acceso pendientes.', 0, 5, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Estado_Solicitud] ([IdEstadoSolicitud], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [OrdenFlujo], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (6, N'LISTA_INGRESO', N'Lista para ingreso', N'Todos los accesos requeridos fueron resueltos.', 0, 6, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Estado_Solicitud] ([IdEstadoSolicitud], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [OrdenFlujo], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (7, N'FINALIZADA', N'Finalizada', N'El periodo de la solicitud ha finalizado.', 1, 7, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Estado_Solicitud] ([IdEstadoSolicitud], [Codigo], [Nombre], [Descripcion], [EsEstadoFinal], [OrdenFlujo], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (8, N'CANCELADA', N'Cancelada', N'La solicitud fue cancelada.', 1, 8, 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')

INSERT [dbo].[Cat_Tipo_Documento] ([IdTipoDocumento], [Codigo], [Nombre], [LongitudMaxima], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (1, N'DNI', N'Documento Nacional de Identificación', 13, 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'SISTEMA', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Tipo_Documento] ([IdTipoDocumento], [Codigo], [Nombre], [LongitudMaxima], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (2, N'PASAPORTE', N'Pasaporte', 30, 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'SISTEMA', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Tipo_Documento] ([IdTipoDocumento], [Codigo], [Nombre], [LongitudMaxima], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (3, N'OTRO', N'Otro documento', 60, 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'SISTEMA', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')

INSERT [dbo].[Cat_Tipo_Ingreso] ([IdTipoIngreso], [Codigo], [Nombre], [Descripcion], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (1, N'VISITA', N'Visita', N'Ingreso temporal de una persona visitante.', 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Tipo_Ingreso] ([IdTipoIngreso], [Codigo], [Nombre], [Descripcion], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (2, N'PRACTICANTE', N'Practicante', N'Ingreso de una persona en práctica profesional.', 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Tipo_Ingreso] ([IdTipoIngreso], [Codigo], [Nombre], [Descripcion], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (3, N'SERV_PROF', N'Servicios Profesionales', N'Ingreso de personal externo para prestar servicios profesionales.', 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Tipo_Ingreso] ([IdTipoIngreso], [Codigo], [Nombre], [Descripcion], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (4, N'EMPLEADO', N'Empleado', N'Ingreso de una persona empleada de la empresa.', 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')

INSERT [dbo].[Cat_Ubicacion] ([IdUbicacion], [Codigo], [Nombre], [Direccion], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (1, N'SRC', N'Santa Rosa de Copán', N'Santa Rosa de Copán, Copán, Honduras.', 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Cat_Ubicacion] ([IdUbicacion], [Codigo], [Nombre], [Direccion], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (2, N'SAM', N'San Andrés Minas', N'San Andrés Minas, Copán, Honduras.', 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')

INSERT [dbo].[Rol] ([IdRol], [Codigo], [Nombre], [Descripcion], [Activo]) VALUES (1, N'ADMINISTRADOR', N'Administrador', N'Administración completa del sistema.', 1)
INSERT [dbo].[Rol] ([IdRol], [Codigo], [Nombre], [Descripcion], [Activo]) VALUES (2, N'SOLICITANTE', N'Solicitante', N'Crea y administra sus propias solicitudes.', 1)
INSERT [dbo].[Rol] ([IdRol], [Codigo], [Nombre], [Descripcion], [Activo]) VALUES (3, N'APROBADOR', N'Aprobador', N'Revisa accesos de las áreas asignadas.', 1)
INSERT [dbo].[Rol] ([IdRol], [Codigo], [Nombre], [Descripcion], [Activo]) VALUES (4, N'RESPONSABLE', N'Responsable', N'Completa actividades asignadas.', 1)
INSERT [dbo].[Rol] ([IdRol], [Codigo], [Nombre], [Descripcion], [Activo]) VALUES (5, N'SEGURIDAD', N'Seguridad', N'Registra entradas y salidas en portería.', 1)
INSERT [dbo].[Rol] ([IdRol], [Codigo], [Nombre], [Descripcion], [Activo]) VALUES (6, N'AUDITOR', N'Auditor', N'Consulta el historial sin modificarlo.', 1)

INSERT [dbo].[Usuario] ([IdUsuario], [NombreCompleto], [Correo], [Usuario_Password], [Telefono], [Puesto], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (N'admin', N'Administrador Control de Ingresos', N'admin@empresa.local', N'Control2026!', NULL, N'Administrador', 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'admin', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Usuario] ([IdUsuario], [NombreCompleto], [Correo], [Usuario_Password], [Telefono], [Puesto], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (N'admin.system', N'Administrador del Sistema', N'admin@empresa.com', NULL, N'+504 2662-0000', N'Administrador IT', 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', NULL, NULL)
INSERT [dbo].[Usuario] ([IdUsuario], [NombreCompleto], [Correo], [Usuario_Password], [Telefono], [Puesto], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (N'aprobador', N'Carlos Pérez', N'aprobador@empresa.local', N'Control2026!', NULL, N'Aprobador', 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'admin', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Usuario] ([IdUsuario], [NombreCompleto], [Correo], [Usuario_Password], [Telefono], [Puesto], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (N'aprobador.sst', N'Aprobador SST', N'aprobador.sst@empresa.com', NULL, N'+504 2662-0002', N'Supervisor SST', 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', NULL, NULL)
INSERT [dbo].[Usuario] ([IdUsuario], [NombreCompleto], [Correo], [Usuario_Password], [Telefono], [Puesto], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (N'solicitante', N'María González', N'solicitante@empresa.local', N'Control2026!', NULL, N'Solicitante', 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'admin', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Usuario] ([IdUsuario], [NombreCompleto], [Correo], [Usuario_Password], [Telefono], [Puesto], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (N'solicitante.demo', N'Usuario Solicitante', N'solicitante@empresa.com', NULL, N'+504 2662-0001', N'Coordinador Operativo', 1, CAST(N'2026-09-17T08:59:06.0000000' AS DateTime2), N'SYSTEM_SEED', NULL, NULL)
INSERT [dbo].[Usuario] ([IdUsuario], [NombreCompleto], [Correo], [Usuario_Password], [Telefono], [Puesto], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (N'usuario.demo', N'Usuario de demostración', N'usuario.demo@empresa.local', NULL, NULL, N'Solicitante', 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'SISTEMA', NULL, NULL)

INSERT [dbo].[Usuario_Area] ([IdUsuarioArea], [IdUsuario], [IdArea], [PuedeSolicitar], [EsAreaPrincipal], [FechaInicio], [FechaFin], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (1, N'admin', 1, 1, 1, CAST(N'2026-09-17' AS Date), NULL, 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'admin', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Usuario_Area] ([IdUsuarioArea], [IdUsuario], [IdArea], [PuedeSolicitar], [EsAreaPrincipal], [FechaInicio], [FechaFin], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (2, N'aprobador', 1, 0, 1, CAST(N'2026-09-17' AS Date), NULL, 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'admin', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Usuario_Area] ([IdUsuarioArea], [IdUsuario], [IdArea], [PuedeSolicitar], [EsAreaPrincipal], [FechaInicio], [FechaFin], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (3, N'solicitante', 2, 1, 1, CAST(N'2026-09-17' AS Date), NULL, 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'admin', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')

INSERT [dbo].[Config_Aprobador_Area] ([IdConfigAprobador], [IdArea], [IdUsuarioAprobador], [EsPrincipal], [FechaInicio], [FechaFin], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (1, 5, N'aprobador', 1, CAST(N'2026-09-17' AS Date), NULL, 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'admin', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Config_Aprobador_Area] ([IdConfigAprobador], [IdArea], [IdUsuarioAprobador], [EsPrincipal], [FechaInicio], [FechaFin], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (2, 1, N'aprobador', 1, CAST(N'2026-09-17' AS Date), NULL, 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'admin', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Config_Aprobador_Area] ([IdConfigAprobador], [IdArea], [IdUsuarioAprobador], [EsPrincipal], [FechaInicio], [FechaFin], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (3, 6, N'aprobador', 1, CAST(N'2026-09-17' AS Date), NULL, 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'admin', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Config_Aprobador_Area] ([IdConfigAprobador], [IdArea], [IdUsuarioAprobador], [EsPrincipal], [FechaInicio], [FechaFin], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (4, 3, N'aprobador', 1, CAST(N'2026-09-17' AS Date), NULL, 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'admin', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Config_Aprobador_Area] ([IdConfigAprobador], [IdArea], [IdUsuarioAprobador], [EsPrincipal], [FechaInicio], [FechaFin], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (5, 2, N'aprobador', 1, CAST(N'2026-09-17' AS Date), NULL, 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'admin', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')
INSERT [dbo].[Config_Aprobador_Area] ([IdConfigAprobador], [IdArea], [IdUsuarioAprobador], [EsPrincipal], [FechaInicio], [FechaFin], [IdEstadoGeneral], [FechaCreacion], [UsuarioCreacion], [FechaModificacion], [UsuarioModificacion]) VALUES (6, 4, N'aprobador', 1, CAST(N'2026-09-17' AS Date), NULL, 1, CAST(N'2026-09-17T09:07:24.0000000' AS DateTime2), N'admin', CAST(N'2026-09-17T10:38:53.0000000' AS DateTime2), N'admin')

INSERT [dbo].[Usuario_Rol] ([IdUsuario], [IdRol], [FechaAsignacion], [UsuarioAsignacion]) VALUES (N'admin', 1, CAST(N'2026-09-25T10:50:09.9660000' AS DateTime2), N'MIGRACION_ROLES')
INSERT [dbo].[Usuario_Rol] ([IdUsuario], [IdRol], [FechaAsignacion], [UsuarioAsignacion]) VALUES (N'admin', 2, CAST(N'2026-09-25T10:50:09.9520000' AS DateTime2), N'MIGRACION_ROLES')
INSERT [dbo].[Usuario_Rol] ([IdUsuario], [IdRol], [FechaAsignacion], [UsuarioAsignacion]) VALUES (N'admin', 4, CAST(N'2026-09-25T10:50:09.9420000' AS DateTime2), N'MIGRACION_ROLES')
INSERT [dbo].[Usuario_Rol] ([IdUsuario], [IdRol], [FechaAsignacion], [UsuarioAsignacion]) VALUES (N'admin.system', 1, CAST(N'2026-09-25T10:50:09.9660000' AS DateTime2), N'MIGRACION_ROLES')
INSERT [dbo].[Usuario_Rol] ([IdUsuario], [IdRol], [FechaAsignacion], [UsuarioAsignacion]) VALUES (N'admin.system', 4, CAST(N'2026-09-25T10:50:09.9420000' AS DateTime2), N'MIGRACION_ROLES')
INSERT [dbo].[Usuario_Rol] ([IdUsuario], [IdRol], [FechaAsignacion], [UsuarioAsignacion]) VALUES (N'aprobador', 2, CAST(N'2026-09-25T10:50:09.9520000' AS DateTime2), N'MIGRACION_ROLES')
INSERT [dbo].[Usuario_Rol] ([IdUsuario], [IdRol], [FechaAsignacion], [UsuarioAsignacion]) VALUES (N'aprobador', 3, CAST(N'2026-09-25T10:50:09.9560000' AS DateTime2), N'MIGRACION_ROLES')
INSERT [dbo].[Usuario_Rol] ([IdUsuario], [IdRol], [FechaAsignacion], [UsuarioAsignacion]) VALUES (N'aprobador', 4, CAST(N'2026-09-25T10:50:09.9420000' AS DateTime2), N'MIGRACION_ROLES')
INSERT [dbo].[Usuario_Rol] ([IdUsuario], [IdRol], [FechaAsignacion], [UsuarioAsignacion]) VALUES (N'aprobador.sst', 4, CAST(N'2026-09-25T10:50:09.9420000' AS DateTime2), N'MIGRACION_ROLES')
INSERT [dbo].[Usuario_Rol] ([IdUsuario], [IdRol], [FechaAsignacion], [UsuarioAsignacion]) VALUES (N'solicitante', 2, CAST(N'2026-09-25T10:50:09.9520000' AS DateTime2), N'MIGRACION_ROLES')
INSERT [dbo].[Usuario_Rol] ([IdUsuario], [IdRol], [FechaAsignacion], [UsuarioAsignacion]) VALUES (N'solicitante', 4, CAST(N'2026-09-25T10:50:09.9420000' AS DateTime2), N'MIGRACION_ROLES')
INSERT [dbo].[Usuario_Rol] ([IdUsuario], [IdRol], [FechaAsignacion], [UsuarioAsignacion]) VALUES (N'solicitante.demo', 4, CAST(N'2026-09-25T10:50:09.9420000' AS DateTime2), N'MIGRACION_ROLES')
INSERT [dbo].[Usuario_Rol] ([IdUsuario], [IdRol], [FechaAsignacion], [UsuarioAsignacion]) VALUES (N'usuario.demo', 4, CAST(N'2026-09-25T10:50:09.9420000' AS DateTime2), N'MIGRACION_ROLES')

COMMIT TRANSACTION;
GO

/* Inicializacion consistente de secuencias manuales. */
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Actividad', COALESCE(MAX(IdActividad), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Actividad;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Actividad_Ticket_Externo', COALESCE(MAX(IdActividadTicket), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Actividad_Ticket_Externo;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Aprobacion_Area', COALESCE(MAX(IdAprobacionArea), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Aprobacion_Area;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Cat_Area', COALESCE(MAX(IdArea), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Cat_Area;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Cat_Categoria_Requerimiento', COALESCE(MAX(IdCategoriaRequerimiento), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Cat_Categoria_Requerimiento;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Cat_Estado_Actividad', COALESCE(MAX(IdEstadoActividad), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Cat_Estado_Actividad;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Cat_Estado_Aprobacion_Area', COALESCE(MAX(IdEstadoAprobacion), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Cat_Estado_Aprobacion_Area;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Cat_Estado_General', COALESCE(MAX(IdEstadoGeneral), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Cat_Estado_General;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Cat_Estado_Persona_Solicitud', COALESCE(MAX(IdEstadoPersonaSolicitud), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Cat_Estado_Persona_Solicitud;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Cat_Estado_Solicitud', COALESCE(MAX(IdEstadoSolicitud), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Cat_Estado_Solicitud;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Cat_Requerimiento', COALESCE(MAX(IdRequerimiento), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Cat_Requerimiento;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Cat_Tipo_Aplicacion_Requerimiento', COALESCE(MAX(IdTipoAplicacion), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Cat_Tipo_Aplicacion_Requerimiento;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Cat_Tipo_Documento', COALESCE(MAX(IdTipoDocumento), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Cat_Tipo_Documento;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Cat_Tipo_Ingreso', COALESCE(MAX(IdTipoIngreso), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Cat_Tipo_Ingreso;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Cat_Ubicacion', COALESCE(MAX(IdUbicacion), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Cat_Ubicacion;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Config_Aprobador_Area', COALESCE(MAX(IdConfigAprobador), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Config_Aprobador_Area;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Config_Requerimiento_Area', COALESCE(MAX(IdConfigReqArea), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Config_Requerimiento_Area;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Config_Requerimiento_Tipo_Ingreso', COALESCE(MAX(IdConfigReqTipoIngreso), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Config_Requerimiento_Tipo_Ingreso;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Historial_Solicitud', COALESCE(MAX(IdHistorialSolicitud), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Historial_Solicitud;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Persona', COALESCE(MAX(IdPersona), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Persona;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Proveedor', COALESCE(MAX(IdProveedor), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Proveedor;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Rechazo_Area', COALESCE(MAX(IdRechazoArea), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Rechazo_Area;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Registro_Ingreso', COALESCE(MAX(IdRegistroIngreso), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Registro_Ingreso;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Solicitud_Ingreso', COALESCE(MAX(IdSolicitud), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Solicitud_Ingreso;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Solicitud_Persona', COALESCE(MAX(IdSolicitudPersona), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Solicitud_Persona;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Solicitud_Persona_Area', COALESCE(MAX(IdSolicitudPersonaArea), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Solicitud_Persona_Area;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Solicitud_Persona_Requerimiento', COALESCE(MAX(IdSolicitudPersonaReq), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Solicitud_Persona_Requerimiento;
INSERT dbo.Control_Secuencia (NombreEntidad, UltimoValor, FechaModificacion, UsuarioModificacion)
SELECT 'Usuario_Area', COALESCE(MAX(IdUsuarioArea), 0), SYSDATETIME(), 'SCRIPT_RECREACION'
FROM dbo.Usuario_Area;
GO

CREATE NONCLUSTERED INDEX [IX_Actividad_IdSolicitud] ON [dbo].[Actividad]
(
	[IdSolicitud] ASC,
	[IdSolicitudPersona] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Actividad_Responsable] ON [dbo].[Actividad]
(
	[IdAreaResponsable] ASC,
	[IdUsuarioResponsable] ASC,
	[IdEstadoActividad] ASC,
	[FechaLimite] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Ticket_Externo_IdActividad] ON [dbo].[Actividad_Ticket_Externo]
(
	[IdActividad] ASC,
	[NumeroTicket] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Config_Aprobador_Area_IdArea] ON [dbo].[Config_Aprobador_Area]
(
	[IdArea] ASC,
	[IdUsuarioAprobador] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Config_Req_Area] ON [dbo].[Config_Requerimiento_Area]
(
	[IdAreaAcceso] ASC,
	[IdRequerimiento] ASC,
	[IdAreaResponsable] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Config_Req_Tipo_Ingreso] ON [dbo].[Config_Requerimiento_Tipo_Ingreso]
(
	[IdTipoIngreso] ASC,
	[IdRequerimiento] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Historial_Solicitud_Cronologia] ON [dbo].[Historial_Solicitud]
(
	[IdSolicitud] ASC,
	[FechaAccion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Persona_NumeroDocumento] ON [dbo].[Persona]
(
	[NumeroDocumento] ASC,
	[IdTipoDocumento] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Rechazo_Area_IdAprobacionArea] ON [dbo].[Rechazo_Area]
(
	[IdAprobacionArea] ASC,
	[FechaRechazo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_RegistroIngreso_PersonaFecha] ON [dbo].[Registro_Ingreso]
(
	[IdPersona] ASC,
	[FechaMovimiento] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Rol] ADD  CONSTRAINT [UQ_Rol_Codigo] UNIQUE NONCLUSTERED 
(
	[Codigo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Solicitud_Ingreso_Seguimiento] ON [dbo].[Solicitud_Ingreso]
(
	[IdEstadoSolicitud] ASC,
	[FechaInicio] ASC,
	[IdAreaSolicitante] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_Solicitud_Ingreso_NumeroSolicitud] ON [dbo].[Solicitud_Ingreso]
(
	[NumeroSolicitud] ASC
)
WHERE ([NumeroSolicitud] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Solicitud_Persona_IdSolicitud] ON [dbo].[Solicitud_Persona]
(
	[IdSolicitud] ASC,
	[IdEstadoPersonaSolicitud] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Solicitud_Persona_Area_Logica] ON [dbo].[Solicitud_Persona_Area]
(
	[IdSolicitudPersona] ASC,
	[IdArea] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Solicitud_Persona_Req_Logica] ON [dbo].[Solicitud_Persona_Requerimiento]
(
	[IdSolicitudPersona] ASC,
	[IdRequerimiento] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Usuario_Area_IdUsuario] ON [dbo].[Usuario_Area]
(
	[IdUsuario] ASC,
	[IdArea] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Registro_Ingreso] ADD  CONSTRAINT [DF_RegistroIngreso_Fecha]  DEFAULT (sysdatetime()) FOR [FechaMovimiento]
GO

ALTER TABLE [dbo].[Rol] ADD  CONSTRAINT [DF_Rol_Activo]  DEFAULT ((1)) FOR [Activo]
GO

ALTER TABLE [dbo].[Usuario_Rol] ADD  CONSTRAINT [DF_UsuarioRol_Fecha]  DEFAULT (sysdatetime()) FOR [FechaAsignacion]
GO

ALTER TABLE [dbo].[Registro_Ingreso]  WITH CHECK ADD  CONSTRAINT [CK_RegistroIngreso_Tipo] CHECK  (([TipoMovimiento]='SALIDA' OR [TipoMovimiento]='ENTRADA'))
GO

ALTER TABLE [dbo].[Registro_Ingreso] CHECK CONSTRAINT [CK_RegistroIngreso_Tipo]
GO

CREATE NONCLUSTERED INDEX [IX_Solicitud_Persona_Area_Estado]
ON [dbo].[Solicitud_Persona_Area]
(
    [IdEstadoAprobacion] ASC,
    [IdArea] ASC,
    [IdSolicitudPersona] ASC
);
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Actividad_Administracion_Listar]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT a.IdActividad,
           a.IdSolicitud,
           s.NumeroSolicitud,
           a.NombreActividad,
           a.IdAreaResponsable,
           ar.Nombre AS AreaResponsable,
           a.IdUsuarioResponsable,
           u.NombreCompleto AS UsuarioResponsable,
           a.IdEstadoActividad,
           ea.Codigo AS CodigoEstado,
           ea.Nombre AS Estado,
           CONVERT(BIT, ISNULL(ea.EsEstadoFinal, 0)) AS EsEstadoFinal,
           a.FechaLimite,
           a.FechaInicio,
           a.FechaFinalizacion,
           a.Comentarios,
           CONVERT(BIT, ISNULL(a.RequiereTicketExterno, 0)) AS RequiereTicketExterno,
           a.IdUsuarioAprobador,
           a.FechaDecision,
           a.ComentarioDecision
    FROM dbo.Actividad AS a
    LEFT JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = a.IdSolicitud
    LEFT JOIN dbo.Cat_Area AS ar ON ar.IdArea = a.IdAreaResponsable
    LEFT JOIN dbo.Usuario AS u ON u.IdUsuario = a.IdUsuarioResponsable
    LEFT JOIN dbo.Cat_Estado_Actividad AS ea ON ea.IdEstadoActividad = a.IdEstadoActividad
    ORDER BY CASE WHEN ea.Codigo = 'PENDIENTE_APROBACION' THEN 0 WHEN ISNULL(ea.EsEstadoFinal, 0) = 0 THEN 1 ELSE 2 END,
             a.FechaLimite,
             a.IdActividad DESC;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Actividad_Completar]
    @IdActividad BIGINT,
    @IdUsuarioResponsable VARCHAR(50),
    @Comentarios NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Actividad WHERE IdActividad = @IdActividad AND IdUsuarioResponsable = @IdUsuarioResponsable)
        THROW 50210, 'La actividad no existe o no está asignada al usuario actual.', 1;

    DECLARE @CodigoActual VARCHAR(30) =
    (
        SELECT ea.Codigo
        FROM dbo.Actividad a
        LEFT JOIN dbo.Cat_Estado_Actividad ea ON ea.IdEstadoActividad = a.IdEstadoActividad
        WHERE a.IdActividad = @IdActividad
    );
    IF @CodigoActual IN ('PENDIENTE_APROBACION', 'APROBADA')
        THROW 50211, 'La actividad ya fue completada y no puede enviarse nuevamente en su estado actual.', 1;

    DECLARE @IdPendienteAprobacion SMALLINT = (SELECT TOP (1) IdEstadoActividad FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'PENDIENTE_APROBACION');
    IF @IdPendienteAprobacion IS NULL THROW 50212, 'No existe el estado PENDIENTE_APROBACION.', 1;

    UPDATE dbo.Actividad
       SET IdEstadoActividad = @IdPendienteAprobacion,
           FechaInicio = COALESCE(FechaInicio, SYSDATETIME()),
           FechaFinalizacion = SYSDATETIME(),
           Comentarios = CASE WHEN NULLIF(LTRIM(RTRIM(@Comentarios)), '') IS NULL THEN Comentarios
                              WHEN NULLIF(LTRIM(RTRIM(Comentarios)), '') IS NULL THEN @Comentarios
                              ELSE CONCAT(Comentarios, CHAR(13), CHAR(10), @Comentarios) END,
           IdUsuarioAprobador = NULL,
           FechaDecision = NULL,
           ComentarioDecision = NULL,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuarioResponsable
     WHERE IdActividad = @IdActividad;

    SELECT @IdActividad;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Actividad_Crear]
    @IdSolicitud BIGINT = NULL,
    @IdAreaResponsable INT = NULL,
    @IdUsuarioResponsable VARCHAR(50),
    @NombreActividad NVARCHAR(200),
    @FechaLimite DATETIME2(3) = NULL,
    @Comentarios NVARCHAR(1000) = NULL,
    @RequiereTicketExterno BIT = 0,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@NombreActividad)), '') IS NULL
        THROW 50200, 'El nombre de la actividad es obligatorio.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuarioResponsable AND ISNULL(IdEstadoGeneral, 1) = 1)
        THROW 50201, 'El usuario responsable no existe o está inactivo.', 1;
    IF @IdSolicitud IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud)
        THROW 50202, 'La solicitud indicada no existe.', 1;
    IF @IdAreaResponsable IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdAreaResponsable)
        THROW 50203, 'El área responsable no existe.', 1;

    DECLARE @IdEstadoActividad SMALLINT = (SELECT TOP (1) IdEstadoActividad FROM dbo.Cat_Estado_Actividad WHERE Codigo = 'PENDIENTE');
    IF @IdEstadoActividad IS NULL THROW 50204, 'No existe el estado PENDIENTE para actividades.', 1;

    DECLARE @IdActividad BIGINT;
    EXEC dbo.usp_ObtenerSiguienteId 'Actividad', @IdActividad OUTPUT;

    INSERT dbo.Actividad
    (
        IdActividad, IdSolicitud, IdAreaResponsable, IdUsuarioResponsable,
        IdEstadoActividad, NombreActividad, FechaLimite, Comentarios,
        RequiereTicketExterno, FechaCreacion, UsuarioCreacion
    )
    VALUES
    (
        @IdActividad, @IdSolicitud, @IdAreaResponsable, @IdUsuarioResponsable,
        @IdEstadoActividad, @NombreActividad, @FechaLimite, @Comentarios,
        ISNULL(@RequiereTicketExterno, 0), SYSDATETIME(), @Usuario
    );

    SELECT @IdActividad;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Actividad_Decidir]
    @IdActividad BIGINT,
    @IdUsuarioAprobador VARCHAR(50),
    @CodigoEstado VARCHAR(30),
    @ComentarioDecision NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @CodigoEstado = UPPER(LTRIM(RTRIM(@CodigoEstado)));
    IF @CodigoEstado NOT IN ('APROBADA', 'RECHAZADA')
        THROW 50220, 'La decisión debe ser APROBADA o RECHAZADA.', 1;
    IF @CodigoEstado = 'RECHAZADA' AND NULLIF(LTRIM(RTRIM(@ComentarioDecision)), '') IS NULL
        THROW 50221, 'Debe indicar el motivo del rechazo.', 1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Actividad a
        INNER JOIN dbo.Cat_Estado_Actividad ea ON ea.IdEstadoActividad = a.IdEstadoActividad
        WHERE a.IdActividad = @IdActividad AND ea.Codigo = 'PENDIENTE_APROBACION'
    )
        THROW 50222, 'La actividad no está pendiente de aprobación.', 1;

    DECLARE @IdEstadoActividad SMALLINT = (SELECT TOP (1) IdEstadoActividad FROM dbo.Cat_Estado_Actividad WHERE Codigo = @CodigoEstado);
    IF @IdEstadoActividad IS NULL THROW 50223, 'El estado solicitado no existe.', 1;

    UPDATE dbo.Actividad
       SET IdEstadoActividad = @IdEstadoActividad,
           IdUsuarioAprobador = @IdUsuarioAprobador,
           FechaDecision = SYSDATETIME(),
           ComentarioDecision = NULLIF(LTRIM(RTRIM(@ComentarioDecision)), ''),
           FechaFinalizacion = CASE WHEN @CodigoEstado = 'APROBADA' THEN COALESCE(FechaFinalizacion, SYSDATETIME()) ELSE NULL END,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuarioAprobador
     WHERE IdActividad = @IdActividad;

    SELECT @IdActividad;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Actividad_Mis_Listar]
    @IdUsuarioResponsable VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT a.IdActividad,
           a.IdSolicitud,
           s.NumeroSolicitud,
           a.NombreActividad,
           ar.Nombre AS AreaResponsable,
           ea.Codigo AS CodigoEstado,
           ea.Nombre AS Estado,
           CONVERT(BIT, ISNULL(ea.EsEstadoFinal, 0)) AS EsEstadoFinal,
           a.FechaLimite,
           a.FechaInicio,
           a.FechaFinalizacion,
           a.Comentarios,
           CONVERT(BIT, ISNULL(a.RequiereTicketExterno, 0)) AS RequiereTicketExterno
    FROM dbo.Actividad AS a
    LEFT JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = a.IdSolicitud
    LEFT JOIN dbo.Cat_Area AS ar ON ar.IdArea = a.IdAreaResponsable
    LEFT JOIN dbo.Cat_Estado_Actividad AS ea ON ea.IdEstadoActividad = a.IdEstadoActividad
    WHERE a.IdUsuarioResponsable = @IdUsuarioResponsable
    ORDER BY CASE WHEN ISNULL(ea.EsEstadoFinal, 0) = 0 THEN 0 ELSE 1 END,
             CASE WHEN a.FechaLimite IS NULL THEN 1 ELSE 0 END,
             a.FechaLimite,
             a.IdActividad DESC;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Aprobacion_Area_Decidir]
    @IdSolicitudPersonaArea BIGINT,
    @IdUsuarioAprobador VARCHAR(50),
    @CodigoEstado VARCHAR(30),
    @ComentarioDecision NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@IdUsuarioAprobador)), '') IS NULL
        THROW 50161, 'El usuario aprobador es obligatorio.', 1;
    IF @CodigoEstado NOT IN ('APROBADA', 'RECHAZADA')
        THROW 50162, 'La decisión debe ser APROBADA o RECHAZADA.', 1;
    IF @CodigoEstado = 'RECHAZADA' AND NULLIF(LTRIM(RTRIM(@ComentarioDecision)), '') IS NULL
        THROW 50163, 'Debes indicar el motivo del rechazo.', 1;
    DECLARE @IdEstadoAprobacion SMALLINT =
    (
        SELECT IdEstadoAprobacion
        FROM dbo.Cat_Estado_Aprobacion_Area
        WHERE Codigo = @CodigoEstado
    );
    DECLARE @IdEstadoPendiente SMALLINT =
    (
        SELECT IdEstadoAprobacion
        FROM dbo.Cat_Estado_Aprobacion_Area
        WHERE Codigo = 'PENDIENTE'
    );

    IF @IdEstadoAprobacion IS NULL OR @IdEstadoPendiente IS NULL
        THROW 50165, 'El estado de aprobación no está configurado.', 1;

    BEGIN TRANSACTION;

    DECLARE @IdEstadoActual SMALLINT;
    SELECT @IdEstadoActual = spa.IdEstadoAprobacion
    FROM dbo.Solicitud_Persona_Area AS spa WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN dbo.Cat_Area AS area
        ON area.IdArea = spa.IdArea
    INNER JOIN dbo.Config_Aprobador_Area AS ca
        ON ca.IdArea = spa.IdArea
       AND ca.IdUsuarioAprobador = @IdUsuarioAprobador
       AND ISNULL(ca.IdEstadoGeneral, 1) = 1
       AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
       AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
    WHERE spa.IdSolicitudPersonaArea = @IdSolicitudPersonaArea
      AND COALESCE(spa.RequiereAprobacion, area.RequiereAprobacion, 0) = 1;

    IF @@ROWCOUNT = 0
        THROW 50164, 'El acceso no existe, no requiere aprobación o no está asignado a este aprobador.', 1;
    IF @IdEstadoActual <> @IdEstadoPendiente
        THROW 50166, 'El acceso ya fue decidido y debe reenviarse antes de una nueva decisión.', 1;

    DECLARE @IdAprobacionArea BIGINT;
    DECLARE @NumeroReenvio SMALLINT =
    (
        SELECT CONVERT(SMALLINT, COUNT_BIG(*))
        FROM dbo.Aprobacion_Area
        WHERE IdSolicitudPersonaArea = @IdSolicitudPersonaArea
          AND IdUsuarioAprobador = @IdUsuarioAprobador
    );

    MERGE dbo.Control_Secuencia WITH (HOLDLOCK) AS destino
    USING
    (
        SELECT 'Aprobacion_Area' AS NombreEntidad,
               ISNULL(MAX(IdAprobacionArea), 0) AS UltimoValor
        FROM dbo.Aprobacion_Area
    ) AS fuente
       ON fuente.NombreEntidad = destino.NombreEntidad
    WHEN MATCHED AND ISNULL(destino.UltimoValor, 0) < fuente.UltimoValor THEN
        UPDATE SET UltimoValor = fuente.UltimoValor,
                   FechaModificacion = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (NombreEntidad, UltimoValor, FechaModificacion)
        VALUES (fuente.NombreEntidad, fuente.UltimoValor, SYSDATETIME());

    EXEC dbo.usp_ObtenerSiguienteId 'Aprobacion_Area', @IdAprobacionArea OUTPUT;

    INSERT dbo.Aprobacion_Area
    (
        IdAprobacionArea, IdSolicitudPersonaArea, IdUsuarioAprobador,
        FechaSolicitud, FechaDecision, ComentarioDecision, NumeroReenvio,
        FechaCreacion, UsuarioCreacion
    )
    VALUES
    (
        @IdAprobacionArea, @IdSolicitudPersonaArea, @IdUsuarioAprobador,
        SYSDATETIME(), SYSDATETIME(), NULLIF(LTRIM(RTRIM(@ComentarioDecision)), ''), @NumeroReenvio,
        SYSDATETIME(), @IdUsuarioAprobador
    );

    UPDATE dbo.Solicitud_Persona_Area
       SET IdEstadoAprobacion = @IdEstadoAprobacion,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuarioAprobador
     WHERE IdSolicitudPersonaArea = @IdSolicitudPersonaArea;

    IF @CodigoEstado = 'RECHAZADA'
    BEGIN
        DECLARE @IdRechazoArea BIGINT;
        MERGE dbo.Control_Secuencia WITH (HOLDLOCK) AS destino
        USING
        (
            SELECT 'Rechazo_Area' AS NombreEntidad,
                   ISNULL(MAX(IdRechazoArea), 0) AS UltimoValor
            FROM dbo.Rechazo_Area
        ) AS fuente
           ON fuente.NombreEntidad = destino.NombreEntidad
        WHEN MATCHED AND ISNULL(destino.UltimoValor, 0) < fuente.UltimoValor THEN
            UPDATE SET UltimoValor = fuente.UltimoValor,
                       FechaModificacion = SYSDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (NombreEntidad, UltimoValor, FechaModificacion)
            VALUES (fuente.NombreEntidad, fuente.UltimoValor, SYSDATETIME());

        EXEC dbo.usp_ObtenerSiguienteId 'Rechazo_Area', @IdRechazoArea OUTPUT;

        INSERT dbo.Rechazo_Area
        (
            IdRechazoArea, IdAprobacionArea, IdUsuarioRechazo, Motivo,
            FechaRechazo, FechaCreacion, UsuarioCreacion
        )
        VALUES
        (
            @IdRechazoArea, @IdAprobacionArea, @IdUsuarioAprobador, NULLIF(LTRIM(RTRIM(@ComentarioDecision)), ''),
            SYSDATETIME(), SYSDATETIME(), @IdUsuarioAprobador
        );
    END;
    EXEC dbo.usp_Solicitud_Estado_Recalcular @IdSolicitudPersonaArea, @IdUsuarioAprobador;

    COMMIT TRANSACTION;
    SELECT @IdAprobacionArea;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Aprobacion_Area_Listar]
    @IdUsuarioAprobador VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@IdUsuarioAprobador)), '') IS NULL
        THROW 50160, 'El usuario aprobador es obligatorio.', 1;

    SELECT
        spa.IdSolicitudPersonaArea,
        s.IdSolicitud,
        s.NumeroSolicitud,
        p.IdPersona,
        p.NombreCompleto AS Persona,
        p.NumeroDocumento,
        COALESCE(pr.NombreComercial, pr.NombreLegal, p.EmpresaTexto) AS Empresa,
        a.IdArea,
        a.Nombre AS Area,
        s.NombreActividad AS Actividad,
        u.Nombre AS Ubicacion,
        s.FechaInicio,
        s.FechaFin,
        COALESCE(accion.FechaSolicitud, spa.FechaCreacion) AS FechaSolicitud,
        estado.IdEstadoAprobacion,
        estado.Codigo AS CodigoEstado,
        estado.Nombre AS Estado,
        CASE WHEN estado.Codigo IN ('APROBADA', 'RECHAZADA') THEN accion.FechaDecision END AS FechaDecision,
        CASE WHEN estado.Codigo = 'RECHAZADA' THEN rechazo.Motivo
             WHEN estado.Codigo = 'APROBADA' THEN accion.ComentarioDecision END AS ComentarioDecision
    FROM dbo.Solicitud_Persona_Area AS spa
    INNER JOIN dbo.Solicitud_Persona AS sp
        ON sp.IdSolicitudPersona = spa.IdSolicitudPersona
    INNER JOIN dbo.Solicitud_Ingreso AS s
        ON s.IdSolicitud = sp.IdSolicitud
    INNER JOIN dbo.Persona AS p
        ON p.IdPersona = sp.IdPersona
    INNER JOIN dbo.Cat_Area AS a
        ON a.IdArea = spa.IdArea
    INNER JOIN dbo.Config_Aprobador_Area AS ca
       ON ca.IdArea = spa.IdArea
       AND ca.IdUsuarioAprobador = @IdUsuarioAprobador
       AND ISNULL(ca.IdEstadoGeneral, 1) = 1
       AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
       AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
    LEFT JOIN dbo.Cat_Ubicacion AS u
        ON u.IdUbicacion = s.IdUbicacion
    LEFT JOIN dbo.Proveedor AS pr
        ON pr.IdProveedor = p.IdProveedor
    LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS estado
        ON estado.IdEstadoAprobacion = spa.IdEstadoAprobacion
    OUTER APPLY
    (
        SELECT TOP (1)
            aa.FechaSolicitud,
            aa.FechaDecision,
            aa.ComentarioDecision
        FROM dbo.Aprobacion_Area AS aa
        WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
          AND aa.IdUsuarioAprobador = @IdUsuarioAprobador
        ORDER BY COALESCE(aa.FechaDecision, aa.FechaSolicitud, aa.FechaCreacion) DESC,
                 aa.IdAprobacionArea DESC
    ) AS accion
    OUTER APPLY
    (
        SELECT TOP (1) r.Motivo
        FROM dbo.Rechazo_Area AS r
        INNER JOIN dbo.Aprobacion_Area AS aa
            ON aa.IdAprobacionArea = r.IdAprobacionArea
        WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
          AND aa.IdUsuarioAprobador = @IdUsuarioAprobador
        ORDER BY COALESCE(r.FechaRechazo, r.FechaCreacion) DESC,
                 r.IdRechazoArea DESC
    ) AS rechazo
    WHERE COALESCE(spa.RequiereAprobacion, a.RequiereAprobacion, 0) = 1
    ORDER BY
        CASE WHEN estado.Codigo = 'PENDIENTE' THEN 0 ELSE 1 END,
        COALESCE(accion.FechaSolicitud, spa.FechaCreacion) DESC,
        spa.IdSolicitudPersonaArea DESC;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Catalogo_Listar]
    @Catalogo VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Catalogo = 'estados-generales'
        SELECT CONVERT(INT, IdEstadoGeneral), Codigo, Nombre, Descripcion FROM dbo.Cat_Estado_General WHERE ISNULL(EsActivo, 1) = 1 ORDER BY OrdenVisualizacion, Nombre;
    ELSE IF @Catalogo = 'tipos-ingreso'
        SELECT CONVERT(INT, IdTipoIngreso), Codigo, Nombre, Descripcion FROM dbo.Cat_Tipo_Ingreso WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE IF @Catalogo = 'estados-solicitud'
        SELECT CONVERT(INT, IdEstadoSolicitud), Codigo, Nombre, Descripcion FROM dbo.Cat_Estado_Solicitud WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY OrdenFlujo, Nombre;
    ELSE IF @Catalogo = 'estados-persona'
        SELECT CONVERT(INT, IdEstadoPersonaSolicitud), Codigo, Nombre, Descripcion FROM dbo.Cat_Estado_Persona_Solicitud WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE IF @Catalogo = 'tipos-documento'
        SELECT CONVERT(INT, IdTipoDocumento), Codigo, Nombre, CONVERT(NVARCHAR(300), NULL) FROM dbo.Cat_Tipo_Documento WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE IF @Catalogo = 'tipos-aplicacion'
        SELECT CONVERT(INT, IdTipoAplicacion), Codigo, Nombre, Descripcion FROM dbo.Cat_Tipo_Aplicacion_Requerimiento WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE IF @Catalogo = 'areas'
        SELECT IdArea, Codigo, Nombre, Descripcion FROM dbo.Cat_Area WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE IF @Catalogo = 'ubicaciones'
        SELECT IdUbicacion, Codigo, Nombre, Direccion FROM dbo.Cat_Ubicacion WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE IF @Catalogo = 'categorias-requerimiento'
        SELECT IdCategoriaRequerimiento, Codigo, Nombre, Descripcion FROM dbo.Cat_Categoria_Requerimiento WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY OrdenVisualizacion, Nombre;
    ELSE IF @Catalogo = 'requerimientos'
        SELECT IdRequerimiento, Codigo, Nombre, Descripcion FROM dbo.Cat_Requerimiento WHERE ISNULL(IdEstadoGeneral, 1) = 1 ORDER BY Nombre;
    ELSE
        THROW 50100, 'Catálogo no permitido.', 1;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Historial_Solicitud_Registrar]
    @IdSolicitud BIGINT,
    @TipoEvento VARCHAR(60),
    @Accion NVARCHAR(200),
    @Comentario NVARCHAR(1000)=NULL,
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdHistorial BIGINT;
    EXEC dbo.usp_ObtenerSiguienteId 'Historial_Solicitud',@IdHistorial OUTPUT;
    INSERT dbo.Historial_Solicitud(IdHistorialSolicitud,IdSolicitud,TipoEvento,Accion,Comentario,IdUsuarioAccion,FechaAccion,FechaCreacion,UsuarioCreacion)
    VALUES(@IdHistorial,@IdSolicitud,@TipoEvento,@Accion,@Comentario,@IdUsuario,SYSDATETIME(),SYSDATETIME(),@IdUsuario);
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_ObtenerSiguienteId]
    @NombreEntidad VARCHAR(100),
    @IdGenerado    BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@NombreEntidad)), '') IS NULL
        THROW 50001, 'El nombre de la entidad es obligatorio.', 1;

    BEGIN TRANSACTION;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Control_Secuencia WITH (UPDLOCK, HOLDLOCK)
        WHERE NombreEntidad = @NombreEntidad
    )
    BEGIN
        INSERT INTO dbo.Control_Secuencia
        (
            NombreEntidad,
            UltimoValor,
            FechaModificacion,
            UsuarioModificacion
        )
        VALUES
        (
            @NombreEntidad,
            0,
            SYSDATETIME(),
            NULL
        );
    END;

    UPDATE dbo.Control_Secuencia WITH (UPDLOCK, HOLDLOCK)
       SET UltimoValor = ISNULL(UltimoValor, 0) + 1,
           FechaModificacion = SYSDATETIME()
     WHERE NombreEntidad = @NombreEntidad;

    SELECT @IdGenerado = UltimoValor
    FROM dbo.Control_Secuencia
    WHERE NombreEntidad = @NombreEntidad;

    COMMIT TRANSACTION;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Persona_Accesos_Obtener] @IdPersona BIGINT AS BEGIN SET NOCOUNT ON; SELECT p.IdPersona, p.NumeroDocumento, p.NombreCompleto, p.FotografiaUrl, p.Telefono, p.Correo, p.CargoFuncion, COALESCE(pr.NombreComercial, pr.NombreLegal, p.EmpresaTexto) AS Empresa, eg.Nombre AS Estado FROM dbo.Persona AS p LEFT JOIN dbo.Proveedor AS pr ON pr.IdProveedor = p.IdProveedor LEFT JOIN dbo.Cat_Estado_General AS eg ON eg.IdEstadoGeneral = p.IdEstadoGeneral WHERE p.IdPersona = @IdPersona; SELECT spa.IdSolicitudPersonaArea, s.IdSolicitud, s.NumeroSolicitud, s.NombreActividad, a.IdArea, a.Nombre AS Area, u.Nombre AS Ubicacion, s.FechaInicio, s.FechaFin, COALESCE(spa.RequiereAprobacion, a.RequiereAprobacion) AS RequiereAprobacion, estado.Nombre AS EstadoAcceso, estado.Codigo AS CodigoEstadoAcceso, CASE WHEN estado.Codigo IN ('APROBADA', 'RECHAZADA') THEN ultimaAccion.FechaDecision END AS FechaDecision, CASE WHEN estado.Codigo = 'RECHAZADA' THEN ultimoRechazo.Motivo WHEN estado.Codigo = 'APROBADA' THEN ultimaAccion.ComentarioDecision END AS ComentarioDecision FROM dbo.Solicitud_Persona AS sp INNER JOIN dbo.Solicitud_Ingreso AS s ON s.IdSolicitud = sp.IdSolicitud INNER JOIN dbo.Solicitud_Persona_Area AS spa ON spa.IdSolicitudPersona = sp.IdSolicitudPersona LEFT JOIN dbo.Cat_Area AS a ON a.IdArea = spa.IdArea LEFT JOIN dbo.Cat_Ubicacion AS u ON u.IdUbicacion = s.IdUbicacion LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS estado ON estado.IdEstadoAprobacion = spa.IdEstadoAprobacion OUTER APPLY (SELECT TOP (1) aa.FechaDecision, aa.ComentarioDecision FROM dbo.Aprobacion_Area AS aa WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea ORDER BY COALESCE(aa.FechaDecision, aa.FechaSolicitud, aa.FechaCreacion) DESC, aa.IdAprobacionArea DESC) AS ultimaAccion OUTER APPLY (SELECT TOP (1) r.Motivo FROM dbo.Rechazo_Area AS r INNER JOIN dbo.Aprobacion_Area AS aa ON aa.IdAprobacionArea = r.IdAprobacionArea WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea ORDER BY COALESCE(r.FechaRechazo, r.FechaCreacion) DESC, r.IdRechazoArea DESC) AS ultimoRechazo WHERE sp.IdPersona = @IdPersona ORDER BY s.FechaInicio DESC, a.Nombre; END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Persona_Crear]
    @IdTipoDocumento SMALLINT = NULL,
    @NumeroDocumento VARCHAR(60),
    @NombreCompleto NVARCHAR(200),
    @FotografiaUrl NVARCHAR(500) = NULL,
    @Telefono VARCHAR(30) = NULL,
    @Correo VARCHAR(254) = NULL,
    @CargoFuncion NVARCHAR(150) = NULL,
    @IdProveedor BIGINT = NULL,
    @EmpresaTexto NVARCHAR(200) = NULL,
    @InformacionAdicional NVARCHAR(1000) = NULL,
    @IdEstadoGeneral SMALLINT = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@NumeroDocumento)), '') IS NULL THROW 50110, 'NumeroDocumento es obligatorio.', 1;
    IF NULLIF(LTRIM(RTRIM(@NombreCompleto)), '') IS NULL THROW 50111, 'NombreCompleto es obligatorio.', 1;
    IF @IdTipoDocumento IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Documento WHERE IdTipoDocumento = @IdTipoDocumento)
        THROW 50112, 'El tipo de documento no existe.', 1;
    IF @IdProveedor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE IdProveedor = @IdProveedor)
        THROW 50113, 'El proveedor no existe.', 1;
    IF @IdEstadoGeneral IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_General WHERE IdEstadoGeneral = @IdEstadoGeneral)
        THROW 50114, 'El estado general no existe.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Persona WHERE NumeroDocumento = @NumeroDocumento AND (IdTipoDocumento = @IdTipoDocumento OR (IdTipoDocumento IS NULL AND @IdTipoDocumento IS NULL)))
        THROW 50115, 'Ya existe una persona con ese tipo y número de documento.', 1;

    DECLARE @IdPersona BIGINT;
    EXEC dbo.usp_ObtenerSiguienteId 'Persona', @IdPersona OUTPUT;
    INSERT dbo.Persona (IdPersona, IdTipoDocumento, NumeroDocumento, NombreCompleto, FotografiaUrl, Telefono, Correo, CargoFuncion, IdProveedor, EmpresaTexto, InformacionAdicional, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (@IdPersona, @IdTipoDocumento, @NumeroDocumento, @NombreCompleto, @FotografiaUrl, @Telefono, @Correo, @CargoFuncion, @IdProveedor, @EmpresaTexto, @InformacionAdicional, @IdEstadoGeneral, SYSDATETIME(), @Usuario);
    SELECT @IdPersona;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Persona_Listar]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.IdPersona,
        p.NumeroDocumento,
        p.NombreCompleto,
        p.CargoFuncion,
        COALESCE(pr.NombreComercial, pr.NombreLegal, p.EmpresaTexto) AS Empresa,
        eg.Nombre AS Estado,
        CONVERT(INT, COUNT(DISTINCT spa.IdSolicitudPersonaArea)) AS CantidadAccesos
    FROM dbo.Persona AS p
    LEFT JOIN dbo.Proveedor AS pr ON pr.IdProveedor = p.IdProveedor
    LEFT JOIN dbo.Cat_Estado_General AS eg ON eg.IdEstadoGeneral = p.IdEstadoGeneral
    LEFT JOIN dbo.Solicitud_Persona AS sp ON sp.IdPersona = p.IdPersona
    LEFT JOIN dbo.Solicitud_Persona_Area AS spa ON spa.IdSolicitudPersona = sp.IdSolicitudPersona
    GROUP BY p.IdPersona, p.NumeroDocumento, p.NombreCompleto, p.CargoFuncion,
             pr.NombreComercial, pr.NombreLegal, p.EmpresaTexto, eg.Nombre
    ORDER BY p.NombreCompleto, p.IdPersona;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Proveedor_Crear]
    @Codigo VARCHAR(30) = NULL,
    @NombreLegal NVARCHAR(200),
    @NombreComercial NVARCHAR(200) = NULL,
    @RTN VARCHAR(30) = NULL,
    @ContactoPrincipal NVARCHAR(200) = NULL,
    @CorreoPrincipal VARCHAR(254) = NULL,
    @TelefonoPrincipal VARCHAR(30) = NULL,
    @IdEstadoGeneral SMALLINT = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@NombreLegal)), '') IS NULL THROW 50101, 'NombreLegal es obligatorio.', 1;
    IF NULLIF(LTRIM(RTRIM(@Usuario)), '') IS NULL THROW 50102, 'Usuario es obligatorio.', 1;
    IF @IdEstadoGeneral IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_General WHERE IdEstadoGeneral = @IdEstadoGeneral)
        THROW 50103, 'El estado general no existe.', 1;
    IF @RTN IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Proveedor WHERE RTN = @RTN)
        THROW 50104, 'Ya existe un proveedor con ese RTN.', 1;

    DECLARE @IdProveedor BIGINT;
    EXEC dbo.usp_ObtenerSiguienteId 'Proveedor', @IdProveedor OUTPUT;
    INSERT dbo.Proveedor (IdProveedor, Codigo, NombreLegal, NombreComercial, RTN, ContactoPrincipal, CorreoPrincipal, TelefonoPrincipal, IdEstadoGeneral, FechaCreacion, UsuarioCreacion)
    VALUES (@IdProveedor, @Codigo, @NombreLegal, @NombreComercial, @RTN, @ContactoPrincipal, @CorreoPrincipal, @TelefonoPrincipal, @IdEstadoGeneral, SYSDATETIME(), @Usuario);
    SELECT @IdProveedor;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Registro_Ingreso_Listar] AS
BEGIN
 SET NOCOUNT ON;
 SELECT TOP(200) ri.IdRegistroIngreso,ri.IdPersona,p.NumeroDocumento,p.NombreCompleto,ri.IdSolicitud,s.NumeroSolicitud,s.NombreActividad,ri.TipoMovimiento,ri.FechaMovimiento,ri.IdUsuarioSeguridad,u.NombreCompleto,ri.Observaciones
 FROM dbo.Registro_Ingreso ri JOIN dbo.Persona p ON p.IdPersona=ri.IdPersona JOIN dbo.Solicitud_Ingreso s ON s.IdSolicitud=ri.IdSolicitud LEFT JOIN dbo.Usuario u ON u.IdUsuario=ri.IdUsuarioSeguridad ORDER BY ri.FechaMovimiento DESC,ri.IdRegistroIngreso DESC;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Registro_Ingreso_Registrar] @IdPersona BIGINT,@TipoMovimiento VARCHAR(10),@IdUsuarioSeguridad VARCHAR(50),@Observaciones NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON; SET @TipoMovimiento=UPPER(LTRIM(RTRIM(@TipoMovimiento)));
    IF @TipoMovimiento NOT IN('ENTRADA','SALIDA') THROW 50510,'El movimiento debe ser ENTRADA o SALIDA.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Persona WHERE IdPersona=@IdPersona) THROW 50511,'La persona no existe.',1;
    DECLARE @IdSolicitud BIGINT,@IdSolicitudPersona BIGINT;
    IF @TipoMovimiento='ENTRADA'
    BEGIN
      SELECT TOP(1) @IdSolicitud=s.IdSolicitud,@IdSolicitudPersona=sp.IdSolicitudPersona FROM dbo.Solicitud_Persona sp JOIN dbo.Solicitud_Ingreso s ON s.IdSolicitud=sp.IdSolicitud JOIN dbo.Cat_Estado_Solicitud es ON es.IdEstadoSolicitud=s.IdEstadoSolicitud WHERE sp.IdPersona=@IdPersona AND es.Codigo='LISTA_INGRESO' AND CONVERT(date,SYSDATETIME()) BETWEEN s.FechaInicio AND s.FechaFin ORDER BY s.FechaInicio DESC;
      IF @IdSolicitud IS NULL THROW 50512,'La persona no tiene una autorización vigente y completamente aprobada.',1;
      IF EXISTS(SELECT 1 FROM dbo.Registro_Ingreso ri WHERE ri.IdPersona=@IdPersona AND ri.IdSolicitud=@IdSolicitud AND ri.TipoMovimiento='ENTRADA' AND NOT EXISTS(SELECT 1 FROM dbo.Registro_Ingreso rs WHERE rs.IdPersona=ri.IdPersona AND rs.IdSolicitud=ri.IdSolicitud AND rs.TipoMovimiento='SALIDA' AND rs.FechaMovimiento>ri.FechaMovimiento)) THROW 50513,'La persona ya tiene una entrada abierta.',1;
    END
    ELSE
    BEGIN
      SELECT TOP(1) @IdSolicitud=ri.IdSolicitud,@IdSolicitudPersona=ri.IdSolicitudPersona FROM dbo.Registro_Ingreso ri WHERE ri.IdPersona=@IdPersona AND ri.TipoMovimiento='ENTRADA' AND NOT EXISTS(SELECT 1 FROM dbo.Registro_Ingreso rs WHERE rs.IdPersona=ri.IdPersona AND rs.IdSolicitud=ri.IdSolicitud AND rs.TipoMovimiento='SALIDA' AND rs.FechaMovimiento>ri.FechaMovimiento) ORDER BY ri.FechaMovimiento DESC;
      IF @IdSolicitud IS NULL THROW 50514,'La persona no tiene una entrada abierta para registrar salida.',1;
    END;
    DECLARE @Id BIGINT; EXEC dbo.usp_ObtenerSiguienteId 'Registro_Ingreso',@Id OUTPUT;
    INSERT dbo.Registro_Ingreso(IdRegistroIngreso,IdPersona,IdSolicitud,IdSolicitudPersona,TipoMovimiento,FechaMovimiento,IdUsuarioSeguridad,Observaciones) VALUES(@Id,@IdPersona,@IdSolicitud,@IdSolicitudPersona,@TipoMovimiento,SYSDATETIME(),@IdUsuarioSeguridad,NULLIF(LTRIM(RTRIM(@Observaciones)),''));
    EXEC dbo.usp_Historial_Solicitud_Registrar @IdSolicitud,'CONTROL_ACCESO',N'Movimiento registrado en portería',@TipoMovimiento,@IdUsuarioSeguridad;
    SELECT @Id;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE [dbo].[usp_Solicitud_Enviar]
    @IdSolicitud BIGINT,
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud)
        THROW 50500, 'La solicitud no existe.', 1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Solicitud_Ingreso AS solicitud
        WHERE solicitud.IdSolicitud = @IdSolicitud
          AND
          (
              solicitud.IdUsuarioSolicitante = @IdUsuario
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.Usuario_Rol AS usuarioRol
                  INNER JOIN dbo.Rol AS rol ON rol.IdRol = usuarioRol.IdRol
                  WHERE usuarioRol.IdUsuario = @IdUsuario
                    AND rol.Codigo = 'ADMINISTRADOR'
              )
          )
    )
        THROW 50501, 'No tienes permiso para enviar esta solicitud.', 1;
    IF EXISTS
    (
        SELECT 1
        FROM dbo.Solicitud_Ingreso AS solicitud
        INNER JOIN dbo.Cat_Estado_Solicitud AS estado ON estado.IdEstadoSolicitud = solicitud.IdEstadoSolicitud
        WHERE solicitud.IdSolicitud = @IdSolicitud
          AND estado.EsEstadoFinal = 1
    )
        THROW 50502, 'La solicitud ya está finalizada o cancelada.', 1;

    DECLARE @IdPendiente SMALLINT =
    (
        SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'PENDIENTE'
    );
    DECLARE @IdNoRequiere SMALLINT =
    (
        SELECT IdEstadoAprobacion FROM dbo.Cat_Estado_Aprobacion_Area WHERE Codigo = 'NO_REQUIERE'
    );
    IF @IdPendiente IS NULL OR @IdNoRequiere IS NULL
        THROW 50503, 'No están configurados los estados de aprobación requeridos.', 1;

    UPDATE acceso
       SET RequiereAprobacion = calculo.RequiereAprobacion,
           IdEstadoAprobacion = CASE WHEN calculo.RequiereAprobacion = 1 THEN @IdPendiente ELSE @IdNoRequiere END,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuario
    FROM dbo.Solicitud_Persona_Area AS acceso
    INNER JOIN dbo.Solicitud_Persona AS personaSolicitud
        ON personaSolicitud.IdSolicitudPersona = acceso.IdSolicitudPersona
    CROSS APPLY
    (
        SELECT CONVERT(BIT, CASE WHEN EXISTS
        (
            SELECT 1
            FROM dbo.Config_Aprobador_Area AS configuracion
            WHERE configuracion.IdArea = acceso.IdArea
              AND ISNULL(configuracion.IdEstadoGeneral, 1) = 1
              AND (configuracion.FechaInicio IS NULL OR configuracion.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
              AND (configuracion.FechaFin IS NULL OR configuracion.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ) THEN 1 ELSE 0 END) AS RequiereAprobacion
    ) AS calculo
    WHERE personaSolicitud.IdSolicitud = @IdSolicitud;

    DECLARE @CodigoEstado VARCHAR(40) = CASE
        WHEN NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud)
         AND EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud AND IdProveedor IS NOT NULL)
            THEN 'PENDIENTE_PROVEEDOR'
        WHEN NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud)
            THEN 'EN_REVISION'
        WHEN EXISTS
        (
            SELECT 1
            FROM dbo.Solicitud_Persona_Area AS acceso
            INNER JOIN dbo.Solicitud_Persona AS personaSolicitud
                ON personaSolicitud.IdSolicitudPersona = acceso.IdSolicitudPersona
            WHERE personaSolicitud.IdSolicitud = @IdSolicitud
              AND acceso.RequiereAprobacion = 1
        )
            THEN 'PENDIENTE_APROBACIONES'
        ELSE 'LISTA_INGRESO'
    END;

    UPDATE solicitud
       SET IdEstadoSolicitud = estado.IdEstadoSolicitud,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuario,
           FechaEnvioProveedor = CASE WHEN @CodigoEstado = 'PENDIENTE_PROVEEDOR'
                                      THEN SYSDATETIME() ELSE FechaEnvioProveedor END
    FROM dbo.Solicitud_Ingreso AS solicitud
    INNER JOIN dbo.Cat_Estado_Solicitud AS estado ON estado.Codigo = @CodigoEstado
    WHERE solicitud.IdSolicitud = @IdSolicitud;

    EXEC dbo.usp_Historial_Solicitud_Registrar
        @IdSolicitud, 'ESTADO_SOLICITUD', N'Solicitud enviada al flujo', @CodigoEstado, @IdUsuario;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE [dbo].[usp_Solicitud_Estado_Recalcular]
    @IdSolicitudPersonaArea BIGINT,
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdSolicitud BIGINT =
    (
        SELECT personaSolicitud.IdSolicitud
        FROM dbo.Solicitud_Persona_Area AS acceso
        INNER JOIN dbo.Solicitud_Persona AS personaSolicitud
            ON personaSolicitud.IdSolicitudPersona = acceso.IdSolicitudPersona
        WHERE acceso.IdSolicitudPersonaArea = @IdSolicitudPersonaArea
    );
    IF @IdSolicitud IS NULL RETURN;

    DECLARE @CodigoEstado VARCHAR(40);
    IF EXISTS
    (
        SELECT 1
        FROM dbo.Solicitud_Persona_Area AS acceso
        INNER JOIN dbo.Solicitud_Persona AS personaSolicitud
            ON personaSolicitud.IdSolicitudPersona = acceso.IdSolicitudPersona
        INNER JOIN dbo.Cat_Estado_Aprobacion_Area AS estado
            ON estado.IdEstadoAprobacion = acceso.IdEstadoAprobacion
        WHERE personaSolicitud.IdSolicitud = @IdSolicitud
          AND acceso.RequiereAprobacion = 1
          AND estado.Codigo = 'RECHAZADA'
    )
        SET @CodigoEstado = 'EN_REVISION';
    ELSE IF EXISTS
    (
        SELECT 1
        FROM dbo.Solicitud_Persona_Area AS acceso
        INNER JOIN dbo.Solicitud_Persona AS personaSolicitud
            ON personaSolicitud.IdSolicitudPersona = acceso.IdSolicitudPersona
        LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS estado
            ON estado.IdEstadoAprobacion = acceso.IdEstadoAprobacion
        WHERE personaSolicitud.IdSolicitud = @IdSolicitud
          AND acceso.RequiereAprobacion = 1
          AND ISNULL(estado.Codigo, 'PENDIENTE') <> 'APROBADA'
    )
        SET @CodigoEstado = 'PENDIENTE_APROBACIONES';
    ELSE
        SET @CodigoEstado = 'LISTA_INGRESO';

    UPDATE solicitud
       SET IdEstadoSolicitud = estado.IdEstadoSolicitud,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuario
    FROM dbo.Solicitud_Ingreso AS solicitud
    INNER JOIN dbo.Cat_Estado_Solicitud AS estado ON estado.Codigo = @CodigoEstado
    WHERE solicitud.IdSolicitud = @IdSolicitud;

    EXEC dbo.usp_Historial_Solicitud_Registrar
        @IdSolicitud, 'APROBACION_AREA', N'Estado consolidado después de una decisión', @CodigoEstado, @IdUsuario;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Solicitud_Formulario_Datos]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT IdTipoIngreso, Codigo, Nombre
    FROM dbo.Cat_Tipo_Ingreso
    WHERE ISNULL(IdEstadoGeneral, 1) = 1
    ORDER BY Nombre;

    SELECT IdEstadoSolicitud, Codigo, Nombre
    FROM dbo.Cat_Estado_Solicitud
    WHERE ISNULL(IdEstadoGeneral, 1) = 1
    ORDER BY OrdenFlujo, Nombre;

    SELECT IdArea, Codigo, Nombre
    FROM dbo.Cat_Area
    WHERE ISNULL(IdEstadoGeneral, 1) = 1
    ORDER BY Nombre;

    SELECT IdUbicacion, Codigo, Nombre
    FROM dbo.Cat_Ubicacion
    WHERE ISNULL(IdEstadoGeneral, 1) = 1
    ORDER BY Nombre;

    SELECT IdProveedor, Codigo, COALESCE(NombreComercial, NombreLegal)
    FROM dbo.Proveedor
    WHERE ISNULL(IdEstadoGeneral, 1) = 1
    ORDER BY COALESCE(NombreComercial, NombreLegal);

    SELECT IdUsuario, CONVERT(VARCHAR(30), NULL), NombreCompleto
    FROM dbo.Usuario
    WHERE ISNULL(IdEstadoGeneral, 1) = 1
    ORDER BY NombreCompleto;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Solicitud_Ingreso_Actualizar]
    @IdSolicitud BIGINT,
    @IdTipoIngreso SMALLINT = NULL,
    @IdEstadoSolicitud SMALLINT = NULL,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL,
    @NombreActividad NVARCHAR(200),
    @DescripcionActividad NVARCHAR(1000) = NULL,
    @IdProveedor BIGINT = NULL,
    @NumeroContrato VARCHAR(60) = NULL,
    @ContactoProveedor NVARCHAR(200) = NULL,
    @CorreoProveedor VARCHAR(254) = NULL,
    @CantidadEstimada INT = NULL,
    @IdAreaSolicitante INT = NULL,
    @IdUsuarioSolicitante VARCHAR(50),
    @IdUbicacion INT = NULL,
    @Observaciones NVARCHAR(1000) = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud) BEGIN SELECT 0; RETURN; END;
    IF NULLIF(LTRIM(RTRIM(@NombreActividad)), '') IS NULL THROW 50142, 'NombreActividad es obligatorio.', 1;
    IF NULLIF(LTRIM(RTRIM(@Usuario)), '') IS NULL THROW 50143, 'Usuario es obligatorio.', 1;
    IF @FechaInicio IS NOT NULL AND @FechaFin IS NOT NULL AND @FechaFin < @FechaInicio THROW 50144, 'El rango de fechas no es válido.', 1;
    IF @CantidadEstimada IS NOT NULL AND @CantidadEstimada < 0 THROW 50145, 'CantidadEstimada no puede ser negativa.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuarioSolicitante) THROW 50146, 'El usuario solicitante no existe.', 1;
    IF @IdTipoIngreso IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Ingreso WHERE IdTipoIngreso = @IdTipoIngreso) THROW 50147, 'El tipo de ingreso no existe.', 1;
    IF @IdEstadoSolicitud IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Solicitud WHERE IdEstadoSolicitud = @IdEstadoSolicitud) THROW 50148, 'El estado de solicitud no existe.', 1;
    IF @IdProveedor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE IdProveedor = @IdProveedor) THROW 50149, 'El proveedor no existe.', 1;
    IF @IdAreaSolicitante IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdAreaSolicitante) THROW 50150, 'El área solicitante no existe.', 1;
    IF @IdUbicacion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Ubicacion WHERE IdUbicacion = @IdUbicacion) THROW 50151, 'La ubicación no existe.', 1;

    UPDATE dbo.Solicitud_Ingreso
       SET IdTipoIngreso = @IdTipoIngreso,
           IdEstadoSolicitud = @IdEstadoSolicitud,
           FechaInicio = @FechaInicio,
           FechaFin = @FechaFin,
           NombreActividad = @NombreActividad,
           DescripcionActividad = @DescripcionActividad,
           IdProveedor = @IdProveedor,
           NumeroContrato = @NumeroContrato,
           ContactoProveedor = @ContactoProveedor,
           CorreoProveedor = @CorreoProveedor,
           CantidadEstimada = @CantidadEstimada,
           IdAreaSolicitante = @IdAreaSolicitante,
           IdUsuarioSolicitante = @IdUsuarioSolicitante,
           IdUbicacion = @IdUbicacion,
           Observaciones = @Observaciones,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @Usuario
     WHERE IdSolicitud = @IdSolicitud;
    SELECT @@ROWCOUNT;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Solicitud_Ingreso_Crear]
    @IdTipoIngreso SMALLINT = NULL,
    @IdEstadoSolicitud SMALLINT = NULL,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL,
    @NombreActividad NVARCHAR(200),
    @DescripcionActividad NVARCHAR(1000) = NULL,
    @IdProveedor BIGINT = NULL,
    @NumeroContrato VARCHAR(60) = NULL,
    @ContactoProveedor NVARCHAR(200) = NULL,
    @CorreoProveedor VARCHAR(254) = NULL,
    @CantidadEstimada INT = NULL,
    @IdAreaSolicitante INT = NULL,
    @IdUsuarioSolicitante VARCHAR(50),
    @IdUbicacion INT = NULL,
    @Observaciones NVARCHAR(1000) = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@NombreActividad)), '') IS NULL THROW 50120, 'NombreActividad es obligatorio.', 1;
    IF @FechaInicio IS NOT NULL AND @FechaFin IS NOT NULL AND @FechaFin < @FechaInicio THROW 50121, 'El rango de fechas no es válido.', 1;
    IF @CantidadEstimada IS NOT NULL AND @CantidadEstimada < 0 THROW 50122, 'CantidadEstimada no puede ser negativa.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuarioSolicitante) THROW 50123, 'El usuario solicitante no existe.', 1;
    IF @IdTipoIngreso IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Ingreso WHERE IdTipoIngreso = @IdTipoIngreso) THROW 50124, 'El tipo de ingreso no existe.', 1;
    IF @IdEstadoSolicitud IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Solicitud WHERE IdEstadoSolicitud = @IdEstadoSolicitud) THROW 50125, 'El estado de solicitud no existe.', 1;
    IF @IdProveedor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE IdProveedor = @IdProveedor) THROW 50126, 'El proveedor no existe.', 1;
    IF @IdAreaSolicitante IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Area WHERE IdArea = @IdAreaSolicitante) THROW 50127, 'El área solicitante no existe.', 1;
    IF @IdUbicacion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Ubicacion WHERE IdUbicacion = @IdUbicacion) THROW 50128, 'La ubicación no existe.', 1;

    DECLARE @IdSolicitud BIGINT, @NumeroSolicitud VARCHAR(30);
    EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Ingreso', @IdSolicitud OUTPUT;
    SET @NumeroSolicitud = CONCAT('SOL-', RIGHT(REPLICATE('0', 10) + CONVERT(VARCHAR(20), @IdSolicitud), 10));
    INSERT dbo.Solicitud_Ingreso (IdSolicitud, NumeroSolicitud, IdTipoIngreso, IdEstadoSolicitud, FechaInicio, FechaFin, NombreActividad, DescripcionActividad, IdProveedor, NumeroContrato, ContactoProveedor, CorreoProveedor, CantidadEstimada, IdAreaSolicitante, IdUsuarioSolicitante, IdUbicacion, Observaciones, FechaCreacion, UsuarioCreacion)
    VALUES (@IdSolicitud, @NumeroSolicitud, @IdTipoIngreso, @IdEstadoSolicitud, @FechaInicio, @FechaFin, @NombreActividad, @DescripcionActividad, @IdProveedor, @NumeroContrato, @ContactoProveedor, @CorreoProveedor, @CantidadEstimada, @IdAreaSolicitante, @IdUsuarioSolicitante, @IdUbicacion, @Observaciones, SYSDATETIME(), @Usuario);
    SELECT @IdSolicitud AS IdSolicitud, @NumeroSolicitud AS NumeroSolicitud;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Solicitud_Ingreso_Eliminar] @IdSolicitud BIGINT,@Usuario VARCHAR(50)
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud=@IdSolicitud) BEGIN SELECT 0; RETURN; END;
 DECLARE @Cancelada SMALLINT=(SELECT TOP(1) IdEstadoSolicitud FROM dbo.Cat_Estado_Solicitud WHERE Codigo='CANCELADA');
 UPDATE dbo.Solicitud_Ingreso SET IdEstadoSolicitud=@Cancelada,FechaModificacion=SYSDATETIME(),UsuarioModificacion=@Usuario WHERE IdSolicitud=@IdSolicitud;
 DECLARE @Filas INT=@@ROWCOUNT;
 IF @Filas>0 EXEC dbo.usp_Historial_Solicitud_Registrar @IdSolicitud,'ESTADO_SOLICITUD',N'Solicitud cancelada',NULL,@Usuario;
 SELECT @Filas;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE [dbo].[usp_Solicitud_Ingreso_Listar]
    @IdUsuario VARCHAR(50),
    @AccesoTotal BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.IdSolicitud,
           s.NumeroSolicitud,
           ti.Nombre,
           es.Nombre,
           s.FechaInicio,
           s.FechaFin,
           s.NombreActividad,
           u.NombreCompleto,
           CONVERT(INT, COUNT(sp.IdSolicitudPersona))
    FROM dbo.Solicitud_Ingreso AS s
    LEFT JOIN dbo.Cat_Tipo_Ingreso AS ti ON ti.IdTipoIngreso = s.IdTipoIngreso
    LEFT JOIN dbo.Cat_Estado_Solicitud AS es ON es.IdEstadoSolicitud = s.IdEstadoSolicitud
    LEFT JOIN dbo.Usuario AS u ON u.IdUsuario = s.IdUsuarioSolicitante
    LEFT JOIN dbo.Solicitud_Persona AS sp ON sp.IdSolicitud = s.IdSolicitud
    WHERE (@AccesoTotal = 1 OR s.IdUsuarioSolicitante = @IdUsuario)
      AND ISNULL(es.Codigo, '') <> 'CANCELADA'
    GROUP BY s.IdSolicitud, s.NumeroSolicitud, ti.Nombre, es.Nombre,
             s.FechaInicio, s.FechaFin, s.NombreActividad, u.NombreCompleto, s.FechaCreacion
    ORDER BY s.FechaCreacion DESC, s.IdSolicitud DESC;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Solicitud_Ingreso_Obtener]
    @IdSolicitud BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdSolicitud,
        NumeroSolicitud,
        IdTipoIngreso,
        IdEstadoSolicitud,
        FechaInicio,
        FechaFin,
        NombreActividad,
        DescripcionActividad,
        IdProveedor,
        NumeroContrato,
        ContactoProveedor,
        CorreoProveedor,
        CantidadEstimada,
        IdAreaSolicitante,
        IdUsuarioSolicitante,
        IdUbicacion,
        Observaciones,
        FechaCreacion
    FROM dbo.Solicitud_Ingreso
    WHERE IdSolicitud = @IdSolicitud;

    SELECT
        sp.IdSolicitudPersona,
        sp.IdPersona,
        p.NumeroDocumento,
        p.NombreCompleto,
        sp.IdEstadoPersonaSolicitud,
        sp.DatosCompletos,
        CASE
            WHEN ISNULL(resumen.AreasRechazadas, 0) > 0 THEN 'RECHAZADA'
            WHEN ISNULL(resumen.AreasPendientes, 0) > 0 THEN 'PENDIENTE'
            WHEN ISNULL(resumen.AreasRequeridas, 0) = 0 THEN 'NO_REQUIERE'
            ELSE 'APROBADA'
        END AS CodigoEstadoAprobacion,
        CASE
            WHEN ISNULL(resumen.AreasRechazadas, 0) > 0 THEN N'Rechazada'
            WHEN ISNULL(resumen.AreasPendientes, 0) > 0 THEN N'Pendiente de aprobación'
            WHEN ISNULL(resumen.AreasRequeridas, 0) = 0 THEN N'No requiere aprobación'
            ELSE N'Aprobada'
        END AS EstadoAprobacion,
        ISNULL(resumen.AreasAprobadas, 0) AS AreasAprobadas,
        ISNULL(resumen.AreasPendientes, 0) AS AreasPendientes,
        ISNULL(resumen.AreasRechazadas, 0) AS AreasRechazadas,
        rechazos.DetalleRechazos
    FROM dbo.Solicitud_Persona AS sp
    LEFT JOIN dbo.Persona AS p ON p.IdPersona = sp.IdPersona
    OUTER APPLY
    (
        SELECT
            COUNT(CASE WHEN ISNULL(spa.RequiereAprobacion, 0) = 1 THEN 1 END) AS AreasRequeridas,
            COUNT(CASE WHEN ISNULL(spa.RequiereAprobacion, 0) = 1 AND ultima.Codigo = 'APROBADA' THEN 1 END) AS AreasAprobadas,
            COUNT(CASE WHEN ISNULL(spa.RequiereAprobacion, 0) = 1 AND ultima.Codigo = 'RECHAZADA' THEN 1 END) AS AreasRechazadas,
            COUNT
            (
                CASE
                    WHEN ISNULL(spa.RequiereAprobacion, 0) = 1
                     AND ISNULL(ultima.Codigo, 'PENDIENTE') NOT IN ('APROBADA', 'RECHAZADA')
                    THEN 1
                END
            ) AS AreasPendientes
        FROM dbo.Solicitud_Persona_Area AS spa
        OUTER APPLY
        (
            SELECT TOP (1) ea.Codigo
            FROM dbo.Aprobacion_Area AS aa
            LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS ea
                ON ea.IdEstadoAprobacion = aa.IdEstadoAprobacion
            WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
            ORDER BY COALESCE(aa.FechaDecision, aa.FechaSolicitud, aa.FechaCreacion) DESC,
                     aa.IdAprobacionArea DESC
        ) AS ultima
        WHERE spa.IdSolicitudPersona = sp.IdSolicitudPersona
    ) AS resumen
    OUTER APPLY
    (
        SELECT STRING_AGG
        (
            CONVERT
            (
                NVARCHAR(MAX),
                CONCAT
                (
                    COALESCE(a.Nombre, N'Área sin nombre'),
                    CASE
                        WHEN NULLIF(LTRIM(RTRIM(ultima.ComentarioDecision)), N'') IS NULL THEN N''
                        ELSE CONCAT(N': ', ultima.ComentarioDecision)
                    END
                )
            ),
            N' | '
        ) AS DetalleRechazos
        FROM dbo.Solicitud_Persona_Area AS spa
        LEFT JOIN dbo.Cat_Area AS a ON a.IdArea = spa.IdArea
        OUTER APPLY
        (
            SELECT TOP (1)
                ea.Codigo,
                aa.ComentarioDecision
            FROM dbo.Aprobacion_Area AS aa
            LEFT JOIN dbo.Cat_Estado_Aprobacion_Area AS ea
                ON ea.IdEstadoAprobacion = aa.IdEstadoAprobacion
            WHERE aa.IdSolicitudPersonaArea = spa.IdSolicitudPersonaArea
            ORDER BY COALESCE(aa.FechaDecision, aa.FechaSolicitud, aa.FechaCreacion) DESC,
                     aa.IdAprobacionArea DESC
        ) AS ultima
        WHERE spa.IdSolicitudPersona = sp.IdSolicitudPersona
          AND ultima.Codigo = 'RECHAZADA'
    ) AS rechazos
    WHERE sp.IdSolicitud = @IdSolicitud
    ORDER BY p.NombreCompleto, sp.IdSolicitudPersona;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Solicitud_Persona_Agregar]
    @IdSolicitud BIGINT,
    @IdPersona BIGINT,
    @IdEstadoPersonaSolicitud SMALLINT = NULL,
    @DatosCompletos BIT = NULL,
    @ObservacionesRevision NVARCHAR(1000) = NULL,
    @AreasJson NVARCHAR(MAX) = NULL,
    @RequerimientosJson NVARCHAR(MAX) = NULL,
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Solicitud_Ingreso WHERE IdSolicitud = @IdSolicitud) THROW 50130, 'La solicitud no existe.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Persona WHERE IdPersona = @IdPersona) THROW 50131, 'La persona no existe.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Solicitud_Persona WHERE IdSolicitud = @IdSolicitud AND IdPersona = @IdPersona) THROW 50132, 'La persona ya pertenece a la solicitud.', 1;
    IF @IdEstadoPersonaSolicitud IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Estado_Persona_Solicitud WHERE IdEstadoPersonaSolicitud = @IdEstadoPersonaSolicitud) THROW 50133, 'El estado de persona no existe.', 1;
    IF @AreasJson IS NOT NULL AND ISJSON(@AreasJson) <> 1 THROW 50134, 'AreasJson no contiene JSON válido.', 1;
    IF @RequerimientosJson IS NOT NULL AND ISJSON(@RequerimientosJson) <> 1 THROW 50135, 'RequerimientosJson no contiene JSON válido.', 1;

    DECLARE @Areas TABLE (IdArea INT PRIMARY KEY);
    INSERT @Areas (IdArea) SELECT DISTINCT TRY_CONVERT(INT, [value]) FROM OPENJSON(COALESCE(@AreasJson, '[]')) WHERE TRY_CONVERT(INT, [value]) IS NOT NULL;
    IF EXISTS (SELECT 1 FROM @Areas a WHERE NOT EXISTS (SELECT 1 FROM dbo.Cat_Area c WHERE c.IdArea = a.IdArea)) THROW 50136, 'Una de las áreas no existe.', 1;

    DECLARE @Requerimientos TABLE (IdRequerimiento INT PRIMARY KEY, IdTipoAplicacion SMALLINT NULL, Seleccionado BIT NULL, ConfiguradoAutomatico BIT NULL, Observaciones NVARCHAR(500) NULL);
    INSERT @Requerimientos SELECT IdRequerimiento, IdTipoAplicacion, Seleccionado, ConfiguradoAutomatico, Observaciones
    FROM OPENJSON(COALESCE(@RequerimientosJson, '[]')) WITH (IdRequerimiento INT '$.IdRequerimiento', IdTipoAplicacion SMALLINT '$.IdTipoAplicacion', Seleccionado BIT '$.Seleccionado', ConfiguradoAutomatico BIT '$.ConfiguradoAutomatico', Observaciones NVARCHAR(500) '$.Observaciones');
    IF EXISTS (SELECT 1 FROM @Requerimientos r WHERE NOT EXISTS (SELECT 1 FROM dbo.Cat_Requerimiento c WHERE c.IdRequerimiento = r.IdRequerimiento)) THROW 50137, 'Uno de los requerimientos no existe.', 1;
    IF EXISTS (SELECT 1 FROM @Requerimientos r WHERE r.IdTipoAplicacion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Cat_Tipo_Aplicacion_Requerimiento c WHERE c.IdTipoAplicacion = r.IdTipoAplicacion)) THROW 50138, 'Uno de los tipos de aplicación no existe.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @IdSolicitudPersona BIGINT;
        EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona', @IdSolicitudPersona OUTPUT;
        INSERT dbo.Solicitud_Persona (IdSolicitudPersona, IdSolicitud, IdPersona, IdEstadoPersonaSolicitud, DatosCompletos, ObservacionesRevision, FechaCreacion, UsuarioCreacion)
        VALUES (@IdSolicitudPersona, @IdSolicitud, @IdPersona, @IdEstadoPersonaSolicitud, @DatosCompletos, @ObservacionesRevision, SYSDATETIME(), @Usuario);

        DECLARE @IdEstadoPendiente SMALLINT =
        (
            SELECT IdEstadoAprobacion
            FROM dbo.Cat_Estado_Aprobacion_Area
            WHERE Codigo = 'PENDIENTE'
        );
        DECLARE @IdEstadoNoRequiere SMALLINT =
        (
            SELECT IdEstadoAprobacion
            FROM dbo.Cat_Estado_Aprobacion_Area
            WHERE Codigo = 'NO_REQUIERE'
        );

        IF @IdEstadoPendiente IS NULL OR @IdEstadoNoRequiere IS NULL
            THROW 50139, 'No están configurados los estados de aprobación requeridos.', 1;

        DECLARE @IdArea INT, @IdDetalle BIGINT, @RequiereAprobacion BIT;
        DECLARE areas_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT IdArea FROM @Areas;
        OPEN areas_cursor; FETCH NEXT FROM areas_cursor INTO @IdArea;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @RequiereAprobacion = COALESCE(RequiereAprobacion, 0)
            FROM dbo.Cat_Area
            WHERE IdArea = @IdArea;

            EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona_Area', @IdDetalle OUTPUT;
            INSERT dbo.Solicitud_Persona_Area
            (
                IdSolicitudPersonaArea, IdSolicitudPersona, IdArea, RequiereAprobacion,
                IdEstadoAprobacion, FechaCreacion, UsuarioCreacion
            )
            VALUES
            (
                @IdDetalle, @IdSolicitudPersona, @IdArea, @RequiereAprobacion,
                CASE WHEN @RequiereAprobacion = 1 THEN @IdEstadoPendiente ELSE @IdEstadoNoRequiere END,
                SYSDATETIME(), @Usuario
            );
            FETCH NEXT FROM areas_cursor INTO @IdArea;
        END
        CLOSE areas_cursor; DEALLOCATE areas_cursor;

        DECLARE @IdReq INT, @IdTipoAplicacion SMALLINT, @Seleccionado BIT, @Configurado BIT, @Obs NVARCHAR(500);
        DECLARE req_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT IdRequerimiento, IdTipoAplicacion, Seleccionado, ConfiguradoAutomatico, Observaciones FROM @Requerimientos;
        OPEN req_cursor; FETCH NEXT FROM req_cursor INTO @IdReq, @IdTipoAplicacion, @Seleccionado, @Configurado, @Obs;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.usp_ObtenerSiguienteId 'Solicitud_Persona_Requerimiento', @IdDetalle OUTPUT;
            INSERT dbo.Solicitud_Persona_Requerimiento (IdSolicitudPersonaReq, IdSolicitudPersona, IdRequerimiento, IdTipoAplicacion, Seleccionado, ConfiguradoAutomatico, Observaciones, FechaCreacion, UsuarioCreacion)
            VALUES (@IdDetalle, @IdSolicitudPersona, @IdReq, @IdTipoAplicacion, @Seleccionado, @Configurado, @Obs, SYSDATETIME(), @Usuario);
            FETCH NEXT FROM req_cursor INTO @IdReq, @IdTipoAplicacion, @Seleccionado, @Configurado, @Obs;
        END
        CLOSE req_cursor; DEALLOCATE req_cursor;
        COMMIT TRANSACTION;
        SELECT @IdSolicitudPersona;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE [dbo].[usp_Usuario_Administracion_Listar]
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
               SELECT 1 FROM dbo.Usuario_Area AS ua
               WHERE ua.IdUsuario = u.IdUsuario
                 AND ISNULL(ua.PuedeSolicitar, 0) = 1
                 AND ISNULL(ua.IdEstadoGeneral, 1) = 1
                 AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                 AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
           ) THEN 1 ELSE 0 END) AS PuedeSolicitar,
           CONVERT(BIT, CASE WHEN EXISTS
           (
               SELECT 1 FROM dbo.Config_Aprobador_Area AS ca
               WHERE ca.IdUsuarioAprobador = u.IdUsuario
                 AND ISNULL(ca.IdEstadoGeneral, 1) = 1
                 AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                 AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
           ) THEN 1 ELSE 0 END) AS EsAprobador,
           CONVERT(BIT, CASE WHEN ISNULL(u.IdEstadoGeneral, 1) = 1 THEN 1 ELSE 0 END) AS Activo,
           u.FechaCreacion,
           roles.Roles
    FROM dbo.Usuario AS u
    OUTER APPLY
    (
        SELECT TOP (1) ua.IdArea, area.Nombre AS Area
        FROM dbo.Usuario_Area AS ua
        LEFT JOIN dbo.Cat_Area AS area ON area.IdArea = ua.IdArea
        WHERE ua.IdUsuario = u.IdUsuario
          AND ISNULL(ua.IdEstadoGeneral, 1) = 1
        ORDER BY ISNULL(ua.EsAreaPrincipal, 0) DESC, ua.IdUsuarioArea
    ) AS areaPrincipal
    OUTER APPLY
    (
        SELECT STRING_AGG(r.Nombre, ',') AS Roles
        FROM dbo.Usuario_Rol AS ur
        INNER JOIN dbo.Rol AS r ON r.IdRol = ur.IdRol
        WHERE ur.IdUsuario = u.IdUsuario
          AND ISNULL(r.Activo, 1) = 1
    ) AS roles
    ORDER BY u.NombreCompleto, u.IdUsuario;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE [dbo].[usp_Usuario_Autenticar]
    @Usuario VARCHAR(254),
    @Contrasena VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@Usuario)), '') IS NULL OR NULLIF(@Contrasena, '') IS NULL
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
              AND ISNULL(ca.IdEstadoGeneral, 1) = 1
              AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
              AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ) THEN 1 ELSE 0 END) AS EsAprobador,
        CONVERT(BIT, CASE WHEN EXISTS
        (
            SELECT 1
            FROM dbo.Usuario_Area AS ua
            WHERE ua.IdUsuario = u.IdUsuario
              AND ISNULL(ua.PuedeSolicitar, 0) = 1
              AND ISNULL(ua.IdEstadoGeneral, 1) = 1
              AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
              AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ) THEN 1 ELSE 0 END) AS PuedeSolicitar,
        roles.Roles
    FROM dbo.Usuario AS u
    LEFT JOIN dbo.Cat_Estado_General AS eg ON eg.IdEstadoGeneral = u.IdEstadoGeneral
    OUTER APPLY
    (
        SELECT TOP (1) ua.IdArea, area.Nombre AS Area
        FROM dbo.Usuario_Area AS ua
        LEFT JOIN dbo.Cat_Area AS area ON area.IdArea = ua.IdArea
        WHERE ua.IdUsuario = u.IdUsuario
          AND ISNULL(ua.IdEstadoGeneral, 1) = 1
          AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
          AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
        ORDER BY ISNULL(ua.EsAreaPrincipal, 0) DESC, ua.IdUsuarioArea
    ) AS areaPrincipal
    OUTER APPLY
    (
        SELECT STRING_AGG(r.Nombre, ',') AS Roles
        FROM dbo.Usuario_Rol AS ur
        INNER JOIN dbo.Rol AS r ON r.IdRol = ur.IdRol
        WHERE ur.IdUsuario = u.IdUsuario
          AND ISNULL(r.Activo, 1) = 1
    ) AS roles
    WHERE (u.IdUsuario = @Usuario OR u.Correo = @Usuario)
      AND u.Usuario_Password = @Contrasena
      AND ISNULL(eg.EsActivo, 1) = 1;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Usuario_Crear]
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

    INSERT dbo.Usuario
    (
        IdUsuario, NombreCompleto, Correo, Usuario_Password, Telefono, Puesto,
        IdEstadoGeneral, FechaCreacion, UsuarioCreacion
    )
    VALUES
    (
        @IdUsuario, @NombreCompleto, NULLIF(LTRIM(RTRIM(@Correo)), ''), @Contrasena,
        NULLIF(LTRIM(RTRIM(@Telefono)), ''), NULLIF(LTRIM(RTRIM(@Puesto)), ''),
        @IdEstadoGeneral, SYSDATETIME(), @UsuarioCreacion
    );

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

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Usuario_Perfil_Obtener]
    @IdUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.IdUsuario,
           u.NombreCompleto,
           u.Correo,
           u.Telefono,
           u.Puesto,
           CONVERT(BIT, CASE WHEN EXISTS (
               SELECT 1 FROM dbo.Config_Aprobador_Area AS ca
               WHERE ca.IdUsuarioAprobador = u.IdUsuario
                 AND ISNULL(ca.IdEstadoGeneral, 1) = 1
                 AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                 AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
           ) THEN 1 ELSE 0 END) AS EsAprobador,
           CONVERT(BIT, CASE WHEN EXISTS (
               SELECT 1 FROM dbo.Usuario_Area AS ua
               WHERE ua.IdUsuario = u.IdUsuario
                 AND ISNULL(ua.PuedeSolicitar, 0) = 1
                 AND ISNULL(ua.IdEstadoGeneral, 1) = 1
                 AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
                 AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))
           ) THEN 1 ELSE 0 END) AS PuedeSolicitar
    FROM dbo.Usuario AS u
    WHERE u.IdUsuario = @IdUsuario;

    SELECT x.IdArea,
           a.Nombre,
           CONVERT(BIT, MAX(x.EsAreaPrincipal)) AS EsAreaPrincipal,
           CONVERT(BIT, MAX(x.PuedeSolicitar)) AS PuedeSolicitar,
           CONVERT(BIT, MAX(x.EsAprobador)) AS EsAprobador,
           CONVERT(BIT, MAX(x.EsAprobadorPrincipal)) AS EsAprobadorPrincipal
    FROM (
        SELECT ua.IdArea,
               CONVERT(INT, ISNULL(ua.EsAreaPrincipal, 0)) AS EsAreaPrincipal,
               CONVERT(INT, ISNULL(ua.PuedeSolicitar, 0)) AS PuedeSolicitar,
               0 AS EsAprobador,
               0 AS EsAprobadorPrincipal
        FROM dbo.Usuario_Area AS ua
        WHERE ua.IdUsuario = @IdUsuario
          AND ISNULL(ua.IdEstadoGeneral, 1) = 1
          AND (ua.FechaInicio IS NULL OR ua.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
          AND (ua.FechaFin IS NULL OR ua.FechaFin >= CONVERT(DATE, SYSDATETIME()))

        UNION ALL

        SELECT ca.IdArea,
               0,
               0,
               1,
               CONVERT(INT, ISNULL(ca.EsPrincipal, 0))
        FROM dbo.Config_Aprobador_Area AS ca
        WHERE ca.IdUsuarioAprobador = @IdUsuario
          AND ISNULL(ca.IdEstadoGeneral, 1) = 1
          AND (ca.FechaInicio IS NULL OR ca.FechaInicio <= CONVERT(DATE, SYSDATETIME()))
          AND (ca.FechaFin IS NULL OR ca.FechaFin >= CONVERT(DATE, SYSDATETIME()))
    ) AS x
    LEFT JOIN dbo.Cat_Area AS a ON a.IdArea = x.IdArea
    WHERE x.IdArea IS NOT NULL
    GROUP BY x.IdArea, a.Nombre
    ORDER BY MAX(x.EsAreaPrincipal) DESC, a.Nombre;

    SELECT s.IdSolicitud,
           s.NumeroSolicitud,
           ti.Nombre AS TipoIngreso,
           es.Nombre AS Estado,
           s.FechaInicio,
           s.FechaFin,
           s.NombreActividad,
           s.IdUsuarioSolicitante,
           CONVERT(INT, COUNT(sp.IdSolicitudPersona)) AS CantidadPersonas
    FROM dbo.Solicitud_Ingreso AS s
    LEFT JOIN dbo.Cat_Tipo_Ingreso AS ti ON ti.IdTipoIngreso = s.IdTipoIngreso
    LEFT JOIN dbo.Cat_Estado_Solicitud AS es ON es.IdEstadoSolicitud = s.IdEstadoSolicitud
    LEFT JOIN dbo.Solicitud_Persona AS sp ON sp.IdSolicitud = s.IdSolicitud
    WHERE s.IdUsuarioSolicitante = @IdUsuario
    GROUP BY s.IdSolicitud, s.NumeroSolicitud, ti.Nombre, es.Nombre,
             s.FechaInicio, s.FechaFin, s.NombreActividad,
             s.IdUsuarioSolicitante, s.FechaCreacion
    ORDER BY s.FechaCreacion DESC, s.IdSolicitud DESC;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Usuario_Rol_Asignar]
    @IdUsuario VARCHAR(50),@CodigoRol VARCHAR(30),@UsuarioAsignacion VARCHAR(50)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @IdRol SMALLINT=(SELECT IdRol FROM dbo.Rol WHERE Codigo=UPPER(LTRIM(RTRIM(@CodigoRol))) AND Activo=1);
 IF NOT EXISTS(SELECT 1 FROM dbo.Usuario WHERE IdUsuario=@IdUsuario) THROW 50520,'El usuario no existe.',1;
 IF @IdRol IS NULL THROW 50521,'El rol solicitado no existe.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Usuario_Rol WHERE IdUsuario=@IdUsuario AND IdRol=@IdRol)
  INSERT dbo.Usuario_Rol(IdUsuario,IdRol,UsuarioAsignacion) VALUES(@IdUsuario,@IdRol,@UsuarioAsignacion);
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE   PROCEDURE [dbo].[usp_Solicitud_Persona_Area_ReenviarAprobacion]
    @IdSolicitudPersonaArea BIGINT,
    @IdUsuarioSolicitante VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@IdUsuarioSolicitante)), '') IS NULL
        THROW 50167, 'El usuario solicitante es obligatorio.', 1;

    DECLARE @IdEstadoPendiente SMALLINT =
    (
        SELECT IdEstadoAprobacion
        FROM dbo.Cat_Estado_Aprobacion_Area
        WHERE Codigo = 'PENDIENTE'
    );
    DECLARE @IdEstadoRechazada SMALLINT =
    (
        SELECT IdEstadoAprobacion
        FROM dbo.Cat_Estado_Aprobacion_Area
        WHERE Codigo = 'RECHAZADA'
    );

    IF @IdEstadoPendiente IS NULL OR @IdEstadoRechazada IS NULL
        THROW 50168, 'No están configurados los estados para el reenvío.', 1;

    UPDATE spa
       SET IdEstadoAprobacion = @IdEstadoPendiente,
           FechaModificacion = SYSDATETIME(),
           UsuarioModificacion = @IdUsuarioSolicitante
    FROM dbo.Solicitud_Persona_Area AS spa
    INNER JOIN dbo.Solicitud_Persona AS sp
        ON sp.IdSolicitudPersona = spa.IdSolicitudPersona
    INNER JOIN dbo.Solicitud_Ingreso AS solicitud
        ON solicitud.IdSolicitud = sp.IdSolicitud
    WHERE spa.IdSolicitudPersonaArea = @IdSolicitudPersonaArea
      AND solicitud.IdUsuarioSolicitante = @IdUsuarioSolicitante
      AND spa.IdEstadoAprobacion = @IdEstadoRechazada;

    IF @@ROWCOUNT = 0
        THROW 50169, 'Solo el solicitante puede reenviar un acceso rechazado.', 1;

    EXEC dbo.usp_Solicitud_Estado_Recalcular @IdSolicitudPersonaArea, @IdUsuarioSolicitante;
END;
GO

PRINT 'Base Control_Ingresos_DB creada correctamente.';
GO
