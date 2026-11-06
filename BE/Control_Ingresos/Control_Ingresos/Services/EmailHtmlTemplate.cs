using System.Net;
using System.Text;

namespace Control_Ingresos.Services;

internal static class EmailHtmlTemplate
{
    private static string Encode(string value) => WebUtility.HtmlEncode(value);

    public static string Render(string title, string body, string? actionUrl, string? actionText, bool hasLogo)
    {
        var blocks = body.Replace("\r\n", "\n").Split("\n\n", StringSplitOptions.RemoveEmptyEntries)
            .Select(paragraph => paragraph.Trim())
            .Where(paragraph => paragraph.Length > 0)
            .Select(paragraph => $"<p style=\"margin:0 0 18px;color:#334a60;font-size:15px;line-height:1.65\">{FormatParagraph(paragraph)}</p>");
        var logo = hasLogo
            ? "<img src=\"cid:aura-logo\" alt=\"Aura 360 Mining\" width=\"146\" style=\"display:block;width:146px;height:auto;border:0\" />"
            : "<span style=\"color:#fff;font-size:24px;font-weight:700;letter-spacing:1px\">aura</span>";
        var button = Uri.TryCreate(actionUrl, UriKind.Absolute, out var uri)
            && uri.Scheme is "http" or "https"
            ? $"<table role=\"presentation\" cellpadding=\"0\" cellspacing=\"0\" style=\"margin:25px 0 8px\"><tr><td bgcolor=\"#2867e8\" style=\"border-radius:9px\"><a href=\"{Encode(uri.ToString())}\" style=\"display:inline-block;padding:14px 23px;color:#fff;text-decoration:none;font-size:14px;font-weight:700\">{Encode(actionText ?? "Abrir portal")}</a></td></tr></table>"
            : "";

        return $"""
            <!doctype html>
            <html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
            <body style="margin:0;padding:0;background:#f1f5f8;font-family:Arial,Helvetica,sans-serif">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f8"><tr><td align="center" style="padding:32px 14px">
                <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;background:#fff;border:1px solid #dce5ec;border-radius:14px;overflow:hidden">
                  <tr><td style="background:#0a2035;padding:24px 30px">{logo}<div style="margin-top:14px;color:#a8c5d9;font-size:11px;font-weight:700;letter-spacing:1.7px">CONTROL DE INGRESOS</div></td></tr>
                  <tr><td style="height:4px;background:#d96750"></td></tr>
                  <tr><td style="padding:31px 30px 25px">
                    <h1 style="margin:0 0 22px;color:#17283a;font-size:25px;line-height:1.25">{Encode(title)}</h1>
                    {string.Join("", blocks)}
                    {button}
                  </td></tr>
                  <tr><td style="border-top:1px solid #edf1f4;padding:17px 30px;color:#66798a;font-size:12px;line-height:1.5">Mensaje automatico de Control de Ingresos.</td></tr>
                </table>
              </td></tr></table>
            </body></html>
            """;
    }

    private static string FormatParagraph(string paragraph)
    {
        var lines = paragraph.Split('\n');
        var result = new StringBuilder();
        foreach (var line in lines)
        {
            if (result.Length > 0) result.Append("<br>");
            var trimmed = line.Trim();
            var separator = trimmed.IndexOf(':');
            if (separator is > 0 and < 30 && !trimmed.StartsWith("http", StringComparison.OrdinalIgnoreCase))
            {
                result.Append("<strong style=\"color:#17283a\">")
                    .Append(Encode(trimmed[..(separator + 1)]))
                    .Append("</strong> ")
                    .Append(Encode(trimmed[(separator + 1)..].Trim()));
            }
            else result.Append(Encode(trimmed));
        }
        return result.ToString();
    }
}
