namespace Control_Ingresos.Services;

public interface ICredentialEmailSender
{
    Task<bool> EnviarCredencialesProveedorAsync(
        string destinatario,
        string nombreProveedor,
        string idUsuario,
        string contrasenaTemporal,
        CancellationToken cancellationToken);
}
