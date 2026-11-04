namespace Control_Ingresos.Services;

public static class PersonPhotoAvailability
{
    public static string? AvailableUrl(string? url, string contentRootPath)
    {
        if (string.IsNullOrWhiteSpace(url)) return null;

        var path = Uri.TryCreate(url, UriKind.Absolute, out var absolute)
            ? absolute.AbsolutePath
            : url.Split('?', '#')[0];
        path = path.Replace('\\', '/');
        if (!path.Contains("uploads/personas/", StringComparison.OrdinalIgnoreCase)) return url;

        var fileName = Path.GetFileName(path);
        if (string.IsNullOrWhiteSpace(fileName)) return null;
        var filePath = Path.Combine(contentRootPath, "wwwroot", "uploads", "personas", fileName);
        return File.Exists(filePath) ? $"/uploads/personas/{fileName}" : null;
    }
}
