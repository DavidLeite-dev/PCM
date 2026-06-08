namespace BookSwapAPI.Models;

/// <summary>
/// Application settings for admin configuration
/// </summary>
public class AppSetting
{
    public string SettingKey { get; set; } = string.Empty; // Primary Key
    public string SettingValue { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public DateTime LastModified { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Predefined setting keys
/// </summary>
public static class AppSettingKeys
{
    public const string AllowDuplicateBooks = "AllowDuplicateBooks";
    public const string ShowSingleBookCondition = "ShowSingleBookCondition";

    public static Dictionary<string, string> DefaultValues => new()
    {
        { AllowDuplicateBooks, "false" },
        { ShowSingleBookCondition, "true" }
    };
}
