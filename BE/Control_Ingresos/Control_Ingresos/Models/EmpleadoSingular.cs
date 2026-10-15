namespace Control_Ingresos.Models;

public sealed record EmpleadoAutorizacionSingular(
    int? Carnet,
    string? Nombre,
    string? Contrato,
    string? Empresa,
    string? Cargo,
    string? CategoriaLicencia,
    DateTime? ValidezLicencia,
    string? NumeroLicencia,
    string? Estado,
    DateTime? ValidezAso,
    string? Area,
    string? Gerencia,
    string? TipoSangre);

public sealed record EmpleadoEntrenamientoSingular(
    string? Entrenamiento,
    string? Validez,
    string? FechaEntrenamiento,
    string? CargaHoraria,
    string? Tipo);

public sealed record EmpleadoInformacionSingular(
    EmpleadoAutorizacionSingular? Autorizacion,
    IReadOnlyCollection<EmpleadoEntrenamientoSingular> Entrenamientos);

public sealed record EmpleadoCredencialPublica(
    string CodigoEmpleado,
    string? Nombre,
    string? Empresa,
    string? Area,
    string? Cargo,
    string? TipoSangre,
    string? NumeroLicencia,
    string? CategoriaLicencia,
    DateTime? ValidezLicencia,
    DateTime? ValidezAso,
    string? AutorizadoConducirVehiculo,
    string? Estado,
    IReadOnlyCollection<EmpleadoEntrenamientoSingular> Entrenamientos,
    bool InformacionHtisDisponible,
    bool InformacionSingularDisponible,
    string? Aviso);
