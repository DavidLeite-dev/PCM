// ═══════════════════════════════════════════════════════════════════════════════
// FILE: Program.cs
// PURPOSE: ASP.NET Core 9 startup — registers all services and configures the
//          HTTP pipeline before the app starts listening.
//
// QUICK REFERENCE
//   DbContext registration    → EF Core + SQL Server (connection string from appsettings.json)
//   Custom services           → AppSettingService, ISBNLookupService, ConversationArchivalService
//   CORS policy               → "AllowMobileApp" — allows the Flutter app to call the API
//   restrictCors flag         → set true to lock to ngrokAllowedOrigin + localhost only
//   DbInitializer.SeedAsync() → creates the admin user if the DB is empty
//   app.Run("0.0.0.0:5003")   → binds to all network interfaces so the phone can reach it
// ═══════════════════════════════════════════════════════════════════════════════

using Microsoft.EntityFrameworkCore;
using BookSwapAPI.Data;
using BookSwapAPI.Services;

var builder = WebApplication.CreateBuilder(args);

// ─── Database ─────────────────────────────────────────────────────────────────
// EF Core with SQL Server. Connection string is in appsettings.json → "DefaultConnection".
builder.Services.AddDbContext<BookSwapDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// ─── Custom Services ──────────────────────────────────────────────────────────
// AppSettingService:          Singleton — reads/writes app settings stored in the DB.
// ISBNLookupService:          Scoped HTTP client — queries the OpenLibrary API for book metadata.
// ConversationArchivalService: Background service — auto-archives old inactive conversations.
builder.Services.AddSingleton<IAppSettingService, AppSettingService>();
builder.Services.AddHttpClient<IISBNLookupService, ISBNLookupService>();
builder.Services.AddHostedService<ConversationArchivalService>();

builder.Services.AddControllers();

// ─── CORS Configuration ───────────────────────────────────────────────────────
// The Flutter app (phone/emulator) and the ngrok tunnel need to be in the CORS
// allow-list, otherwise the browser/Flutter HTTP layer will block responses.
//
//   restrictCors = false (default) → allow any origin (easiest during demos)
//   restrictCors = true            → allow only ngrokAllowedOrigin + localhost
//
// If switching to true, update ngrokAllowedOrigin whenever the tunnel URL changes.
const bool restrictCors = false;
const string ngrokAllowedOrigin = "https://generic-purely-bankbook.ngrok-free.dev";

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowMobileApp",
        policy =>
        {
            if (restrictCors)
                // Strict: only allow the known ngrok URL and localhost
                policy.WithOrigins(ngrokAllowedOrigin, "http://localhost:5003",
                                   "http://127.0.0.1:5003")
                      .AllowAnyMethod()
                      .AllowAnyHeader();
            else
                // Open: allow any origin — simplifies development and demos
                policy.AllowAnyOrigin()
                      .AllowAnyMethod()
                      .AllowAnyHeader();
        });
});

// ─── Swagger (API Documentation UI) ──────────────────────────────────────────
// Available at /swagger in Development mode.
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// ─── App Settings Seed ────────────────────────────────────────────────────────
// Ensures default app settings (e.g. AllowDuplicateBooks) exist in the DB on
// first run, so controllers always have values to read.
using (var scope = app.Services.CreateScope())
{
    var settingService = scope.ServiceProvider.GetRequiredService<IAppSettingService>();
    await settingService.InitializeDefaultSettingsAsync();
}

// ─── Database Seed ────────────────────────────────────────────────────────────
// Creates the default admin user if the Users table is empty.
// Defined in Data/DbInitializer.cs.
using (var scope2 = app.Services.CreateScope())
{
    await BookSwapAPI.Data.DbInitializer.SeedAsync(scope2.ServiceProvider);
}

// ─── HTTP Middleware Pipeline ─────────────────────────────────────────────────
// Order matters: CORS must be registered before routing and controllers.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("AllowMobileApp"); // Must come BEFORE UseHttpsRedirection
// app.UseHttpsRedirection();  // Disabled — ngrok provides TLS termination externally

app.MapControllers();

// ─── Start Server ─────────────────────────────────────────────────────────────
// Binds to 0.0.0.0 (all interfaces) on port 5003 so the phone on the same
// network (or via ngrok tunnel) can reach the API.
app.Run("http://0.0.0.0:5003");
