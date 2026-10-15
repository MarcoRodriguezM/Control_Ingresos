using Control_Ingresos.Models;

namespace Control_Ingresos.Data;

public interface IEmpleadoSingularRepository
{
    Task<EmpleadoInformacionSingular> ObtenerAsync(
        string codigoEmpleado,
        CancellationToken cancellationToken);
}
