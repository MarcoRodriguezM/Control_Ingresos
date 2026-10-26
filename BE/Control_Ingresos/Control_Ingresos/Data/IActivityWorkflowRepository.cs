using Control_Ingresos.Models;

namespace Control_Ingresos.Data;

public interface IActivityWorkflowRepository
{
    Task<ActividadFlujoConfiguracion> ObtenerAsync(CancellationToken cancellationToken);
    Task GuardarAsync(int idAreaAcceso, GuardarActividadFlujoRequest request, string usuario, CancellationToken cancellationToken);
    Task SincronizarActividadesAsync(long idSolicitud, long idSolicitudPersona, IReadOnlyCollection<int> areas, string usuario, CancellationToken cancellationToken);
    Task ValidarActividadDesbloqueadaAsync(long idActividad, string idUsuarioResponsable, CancellationToken cancellationToken);
    Task<IReadOnlySet<long>> ObtenerAccesosBloqueadosAsync(IReadOnlyCollection<long> idsSolicitudPersonaArea, CancellationToken cancellationToken);
    Task<IReadOnlySet<string>> ObtenerAreasQrBloqueadasAsync(long idPersona, CancellationToken cancellationToken);
}
