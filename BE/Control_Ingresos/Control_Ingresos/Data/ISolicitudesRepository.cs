using Control_Ingresos.Models;

namespace Control_Ingresos.Data;

public interface ISolicitudesRepository
{
    Task<SesionUsuario?> AutenticarAsync(LoginRequest request, CancellationToken cancellationToken);
    Task<PerfilUsuario?> ObtenerPerfilAsync(string idUsuario, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<UsuarioAdministracionResumen>> ListarUsuariosAsync(CancellationToken cancellationToken);
    Task<string> CrearUsuarioAsync(CrearUsuarioRequest request, string usuarioCreacion, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<CatalogoItem>> ListarCatalogoAsync(string catalogo, CancellationToken cancellationToken);
    Task<SolicitudFormularioDatos> ObtenerDatosFormularioSolicitudAsync(CancellationToken cancellationToken);
    Task<long> CrearProveedorAsync(CrearProveedorRequest request, CancellationToken cancellationToken);
    Task<long> CrearPersonaAsync(CrearPersonaRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<PersonaResumen>> ListarPersonasAsync(CancellationToken cancellationToken);
    Task<PersonaConAccesos?> ObtenerPersonaAccesosAsync(long idPersona, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<AprobacionResumen>> ListarAprobacionesAsync(string idUsuarioAprobador, CancellationToken cancellationToken);
    Task<long> DecidirAprobacionAsync(long idSolicitudPersonaArea, string idUsuarioAprobador, DecidirAprobacionRequest request, CancellationToken cancellationToken);
    Task<IdCreadoResponse> CrearSolicitudAsync(CrearSolicitudRequest request, CancellationToken cancellationToken);
    Task<bool> ActualizarSolicitudAsync(long idSolicitud, CrearSolicitudRequest request, CancellationToken cancellationToken);
    Task<bool> EliminarSolicitudAsync(long idSolicitud, string usuario, CancellationToken cancellationToken);
    Task<long> AgregarPersonaAsync(long idSolicitud, AgregarPersonaSolicitudRequest request, CancellationToken cancellationToken);
    Task ReenviarAprobacionAsync(long idSolicitudPersonaArea, string idUsuarioSolicitante, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<SolicitudResumen>> ListarSolicitudesAsync(CancellationToken cancellationToken);
    Task<IReadOnlyCollection<ActividadResumen>> ListarMisActividadesAsync(string idUsuarioResponsable, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<ActividadAdministracionResumen>> ListarActividadesAsync(CancellationToken cancellationToken);
    Task<long> CrearActividadAsync(CrearActividadRequest request, string usuario, CancellationToken cancellationToken);
    Task<long> CompletarActividadAsync(long idActividad, string idUsuarioResponsable, CompletarActividadRequest request, CancellationToken cancellationToken);
    Task<long> DecidirActividadAsync(long idActividad, string idUsuarioAprobador, DecidirActividadRequest request, CancellationToken cancellationToken);
    Task<SolicitudDetalle?> ObtenerSolicitudAsync(long idSolicitud, CancellationToken cancellationToken);
}
