using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
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
app.UseAuthorization();

app.MapControllers();

app.Run();
