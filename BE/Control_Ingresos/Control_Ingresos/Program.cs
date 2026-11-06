using Control_Ingresos.Data;
using Control_Ingresos.Integrations.Freshservice;
using Control_Ingresos.Models;
using Control_Ingresos.Services;
using Control_Ingresos.Security;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
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
builder.Services.AddScoped<IActivityWorkflowRepository, ActivityWorkflowRepository>();
builder.Services.AddSingleton<ApplicationSession>();
builder.Services.AddSingleton<AuditLogService>();
builder.Services.AddScoped<CurrentUserAccessValidator>();
builder.Services.AddSingleton<ICredentialEmailSender, SmtpCredentialEmailSender>();
builder.Services.AddScoped<EmailNotificationService>();
builder.Services.Configure<FreshserviceOptions>(
    builder.Configuration.GetSection(FreshserviceOptions.SectionName));
builder.Services.AddHttpClient<IFreshserviceReadOnlyClient, FreshserviceReadOnlyClient>(client =>
{
    client.Timeout = TimeSpan.FromSeconds(30);
});

builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<HtisExceptionHandler>();
builder.Services.AddExceptionHandler<SingularExceptionHandler>();
builder.Services.AddExceptionHandler<FreshserviceExceptionHandler>();
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
            if (context.Principal is not null)
            {
                var accessValidator = context.HttpContext.RequestServices
                    .GetRequiredService<CurrentUserAccessValidator>();
                var currentRoles = await accessValidator.GetCurrentRolesAsync(
                    context.Principal, context.HttpContext.RequestAborted);
                if (currentRoles is not null)
                {
                    context.HttpContext.Items[CurrentUserAccessValidator.CurrentRolesItemKey] = currentRoles;
                    var cookieRoles = context.Principal.FindAll(ClaimTypes.Role)
                        .Select(claim => claim.Value)
                        .ToHashSet(StringComparer.OrdinalIgnoreCase);
                    if (!cookieRoles.SetEquals(currentRoles))
                    {
                        var claims = context.Principal.Claims
                            .Where(claim => claim.Type != ClaimTypes.Role)
                            .Concat(currentRoles.Select(role => new Claim(ClaimTypes.Role, role)));
                        var renewedPrincipal = new ClaimsPrincipal(new ClaimsIdentity(
                            claims, CookieAuthenticationDefaults.AuthenticationScheme));
                        context.ReplacePrincipal(renewedPrincipal);
                        context.HttpContext.User = renewedPrincipal;
                        context.ShouldRenew = true;
                    }
                    return;
                }
            }

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

await AuditSchemaInstaller.EnsureInstalledAsync(app.Configuration, app.Logger,
    app.Lifetime.ApplicationStopping);
await IngresoTypeCatalogInstaller.EnsureInstalledAsync(app.Configuration, app.Logger,
    app.Lifetime.ApplicationStopping);
var legacyAuditCount = await app.Services.GetRequiredService<AuditLogService>()
    .ImportLegacyFilesAsync(app.Lifetime.ApplicationStopping);
if (legacyAuditCount > 0)
    app.Logger.LogInformation("Se importaron {Count} registros de auditoria previos.", legacyAuditCount);

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

app.Use(async (context, next) =>
{
    try
    {
        await next();
    }
    catch (Microsoft.Data.SqlClient.SqlException exception) when (context.RequestAborted.IsCancellationRequested)
    {
        // Al reiniciar el backend, SqlClient puede reportar la cancelacion de la solicitud
        // como SqlException. No es un fallo funcional y ya no existe un cliente al cual responder.
        app.Logger.LogDebug(exception, "Consulta SQL cancelada porque la solicitud HTTP fue interrumpida.");
    }
});

app.UseCors("Frontend");

app.UseStaticFiles();

app.UseAuthentication();
app.Use(AuditLogMiddleware.Invoke);

app.Use(async (context, next) =>
{
    // Una cookie anterior no debe impedir iniciar una nueva sesion o consultar la actual.
    // Los endpoints protegidos de autenticacion conservan sus atributos [Authorize].
    if (context.Request.Path.StartsWithSegments("/api/autenticacion", StringComparison.OrdinalIgnoreCase))
    {
        await next();
        return;
    }

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
            Detail = "El rol Guardia solo puede escanear códigos QR y consultar sus resultados.",
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

app.Use(PermissionGate.Invoke);
app.UseAuthorization();

app.MapControllers();

app.Run();

static bool EsRutaPermitidaParaGuardia(HttpRequest request)
{
    if (HttpMethods.IsPost(request.Method)
        && (request.Path.Equals("/api/autenticacion/logout", StringComparison.OrdinalIgnoreCase)
            || request.Path.Equals("/api/auditoria/navegacion", StringComparison.OrdinalIgnoreCase)))
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
            || request.Path.Equals("/api/auditoria/navegacion", StringComparison.OrdinalIgnoreCase)
            || request.Path.Equals("/api/personas", StringComparison.OrdinalIgnoreCase)
            || request.Path.Equals("/api/personas/fotografia", StringComparison.OrdinalIgnoreCase)
            || request.Path.StartsWithSegments("/api/proveedores/solicitudes", StringComparison.OrdinalIgnoreCase);
    }

    if (HttpMethods.IsDelete(request.Method))
        return request.Path.StartsWithSegments("/api/proveedores/solicitudes", StringComparison.OrdinalIgnoreCase);

    if (!HttpMethods.IsGet(request.Method)) return false;

    return request.Path.Equals("/api/catalogos/tipos-documento", StringComparison.OrdinalIgnoreCase)
        || request.Path.Equals("/api/catalogos/estados-generales", StringComparison.OrdinalIgnoreCase)
        || request.Path.Equals("/api/catalogos/areas", StringComparison.OrdinalIgnoreCase)
        || request.Path.StartsWithSegments("/api/proveedores", StringComparison.OrdinalIgnoreCase);
}
