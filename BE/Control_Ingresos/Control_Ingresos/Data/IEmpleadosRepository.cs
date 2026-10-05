using Control_Ingresos.Models;

namespace Control_Ingresos.Data;

public interface IEmpleadosRepository
{
    Task<IReadOnlyCollection<Empleado>> ListarAsync(CancellationToken cancellationToken);
    Task<IReadOnlyCollection<EmpleadoStatus>> ListarEstadosAsync(CancellationToken cancellationToken);
    Task<byte[]?> ObtenerFotografiaAsync(string codigoEmpleado, CancellationToken cancellationToken);
    Task<string?> ObtenerCodigoQrAsync(string codigoEmpleado, CancellationToken cancellationToken);
    Task<Empleado?> ConsultarQrAsync(string codigoQr, CancellationToken cancellationToken);
}
