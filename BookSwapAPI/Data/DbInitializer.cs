using BookSwapAPI.Models;

namespace BookSwapAPI.Data;

public static class DbInitializer
{
    public static async Task SeedAsync(IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<BookSwapDbContext>();

        // Ensure at least one admin user exists
        if (!context.Users.Any(u => u.IsAdmin))
        {
            context.Users.Add(new User
            {
                Name = "Admin",
                Email = "admin@bookswap.pt",
                Password = BCrypt.Net.BCrypt.HashPassword("admin123"),
                IsAdmin = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            });
            await context.SaveChangesAsync();
        }
    }
}
