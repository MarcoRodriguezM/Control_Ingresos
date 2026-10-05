namespace Control_Ingresos.Models;

public sealed record Empleado(
    string? CodigoEmpleado,
    string? NombreCompleto,
    string? Nombre1,
    string? Nombre2,
    string? Apellido1,
    string? Apellido2,
    string? TipoSangre,
    string? Nit,
    string? CodigoNacionalidad,
    DateTime? FechaNacimiento,
    string? LugarNacimiento,
    string? CodigoStatus,
    string? DescripcionStatus,
    string? EstadoCivil,
    string? Sexo,
    DateTime? FechaIngreso,
    DateTime? FechaEgreso,
    string? Correo,
    string? TipoLicencia,
    string? Departamento,
    string? CargoNivel);

public sealed record EmpleadoStatus(
    int StatusId,
    string? Descripcion);

public sealed record EmpleadoQrResponse(string CodigoQr);
