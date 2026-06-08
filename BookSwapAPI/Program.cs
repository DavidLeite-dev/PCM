using Microsoft.EntityFrameworkCore;
using BookSwapAPI.Data;
using BookSwapAPI.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddDbContext<BookSwapDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Add custom services
builder.Services.AddSingleton<IAppSettingService, AppSettingService>();
builder.Services.AddHttpClient<IISBNLookupService, ISBNLookupService>();
builder.Services.AddHostedService<ConversationArchivalService>();

// Add controllers
builder.Services.AddControllers();

// ─── CORS CONFIGURATION ────────────────────────────────────────────────────
// Set restrictCors = true to allow only the known ngrok URL and localhost.
// Set restrictCors = false (default) to allow any origin — useful during
// development when the client IP changes frequently.
//
// If restrictCors = true, update ngrokAllowedOrigin below whenever the
// ngrok tunnel URL changes (see README.md → "CORS Configuration" section).
// ───────────────────────────────────────────────────────────────────────────
const bool restrictCors = false;
const string ngrokAllowedOrigin = "https://generic-purely-bankbook.ngrok-free.dev";

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowMobileApp",
        policy =>
        {
            if (restrictCors)
                policy.WithOrigins(ngrokAllowedOrigin, "http://localhost:5003",
                                   "http://127.0.0.1:5003")
                      .AllowAnyMethod()
                      .AllowAnyHeader();
            else
                policy.AllowAnyOrigin()
                      .AllowAnyMethod()
                      .AllowAnyHeader();
        });
});

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Initialize settings
using (var scope = app.Services.CreateScope())
{
    var settingService = scope.ServiceProvider.GetRequiredService<IAppSettingService>();
    await settingService.InitializeDefaultSettingsAsync();
}

// Seed DB (ensure at least one admin user exists)
using (var scope2 = app.Services.CreateScope())
{
    await BookSwapAPI.Data.DbInitializer.SeedAsync(scope2.ServiceProvider);
}

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// CORS must come BEFORE UseHttpsRedirection
app.UseCors("AllowMobileApp");
//app.UseHttpsRedirection();
app.MapControllers();

app.Run("http://0.0.0.0:5003");
