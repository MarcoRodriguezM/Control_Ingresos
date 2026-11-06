using System.Net;
using System.Net.Mail;
using System.Net.Mime;
using System.Text;

namespace Control_Ingresos.Services;

public sealed class SmtpCredentialEmailSender(
    IConfiguration configuration,
    ILogger<SmtpCredentialEmailSender> logger) : ICredentialEmailSender
{
    public Task<bool> EnviarCredencialesUsuarioAsync(
        string destinatario,
        string nombreUsuario,
        string idUsuario,
        string contrasenaInicial,
        CancellationToken cancellationToken) => EnviarNotificacionAsync(
            destinatario,
            "Credenciales de acceso - Control de Ingresos",
            $"""
                Hola {nombreUsuario},

                Se creo tu cuenta de Control de Ingresos.

                Usuario: {idUsuario}
                Contrasena inicial: {contrasenaInicial}
                No compartas estas credenciales.
                """,
            cancellationToken,
            $"{ApplicationUrl}/login",
            "Iniciar sesion");

    public Task<bool> EnviarCredencialesProveedorAsync(
        string destinatario,
        string nombreProveedor,
        string idUsuario,
        string contrasenaTemporal,
        CancellationToken cancellationToken)
        => EnviarNotificacionAsync(
            destinatario,
            "Credenciales de acceso - Control de Ingresos",
            $"""
                Hola {nombreProveedor},

                Se creo su cuenta para ingresar al portal de proveedores.

                Usuario: {idUsuario}
                Contrasena temporal: {contrasenaTemporal}
                No comparta estas credenciales.
                """,
            cancellationToken,
            $"{ApplicationUrl}/login",
            "Ingresar al portal");

    private string ApplicationUrl =>
        (configuration["Frontend:BaseUrl"] ?? "http://localhost:5173").TrimEnd('/');

    public async Task<bool> EnviarNotificacionAsync(
        string destinatario,
        string asunto,
        string cuerpo,
        CancellationToken cancellationToken,
        string? urlAccion = null,
        string? textoAccion = null)
    {
        if (configuration.GetValue<bool?>("Email:Enabled") == false) return false;

        var host = FirstConfigured("Email:Smtp:Host", "Email:SmtpHost");
        var remitente = FirstConfigured("Email:Smtp:SenderAddress", "Email:SenderEmail");
        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(remitente))
        {
            logger.LogWarning("No se envio el correo: falta configurar el servidor o remitente SMTP.");
            return false;
        }

        var puerto = configuration.GetValue("Email:Smtp:Port",
            configuration.GetValue("Email:SmtpPort", 587));
        var ssl = configuration.GetValue("Email:Smtp:EnableSsl", true);
        var usuario = FirstConfigured("Email:Smtp:UserName", "Email:SenderEmail");
        var contrasena = FirstConfigured("Email:Smtp:Password", "Email:AppPassword");
        var nombreRemitente = FirstConfigured("Email:Smtp:SenderName", "Email:SenderName")
            ?? "Control de Ingresos";
        if (string.IsNullOrWhiteSpace(usuario) || string.IsNullOrWhiteSpace(contrasena))
        {
            logger.LogWarning("No se envio el correo: faltan las credenciales SMTP.");
            return false;
        }

        if (host.Equals("smtp.gmail.com", StringComparison.OrdinalIgnoreCase))
            contrasena = string.Concat(contrasena.Where(character => !char.IsWhiteSpace(character)));

        try
        {
            var logoPath = Path.Combine(AppContext.BaseDirectory, "Assets", "aura-logo.png");
            var hasLogo = File.Exists(logoPath);
            using var mensaje = new MailMessage
            {
                From = new MailAddress(remitente, nombreRemitente),
                Subject = asunto,
                SubjectEncoding = Encoding.UTF8,
                Body = cuerpo,
                BodyEncoding = Encoding.UTF8,
                IsBodyHtml = false
            };
            mensaje.To.Add(new MailAddress(destinatario));
            if (!string.IsNullOrWhiteSpace(urlAccion))
                mensaje.Body += $"\n\n{textoAccion ?? "Abrir portal"}: {urlAccion}";
            var html = EmailHtmlTemplate.Render(asunto, cuerpo, urlAccion, textoAccion, hasLogo);
            var htmlView = AlternateView.CreateAlternateViewFromString(html, Encoding.UTF8, MediaTypeNames.Text.Html);
            if (hasLogo)
            {
                var logo = new LinkedResource(logoPath, MediaTypeNames.Image.Png)
                {
                    ContentId = "aura-logo",
                    TransferEncoding = TransferEncoding.Base64
                };
                htmlView.LinkedResources.Add(logo);
            }
            mensaje.AlternateViews.Add(htmlView);
            using var cliente = new SmtpClient(host, puerto)
            {
                EnableSsl = ssl,
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential(usuario, contrasena),
                Timeout = 20000
            };
            await cliente.SendMailAsync(mensaje).WaitAsync(cancellationToken);
            return true;
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "No se pudo enviar el correo a {Destinatario}.", destinatario);
            return false;
        }
    }

    private string? FirstConfigured(string primary, string fallback) =>
        !string.IsNullOrWhiteSpace(configuration[primary])
            ? configuration[primary]
            : configuration[fallback];
}
