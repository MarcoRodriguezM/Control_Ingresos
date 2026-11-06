namespace Control_Ingresos.Services;

public interface ICredentialEmailSender
{
    Task<bool> EnviarCredencialesUsuarioAsync(
        string destinatario,
        string nombreUsuario,
        string idUsuario,
        string contrasenaInicial,
        CancellationToken cancellationToken);

    Task<bool> EnviarCredencialesProveedorAsync(
        string destinatario,
        string nombreProveedor,
        string idUsuario,
        string contrasenaTemporal,
        CancellationToken cancellationToken);

    Task<bool> EnviarNotificacionAsync(
        string destinatario,
        string asunto,
        string cuerpo,
        CancellationToken cancellationToken,
        string? urlAccion = null,
        string? textoAccion = null);
}
