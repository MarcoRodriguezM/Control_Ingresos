using System.ComponentModel.DataAnnotations;

namespace Control_Ingresos.Models;

public sealed record CrearProveedorRequest(
    string? Codigo,
    [Required, MaxLength(200)] string NombreLegal,
    string? NombreComercial,
    string? Rtn,
    string? ContactoPrincipal,
    [Required, EmailAddress, MaxLength(254)] string CorreoPrincipal,
    string? TelefonoPrincipal,
    short? IdEstadoGeneral,
    [Required, MaxLength(50)] string Usuario);

public sealed record ProveedorCreadoResponse(
    long Id,
    string IdUsuario,
    bool CredencialesEnviadas,
    string? ContrasenaTemporal = null);

public sealed record ProveedorUsuarioCreado(
    long IdProveedor,
    string IdUsuario);

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
    [MaxLength(200)] string? ContactoProveedor,
    [EmailAddress, MaxLength(254)] string? CorreoProveedor,
    [Required, Range(1, int.MaxValue)] int? CantidadEstimada,
    int? IdAreaSolicitante,
    [Required, MaxLength(50)] string IdUsuarioSolicitante,
    int? IdUbicacion,
    string? Observaciones,
    [Required, MaxLength(50)] string Usuario);

public sealed record AgregarPersonaSolicitudRequest(
    long? IdPersona,
    [MaxLength(50)] string? CodigoEmpleadoHtis,
    short? IdEstadoPersonaSolicitud,
    bool? DatosCompletos,
    string? ObservacionesRevision,
    IReadOnlyCollection<int>? Areas,
    IReadOnlyCollection<RequerimientoSolicitudRequest>? Requerimientos,
    IReadOnlyCollection<long>? Flujos,
    [Required, MaxLength(50)] string Usuario);

public sealed record AgregarEmpleadoSolicitudRequest(
    [Required, MaxLength(50)] string CodigoEmpleado,
    [Required] IReadOnlyCollection<int> Areas,
    IReadOnlyCollection<long>? Flujos = null);

public sealed record AsignarAreasPersonaSolicitudRequest(
    [Required] IReadOnlyCollection<int> Areas,
    IReadOnlyCollection<RequerimientoSolicitudRequest>? Requerimientos = null,
    IReadOnlyCollection<long>? Flujos = null);

public sealed record RequerimientoSolicitudRequest(
    int IdRequerimiento,
    short? IdTipoAplicacion,
    bool? Seleccionado,
    bool? ConfiguradoAutomatico,
    string? Observaciones);

public sealed record IdCreadoResponse(
    long Id,
    string? Numero = null);

public sealed record FotografiaSubidaResponse(string Url);

public sealed record FotografiaContenidoResponse(string DataUrl);

public sealed record CatalogoItem(
    int Id,
    string? Codigo,
    string? Nombre,
    string? Descripcion);

public sealed record OpcionFormulario<T>(
    T Id,
    string? Codigo,
    string? Nombre);

public sealed record ProveedorFormularioOpcion(
    long Id,
    string? Codigo,
    string? Nombre,
    string? ContactoPrincipal,
    string? CorreoPrincipal);

public sealed record SolicitudFormularioDatos(
    IReadOnlyCollection<OpcionFormulario<short>> TiposIngreso,
    IReadOnlyCollection<OpcionFormulario<short>> EstadosSolicitud,
    IReadOnlyCollection<OpcionFormulario<int>> Areas,
    IReadOnlyCollection<OpcionFormulario<int>> Ubicaciones,
    IReadOnlyCollection<ProveedorFormularioOpcion> Proveedores,
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
    int CantidadPersonas,
    bool EsPropia = false,
    int TicketsPendientes = 0);

public sealed record SeguimientoArea(
    long IdSolicitudPersonaArea,
    long IdSolicitudPersona,
    string? Persona,
    string? NumeroDocumento,
    string? Area,
    string? CodigoEstado,
    string? Estado,
    string? ComentarioDecision,
    DateTime? FechaDecision,
    string? UsuarioDecision);

public sealed record SeguimientoActividad(
    long IdActividad,
    long? IdSolicitudPersona,
    string? Persona,
    string? AreaResponsable,
    string? NombreActividad,
    string? CodigoEstado,
    string? Estado,
    bool RequiereTicket,
    string? NumeroTicket,
    DateTime? FechaFinalizacion,
    string? UsuarioDecision,
    string? ComentarioDecision,
    DateTime? FechaDecision,
    bool EsEstadoFinal,
    bool TicketPendiente);

public sealed record SeguimientoReenvio(
    long IdSolicitudPersonaArea,
    string? Justificacion,
    string? Usuario,
    DateTime? Fecha);

public sealed record SeguimientoDecision(
    long IdSolicitudPersonaArea,
    string? Persona,
    string? Area,
    string? CodigoEstado,
    string? Comentario,
    DateTime? Fecha,
    string? UsuarioDecision);

public sealed record SeguimientoSolicitud(
    SolicitudDetalle Solicitud,
    string Estado,
    string CodigoEstado,
    int TicketsPendientes,
    IReadOnlyCollection<SeguimientoArea> Areas,
    IReadOnlyCollection<SeguimientoActividad> Actividades,
    IReadOnlyCollection<SeguimientoDecision> Decisiones,
    IReadOnlyCollection<SeguimientoReenvio> Reenvios);

public sealed record ReenviarAprobacionRequest(
    [Required, MaxLength(1000)] string Justificacion);

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
    bool RequiereTicketExterno,
    ActividadTicketResumen? Ticket,
    long? IdSolicitudPersona,
    string? Persona,
    string? NumeroDocumento,
    int? IdAreaAcceso,
    string? AreaAcceso);

public sealed record ActividadAdministracionResumen(
    long IdActividad,
    long? IdSolicitud,
    string? NumeroSolicitud,
    string? NombreActividad,
    int? IdAreaResponsable,
    string? AreaResponsable,
    string? IdUsuarioResponsable,
    string? UsuarioResponsable,
    short? IdEstadoActividad,
    string? CodigoEstado,
    string? Estado,
    bool EsEstadoFinal,
    DateTime? FechaLimite,
    DateTime? FechaInicio,
    DateTime? FechaFinalizacion,
    string? Comentarios,
    bool RequiereTicketExterno,
    string? IdUsuarioAprobador,
    DateTime? FechaDecision,
    string? ComentarioDecision,
    long? IdSolicitudPersona,
    string? Persona,
    string? NumeroDocumento,
    int? IdAreaAcceso,
    string? AreaAcceso,
    ActividadTicketResumen? Ticket = null);

public sealed record CrearActividadRequest(
    long? IdSolicitud,
    int? IdAreaResponsable,
    [Required, MaxLength(50)] string IdUsuarioResponsable,
    [Required, MaxLength(200)] string NombreActividad,
    DateTime? FechaLimite,
    [MaxLength(1000)] string? Comentarios,
    bool RequiereTicketExterno);

public sealed record CompletarActividadRequest(
    [MaxLength(1000)] string? Comentarios);

public sealed record CrearActividadTicketRequest(
    long? IdTicketExterno,
    IReadOnlyCollection<long>? IdsActividad,
    [MaxLength(100)] string? Plataforma,
    [MaxLength(80)] string? NumeroTicket,
    [MaxLength(500)] string? UrlTicket);

public sealed record ActividadTicketResumen(
    long IdActividadTicket,
    string? Plataforma,
    string? NumeroTicket,
    string? UrlTicket,
    DateTime? FechaRegistro);

public sealed record TicketSolicitudResumen(
    long IdActividad,
    long IdSolicitud,
    DateTime? FechaFin,
    string? NumeroSolicitud,
    string? NombreActividad,
    string? Persona,
    string? AreaResponsable,
    bool EsEstadoFinal,
    ActividadTicketResumen? Ticket,
    IReadOnlyCollection<ActividadTicketResumen> Tickets,
    long? IdSolicitudPersona);

public sealed record DecidirActividadRequest(
    [Required, MaxLength(30)] string CodigoEstado,
    [MaxLength(1000)] string? ComentarioDecision);

public sealed record ActividadFlujoPaso(
    long IdActividadFlujoPaso,
    string? ClavePaso,
    int OrdenVisual,
    int IdRequerimiento,
    string? NombreActividad,
    int IdAreaResponsable,
    string? AreaResponsable,
    bool RequiereTicketExterno,
    int VigenciaMeses,
    DateOnly? FechaInicio,
    DateOnly? FechaFin,
    IReadOnlyCollection<long> Dependencias,
    IReadOnlyCollection<ActividadFlujoDependenciaExterna> DependenciasExternas);

public sealed record ActividadFlujoDependenciaExterna(
    long IdActividadFlujo,
    [Required, MaxLength(80)] string ClavePaso);

public sealed record ActividadFlujo(
    long IdActividadFlujo,
    long IdActividadFlujoVersion,
    int NumeroVersion,
    string? Codigo,
    string? Nombre,
    string? Descripcion,
    bool EsVersionActual,
    IReadOnlyCollection<string> TiposIngreso,
    IReadOnlyCollection<string> TiposIngresoAutomaticos,
    IReadOnlyCollection<ActividadFlujoPaso> Pasos);

public sealed record ActividadFlujoArea(
    int IdArea,
    string? Codigo,
    string? Nombre,
    IReadOnlyCollection<ActividadFlujo> Flujos);

public sealed record ActividadFlujoConfiguracion(
    IReadOnlyCollection<ActividadFlujoArea> Areas);

public sealed record GuardarActividadFlujoPasoRequest(
    [Required, MaxLength(80)] string ClavePaso,
    int? IdRequerimiento,
    [Required, MaxLength(150)] string NombreActividad,
    int IdAreaResponsable,
    bool RequiereTicketExterno,
    [Range(1, 1200)] int VigenciaMeses = 24,
    DateOnly? FechaInicio = null,
    DateOnly? FechaFin = null,
    IReadOnlyCollection<string>? Dependencias = null,
    IReadOnlyCollection<ActividadFlujoDependenciaExterna>? DependenciasExternas = null);

public sealed record GuardarActividadFlujoRequest(
    [Required, MaxLength(150)] string Nombre,
    [MaxLength(40)] string? Codigo,
    [MaxLength(500)] string? Descripcion,
    IReadOnlyCollection<string>? TiposIngreso,
    IReadOnlyCollection<string>? TiposIngresoAutomaticos,
    [Required] IReadOnlyCollection<GuardarActividadFlujoPasoRequest> Pasos);

public sealed record ActividadFlujoGuardadoResponse(
    long IdActividadFlujo,
    long IdActividadFlujoVersion);

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
    bool? DatosCompletos,
    string? CodigoEstadoAprobacion,
    string? EstadoAprobacion,
    int AreasAprobadas,
    int AreasPendientes,
    int AreasRechazadas,
    string? DetalleRechazos,
    string? CodigoEmpleadoHtis,
    IReadOnlyCollection<int>? Areas = null,
    IReadOnlyCollection<int>? Requerimientos = null,
    IReadOnlyCollection<long>? Flujos = null);


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
    string? CodigoEstadoAcceso,
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

public sealed record AreaAccesoQr(
    int IdArea,
    string? Codigo,
    string? Area,
    string? CodigoAcceso,
    string? EstadoAcceso,
    bool TieneAcceso,
    string? NumeroSolicitud,
    string? Actividad,
    string? Ubicacion,
    DateOnly? FechaInicio,
    DateOnly? FechaFin,
    string? ComentarioDecision);

public sealed record PersonaQrDetalle(
    long IdPersona,
    string? NumeroDocumento,
    string? NombreCompleto,
    string? FotografiaUrl,
    string? Telefono,
    string? Correo,
    string? CargoFuncion,
    string? Empresa,
    string? Estado,
    IReadOnlyCollection<AreaAccesoQr> Areas);

public sealed record PersonaQrResponse(string CodigoQr);

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
    string? ComentarioDecision,
    string? CodigoEmpleadoHtis,
    bool ActividadesPendientes = false);

public sealed record DecidirAprobacionRequest(
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
    bool PuedeSolicitar,
    IReadOnlyCollection<string> Roles);

public sealed record ProveedorUsuario(
    long IdProveedor,
    string? NombreLegal,
    string? NombreComercial);

public sealed record SolicitudProveedorResumen(
    long IdSolicitud,
    string? NumeroSolicitud,
    string? TipoIngreso,
    string? CodigoEstado,
    string? Estado,
    DateOnly? FechaInicio,
    DateOnly? FechaFin,
    string? NombreActividad,
    string? Ubicacion,
    string? UsuarioSolicitante,
    int CantidadEstimada,
    int CantidadPersonas);

public sealed record SolicitudProveedorDetalle(
    long IdSolicitud,
    string? NumeroSolicitud,
    string? TipoIngreso,
    string? CodigoEstado,
    string? Estado,
    DateOnly? FechaInicio,
    DateOnly? FechaFin,
    string? NombreActividad,
    string? DescripcionActividad,
    string? NumeroContrato,
    string? ContactoProveedor,
    string? CorreoProveedor,
    string? Ubicacion,
    string? UsuarioSolicitante,
    int CantidadEstimada,
    int CantidadPersonas,
    string? Observaciones,
    IReadOnlyCollection<PersonaSolicitudDetalle> Personas);

public sealed record CrearSolicitudCompletaRequest(
    [Required] CrearSolicitudRequest Solicitud,
    IReadOnlyCollection<AgregarPersonaSolicitudRequest>? Personas);

public sealed record RegistroIngresoResumen(
    long IdRegistroIngreso,
    long IdPersona,
    string? NumeroDocumento,
    string? NombreCompleto,
    long IdSolicitud,
    string? NumeroSolicitud,
    string? Actividad,
    string TipoMovimiento,
    DateTime FechaMovimiento,
    string? IdUsuarioSeguridad,
    string? UsuarioSeguridad,
    string? Observaciones);

public sealed record RegistrarIngresoRequest(
    long IdPersona,
    [Required, MaxLength(10)] string TipoMovimiento,
    [MaxLength(500)] string? Observaciones);

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

public sealed record UsuarioAdministracionResumen(
    string IdUsuario,
    string? NombreCompleto,
    string? Correo,
    string? Telefono,
    string? Puesto,
    int? IdArea,
    string? Area,
    bool PuedeSolicitar,
    bool EsAprobador,
    bool Activo,
    DateTime? FechaCreacion,
    string? Roles);

public sealed record AreaUsuarioAdministracion(
    int IdArea,
    string? Codigo,
    string? Nombre,
    bool PuedeSolicitar,
    bool EsAreaPrincipal,
    bool EsAprobador,
    bool EsAprobadorPrincipal,
    DateOnly? FechaInicio,
    DateOnly? FechaFin,
    bool Activo);

public sealed record UsuarioAdministracionDetalle(
    string IdUsuario,
    string? NombreCompleto,
    string? Correo,
    string? Telefono,
    string? Puesto,
    string? Estado,
    bool Activo,
    DateTime? FechaCreacion,
    string? UsuarioCreacion,
    DateTime? FechaModificacion,
    string? UsuarioModificacion,
    string? Roles,
    IReadOnlyCollection<AreaUsuarioAdministracion> Areas);

public sealed record CrearUsuarioRequest(
    [Required, MaxLength(50)] string IdUsuario,
    [Required, MaxLength(200)] string NombreCompleto,
    [EmailAddress, MaxLength(254)] string? Correo,
    [MaxLength(30)] string? Telefono,
    [MaxLength(150)] string? Puesto,
    [Required, MinLength(8), MaxLength(200)] string Contrasena,
    int? IdArea,
    bool PuedeSolicitar,
    bool EsAprobador,
    bool EsSeguridad,
    bool EsGuardia,
    bool EsProveedor,
    bool Activo);

public sealed record ActualizarUsuarioRequest(
    [Required, MaxLength(200)] string NombreCompleto,
    [EmailAddress, MaxLength(254)] string? Correo,
    [MaxLength(30)] string? Telefono,
    [MaxLength(150)] string? Puesto,
    int? IdArea,
    bool PuedeSolicitar,
    bool EsAprobador,
    bool EsSeguridad,
    bool EsGuardia,
    bool EsProveedor,
    bool Activo);
