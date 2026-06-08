using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Http;

namespace BookSwapAPI.Helpers;

public static class TokenHelper
{
    public static string HashToken(string rawToken)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(rawToken));
        return Convert.ToHexString(bytes).ToLower();
    }

    public static string? ExtractBearerToken(HttpRequest request)
    {
        if (!request.Headers.TryGetValue("Authorization", out var value))
            return null;
        var header = value.ToString();
        if (!header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            return null;
        return header["Bearer ".Length..].Trim();
    }
}
