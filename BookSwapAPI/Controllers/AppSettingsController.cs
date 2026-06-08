using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BookSwapAPI.Data;
using BookSwapAPI.Models;
using BookSwapAPI.Services;

namespace BookSwapAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AppSettingsController : ControllerBase
{
    private readonly IAppSettingService _settingService;
    private readonly BookSwapDbContext _context;
    private readonly ILogger<AppSettingsController> _logger;

    public AppSettingsController(
        IAppSettingService settingService,
        BookSwapDbContext context,
        ILogger<AppSettingsController> logger)
    {
        _settingService = settingService;
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Get all application settings
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAllSettings()
    {
        try
        {
            var settings = await _context.AppSettings.ToListAsync();

            return Ok(new
            {
                success = true,
                settings = settings.Select(s => new
                {
                    key = s.SettingKey,
                    value = s.SettingValue,
                    description = s.Description,
                    lastModified = s.LastModified
                })
            });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error getting all settings: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao carregar configurações" });
        }
    }

    /// <summary>
    /// Get a specific setting by key
    /// </summary>
    [HttpGet("{key}")]
    public async Task<IActionResult> GetSetting(string key)
    {
        try
        {
            var value = await _settingService.GetSettingAsync(key);

            return Ok(new
            {
                success = true,
                key,
                value
            });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error getting setting {key}: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao carregar configuração" });
        }
    }

    /// <summary>
    /// Update a setting value
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> UpdateSetting([FromBody] UpdateSettingRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Key) || request.Value == null)
        {
            return BadRequest(new { message = "Key e Value são obrigatórios" });
        }

        try
        {
            await _settingService.SetSettingAsync(request.Key, request.Value);

            _logger.LogInformation($"Setting updated: {request.Key} = {request.Value}");
            return Ok(new
            {
                success = true,
                message = "Configuração atualizada com sucesso",
                key = request.Key,
                value = request.Value
            });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error updating setting {request.Key}: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao atualizar configuração" });
        }
    }

    /// <summary>
    /// Toggle a boolean setting
    /// </summary>
    [HttpPut("{key}/toggle")]
    public async Task<IActionResult> ToggleSetting(string key)
    {
        try
        {
            var currentValue = await _settingService.GetBoolSettingAsync(key);
            var newValue = (!currentValue).ToString();

            await _settingService.SetSettingAsync(key, newValue);

            _logger.LogInformation($"Setting toggled: {key} = {newValue}");
            return Ok(new
            {
                success = true,
                message = "Configuração alternada com sucesso",
                key,
                value = newValue,
                boolValue = !currentValue
            });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error toggling setting {key}: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao alternar configuração" });
        }
    }
}

public class UpdateSettingRequest
{
    public string Key { get; set; } = string.Empty;
    public string Value { get; set; } = string.Empty;
}
