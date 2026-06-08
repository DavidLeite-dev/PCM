using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BookSwapAPI.Data;
using BookSwapAPI.Models;

namespace BookSwapAPI.Controllers;

public class UpdateUserRequest
{
    public string? Name { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
}



[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly BookSwapDbContext _context;
    private readonly ILogger<UsersController> _logger;

    public UsersController(BookSwapDbContext context, ILogger<UsersController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Get all users
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAllUsers()
    {
        try
        {
            var users = await _context.Users
                .Select(u => new
                {
                    u.Id,
                    u.Name,
                    u.Email,
                    u.Phone,
                    u.Address,
                    u.IsAdmin,
                    u.CreatedAt
                })
                .ToListAsync();

            return Ok(new { success = true, users });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error getting users: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao carregar utilizadores" });
        }
    }

    /// <summary>
    /// Get user by ID
    /// </summary>
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
                success = true,
                user = new
                {
                    user.Id,
                    user.Name,
                    user.Email,
                    user.Phone,
                    user.Address,
                    user.IsAdmin,
                    user.CreatedAt
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error getting user: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao carregar utilizador" });
        }
    }

    /// <summary>
    /// Update user profile
    /// </summary>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateUser(int id, [FromBody] UpdateUserRequest request)
    {
        try
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null)
                return NotFound(new { message = "Utilizador não encontrado" });

            if (!string.IsNullOrEmpty(request.Name))
                user.Name = request.Name;

            if (!string.IsNullOrEmpty(request.Phone))
                user.Phone = request.Phone;

            if (!string.IsNullOrEmpty(request.Address))
                user.Address = request.Address;

            await _context.SaveChangesAsync();

            _logger.LogInformation($"User updated: {user.Email}");
            return Ok(new { message = "Utilizador atualizado com sucesso", user });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error updating user: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao atualizar utilizador" });
        }
    }

    /// <summary>
    /// Delete user
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteUser(int id)
    {
        try
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null)
                return NotFound(new { message = "Utilizador não encontrado" });

            _context.Users.Remove(user);
            await _context.SaveChangesAsync();

            _logger.LogInformation($"User deleted: {user.Email}");
            return Ok(new { message = "Utilizador eliminado com sucesso" });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error deleting user: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao eliminar utilizador" });
        }
    }

    /// <summary>
    /// Toggle admin status for a user
    /// </summary>
    [HttpPut("{id}/admin")]
    public async Task<IActionResult> ToggleAdminStatus(int id)
    {
        try
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null)
                return NotFound(new { message = "Utilizador não encontrado" });

            user.IsAdmin = !user.IsAdmin;
            await _context.SaveChangesAsync();

            _logger.LogInformation($"Admin status toggled for user: {user.Email}");
            return Ok(new { message = "Status de admin atualizado", isAdmin = user.IsAdmin });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error toggling admin status: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao atualizar status de admin" });
        }
    }
}
