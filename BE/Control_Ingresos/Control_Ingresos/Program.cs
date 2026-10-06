using Control_Ingresos.Data;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

builder.Services.AddControllers();
builder.Services.AddOpenApi();

builder.Services.AddScoped<ISolicitudesRepository, SolicitudesRepository>();
builder.Services.AddScoped<IEmpleadosRepository, EmpleadosRepository>();

builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<SqlExceptionHandler>();

builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.Name = "ControlIngresos.Session";
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = SameSiteMode.None;
        options.Cookie.SecurePolicy = CookieSecurePolicy.Always;

        options.ExpireTimeSpan = TimeSpan.FromHours(8);
        options.SlidingExpiration = true;

        options.Events.OnRedirectToLogin = context =>
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return Task.CompletedTask;
        };

        options.Events.OnRedirectToAccessDenied = context =>
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            return Task.CompletedTask;
        };
    });

builder.Services.AddAuthorization();

builder.Services.AddCors(options =>
{
    options.AddPolicy("Frontend", policy => policy
        .WithOrigins(
            builder.Configuration
                .GetSection("Cors:AllowedOrigins")
                .Get<string[]>()
            ?? ["http://localhost:5173"])
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials());
});

var app = builder.Build();

await DatabaseProcedureInstaller.EnsureInstalledAsync(
    builder.Configuration,
    app.Logger,
    app.Lifetime.ApplicationStopping);

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseHttpsRedirection();

app.UseExceptionHandler();

app.UseCors("Frontend");

app.UseStaticFiles();

app.UseAuthentication();

app.Use(async (context, next) =>
{
    var guardiaRestringido = context.User.Identity?.IsAuthenticated == true
        && context.User.IsInRole("Guardia")
        && !context.User.IsInRole("Administrador");

    if (guardiaRestringido && !EsRutaPermitidaParaGuardia(context.Request))
    {
        context.Response.StatusCode = StatusCodes.Status403Forbidden;
        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Title = "Acceso restringido",
            Detail = "El rol Guardia solo puede escanear códigos QR y consultar sus resultados.",
            Status = StatusCodes.Status403Forbidden
        });
        return;
    }

    await next();
});

app.UseAuthorization();

app.MapControllers();

app.Run();

static bool EsRutaPermitidaParaGuardia(HttpRequest request)
{
    if (HttpMethods.IsPost(request.Method)
        && request.Path.Equals("/api/autenticacion/logout", StringComparison.OrdinalIgnoreCase))
        return true;

    if (!HttpMethods.IsGet(request.Method)) return false;

    var path = request.Path.Value ?? string.Empty;
    if (path.StartsWith("/api/personas/qr/", StringComparison.OrdinalIgnoreCase)
        || path.StartsWith("/api/empleados/qr/", StringComparison.OrdinalIgnoreCase))
        return true;

    var segments = path.Split('/', StringSplitOptions.RemoveEmptyEntries);
    return segments.Length == 4
        && segments[0].Equals("api", StringComparison.OrdinalIgnoreCase)
        && ((segments[1].Equals("personas", StringComparison.OrdinalIgnoreCase)
             && segments[3].Equals("fotografia-contenido", StringComparison.OrdinalIgnoreCase))
            || (segments[1].Equals("empleados", StringComparison.OrdinalIgnoreCase)
                && segments[3].Equals("fotografia", StringComparison.OrdinalIgnoreCase)));
}
