using BookSwapAPI.Data;
using BookSwapAPI.Models;
using Microsoft.EntityFrameworkCore;

namespace BookSwapAPI.Services;

/// <summary>
/// Background service that runs daily and archives conversations that are:
/// 1. Inactive for more than 7 days (no new messages)
/// 2. Linked to a transaction that is Confirmada or Cancelada
/// Conversations are archived (Status="Archived"), never deleted.
/// </summary>
public class ConversationArchivalService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<ConversationArchivalService> _logger;

    // Run every 24 hours
    private static readonly TimeSpan CheckInterval = TimeSpan.FromHours(24);

    public ConversationArchivalService(
        IServiceScopeFactory scopeFactory,
        ILogger<ConversationArchivalService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("ConversationArchivalService started.");

        // Run once on startup, then every 24 hours
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ArchiveConversationsAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during conversation archival.");
            }

            await Task.Delay(CheckInterval, stoppingToken);
        }
    }

    private async Task ArchiveConversationsAsync(CancellationToken cancellationToken)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<BookSwapDbContext>();

        var cutoffDate = DateTime.UtcNow.AddDays(-7);
        var now = DateTime.UtcNow;

        // Find all active conversations eligible for archival
        var toArchive = await context.Conversations
            .Include(c => c.Transaction)
            .Where(c => c.Status == "Active" && (
                // Rule 1: No activity for 7+ days
                c.LastMessageAt < cutoffDate ||
                // Rule 2: Linked transaction is completed or cancelled
                (c.TransactionId != null &&
                 c.Transaction != null &&
                 (c.Transaction.Status == "Confirmada" || c.Transaction.Status == "Cancelada"))
            ))
            .ToListAsync(cancellationToken);

        if (toArchive.Count == 0)
        {
            _logger.LogInformation("ConversationArchivalService: No conversations to archive.");
            return;
        }

        foreach (var conversation in toArchive)
        {
            conversation.Status = "Archived";
            conversation.ArchivedAt = now;
        }

        await context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "ConversationArchivalService: Archived {Count} conversation(s).",
            toArchive.Count);
    }
}
