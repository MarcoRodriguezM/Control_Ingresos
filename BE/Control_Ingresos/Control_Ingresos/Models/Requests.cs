using System.ComponentModel.DataAnnotations;

namespace Control_Ingresos.Models;

public sealed record CrearProveedorRequest(
    string? Codigo,
    [Required, MaxLength(200)] string NombreLegal,
    string? NombreComercial,
    string? Rtn,
    string? ContactoPrincipal,
    [EmailAddress] string? CorreoPrincipal,
    string? TelefonoPrincipal,
    short? IdEstadoGeneral,
    [Required, MaxLength(50)] string Usuario);

public sealed record CrearPersonaRequest(
    short? IdTipoDocumento,
    [Required, MaxLength(60)] string NumeroDocumento,
    [Required, MaxLength(200)] string NombreCompleto,
    string? FotografiaUrl,
    string? Telefono,
    [EmailAddress] string? Correo,
    string? CargoFuncion,
    long? IdProveedor,
    string? EmpresaTexto,
    string? InformacionAdicional,
    short? IdEstadoGeneral,
    [Required, MaxLength(50)] string Usuario);

public sealed record CrearSolicitudRequest(
    short? IdTipoIngreso,
    short? IdEstadoSolicitud,
    DateOnly? FechaInicio,
    DateOnly? FechaFin,
    [Required, MaxLength(200)] string NombreActividad,
    string? DescripcionActividad,
    long? IdProveedor,
    string? NumeroContrato,
    string? ContactoProveedor,
    [EmailAddress] string? CorreoProveedor,
    int? CantidadEstimada,
    int? IdAreaSolicitante,
    [Required, MaxLength(50)] string IdUsuarioSolicitante,
    int? IdUbicacion,
    string? Observaciones,
    [Required, MaxLength(50)] string Usuario);

public sealed record AgregarPersonaSolicitudRequest(
    long IdPersona,
    short? IdEstadoPersonaSolicitud,
    bool? DatosCompletos,
    string? ObservacionesRevision,
    IReadOnlyCollection<int>? Areas,
    IReadOnlyCollection<RequerimientoSolicitudRequest>? Requerimientos,
    [Required, MaxLength(50)] string Usuario);

public sealed record RequerimientoSolicitudRequest(
    int IdRequerimiento,
    short? IdTipoAplicacion,
    bool? Seleccionado,
    bool? ConfiguradoAutomatico,
    string? Observaciones);

public sealed record IdCreadoResponse(
    long Id,
    string? Numero = null);

public sealed record CatalogoItem(
    int Id,
    string? Codigo,
    string? Nombre,
    string? Descripcion);

public sealed record OpcionFormulario<T>(
    T Id,
    string? Codigo,
    string? Nombre);

public sealed record SolicitudFormularioDatos(
    IReadOnlyCollection<OpcionFormulario<short>> TiposIngreso,
    IReadOnlyCollection<OpcionFormulario<short>> EstadosSolicitud,
    IReadOnlyCollection<OpcionFormulario<int>> Areas,
    IReadOnlyCollection<OpcionFormulario<int>> Ubicaciones,
    IReadOnlyCollection<OpcionFormulario<long>> Proveedores,
    IReadOnlyCollection<OpcionFormulario<string>> Usuarios);

public sealed record SolicitudResumen(
    long IdSolicitud,
    string? NumeroSolicitud,
    string? TipoIngreso,
    string? Estado,
    DateOnly? FechaInicio,
    DateOnly? FechaFin,
    string? NombreActividad,
    string? UsuarioSolicitante,
    int CantidadPersonas);

public sealed record ActividadResumen(
    long IdActividad,
    long? IdSolicitud,
    string? NumeroSolicitud,
    string? NombreActividad,
    string? AreaResponsable,
    string? CodigoEstado,
    string? Estado,
    bool EsEstadoFinal,
    DateTime? FechaLimite,
    DateTime? FechaInicio,
    DateTime? FechaFinalizacion,
    string? Comentarios,
    bool RequiereTicketExterno);

public sealed record SolicitudDetalle(
    long IdSolicitud,
    string? NumeroSolicitud,
    short? IdTipoIngreso,
    short? IdEstadoSolicitud,
    DateOnly? FechaInicio,
    DateOnly? FechaFin,
    string? NombreActividad,
    string? DescripcionActividad,
    long? IdProveedor,
    string? NumeroContrato,
    string? ContactoProveedor,
    string? CorreoProveedor,
    int? CantidadEstimada,
    int? IdAreaSolicitante,
    string? IdUsuarioSolicitante,
    int? IdUbicacion,
    string? Observaciones,
    DateTime? FechaCreacion,
    IReadOnlyCollection<PersonaSolicitudDetalle> Personas);

public sealed record PersonaSolicitudDetalle(
    long IdSolicitudPersona,
    long? IdPersona,
    string? NumeroDocumento,
    string? NombreCompleto,
    short? IdEstadoPersonaSolicitud,
    bool? DatosCompletos);

public sealed record PersonaResumen(
    long IdPersona,
    string? NumeroDocumento,
    string? NombreCompleto,
    string? CargoFuncion,
    string? Empresa,
    string? Estado,
    int CantidadAccesos);

public sealed record PersonaAccesoDetalle(
    long IdSolicitudPersonaArea,
    long? IdSolicitud,
    string? NumeroSolicitud,
    string? Actividad,
    int? IdArea,
    string? Area,
    string? Ubicacion,
    DateOnly? FechaInicio,
    DateOnly? FechaFin,
    bool? RequiereAprobacion,
    string? EstadoAcceso,
    DateTime? FechaDecision,
    string? ComentarioDecision);

public sealed record PersonaConAccesos(
    long IdPersona,
    string? NumeroDocumento,
    string? NombreCompleto,
    string? FotografiaUrl,
    string? Telefono,
    string? Correo,
    string? CargoFuncion,
    string? Empresa,
    string? Estado,
    IReadOnlyCollection<PersonaAccesoDetalle> Accesos);

public sealed record AprobacionResumen(
    long IdSolicitudPersonaArea,
    long? IdSolicitud,
    string? NumeroSolicitud,
    long? IdPersona,
    string? Persona,
    string? NumeroDocumento,
    string? Empresa,
    int? IdArea,
    string? Area,
    string? Actividad,
    string? Ubicacion,
    DateOnly? FechaInicio,
    DateOnly? FechaFin,
    DateTime? FechaSolicitud,
    short? IdEstadoAprobacion,
    string? CodigoEstado,
    string? Estado,
    DateTime? FechaDecision,
    string? ComentarioDecision);

public sealed record DecidirAprobacionRequest(
    [Required, MaxLength(50)] string IdUsuarioAprobador,
    [Required, MaxLength(30)] string CodigoEstado,
    [MaxLength(1000)] string? ComentarioDecision);

public sealed record LoginRequest(
    [Required, MaxLength(254)] string Usuario,
    [Required, MaxLength(200)] string Contrasena);

public sealed record SesionUsuario(
    string IdUsuario,
    string? NombreCompleto,
    string? Correo,
    string? Puesto,
    int? IdArea,
    string? Area,
    bool EsAprobador,
    bool PuedeSolicitar);

public sealed record AreaUsuarioPerfil(
    int IdArea,
    string? Nombre,
    bool EsAreaPrincipal,
    bool PuedeSolicitar,
    bool EsAprobador,
    bool EsAprobadorPrincipal);

public sealed record PerfilUsuario(
    string IdUsuario,
    string? NombreCompleto,
    string? Correo,
    string? Telefono,
    string? Puesto,
    bool EsAprobador,
    bool PuedeSolicitar,
    IReadOnlyCollection<AreaUsuarioPerfil> Areas,
    IReadOnlyCollection<SolicitudResumen> Solicitudes);
