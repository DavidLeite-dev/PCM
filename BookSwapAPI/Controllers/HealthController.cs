using Microsoft.AspNetCore.Mvc;
using BookSwapAPI.Data;

namespace BookSwapAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HealthController : ControllerBase
{
    private readonly BookSwapDbContext _context;
    private readonly ILogger<HealthController> _logger;

    public HealthController(BookSwapDbContext context, ILogger<HealthController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Health check endpoint that verifies both API and Database connectivity
    /// </summary>
    [HttpGet("check")]
    public async Task<IActionResult> HealthCheck()
    {
        var result = new HealthCheckResponse
        {
            Status = "Healthy",
            Timestamp = DateTime.UtcNow,
            ApiStatus = "OK",
            DatabaseStatus = "OK",
            Errors = new List<string>()
        };

        try
        {
            // Test database connectivity
            _logger.LogInformation("Performing health check...");
            
            var canConnect = await _context.Database.CanConnectAsync();
            if (!canConnect)
            {
                result.DatabaseStatus = "FAILED";
                result.Errors.Add("Cannot connect to database");
                result.Status = "Unhealthy";
                _logger.LogWarning("Database connectivity check failed");
            }

            // Try a simple query to ensure database is responsive
            if (canConnect)
            {
                try
                {
                    // Simple query to verify database is responding
                    var userCount = _context.Users.Count();
                    _logger.LogInformation($"Database query successful. User count: {userCount}");
                }
                catch (Exception ex)
                {
                    result.DatabaseStatus = "ERROR";
                    result.Errors.Add($"Database query error: {ex.Message}");
                    result.Status = "Unhealthy";
                    _logger.LogWarning($"Database query failed: {ex.Message}");
                }
            }

            if (result.Status == "Healthy")
            {
                _logger.LogInformation("Health check passed");
                return Ok(result);
            }
            else
            {
                _logger.LogWarning($"Health check failed: {string.Join(", ", result.Errors)}");
                return StatusCode(503, result);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError($"Unexpected error in health check: {ex.Message}");
            result.Status = "Error";
            result.Errors.Add($"Unexpected error: {ex.Message}");
            return StatusCode(500, result);
        }
    }

    /// <summary>
    /// Simple ping endpoint to check if API is responsive
    /// </summary>
    [HttpGet("ping")]
    public IActionResult Ping()
    {
        return Ok(new { status = "pong", timestamp = DateTime.UtcNow });
    }
}

public class HealthCheckResponse
{
    public string Status { get; set; } = "Healthy";
    public DateTime Timestamp { get; set; }
    public string ApiStatus { get; set; } = "OK";
    public string DatabaseStatus { get; set; } = "OK";
    public List<string> Errors { get; set; } = new();
}
