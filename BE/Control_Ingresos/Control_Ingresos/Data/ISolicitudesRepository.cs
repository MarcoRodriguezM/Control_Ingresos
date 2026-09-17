using Control_Ingresos.Models;

namespace Control_Ingresos.Data;

public interface ISolicitudesRepository
{
    Task<IReadOnlyCollection<CatalogoItem>> ListarCatalogoAsync(string catalogo, CancellationToken cancellationToken);
    Task<SolicitudFormularioDatos> ObtenerDatosFormularioSolicitudAsync(CancellationToken cancellationToken);
    Task<long> CrearProveedorAsync(CrearProveedorRequest request, CancellationToken cancellationToken);
    Task<long> CrearPersonaAsync(CrearPersonaRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<PersonaResumen>> ListarPersonasAsync(CancellationToken cancellationToken);
    Task<PersonaConAccesos?> ObtenerPersonaAccesosAsync(long idPersona, CancellationToken cancellationToken);
    Task<IdCreadoResponse> CrearSolicitudAsync(CrearSolicitudRequest request, CancellationToken cancellationToken);
    Task<bool> ActualizarSolicitudAsync(long idSolicitud, CrearSolicitudRequest request, CancellationToken cancellationToken);
    Task<bool> EliminarSolicitudAsync(long idSolicitud, string usuario, CancellationToken cancellationToken);
    Task<long> AgregarPersonaAsync(long idSolicitud, AgregarPersonaSolicitudRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<SolicitudResumen>> ListarSolicitudesAsync(CancellationToken cancellationToken);
    Task<SolicitudDetalle?> ObtenerSolicitudAsync(long idSolicitud, CancellationToken cancellationToken);
}
