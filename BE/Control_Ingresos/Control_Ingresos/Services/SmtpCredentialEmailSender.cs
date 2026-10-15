using System.Net;
using System.Net.Mail;

namespace Control_Ingresos.Services;

public sealed class SmtpCredentialEmailSender(
    IConfiguration configuration,
    ILogger<SmtpCredentialEmailSender> logger) : ICredentialEmailSender
{
    public async Task<bool> EnviarCredencialesProveedorAsync(
        string destinatario,
        string nombreProveedor,
        string idUsuario,
        string contrasenaTemporal,
        CancellationToken cancellationToken)
    {
        var host = configuration["Email:Smtp:Host"];
        var remitente = configuration["Email:Smtp:SenderAddress"];
        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(remitente))
        {
            logger.LogWarning(
                "No se enviaron las credenciales de {IdUsuario}: falta configurar Email:Smtp:Host o SenderAddress.",
                idUsuario);
            return false;
        }

        var puerto = configuration.GetValue("Email:Smtp:Port", 587);
        var ssl = configuration.GetValue("Email:Smtp:EnableSsl", true);
        var usuario = configuration["Email:Smtp:UserName"];
        var contrasena = configuration["Email:Smtp:Password"];
        var nombreRemitente = configuration["Email:Smtp:SenderName"] ?? "Control de Ingresos";
        var urlAplicacion = configuration["Frontend:BaseUrl"] ?? "http://localhost:5173";

        using var mensaje = new MailMessage
        {
            From = new MailAddress(remitente, nombreRemitente),
            Subject = "Credenciales de acceso - Control de Ingresos",
            Body = $"""
                Hola {nombreProveedor},

                Se creo su cuenta para ingresar al portal de proveedores.

                Usuario: {idUsuario}
                Contrasena temporal: {contrasenaTemporal}
                Acceso: {urlAplicacion.TrimEnd('/')}/login

                Por seguridad, no comparta estas credenciales.
                """,
            IsBodyHtml = false
        };
        mensaje.To.Add(new MailAddress(destinatario));

        using var cliente = new SmtpClient(host, puerto)
        {
            EnableSsl = ssl,
            UseDefaultCredentials = string.IsNullOrWhiteSpace(usuario)
        };
        if (!string.IsNullOrWhiteSpace(usuario))
            cliente.Credentials = new NetworkCredential(usuario, contrasena);

        try
        {
            await cliente.SendMailAsync(mensaje).WaitAsync(cancellationToken);
            return true;
        }
        catch (Exception exception) when (exception is SmtpException or InvalidOperationException)
        {
            logger.LogError(exception, "No se pudieron enviar las credenciales de {IdUsuario}.", idUsuario);
            return false;
        }
    }
}
