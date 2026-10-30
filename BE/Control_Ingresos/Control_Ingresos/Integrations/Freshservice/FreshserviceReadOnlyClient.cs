using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Control_Ingresos.Integrations.Freshservice;

public sealed class FreshserviceOptions
{
    public const string SectionName = "ExternalApis:Freshservice";
    public string BaseUrl { get; set; } = "https://auramineralshelpdesk.freshservice.com";
    public string? ApiKey { get; set; }
    public int? WorkspaceId { get; set; }
}

public interface IFreshserviceReadOnlyClient
{
    Task<FreshserviceCatalogPage> ListCatalogAsync(
        int page,
        int perPage,
        int? workspaceId,
        CancellationToken cancellationToken);

    Task<FreshserviceServiceItemForm> GetServiceItemAsync(
        long displayId,
        int? workspaceId,
        CancellationToken cancellationToken);
}

public sealed class FreshserviceIntegrationException(
    int statusCode,
    string title,
    string message,
    Exception? innerException = null) : Exception(message, innerException)
{
    public int StatusCode { get; } = statusCode;
    public string Title { get; } = title;
}

public sealed class FreshserviceReadOnlyClient(
    HttpClient httpClient,
    IOptions<FreshserviceOptions> configuredOptions) : IFreshserviceReadOnlyClient
{
    private static readonly HashSet<string> InputTypes =
    [
        "text", "textarea", "number", "decimal", "checkbox", "date", "datetime",
        "url", "dropdown", "multiselect", "info"
    ];

    private readonly FreshserviceOptions options = configuredOptions.Value;

    public async Task<FreshserviceCatalogPage> ListCatalogAsync(
        int page,
        int perPage,
        int? workspaceId,
        CancellationToken cancellationToken)
    {
        page = Math.Max(1, page);
        perPage = Math.Clamp(perPage, 1, 30);
        workspaceId ??= options.WorkspaceId;

        var query = new StringBuilder($"api/v2/service_catalog/items?page={page}&per_page={perPage}");
        if (workspaceId is > 0)
            query.Append("&workspace_id=").Append(workspaceId.Value);

        using var document = await GetJsonAsync(query.ToString(), cancellationToken);
        if (!TryGetProperty(document.RootElement, "service_items", out var serviceItems)
            || serviceItems.ValueKind != JsonValueKind.Array)
            throw InvalidResponse();

        var items = serviceItems.EnumerateArray()
            .Select(ParseCatalogItem)
            .Where(item => item.DisplayId > 0)
            .ToArray();

        return new FreshserviceCatalogPage(page, perPage, items.Length == perPage, items);
    }

    public async Task<FreshserviceServiceItemForm> GetServiceItemAsync(
        long displayId,
        int? workspaceId,
        CancellationToken cancellationToken)
    {
        if (displayId <= 0)
            throw new FreshserviceIntegrationException(
                StatusCodes.Status400BadRequest,
                "Servicio no válido",
                "El identificador visible del servicio debe ser mayor que cero.");

        workspaceId ??= options.WorkspaceId;
        var path = $"api/v2/service_catalog/items/{displayId}";
        if (workspaceId is > 0) path += $"?workspace_id={workspaceId.Value}";

        using var document = await GetJsonAsync(path, cancellationToken);
        if (!TryGetProperty(document.RootElement, "service_item", out var serviceItem)
            || serviceItem.ValueKind != JsonValueKind.Object)
            throw InvalidResponse();

        var parsedFields = TryGetProperty(serviceItem, "custom_fields", out var customFields)
            && customFields.ValueKind == JsonValueKind.Array
            ? customFields.EnumerateArray().Select(ParseField).OrderBy(field => field.Field.Position).ToArray()
            : [];
        var serviceWorkspaceId = ReadInt32(serviceItem, "workspace_id");
        var fields = await ResolveFieldOptionsAsync(
            parsedFields,
            workspaceId ?? serviceWorkspaceId,
            cancellationToken);

        var fingerprint = Convert.ToHexString(SHA256.HashData(
            Encoding.UTF8.GetBytes(serviceItem.GetRawText())));

        return new FreshserviceServiceItemForm(
            ReadInt64(serviceItem, "id"),
            ReadInt64(serviceItem, "display_id") ?? displayId,
            ReadString(serviceItem, "name"),
            ReadString(serviceItem, "short_description"),
            ReadString(serviceItem, "description"),
            serviceWorkspaceId,
            ReadBool(serviceItem, "allow_quantity"),
            ReadBool(serviceItem, "allow_attachments"),
            ReadBool(serviceItem, "is_bundle"),
            fingerprint,
            fields);
    }

    private async Task<JsonDocument> GetJsonAsync(string relativePath, CancellationToken cancellationToken)
    {
        var baseUri = ValidateConfiguration();
        using var request = new HttpRequestMessage(HttpMethod.Get, new Uri(baseUri, relativePath));
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        request.Headers.Authorization = new AuthenticationHeaderValue(
            "Basic",
            Convert.ToBase64String(Encoding.ASCII.GetBytes($"{options.ApiKey}:X")));

        try
        {
            using var response = await httpClient.SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);

            if (!response.IsSuccessStatusCode)
                throw CreateRemoteError(response);

            await using var responseStream = await response.Content.ReadAsStreamAsync(cancellationToken);
            return await JsonDocument.ParseAsync(responseStream, cancellationToken: cancellationToken);
        }
        catch (FreshserviceIntegrationException)
        {
            throw;
        }
        catch (OperationCanceledException exception) when (!cancellationToken.IsCancellationRequested)
        {
            throw new FreshserviceIntegrationException(
                StatusCodes.Status503ServiceUnavailable,
                "Freshservice no respondió a tiempo",
                "La consulta de solo lectura superó el tiempo de espera configurado.",
                exception);
        }
        catch (HttpRequestException exception)
        {
            throw new FreshserviceIntegrationException(
                StatusCodes.Status503ServiceUnavailable,
                "Freshservice no está disponible",
                "No fue posible establecer una conexión segura con Freshservice.",
                exception);
        }
        catch (JsonException exception)
        {
            throw new FreshserviceIntegrationException(
                StatusCodes.Status502BadGateway,
                "Respuesta no reconocida",
                "Freshservice devolvió una respuesta que no pudo interpretarse.",
                exception);
        }
    }

    private Uri ValidateConfiguration()
    {
        if (string.IsNullOrWhiteSpace(options.ApiKey))
            throw new FreshserviceIntegrationException(
                StatusCodes.Status503ServiceUnavailable,
                "Integración no configurada",
                "Configura ExternalApis:Freshservice:ApiKey mediante User Secrets antes de consultar el catálogo.");

        if (!Uri.TryCreate(options.BaseUrl?.TrimEnd('/') + "/", UriKind.Absolute, out var baseUri)
            || baseUri.Scheme != Uri.UriSchemeHttps
            || !baseUri.Host.EndsWith(".freshservice.com", StringComparison.OrdinalIgnoreCase))
            throw new FreshserviceIntegrationException(
                StatusCodes.Status503ServiceUnavailable,
                "Configuración no válida",
                "ExternalApis:Freshservice:BaseUrl debe ser una dirección HTTPS del dominio freshservice.com.");

        return baseUri;
    }

    private static FreshserviceIntegrationException CreateRemoteError(HttpResponseMessage response)
    {
        return response.StatusCode switch
        {
            HttpStatusCode.Unauthorized => new FreshserviceIntegrationException(
                StatusCodes.Status502BadGateway,
                "Autenticación rechazada",
                "Freshservice rechazó la API key configurada."),
            HttpStatusCode.Forbidden => new FreshserviceIntegrationException(
                StatusCodes.Status502BadGateway,
                "Permiso insuficiente",
                "La API key no tiene permiso para consultar el catálogo de servicios."),
            HttpStatusCode.NotFound => new FreshserviceIntegrationException(
                StatusCodes.Status404NotFound,
                "Servicio no encontrado",
                "Freshservice no encontró el servicio solicitado."),
            HttpStatusCode.TooManyRequests => new FreshserviceIntegrationException(
                StatusCodes.Status503ServiceUnavailable,
                "Límite de consultas alcanzado",
                response.Headers.RetryAfter?.Delta is { } retryAfter
                    ? $"Freshservice solicitó esperar aproximadamente {Math.Ceiling(retryAfter.TotalSeconds)} segundos."
                    : "Freshservice solicitó esperar antes de realizar otra consulta."),
            _ => new FreshserviceIntegrationException(
                StatusCodes.Status502BadGateway,
                "Error al consultar Freshservice",
                $"Freshservice respondió con el estado HTTP {(int)response.StatusCode}.")
        };
    }

    private static FreshserviceCatalogItemSummary ParseCatalogItem(JsonElement item)
    {
        var fieldCount = TryGetProperty(item, "custom_fields", out var fields)
            && fields.ValueKind == JsonValueKind.Array
            ? fields.GetArrayLength()
            : 0;

        return new FreshserviceCatalogItemSummary(
            ReadInt64(item, "id"),
            ReadInt64(item, "display_id") ?? 0,
            ReadString(item, "name"),
            ReadString(item, "short_description"),
            ReadInt32(item, "workspace_id"),
            ReadBool(item, "is_bundle"),
            ReadBool(item, "allow_quantity"),
            fieldCount);
    }

    private async Task<IReadOnlyCollection<FreshserviceFormField>> ResolveFieldOptionsAsync(
        IReadOnlyCollection<ParsedFreshserviceField> parsedFields,
        int? workspaceId,
        CancellationToken cancellationToken)
    {
        var sharedChoices = new Dictionary<string, IReadOnlyCollection<FreshserviceFieldOption>>(
            StringComparer.OrdinalIgnoreCase);
        var result = new List<FreshserviceFormField>(parsedFields.Count);

        foreach (var parsedField in parsedFields)
        {
            var field = parsedField.Field;
            if (!field.Supported
                || field.Type is not ("dropdown" or "multiselect")
                || field.Options.Count > 0)
            {
                result.Add(field);
                continue;
            }

            if (string.IsNullOrWhiteSpace(parsedField.ReferenceFieldId))
            {
                result.Add(field with
                {
                    Supported = false,
                    UnsupportedReason = "Freshservice no devolvió opciones para este selector."
                });
                continue;
            }

            if (workspaceId is not > 0)
            {
                result.Add(field with
                {
                    Supported = false,
                    UnsupportedReason = "No fue posible determinar el workspace para consultar las opciones del campo compartido."
                });
                continue;
            }

            try
            {
                if (!sharedChoices.TryGetValue(parsedField.ReferenceFieldId, out var choices))
                {
                    choices = await GetSharedFieldChoicesAsync(
                        parsedField.ReferenceFieldId,
                        workspaceId.Value,
                        cancellationToken);
                    sharedChoices[parsedField.ReferenceFieldId] = choices;
                }

                result.Add(choices.Count > 0
                    ? field with { Options = choices }
                    : field with
                    {
                        Supported = false,
                        UnsupportedReason = "El campo compartido no contiene opciones disponibles en Freshservice."
                    });
            }
            catch (FreshserviceIntegrationException exception)
            {
                result.Add(field with
                {
                    Supported = false,
                    UnsupportedReason = $"No fue posible cargar las opciones del campo compartido: {exception.Message}"
                });
            }
        }

        return result;
    }

    private async Task<IReadOnlyCollection<FreshserviceFieldOption>> GetSharedFieldChoicesAsync(
        string referenceFieldId,
        int workspaceId,
        CancellationToken cancellationToken)
    {
        var path = $"api/v2/service-catalog/shared-fields/{Uri.EscapeDataString(referenceFieldId)}?workspace_id={workspaceId}";
        using var document = await GetJsonAsync(path, cancellationToken);
        return ReadChoices(document.RootElement);
    }

    private static ParsedFreshserviceField ParseField(JsonElement field)
    {
        var apiName = ReadString(field, "name")
            ?? ReadString(field, "api_name")
            ?? ReadString(field, "field_name");
        var rawType = ReadString(field, "field_type")
            ?? ReadString(field, "type")
            ?? "unknown";
        var type = NormalizeType(rawType);
        var required = ReadBool(field, "required") || ReadBool(field, "mandatory");
        var displayed = ReadNestedBool(field, "field_options", "displayed_to_requester")
            ?? ReadNullableBool(field, "visible_in_portal")
            ?? true;
        var editable = ReadNestedBool(field, "field_options", "requester_can_edit")
            ?? ReadNullableBool(field, "requester_can_edit")
            ?? true;
        var referenceFieldId = ReadNestedSimpleValue(field, "reference", "field_id");
        var hasNestedFields = TryGetProperty(field, "nested_fields", out var nestedFields)
            && nestedFields.ValueKind == JsonValueKind.Array
            && nestedFields.GetArrayLength() > 0;

        string? unsupportedReason = null;
        if (!InputTypes.Contains(type))
            unsupportedReason = $"El tipo {rawType} todavía no tiene un control compatible.";
        else if (hasNestedFields)
            unsupportedReason = "Los campos anidados o dependientes requieren una implementación específica.";
        else if (type != "info" && string.IsNullOrWhiteSpace(apiName))
            unsupportedReason = "Freshservice no devolvió un nombre interno utilizable para el payload.";

        return new ParsedFreshserviceField(
            new FreshserviceFormField(
                apiName,
                ReadString(field, "label") ?? apiName,
                ReadString(field, "description"),
                ReadString(field, "placeholder"),
                rawType,
                type,
                required,
                displayed,
                editable,
                ReadInt32(field, "position") ?? int.MaxValue,
                ReadSimpleValue(field, "default_value") ?? ReadSimpleValue(field, "value"),
                unsupportedReason is null,
                unsupportedReason,
                ReadChoices(field)),
            referenceFieldId);
    }

    private static string NormalizeType(string rawType) => rawType.Trim().ToLowerInvariant() switch
    {
        "custom_text" or "text" or "single_line_text" => "text",
        "custom_paragraph" or "paragraph" or "textarea" => "textarea",
        "custom_number" or "custom_big_number" or "number" => "number",
        "custom_decimal" or "decimal" => "decimal",
        "custom_checkbox" or "checkbox" => "checkbox",
        "custom_date" or "date" => "date",
        "custom_date_time" or "date_time" or "datetime" => "datetime",
        "custom_url" or "url" => "url",
        "custom_dropdown" or "dropdown" => "dropdown",
        "custom_multi_select_dropdown" or "multi_select_dropdown" or "multiselect" => "multiselect",
        "custom_static_rich_text" or "static_rich_text" => "info",
        _ => "unsupported"
    };

    private static IReadOnlyCollection<FreshserviceFieldOption> ReadChoices(JsonElement field)
    {
        if (!TryGetProperty(field, "choices", out var choices) || choices.ValueKind != JsonValueKind.Array)
            return [];

        var result = new List<FreshserviceFieldOption>();
        foreach (var choice in choices.EnumerateArray())
        {
            string? value = null;
            string? label = null;
            if (choice.ValueKind == JsonValueKind.Object)
            {
                value = ReadSimpleValue(choice, "value") ?? ReadSimpleValue(choice, "id");
                label = ReadSimpleValue(choice, "label") ?? value;
            }
            else if (choice.ValueKind == JsonValueKind.Array)
            {
                var values = choice.EnumerateArray().Select(ReadSimpleValue).Where(item => item is not null).ToArray();
                label = values.FirstOrDefault();
                value = values.Skip(1).FirstOrDefault() ?? label;
            }
            else
            {
                value = ReadSimpleValue(choice);
                label = value;
            }

            if (!string.IsNullOrWhiteSpace(value))
                result.Add(new FreshserviceFieldOption(value, label ?? value));
        }

        return result;
    }

    private static FreshserviceIntegrationException InvalidResponse() => new(
        StatusCodes.Status502BadGateway,
        "Respuesta no reconocida",
        "Freshservice no devolvió la estructura esperada para el catálogo de servicios.");

    private static bool TryGetProperty(JsonElement element, string name, out JsonElement value)
    {
        if (element.ValueKind == JsonValueKind.Object && element.TryGetProperty(name, out value)) return true;
        value = default;
        return false;
    }

    private static string? ReadString(JsonElement element, string name) =>
        TryGetProperty(element, name, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

    private static long? ReadInt64(JsonElement element, string name) =>
        TryGetProperty(element, name, out var value) ? ReadInt64(value) : null;

    private static long? ReadInt64(JsonElement value)
    {
        if (value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out var number)) return number;
        return value.ValueKind == JsonValueKind.String
            && long.TryParse(value.GetString(), NumberStyles.Integer, CultureInfo.InvariantCulture, out number)
            ? number
            : null;
    }

    private static int? ReadInt32(JsonElement element, string name)
    {
        var number = ReadInt64(element, name);
        return number is >= int.MinValue and <= int.MaxValue ? (int)number.Value : null;
    }

    private static bool ReadBool(JsonElement element, string name) => ReadNullableBool(element, name) ?? false;

    private static bool? ReadNullableBool(JsonElement element, string name)
    {
        if (!TryGetProperty(element, name, out var value)) return null;
        return value.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            JsonValueKind.Number when value.TryGetInt32(out var number) => number != 0,
            JsonValueKind.String when bool.TryParse(value.GetString(), out var boolean) => boolean,
            JsonValueKind.String when int.TryParse(value.GetString(), out var number) => number != 0,
            _ => null
        };
    }

    private static bool? ReadNestedBool(JsonElement element, string objectName, string propertyName) =>
        TryGetProperty(element, objectName, out var nested) && nested.ValueKind == JsonValueKind.Object
            ? ReadNullableBool(nested, propertyName)
            : null;

    private static string? ReadNestedSimpleValue(JsonElement element, string objectName, string propertyName) =>
        TryGetProperty(element, objectName, out var nested) && nested.ValueKind == JsonValueKind.Object
            ? ReadSimpleValue(nested, propertyName)
            : null;

    private static string? ReadSimpleValue(JsonElement element, string name) =>
        TryGetProperty(element, name, out var value) ? ReadSimpleValue(value) : null;

    private static string? ReadSimpleValue(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.String => value.GetString(),
        JsonValueKind.Number => value.GetRawText(),
        JsonValueKind.True => bool.TrueString,
        JsonValueKind.False => bool.FalseString,
        _ => null
    };

    private sealed record ParsedFreshserviceField(
        FreshserviceFormField Field,
        string? ReferenceFieldId);
}

