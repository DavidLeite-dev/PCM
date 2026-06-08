using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BookSwapAPI.Data;
using BookSwapAPI.Helpers;
using BookSwapAPI.Models;

namespace BookSwapAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AdminController : ControllerBase
{
    private readonly BookSwapDbContext _context;
    private readonly ILogger<AdminController> _logger;

    public AdminController(BookSwapDbContext context, ILogger<AdminController> logger)
    {
        _context = context;
        _logger = logger;
    }

    private async Task<IActionResult?> RequireAdmin()
    {
        var rawToken = TokenHelper.ExtractBearerToken(Request);
        if (rawToken == null)
            return StatusCode(401, new { message = "Token de autenticação em falta" });

        var hash = TokenHelper.HashToken(rawToken);
        var tokenRow = await _context.AuthTokens
            .Include(t => t.User)
            .FirstOrDefaultAsync(t => t.TokenHash == hash && t.ExpiresAt > DateTime.UtcNow);

        if (tokenRow?.User == null)
            return StatusCode(401, new { message = "Token inválido ou expirado" });

        if (!tokenRow.User.IsAdmin)
            return StatusCode(403, new { message = "Acesso negado: utilizador não é administrador" });

        return null;
    }

    /// <summary>
    /// Get system statistics with computed indicators for the dashboard.
    /// </summary>
    [HttpGet("statistics")]
    public async Task<IActionResult> GetStatistics()
    {
        var authError = await RequireAdmin();
        if (authError != null) return authError;

        try
        {
            // ── Basic counts ───────────────────────────────────────
            var totalUsers        = await _context.Users.CountAsync();
            var totalBooks        = await _context.Books.CountAsync();
            var totalUserBooks    = await _context.UserBooks.CountAsync();
            var totalTransactions = await _context.Transactions.CountAsync();

            // ── Transactions by type ───────────────────────────────
            var byType = await _context.Transactions
                .GroupBy(t => t.Type)
                .Select(g => new { type = g.Key, count = g.Count() })
                .ToListAsync();

            // ── Transactions by status ─────────────────────────────
            var byStatus = await _context.Transactions
                .GroupBy(t => t.Status)
                .Select(g => new { status = g.Key, count = g.Count() })
                .ToListAsync();

            // ── Completion rate ─────────────────────────────────────
            var confirmed      = byStatus.FirstOrDefault(s => s.status == "Confirmada")?.count ?? 0;
            var completionRate = totalTransactions > 0
                ? Math.Round((double)confirmed / totalTransactions * 100, 1)
                : 0.0;

            // ── Monthly activity (last 6 months) ────────────────────
            var since = DateTime.UtcNow.AddMonths(-5);
            // Project to integer fields first so EF Core can translate the GroupBy to SQL
            var monthlyRaw = await _context.Transactions
                .Where(t => t.CreatedAt >= since)
                .Select(t => new { t.CreatedAt.Year, t.CreatedAt.Month })
                .ToListAsync();

            var monthlyActivity = monthlyRaw
                .GroupBy(t => new { t.Year, t.Month })
                .OrderBy(g => g.Key.Year).ThenBy(g => g.Key.Month)
                .Select(g => new
                {
                    year  = g.Key.Year,
                    month = g.Key.Month,
                    label = new DateTime(g.Key.Year, g.Key.Month, 1).ToString("MMM yy"),
                    count = g.Count()
                })
                .ToList();

            // ── Average resolution time (Pendente → Confirmada/Rejeitada) ──
            var resolvedTransactions = await _context.Transactions
                .Where(t => t.Status == "Confirmada" || t.Status == "Rejeitada" || t.Status == "Cancelada")
                .ToListAsync();

            double avgResolutionDays = 0;
            if (resolvedTransactions.Count > 0)
            {
                avgResolutionDays = Math.Round(
                    resolvedTransactions.Average(t => (t.UpdatedAt - t.CreatedAt).TotalDays),
                    1);
            }

            // ── Books by category (genre) ───────────────────────────
            var booksByCategory = await _context.Books
                .Where(b => !string.IsNullOrEmpty(b.Genre))
                .GroupBy(b => b.Genre)
                .Select(g => new { category = g.Key, count = g.Count() })
                .OrderByDescending(g => g.count)
                .Take(10)
                .ToListAsync();

            // ── Books added today ───────────────────────────────────
            var todayStart    = DateTime.UtcNow.Date;
            var booksAddedToday = await _context.UserBooks
                .CountAsync(ub => ub.DateAdded >= todayStart);

            // ── Active users (at least one UserBook) ────────────────
            var activeUsers = await _context.UserBooks
                .Select(ub => ub.UserId)
                .Distinct()
                .CountAsync();

            // ── Average books per active user ────────────────────────
            var avgBooksPerUser = activeUsers > 0
                ? Math.Round((double)totalUserBooks / activeUsers, 1)
                : 0.0;

            return Ok(new
            {
                success = true,
                statistics = new
                {
                    totalUsers,
                    totalBooks,
                    totalUserBooks,
                    totalTransactions,
                    activeUsers,
                    avgBooksPerUser,
                    booksAddedToday,
                    completionRate,
                    avgResolutionDays,
                    byType,
                    byStatus,
                    monthlyActivity,
                    booksByCategory,
                    timestamp = DateTime.UtcNow
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error getting statistics: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao carregar estatísticas" });
        }
    }

    /// <summary>
    /// Get all users (admin view)
    /// </summary>
    [HttpGet("users")]
    public async Task<IActionResult> GetAllUsers()
    {
        var authError = await RequireAdmin();
        if (authError != null) return authError;

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
    /// Get all books (admin view)
    /// </summary>
    [HttpGet("books")]
    public async Task<IActionResult> GetAllBooks()
    {
        var authError = await RequireAdmin();
        if (authError != null) return authError;

        try
        {
            var books = await _context.Books
                .Select(b => new
                {
                    b.ISBN,
                    b.Title,
                    b.Authors,
                    b.Genre,
                    b.Tags,
                    b.Publisher,
                    b.PublicationYear,
                    b.CoverImageUrl
                })
                .ToListAsync();

            return Ok(new { success = true, books });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error getting books: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao carregar livros" });
        }
    }

    /// <summary>
    /// Get system transactions (admin) with optional status filter (pending/completed/all)
    /// </summary>
    [HttpGet("transactions")]
    public async Task<IActionResult> GetSystemTransactions([FromQuery] string status = "all")
    {
        var authError = await RequireAdmin();
        if (authError != null) return authError;

        try
        {
            var query = _context.Transactions
                .Include(t => t.Sender)
                .Include(t => t.Receiver)
                .Include(t => t.UserBook).ThenInclude(ub => ub!.Book)
                .Include(t => t.SenderUserBook).ThenInclude(ub => ub!.Book)
                .AsQueryable();

            if (status == "pending")
                query = query.Where(t => t.Status == "Pendente");
            else if (status == "completed")
                query = query.Where(t => t.Status == "Confirmada" || t.Status == "Rejeitada" || t.Status == "Cancelada");

            var list = await query.OrderByDescending(t => t.CreatedAt).ToListAsync();

            var dtos = list.Select(t => new
            {
                id         = t.Id,
                type       = t.Type,
                status     = t.Status,
                notes      = t.Notes,
                price      = t.Price,
                createdAt  = t.CreatedAt,
                updatedAt  = t.UpdatedAt,
                sender     = t.Sender   == null ? null : new { name = t.Sender.Name,   email = t.Sender.Email },
                receiver   = t.Receiver == null ? null : new { name = t.Receiver.Name, email = t.Receiver.Email },
                bookTitle  = t.UserBook?.Book?.Title,
                bookISBN   = t.UserBook?.Book?.ISBN,
                bookAuthor = t.UserBook?.Book?.Authors,
                tradeBookTitle  = t.SenderUserBook?.Book?.Title,
                tradeBookISBN   = t.SenderUserBook?.Book?.ISBN,
            }).ToList();

            return Ok(new { success = true, transactions = dtos });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error getting transactions: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao carregar transações" });
        }
    }

    /// <summary>
    /// Admin action on a pending transaction: accept, deny, or cancel (admin may act on any transaction)
    /// </summary>
    [HttpPost("transactions/{id}/action")]
    public async Task<IActionResult> AdminTransactionAction(int id, [FromBody] AdminTransactionActionRequest request)
    {
        var authError = await RequireAdmin();
        if (authError != null) return authError;

        try
        {
            var transaction = await _context.Transactions
                .Include(t => t.Sender)
                .Include(t => t.Receiver)
                .FirstOrDefaultAsync(t => t.Id == id);

            if (transaction == null)
                return NotFound(new { message = "Transação não encontrada" });

            if (transaction.Status != "Pendente")
                return BadRequest(new { message = "Apenas transações pendentes podem ser processadas" });

            var action = request.Action?.ToLowerInvariant();
            if (action == "accept")
            {
                // Reuse the same acceptance logic as TransactionsController but allow admin override
                // Resolve the main UserBook (inventory) referenced by the transaction and the Book record
                UserBook? referencedUserBook = null;
                if (transaction.UserBookId.HasValue)
                    referencedUserBook = await _context.UserBooks.FirstOrDefaultAsync(ub => ub.Id == transaction.UserBookId.Value);

                Book? book = null;
                if (referencedUserBook != null)
                    book = await _context.Books.FirstOrDefaultAsync(b => b.ISBN == referencedUserBook.ISBN);

                // If we couldn't resolve via UserBookId, try to find a book by searching seller listings (fallback)
                if (book == null)
                {
                    // attempt to find any book referenced by the receiver's listings
                    var fallbackUserBook = await _context.UserBooks.FirstOrDefaultAsync(ub => ub.UserId == transaction.ReceiverId);
                    if (fallbackUserBook != null)
                        book = await _context.Books.FirstOrDefaultAsync(b => b.ISBN == fallbackUserBook.ISBN);
                }

                if (book == null)
                {
                    return BadRequest(new { message = "Livro não encontrado" });
                }

                if (transaction.Type == "Compra")
                {
                    var sellerBook = referencedUserBook ?? await _context.UserBooks
                        .FirstOrDefaultAsync(ub => ub.UserId == transaction.ReceiverId && ub.ISBN == book.ISBN);

                    if (sellerBook == null)
                        return BadRequest(new { message = "Livro não encontrado no vendedor" });

                    if (sellerBook.Quantity > 1)
                        sellerBook.Quantity--;
                    else
                        sellerBook.IsActive = false;

                    var buyerBook = await _context.UserBooks
                        .FirstOrDefaultAsync(ub => ub.UserId == transaction.SenderId && ub.ISBN == book.ISBN && ub.Condition == sellerBook.Condition);

                    if (buyerBook != null)
                    {
                        buyerBook.Quantity++;
                        buyerBook.IsActive = true;
                    }
                    else
                    {
                        _context.UserBooks.Add(new UserBook
                        {
                            UserId = transaction.SenderId,
                            ISBN = book.ISBN,
                            Condition = sellerBook.Condition,
                            Quantity = 1,
                            DateAdded = DateTime.UtcNow,
                            Available = true,
                            IsActive = true
                        });
                    }

                    transaction.Status = "Confirmada";
                    if (transaction.UserBookId.HasValue)
                        await CancelOtherPendingForUserBook(transaction.UserBookId.Value, id);
                }
                else if (transaction.Type == "Requisição")
                {
                    var ownerBook = referencedUserBook ?? await _context.UserBooks
                        .FirstOrDefaultAsync(ub => ub.UserId == transaction.ReceiverId && ub.ISBN == book.ISBN);

                    if (ownerBook != null)
                    {
                        ownerBook.Emprestado = true;
                        transaction.Status = "Aceita";
                        if (transaction.UserBookId.HasValue)
                            await CancelOtherPendingForUserBook(transaction.UserBookId.Value, id);
                    }
                    else
                    {
                        return BadRequest(new { message = "Livro não encontrado no proprietário" });
                    }
                }
                else if (transaction.Type == "Troca")
                {
                    // Resolve sender's offered book and receiver's requested book via UserBook references
                    UserBook? senderOffered = null;
                    if (transaction.SenderUserBookId.HasValue)
                        senderOffered = await _context.UserBooks.FirstOrDefaultAsync(ub => ub.Id == transaction.SenderUserBookId.Value);

                    UserBook? receiverRequested = referencedUserBook ?? (transaction.UserBookId.HasValue ? await _context.UserBooks.FirstOrDefaultAsync(ub => ub.Id == transaction.UserBookId.Value) : null);

                    if (senderOffered == null || receiverRequested == null)
                        return BadRequest(new { message = "Informação dos livros para troca incompleta" });

                    var senderUserBooks = await _context.UserBooks
                        .Where(ub => ub.UserId == transaction.SenderId && ub.ISBN == senderOffered.ISBN && ub.IsActive)
                        .ToListAsync();

                    var receiverUserBooks = await _context.UserBooks
                        .Where(ub => ub.UserId == transaction.ReceiverId && ub.ISBN == receiverRequested.ISBN && ub.IsActive)
                        .ToListAsync();

                    if (senderUserBooks.Count == 0 || receiverUserBooks.Count == 0)
                        return BadRequest(new { message = "Utilizadores não possuem os livros necessários para troca" });

                    var senderBook = senderUserBooks.FirstOrDefault(ub => ub.Available) ?? senderUserBooks.First();
                    var receiverBook = receiverUserBooks.FirstOrDefault(ub => ub.Available) ?? receiverUserBooks.First();

                    if (senderBook.Quantity > 1) senderBook.Quantity--; else senderBook.IsActive = false;
                    if (receiverBook.Quantity > 1) receiverBook.Quantity--; else receiverBook.IsActive = false;

                    var senderGetsBook = await _context.UserBooks
                        .FirstOrDefaultAsync(ub => ub.UserId == transaction.SenderId && ub.ISBN == receiverRequested.ISBN && ub.Condition == receiverBook.Condition);

                    if (senderGetsBook == null)
                    {
                        _context.UserBooks.Add(new UserBook
                        {
                            UserId = transaction.SenderId,
                            ISBN = receiverRequested.ISBN,
                            Condition = receiverBook.Condition,
                            Quantity = 1,
                            DateAdded = DateTime.UtcNow,
                            Available = true,
                            IsActive = true
                        });
                    }
                    else
                    {
                        senderGetsBook.Quantity++;
                        senderGetsBook.IsActive = true;
                    }

                    var receiverGetsBook = await _context.UserBooks
                        .FirstOrDefaultAsync(ub => ub.UserId == transaction.ReceiverId && ub.ISBN == senderOffered.ISBN && ub.Condition == senderBook.Condition);

                    if (receiverGetsBook == null)
                    {
                        _context.UserBooks.Add(new UserBook
                        {
                            UserId = transaction.ReceiverId,
                            ISBN = senderOffered.ISBN,
                            Condition = senderBook.Condition,
                            Quantity = 1,
                            DateAdded = DateTime.UtcNow,
                            Available = true,
                            IsActive = true
                        });
                    }
                    else
                    {
                        receiverGetsBook.Quantity++;
                        receiverGetsBook.IsActive = true;
                    }

                    transaction.Status = "Confirmada";
                    if (transaction.SenderUserBookId.HasValue)
                        await CancelOtherPendingForUserBook(transaction.SenderUserBookId.Value, id);
                    if (transaction.UserBookId.HasValue)
                        await CancelOtherPendingForUserBook(transaction.UserBookId.Value, id);
                }

                transaction.UpdatedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();
                return Ok(new { message = "Ação de administrador executada: accept" });
            }
            else if (action == "deny" || action == "reject")
            {
                transaction.Status = "Rejeitada";
                transaction.UpdatedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();
                return Ok(new { message = "Ação de administrador executada: reject" });
            }
            else if (action == "cancel")
            {
                transaction.Status = "Cancelada";
                transaction.UpdatedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();
                return Ok(new { message = "Ação de administrador executada: cancel" });
            }

            return BadRequest(new { message = "Ação inválida" });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error performing admin action: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao executar ação de administrador" });
        }
    }

    private async Task CancelOtherPendingForUserBook(int userBookId, int exceptTransactionId)
    {
        var pending = await _context.Transactions
            .Where(t => t.UserBookId == userBookId
                     && t.Status == "Pendente"
                     && t.Id != exceptTransactionId)
            .ToListAsync();
        foreach (var t in pending) { t.Status = "Cancelada"; t.UpdatedAt = DateTime.UtcNow; }
    }

    /// <summary>
    /// Delete a user (admin action)
    /// </summary>
    [HttpDelete("users/{userId}")]
    public async Task<IActionResult> DeleteUser(int userId)
    {
        var authError = await RequireAdmin();
        if (authError != null) return authError;

        try
        {
            var user = await _context.Users.FindAsync(userId);
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
    [HttpPut("users/{userId}/admin")]
    public async Task<IActionResult> ToggleAdminStatus(int userId, [FromBody] ToggleAdminRequest request)
    {
        var authError = await RequireAdmin();
        if (authError != null) return authError;

        try
        {
            var user = await _context.Users.FindAsync(userId);
            if (user == null)
                return NotFound(new { message = "Utilizador não encontrado" });

            user.IsAdmin = request.IsAdmin;
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

    /// <summary>
    /// Get distinct authors extracted from the Books catalog (for the edit-form select list).
    /// </summary>
    [HttpGet("authors")]
    public async Task<IActionResult> GetAuthors()
    {
        var authError = await RequireAdmin();
        if (authError != null) return authError;

        var rawAuthors = await _context.Books
            .Where(b => !string.IsNullOrEmpty(b.Authors))
            .Select(b => b.Authors)
            .ToListAsync();

        var authors = rawAuthors
            .SelectMany(a => a.Split(',').Select(x => x.Trim()))
            .Where(a => !string.IsNullOrEmpty(a))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(a => a)
            .ToList();

        return Ok(new { success = true, authors });
    }

    /// <summary>
    /// Get the list of recognised genres (for the edit-form select list).
    /// </summary>
    [HttpGet("genres")]
    public async Task<IActionResult> GetGenres()
    {
        var authError = await RequireAdmin();
        if (authError != null) return authError;

        // Return both predefined genres and any genres already stored in the DB
        var dbGenres = await _context.Books
            .Where(b => !string.IsNullOrEmpty(b.Genre))
            .Select(b => b.Genre)
            .Distinct()
            .ToListAsync();

        var predefined = new List<string>
        {
            "Science Fiction", "Fantasy", "Mystery", "Romance", "Thriller", "Horror",
            "Historical Fiction", "Biography", "Memoir", "Poetry", "Drama", "Fiction",
            "Non-fiction", "Self-help", "Essay", "Adventure", "Young Adult", "Children's",
            "Dystopian Fiction", "Literary Fiction", "Crime", "Suspense", "Western",
            "Comedy", "Graphic Novel", "Short Stories", "Science", "History",
            "True Crime", "Paranormal", "Steampunk", "Romance Fiction", "Action"
        };

        var genres = predefined
            .Union(dbGenres, StringComparer.OrdinalIgnoreCase)
            .OrderBy(g => g)
            .ToList();

        return Ok(new { success = true, genres });
    }

    /// <summary>
    /// Update a book's catalog metadata (admin action). ISBN cannot be changed.
    /// </summary>
    [HttpPut("books/{isbn}")]
    public async Task<IActionResult> UpdateBook(string isbn, [FromBody] AdminUpdateBookRequest request)
    {
        var authError = await RequireAdmin();
        if (authError != null) return authError;

        try
        {
            var book = await _context.Books.FindAsync(isbn);
            if (book == null)
                return NotFound(new { message = "Livro não encontrado" });

            if (!string.IsNullOrWhiteSpace(request.Title))
                book.Title = request.Title.Trim();

            if (request.Authors != null)
                book.Authors = string.Join(", ", request.Authors.Select(a => a.Trim()).Where(a => a.Length > 0));

            if (request.Genre != null)
                book.Genre = request.Genre.Trim();

            if (request.Tags != null)
                book.Tags = request.Tags.Trim();

            if (request.Publisher != null)
                book.Publisher = request.Publisher.Trim();

            if (request.PublicationYear.HasValue)
                book.PublicationYear = request.PublicationYear.Value;

            if (request.CoverImageUrl != null)
                book.CoverImageUrl = request.CoverImageUrl.Trim();

            await _context.SaveChangesAsync();
            _logger.LogInformation($"Book updated by admin: {isbn}");

            return Ok(new
            {
                success = true,
                message = "Livro atualizado com sucesso",
                book = new
                {
                    isbn = book.ISBN,
                    title = book.Title,
                    authors = book.Authors,
                    genre = book.Genre,
                    tags = book.Tags,
                    publisher = book.Publisher,
                    publicationYear = book.PublicationYear,
                    coverImageUrl = book.CoverImageUrl
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error updating book: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao atualizar livro" });
        }
    }

    /// <summary>
    /// Delete a book and all associated user listings (admin action).
    /// </summary>
    [HttpDelete("books/{isbn}")]
    public async Task<IActionResult> DeleteBook(string isbn)
    {
        var authError = await RequireAdmin();
        if (authError != null) return authError;

        try
        {
            var book = await _context.Books.FindAsync(isbn);
            if (book == null)
                return NotFound(new { message = "Livro não encontrado" });

            // Remove all user-book listings first
            var userBooks = _context.UserBooks.Where(ub => ub.ISBN == isbn);
            _context.UserBooks.RemoveRange(userBooks);

            _context.Books.Remove(book);
            await _context.SaveChangesAsync();

            _logger.LogInformation($"Book deleted by admin: {isbn}");
            return Ok(new { message = "Livro eliminado com sucesso" });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error deleting book: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao eliminar livro" });
        }
    }
}

public class ToggleAdminRequest
{
    public bool IsAdmin { get; set; }
}

public class AdminUpdateBookRequest
{
    public string? Title { get; set; }
    public List<string>? Authors { get; set; }
    public string? Genre { get; set; }
    public string? Tags { get; set; }
    public string? Publisher { get; set; }
    public int? PublicationYear { get; set; }
    public string? CoverImageUrl { get; set; }
}

public class AdminTransactionActionRequest
{
    public string? Action { get; set; }
}

