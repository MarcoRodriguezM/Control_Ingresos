using Control_Ingresos.Data;
using Control_Ingresos.Models;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Control_Ingresos.Controllers;

[ApiController]
[Route("api/autenticacion")]
public sealed class AutenticacionController(ISolicitudesRepository repository) : ControllerBase
{
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
        return perfil is null ? NotFound() : Ok(perfil);
    }

    [HttpPost("login")]
    [ProducesResponseType<SesionUsuario>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<SesionUsuario>> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        var usuario = await repository.AutenticarAsync(request, cancellationToken);
        if (usuario is null)
            return Unauthorized(new ProblemDetails
            {
                Title = "Credenciales incorrectas",
                Detail = "El usuario, correo o contraseña no son válidos."
            });

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, usuario.IdUsuario),
            new(ClaimTypes.Name, usuario.NombreCompleto ?? usuario.IdUsuario),
            new(ClaimTypes.Email, usuario.Correo ?? string.Empty)
        };
        claims.AddRange(usuario.Roles.Select(role => new Claim(ClaimTypes.Role, role)));
        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        await HttpContext.SignInAsync(
            CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(identity),
            new AuthenticationProperties { IsPersistent = true, ExpiresUtc = DateTimeOffset.UtcNow.AddHours(8) });

        return Ok(usuario);
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
