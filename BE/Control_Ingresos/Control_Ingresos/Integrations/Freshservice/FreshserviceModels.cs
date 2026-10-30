namespace Control_Ingresos.Integrations.Freshservice;

public sealed record FreshserviceCatalogPage(
    int Page,
    int PerPage,
    bool HasNextPage,
    IReadOnlyCollection<FreshserviceCatalogItemSummary> Items);

public sealed record FreshserviceCatalogItemSummary(
    long? Id,
    long DisplayId,
    string? Name,
    string? ShortDescription,
    int? WorkspaceId,
    bool IsBundle,
    bool AllowQuantity,
    int FieldCount);

public sealed record FreshserviceServiceItemForm(
    long? Id,
    long DisplayId,
    string? Name,
    string? ShortDescription,
    string? Description,
    int? WorkspaceId,
    bool AllowQuantity,
    bool AllowAttachments,
    bool IsBundle,
    string DefinitionFingerprint,
    IReadOnlyCollection<FreshserviceFormField> Fields);

public sealed record FreshserviceFormField(
    string? ApiName,
    string? Label,
    string? Description,
    string? Placeholder,
    string RawType,
    string Type,
    bool Required,
    bool DisplayedToRequester,
    bool RequesterCanEdit,
    int Position,
    string? DefaultValue,
    bool Supported,
    string? UnsupportedReason,
    IReadOnlyCollection<FreshserviceFieldOption> Options);

public sealed record FreshserviceFieldOption(string Value, string Label);

