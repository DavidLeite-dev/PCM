using System.Security.Cryptography;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BookSwapAPI.Data;
using BookSwapAPI.Helpers;
using BookSwapAPI.Models;

namespace BookSwapAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly BookSwapDbContext _context;
    private readonly ILogger<AuthController> _logger;

    private const int TokenExpiryDays = 30;

    public AuthController(BookSwapDbContext context, ILogger<AuthController> logger)
    {
        _context = context;
        _logger = logger;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        try
        {
            var existingUser = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (existingUser != null)
                return BadRequest(new { message = "Email já está registado" });

            var user = new User
            {
                Name = request.Name,
                Email = request.Email,
                Password = BCrypt.Net.BCrypt.HashPassword(request.Password),
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            _logger.LogInformation("User registered: {Email}", user.Email);
            return Ok(new { message = "Utilizador registado com sucesso", id = user.Id });
        }
        catch (Exception ex)
        {
            _logger.LogError("Error registering user: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao registar utilizador" });
        }
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        try
        {
            // Diagnostic: log which database the DbContext is connected to
            try
            {
                var conn = _context.Database.GetDbConnection();
                _logger.LogInformation("Database connection: Database={Database}, DataSource={DataSource}", conn.Database, conn.DataSource);
            }
            catch { /* swallow to avoid leaking connection details in production */ }

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (user == null)
                return Unauthorized(new { message = "Email ou senha incorretos" });

            try
            {
                if (!BCrypt.Net.BCrypt.Verify(request.Password, user.Password))
                    return Unauthorized(new { message = "Email ou senha incorretos" });
            }
            catch (Exception ex)
            {
                // Detailed diagnostic logging for bcrypt parsing/verify issues (temporary)
                var hashPreview = user.Password != null && user.Password.Length >= 8 ? user.Password.Substring(0, 8) : user.Password;
                _logger.LogError(ex, "BCrypt.Verify failed for {Email}; hashPreview={HashPreview}; hashLen={Len}; fullHash={Full}", user.Email, hashPreview, user.Password?.Length ?? 0, user.Password);
                return StatusCode(500, new { message = "Erro ao fazer login", detail = "BCrypt verify error" });
            }

            var rawToken = GenerateRawToken();
            var tokenHash = TokenHelper.HashToken(rawToken);

            _context.AuthTokens.Add(new AuthToken
            {
                UserId = user.Id,
                TokenHash = tokenHash,
                ExpiresAt = DateTime.UtcNow.AddDays(TokenExpiryDays),
                CreatedAt = DateTime.UtcNow
            });
            await _context.SaveChangesAsync();

            _logger.LogInformation("User logged in: {Email}", user.Email);
            return Ok(new
            {
                message = "Login bem-sucedido",
                token = rawToken,
                id = user.Id,
                name = user.Name,
                email = user.Email,
                phone = user.Phone,
                address = user.Address,
                isAdmin = user.IsAdmin,
                createdAt = user.CreatedAt
            });
        }
        catch (Exception ex)
        {
            _logger.LogError("Error logging in: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao fazer login" });
        }
    }

    /// <summary>
    /// Validate the bearer token and return the current user.
    /// </summary>
    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var rawToken = TokenHelper.ExtractBearerToken(Request);
        if (rawToken == null)
            return Unauthorized(new { message = "Token em falta" });

        var user = await ValidateTokenAsync(rawToken);
        if (user == null)
            return Unauthorized(new { message = "Token inválido ou expirado" });

        return Ok(new
        {
            id = user.Id,
            name = user.Name,
            email = user.Email,
            phone = user.Phone,
            address = user.Address,
            isAdmin = user.IsAdmin,
            createdAt = user.CreatedAt
        });
    }

    /// <summary>
    /// Invalidate the bearer token (logout).
    /// </summary>
    [HttpPost("logout")]
    public async Task<IActionResult> Logout()
    {
        var rawToken = TokenHelper.ExtractBearerToken(Request);
        if (rawToken != null)
        {
            var hash = TokenHelper.HashToken(rawToken);
            var tokenRow = await _context.AuthTokens.FirstOrDefaultAsync(t => t.TokenHash == hash);
            if (tokenRow != null)
            {
                _context.AuthTokens.Remove(tokenRow);
                await _context.SaveChangesAsync();
            }
        }
        return Ok(new { message = "Sessão terminada" });
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetUser(int id)
    {
        try
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null)
                return NotFound(new { message = "Utilizador não encontrado" });

            return Ok(new
            {
                id = user.Id,
                name = user.Name,
                email = user.Email,
                phone = user.Phone,
                address = user.Address,
                isAdmin = user.IsAdmin,
                createdAt = user.CreatedAt
            });
        }
        catch (Exception ex)
        {
            _logger.LogError("Error getting user: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao buscar utilizador" });
        }
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateProfile(int id, [FromBody] UpdateProfileRequest request)
    {
        try
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null)
                return NotFound(new { message = "Utilizador não encontrado" });

            if (!string.IsNullOrEmpty(request.Name)) user.Name = request.Name;
            if (!string.IsNullOrEmpty(request.Phone)) user.Phone = request.Phone;
            if (!string.IsNullOrEmpty(request.Address)) user.Address = request.Address;
            user.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            _logger.LogInformation("User profile updated: {Email}", user.Email);
            return Ok(new { message = "Perfil atualizado com sucesso" });
        }
        catch (Exception ex)
        {
            _logger.LogError("Error updating profile: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao atualizar perfil" });
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static string GenerateRawToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(32);
        return Convert.ToHexString(bytes).ToLower();
    }


    private async Task<User?> ValidateTokenAsync(string rawToken)
    {
        var hash = TokenHelper.HashToken(rawToken);
        var tokenRow = await _context.AuthTokens
            .Include(t => t.User)
            .FirstOrDefaultAsync(t => t.TokenHash == hash && t.ExpiresAt > DateTime.UtcNow);
        return tokenRow?.User;
    }
}

public class RegisterRequest
{
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class LoginRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class UpdateProfileRequest
{
    public string? Name { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
}
