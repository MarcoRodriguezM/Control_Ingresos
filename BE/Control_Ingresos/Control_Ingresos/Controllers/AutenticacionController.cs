using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using Control_Ingresos.Security;
using Control_Ingresos.Services;

namespace Control_Ingresos.Controllers;

[ApiController]
[Route("api/autenticacion")]
public sealed class AutenticacionController(
    ISolicitudesRepository repository,
    ApplicationSession applicationSession,
    CurrentUserAccessValidator accessValidator,
    AuditLogService auditLog,
    ILogger<AutenticacionController> logger) : ControllerBase
{
    [Authorize]
    [HttpGet("sesion")]
    [ProducesResponseType<SesionUsuario>(StatusCodes.Status200OK)]
    public async Task<ActionResult<SesionUsuario>> Sesion(CancellationToken cancellationToken)
    {
        var idUsuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuario)) return Unauthorized();
        var roles = await accessValidator.GetCurrentRolesAsync(User, cancellationToken);
        if (roles is null) return Unauthorized();
        var perfil = await repository.ObtenerPerfilAsync(idUsuario, cancellationToken);
        if (perfil is null) return Unauthorized();
        var area = perfil.Areas.FirstOrDefault(item => item.EsAreaPrincipal) ?? perfil.Areas.FirstOrDefault();
        return Ok(new SesionUsuario(
            perfil.IdUsuario,
            perfil.NombreCompleto,
            perfil.Correo,
            perfil.Puesto,
            area?.IdArea,
            area?.Nombre,
            perfil.EsAprobador,
            perfil.PuedeSolicitar,
            roles));
    }

    [Authorize]
    [HttpGet("perfil")]
    [ProducesResponseType<PerfilUsuario>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PerfilUsuario>> Perfil(CancellationToken cancellationToken)
    {
        var idUsuario = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(idUsuario)) return Unauthorized();
        var perfil = await repository.ObtenerPerfilAsync(idUsuario, cancellationToken);
        if (perfil is null) return NotFound();
        return Ok(AppPermissions.Has(User, "VER_SOLICITUDES")
            ? perfil
            : perfil with { Solicitudes = [] });
    }

    [HttpPost("login")]
    [ProducesResponseType<SesionUsuario>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<SesionUsuario>> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        var usuario = await repository.AutenticarAsync(request, cancellationToken);
        if (usuario is null)
        {
            await LogLoginAsync(request.Usuario, request.Usuario, StatusCodes.Status401Unauthorized);
            return Unauthorized(new ProblemDetails
            {
                Title = "Credenciales incorrectas",
                Detail = "El usuario, correo o contraseña no son válidos."
            });
        }

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, usuario.IdUsuario),
            new(ClaimTypes.Name, usuario.NombreCompleto ?? usuario.IdUsuario),
            new(ClaimTypes.Email, usuario.Correo ?? string.Empty),
            new(ApplicationSession.ClaimType, applicationSession.InstanceId)
        };
        claims.AddRange(usuario.Roles.Select(role => new Claim(ClaimTypes.Role, role)));
        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        await HttpContext.SignInAsync(
            CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(identity),
            new AuthenticationProperties { IsPersistent = true, ExpiresUtc = DateTimeOffset.UtcNow.AddHours(1) });

        await LogLoginAsync(usuario.IdUsuario, usuario.NombreCompleto ?? usuario.IdUsuario,
            StatusCodes.Status200OK);

        return Ok(usuario);
    }

    private async Task LogLoginAsync(string idUsuario, string nombre, int estado)
    {
        try
        {
            await auditLog.AppendAsync(new AuditEntry(Guid.NewGuid(), DateTimeOffset.UtcNow,
                idUsuario, nombre, "POST", "api/autenticacion/login", null, estado));
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "No se pudo registrar el inicio de sesion en auditoria.");
        }
    }

    [Authorize]
    [HttpPost("logout")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return NoContent();
    }
}
