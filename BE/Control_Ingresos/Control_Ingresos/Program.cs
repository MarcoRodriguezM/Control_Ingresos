using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Control_Ingresos.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);
var allowHttp = builder.Configuration.GetValue<bool>("Hosting:AllowHttp");

builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

builder.Services.AddControllers();
builder.Services.AddOpenApi();

builder.Services.AddScoped<ISolicitudesRepository, SolicitudesRepository>();
builder.Services.AddScoped<IEmpleadosRepository, EmpleadosRepository>();
builder.Services.AddScoped<IEmpleadoSingularRepository, EmpleadoSingularRepository>();
builder.Services.AddSingleton<ApplicationSession>();
builder.Services.AddSingleton<ICredentialEmailSender, SmtpCredentialEmailSender>();

builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<HtisExceptionHandler>();
builder.Services.AddExceptionHandler<SingularExceptionHandler>();
builder.Services.AddExceptionHandler<SqlExceptionHandler>();

builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.Name = "ControlIngresos.Session";
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = allowHttp
            ? SameSiteMode.Lax
            : SameSiteMode.None;
        options.Cookie.SecurePolicy = allowHttp
            ? CookieSecurePolicy.SameAsRequest
            : CookieSecurePolicy.Always;

        options.ExpireTimeSpan = TimeSpan.FromHours(1);
        options.SlidingExpiration = false;

        options.Events.OnValidatePrincipal = async context =>
        {
            var applicationSession = context.HttpContext.RequestServices
                .GetRequiredService<ApplicationSession>();
            var cookieInstanceId = context.Principal?
                .FindFirst(ApplicationSession.ClaimType)?
                .Value;

            if (string.Equals(
                cookieInstanceId,
                applicationSession.InstanceId,
                StringComparison.Ordinal)) return;

            context.RejectPrincipal();
            await context.HttpContext.SignOutAsync(
                CookieAuthenticationDefaults.AuthenticationScheme);
        };

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

if (!allowHttp)
{
    app.UseHttpsRedirection();
}

app.UseExceptionHandler();

app.UseCors("Frontend");

app.UseStaticFiles();

app.UseAuthentication();

app.Use(async (context, next) =>
{
    var guardiaRestringido = context.User.Identity?.IsAuthenticated == true
        && context.User.IsInRole("Guardia")
        && !context.User.IsInRole("Administrador");
    var proveedorRestringido = context.User.Identity?.IsAuthenticated == true
        && context.User.IsInRole("Proveedor")
        && !context.User.IsInRole("Administrador");

    if (guardiaRestringido && !EsRutaPermitidaParaGuardia(context.Request))
    {
        context.Response.StatusCode = StatusCodes.Status403Forbidden;
        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Title = "Acceso restringido",
            Detail = "El rol Guardia solo puede escanear codigos QR y consultar sus resultados.",
            Status = StatusCodes.Status403Forbidden
        });
        return;
    }

    if (proveedorRestringido && !EsRutaPermitidaParaProveedor(context.Request))
    {
        context.Response.StatusCode = StatusCodes.Status403Forbidden;
        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Title = "Acceso restringido",
            Detail = "Esta cuenta solo puede utilizar los servicios del portal de proveedores.",
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

static bool EsRutaPermitidaParaProveedor(HttpRequest request)
{
    if (HttpMethods.IsPost(request.Method))
    {
        return request.Path.Equals("/api/autenticacion/logout", StringComparison.OrdinalIgnoreCase)
            || request.Path.Equals("/api/personas", StringComparison.OrdinalIgnoreCase)
            || request.Path.Equals("/api/personas/fotografia", StringComparison.OrdinalIgnoreCase)
            || request.Path.StartsWithSegments("/api/proveedores/solicitudes", StringComparison.OrdinalIgnoreCase);
    }

    if (!HttpMethods.IsGet(request.Method)) return false;

    return request.Path.Equals("/api/catalogos/tipos-documento", StringComparison.OrdinalIgnoreCase)
        || request.Path.Equals("/api/catalogos/estados-generales", StringComparison.OrdinalIgnoreCase)
        || request.Path.Equals("/api/catalogos/areas", StringComparison.OrdinalIgnoreCase)
        || request.Path.StartsWithSegments("/api/proveedores", StringComparison.OrdinalIgnoreCase);
}
