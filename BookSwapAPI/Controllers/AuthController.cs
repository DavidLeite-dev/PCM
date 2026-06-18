// ═══════════════════════════════════════════════════════════════════════════════
// FILE: Controllers/AuthController.cs
// PURPOSE: Authentication REST endpoints — register, login, logout, /me, profile.
//
// QUICK REFERENCE  (all routes prefixed with /api/auth)
//   POST   /register    → create new user (BCrypt password hash)
//   POST   /login       → verify credentials → issue raw token (stored as SHA-256 hash)
//   GET    /me          → validate bearer token → return current user
//   POST   /logout      → delete token row from DB
//   GET    /{id}        → get any user by numeric ID
//   PUT    /{id}        → update name / phone / address
//
// TOKEN DESIGN
//   Raw token = 32 random bytes encoded as hex (64 char string)
//   Stored in DB: SHA-256 hash of the raw token (TokenHelper.HashToken)
//   Sent by client: raw token in Authorization: Bearer header
//   Expiry: 30 days from login
//
// REQUEST/RESPONSE MODELS (at bottom of file)
//   RegisterRequest, LoginRequest, UpdateProfileRequest
// ═══════════════════════════════════════════════════════════════════════════════

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

    private const int TokenExpiryDays = 30; // Sessions last 30 days

    public AuthController(BookSwapDbContext context, ILogger<AuthController> logger)
    {
        _context = context;
        _logger  = logger;
    }

    // ─── POST /api/auth/register ──────────────────────────────────────────────
    // Creates a new user account.
    // Password is hashed with BCrypt before storage — never stored in plain text.
    // Returns 400 if the email is already registered.
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        try
        {
            // Block duplicate emails
            var existingUser = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (existingUser != null)
                return BadRequest(new { message = "Email já está registado" });

            var user = new User
            {
                Name      = request.Name,
                Email     = request.Email,
                Password  = BCrypt.Net.BCrypt.HashPassword(request.Password), // Hash before storing
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

    // ─── POST /api/auth/login ─────────────────────────────────────────────────
    // Verifies credentials with BCrypt, then generates a random session token.
    // The raw token is returned to the client; only the SHA-256 hash is stored in DB.
    // Response includes the full user object so the Flutter app can hydrate AuthProvider.
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        try
        {
            // Diagnostic: log which database is in use (helpful during demos)
            try
            {
                var conn = _context.Database.GetDbConnection();
                _logger.LogInformation("Database connection: Database={Database}, DataSource={DataSource}", conn.Database, conn.DataSource);
            }
            catch { /* Swallow — avoid leaking connection details */ }

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (user == null)
                return Unauthorized(new { message = "Email ou senha incorretos" });

            try
            {
                // BCrypt verify: compares the raw password against the stored hash
                if (!BCrypt.Net.BCrypt.Verify(request.Password, user.Password))
                    return Unauthorized(new { message = "Email ou senha incorretos" });
            }
            catch (Exception ex)
            {
                var hashPreview = user.Password != null && user.Password.Length >= 8 ? user.Password.Substring(0, 8) : user.Password;
                _logger.LogError(ex, "BCrypt.Verify failed for {Email}; hashPreview={HashPreview}; hashLen={Len}; fullHash={Full}", user.Email, hashPreview, user.Password?.Length ?? 0, user.Password);
                return StatusCode(500, new { message = "Erro ao fazer login", detail = "BCrypt verify error" });
            }

            // ── Generate & Store Token ────────────────────────────────────────
            var rawToken   = GenerateRawToken();           // 32 random bytes → hex string
            var tokenHash  = TokenHelper.HashToken(rawToken); // SHA-256 hash for DB storage

            _context.AuthTokens.Add(new AuthToken
            {
                UserId    = user.Id,
                TokenHash = tokenHash,                               // Only hash goes into DB
                ExpiresAt = DateTime.UtcNow.AddDays(TokenExpiryDays),
                CreatedAt = DateTime.UtcNow
            });
            await _context.SaveChangesAsync();

            _logger.LogInformation("User logged in: {Email}", user.Email);

            // Return the RAW token to the client (hashed version stays in DB only)
            return Ok(new
            {
                message   = "Login bem-sucedido",
                token     = rawToken,  // Stored locally by Flutter's TokenStorageService
                id        = user.Id,
                name      = user.Name,
                email     = user.Email,
                phone     = user.Phone,
                address   = user.Address,
                isAdmin   = user.IsAdmin,
                createdAt = user.CreatedAt
            });
        }
        catch (Exception ex)
        {
            _logger.LogError("Error logging in: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao fazer login" });
        }
    }

    // ─── GET /api/auth/me ─────────────────────────────────────────────────────
    // Validates the bearer token and returns the current user.
    // Called by AuthService.init() on app startup to restore a saved session.
    // Returns 401 if the token is missing, expired, or not found in DB.
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
            id        = user.Id,
            name      = user.Name,
            email     = user.Email,
            phone     = user.Phone,
            address   = user.Address,
            isAdmin   = user.IsAdmin,
            createdAt = user.CreatedAt
        });
    }

    // ─── POST /api/auth/logout ────────────────────────────────────────────────
    // Deletes the token row from the AuthTokens table, invalidating the session.
    // The Flutter client also clears its local storage regardless of this response.
    [HttpPost("logout")]
    public async Task<IActionResult> Logout()
    {
        var rawToken = TokenHelper.ExtractBearerToken(Request);
        if (rawToken != null)
        {
            var hash     = TokenHelper.HashToken(rawToken);
            var tokenRow = await _context.AuthTokens.FirstOrDefaultAsync(t => t.TokenHash == hash);
            if (tokenRow != null)
            {
                _context.AuthTokens.Remove(tokenRow);
                await _context.SaveChangesAsync();
            }
        }
        return Ok(new { message = "Sessão terminada" });
    }

    // ─── GET /api/auth/{id} ───────────────────────────────────────────────────
    // Returns a user's public profile by numeric ID.
    // Used by other services when they need to display a user's name/email.
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
                id        = user.Id,
                name      = user.Name,
                email     = user.Email,
                phone     = user.Phone,
                address   = user.Address,
                isAdmin   = user.IsAdmin,
                createdAt = user.CreatedAt
            });
        }
        catch (Exception ex)
        {
            _logger.LogError("Error getting user: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao buscar utilizador" });
        }
    }

    // ─── PUT /api/auth/{id} ───────────────────────────────────────────────────
    // Updates the user's profile. Only updates fields that are non-empty in the request.
    // Called by AuthService.updateUserProfile() when the user edits their profile.
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateProfile(int id, [FromBody] UpdateProfileRequest request)
    {
        try
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null)
                return NotFound(new { message = "Utilizador não encontrado" });

            // Only update fields that were explicitly provided
            if (!string.IsNullOrEmpty(request.Name))    user.Name    = request.Name;
            if (!string.IsNullOrEmpty(request.Phone))   user.Phone   = request.Phone;
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

    // ─── Private Helpers ──────────────────────────────────────────────────────

    // Generates a cryptographically random 64-character hex token (32 bytes).
    private static string GenerateRawToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(32);
        return Convert.ToHexString(bytes).ToLower();
    }

    // Looks up the hashed token in the DB; returns the linked User if found and not expired.
    private async Task<User?> ValidateTokenAsync(string rawToken)
    {
        var hash = TokenHelper.HashToken(rawToken);
        var tokenRow = await _context.AuthTokens
            .Include(t => t.User) // Eager-load the User so we don't need a second query
            .FirstOrDefaultAsync(t => t.TokenHash == hash && t.ExpiresAt > DateTime.UtcNow);
        return tokenRow?.User;
    }
}

// ─── Request Models ───────────────────────────────────────────────────────────
// These are deserialised from the JSON body of the corresponding HTTP requests.

public class RegisterRequest
{
    public string Name     { get; set; } = string.Empty;
    public string Email    { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class LoginRequest
{
    public string Email    { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class UpdateProfileRequest
{
    public string? Name    { get; set; } // Nullable — only update if provided
    public string? Phone   { get; set; }
    public string? Address { get; set; }
}
