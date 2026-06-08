using BookSwapAPI.Data;
using BookSwapAPI.Models;
using Microsoft.EntityFrameworkCore;

namespace BookSwapAPI.Services;

/// <summary>
/// Service for managing application settings
/// </summary>
public interface IAppSettingService
{
    Task<string?> GetSettingAsync(string key);
    Task<bool> GetBoolSettingAsync(string key);
    Task SetSettingAsync(string key, string value);
    Task InitializeDefaultSettingsAsync();
}

public class AppSettingService : IAppSettingService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<AppSettingService> _logger;
    private readonly Dictionary<string, string> _cache = new();

    public AppSettingService(IServiceScopeFactory scopeFactory, ILogger<AppSettingService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    public async Task<string?> GetSettingAsync(string key)
    {
        if (_cache.TryGetValue(key, out var cachedValue))
            return cachedValue;

        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<BookSwapDbContext>();
        var setting = await db.AppSettings.FirstOrDefaultAsync(s => s.SettingKey == key);

        if (setting != null)
        {
            _cache[key] = setting.SettingValue;
            return setting.SettingValue;
        }

        return null;
    }

    public async Task<bool> GetBoolSettingAsync(string key)
    {
        var value = await GetSettingAsync(key);
        if (string.IsNullOrEmpty(value))
            return false;

        return bool.TryParse(value, out var result) && result;
    }

    public async Task SetSettingAsync(string key, string value)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<BookSwapDbContext>();

        var setting = await db.AppSettings.FirstOrDefaultAsync(s => s.SettingKey == key);

        if (setting != null)
        {
            setting.SettingValue = value;
            setting.LastModified = DateTime.UtcNow;
        }
        else
        {
            setting = new AppSetting
            {
                SettingKey = key,
                SettingValue = value,
                LastModified = DateTime.UtcNow
            };
            await db.AppSettings.AddAsync(setting);
        }

        await db.SaveChangesAsync();
        _cache[key] = value;
        _logger.LogInformation($"Setting updated: {key} = {value}");
    }

    public async Task InitializeDefaultSettingsAsync()
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<BookSwapDbContext>();

        foreach (var (key, value) in AppSettingKeys.DefaultValues)
        {
            var existing = await db.AppSettings.FirstOrDefaultAsync(s => s.SettingKey == key);

            if (existing == null)
            {
                await db.AppSettings.AddAsync(new AppSetting
                {
                    SettingKey = key,
                    SettingValue = value,
                    Description = $"Default setting: {key}"
                });

                _logger.LogInformation($"Initialized default setting: {key} = {value}");
            }
        }

        await db.SaveChangesAsync();
    }
}
