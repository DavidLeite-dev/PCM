// ═══════════════════════════════════════════════════════════════════════════════
// FILE: Controllers/BooksController.cs
// PURPOSE: All book-related REST endpoints — ISBN lookup, catalog search,
//          user shelf management, and listing queries.
//
// QUICK REFERENCE  (all routes prefixed with /api/books)
//   POST   /lookup               → query OpenLibrary API by ISBN → return book metadata
//   POST   /register             → add a book copy to a user's shelf (creates UserBook)
//   GET    /user/{email}         → get all books on a user's shelf
//   GET    /search?…             → paginated catalog search (title/author/genre/tags)
//   PATCH  /user/{email}/{isbn}/{condition} → update book condition
//   DELETE /user/{email}/{isbn}/{condition} → soft-delete a book listing
//   GET    /distinct?property=…  → get unique authors/genres/tags for filter options
//   GET    /{isbn}/listings      → get all available copies of a specific book
//
// REQUEST MODELS (bottom of file)
//   ISBNLookupRequest, BookRegistrationRequest, UpdateConditionRequest
// ═══════════════════════════════════════════════════════════════════════════════

using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BookSwapAPI.Data;
using BookSwapAPI.Models;
using BookSwapAPI.Services;

namespace BookSwapAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BooksController : ControllerBase
{
    private readonly BookSwapDbContext _context;
    private readonly IISBNLookupService _isbnLookupService;
    private readonly IAppSettingService _settingService;
    private readonly ILogger<BooksController> _logger;

    public BooksController(
        BookSwapDbContext context,
        IISBNLookupService isbnLookupService,
        IAppSettingService settingService,
        ILogger<BooksController> logger)
    {
        _context           = context;
        _isbnLookupService = isbnLookupService;
        _settingService    = settingService;
        _logger            = logger;
    }

    // ─── POST /api/books/lookup ───────────────────────────────────────────────
    // Fetches book metadata from the OpenLibrary API via ISBNLookupService.
    // If the book is found, it is automatically saved to the Books table so
    // subsequent /register calls can link to it.
    // Returns 503 if OpenLibrary is unreachable or the ISBN is not found.
    [HttpPost("lookup")]
    public async Task<IActionResult> LookupISBN([FromBody] ISBNLookupRequest request)
    {
        _logger.LogInformation($"LookupISBN called with ISBN: '{request.ISBN}'");

        if (string.IsNullOrWhiteSpace(request.ISBN))
        {
            _logger.LogWarning("ISBN is null or empty");
            return BadRequest(new { message = "ISBN is required" });
        }

        var result = await _isbnLookupService.LookupISBNAsync(request.ISBN);

        if (!result.Success)
        {
            return StatusCode(503, new { message = result.ErrorMessage });
        }

        return Ok(new
        {
            success = true,
            source  = result.Source, // "database" or "openlibrary"
            book = new
            {
                isbn            = result.Book?.ISBN,
                title           = result.Book?.Title,
                authors         = result.Book?.Authors,
                genre           = result.Book?.Genre,
                tags            = result.Book?.Tags,
                description     = result.Book?.Description,
                publisher       = result.Book?.Publisher,
                publicationYear = result.Book?.PublicationYear,
                coverImageUrl   = result.Book?.CoverImageUrl
            }
        });
    }

    // ─── POST /api/books/register ─────────────────────────────────────────────
    // Adds a copy of a book to a user's shelf.
    // The book must already exist in the catalog (populated by /lookup first).
    // Handles three cases:
    //   1. New listing         → create UserBook record
    //   2. Active duplicate    → increment quantity (if AllowDuplicateBooks = true)
    //   3. Soft-deleted record → re-activate the existing row
    [HttpPost("register")]
    public async Task<IActionResult> RegisterBook([FromBody] BookRegistrationRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.ISBN) || string.IsNullOrWhiteSpace(request.Condition) || string.IsNullOrWhiteSpace(request.UserEmail))
        {
            return BadRequest(new { message = "ISBN, condition and userEmail are required" });
        }

        if (request.Quantity < 1)
        {
            return BadRequest(new { message = "Quantity must be at least 1" });
        }

        try
        {
            // Validate condition against the allowed set (novo/semi-novo/usado)
            if (!BookConditions.All.Contains(request.Condition))
            {
                return BadRequest(new { message = $"Invalid condition. Must be one of: {string.Join(", ", BookConditions.All)}" });
            }

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.UserEmail);
            if (user == null)
                return NotFound(new { message = "User not found" });

            // Normalise ISBN by stripping hyphens/spaces
            var normalizedIsbn = request.ISBN.Replace("-", "").Replace(" ", "").Trim();
            var catalogBook = await _context.Books.FirstOrDefaultAsync(b => b.ISBN == normalizedIsbn);
            if (catalogBook == null)
                return NotFound(new { message = "Book not found in catalog. Please look up the ISBN first." });

            // Read the AllowDuplicateBooks setting from the AppSettings table
            var allowDuplicates = await _settingService.GetBoolSettingAsync(AppSettingKeys.AllowDuplicateBooks);

            var existingUserBook = await _context.UserBooks
                .FirstOrDefaultAsync(ub => ub.UserId == user.Id && ub.ISBN == normalizedIsbn && ub.Condition == request.Condition);

            if (existingUserBook != null)
            {
                if (existingUserBook.IsActive)
                {
                    if (!allowDuplicates)
                        return BadRequest(new { message = "Já tem este livro nesta condição" });

                    // Increment quantity on the existing active record
                    existingUserBook.Quantity += request.Quantity;
                    _logger.LogInformation($"Updated quantity for user book: {user.Email} - {normalizedIsbn} ({request.Condition})");
                }
                else
                {
                    // Re-activate a previously soft-deleted record
                    existingUserBook.IsActive  = true;
                    existingUserBook.Quantity  = request.Quantity;
                    existingUserBook.DateAdded = DateTime.UtcNow;
                    _logger.LogInformation($"Re-activated soft-deleted book for user: {user.Email} - {normalizedIsbn} ({request.Condition})");
                }
            }
            else
            {
                // Fresh listing — create a new UserBook row
                var userBook = new UserBook
                {
                    UserId    = user.Id,
                    ISBN      = normalizedIsbn,
                    Condition = request.Condition,
                    Quantity  = request.Quantity,
                    DateAdded = DateTime.UtcNow
                };

                await _context.UserBooks.AddAsync(userBook);
                _logger.LogInformation($"Added new book for user: {user.Email} - {normalizedIsbn} ({request.Condition})");
            }

            await _context.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                message = "Book registered successfully",
                book = new
                {
                    isbn      = catalogBook.ISBN,
                    title     = catalogBook.Title,
                    authors   = catalogBook.Authors,
                    condition = request.Condition,
                    quantity  = existingUserBook?.Quantity ?? request.Quantity
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error registering book: {ex.Message}");
            return StatusCode(500, new { message = "Error registering book" });
        }
    }

    // ─── GET /api/books/user/{email} ──────────────────────────────────────────
    // Returns all active UserBook records for this user with embedded book data.
    // "Flattened" means each entry in the list already contains title/cover/etc
    // so the Flutter client doesn't need a second request.
    [HttpGet("user/{email}")]
    public async Task<IActionResult> GetUserBooks(string email)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
        if (user == null)
            return NotFound(new { message = "User not found" });

        var userBooks = await _context.UserBooks
            .Where(ub => ub.UserId == user.Id && ub.IsActive)
            .Include(ub => ub.Book)            // Eager-load the book catalog entry
            .OrderByDescending(ub => ub.DateAdded)
            .ToListAsync();

        // Project to a flat DTO: book metadata + condition + quantity
        var flattenedBooks = userBooks
            .Select(ub => new
            {
                bookData = new
                {
                    isbn            = ub.Book!.ISBN,
                    title           = ub.Book.Title,
                    authors         = ub.Book.Authors,
                    genre           = ub.Book!.Genre,
                    tags            = ub.Book.Tags,
                    description     = ub.Book.Description,
                    publisher       = ub.Book.Publisher,
                    publicationYear = ub.Book.PublicationYear,
                    coverImageUrl   = ub.Book.CoverImageUrl
                },
                condition = ub.Condition,
                quantity  = ub.Quantity,
                emprestado = ub.Emprestado // true if the copy is currently on loan
            })
            .ToList();

        return Ok(new { success = true, books = flattenedBooks });
    }

    // ─── GET /api/books/search ────────────────────────────────────────────────
    // Paginated search of the Books catalog.
    // Supports filtering by title (contains), author (contains), genre (contains),
    // and tags (contains). All filters are ANDed together.
    // Returns totalCount and totalPages so the client can render pagination controls.
    [HttpGet("search")]
    public async Task<IActionResult> SearchBooks(
        [FromQuery] string? title,
        [FromQuery] string? author,
        [FromQuery] string? genre,
        [FromQuery] string? tags,
        [FromQuery] int page     = 1,
        [FromQuery] int pageSize = 25)
    {
        // Clamp pagination parameters
        if (page < 1)      page     = 1;
        if (pageSize < 1)  pageSize = 25;
        if (pageSize > 100) pageSize = 100; // Hard cap at 100 per page

        var query = _context.Books.AsQueryable();

        // Apply each filter if provided (all are case-insensitive Contains on SQL Server)
        if (!string.IsNullOrWhiteSpace(title))  query = query.Where(b => b.Title.Contains(title));
        if (!string.IsNullOrWhiteSpace(author)) query = query.Where(b => b.Authors.Contains(author));
        if (!string.IsNullOrWhiteSpace(genre))  query = query.Where(b => b.Genre.Contains(genre));
        if (!string.IsNullOrWhiteSpace(tags))   query = query.Where(b => b.Tags.Contains(tags));

        // Count total matching records before slicing (for pagination controls)
        var totalCount = await query.CountAsync();
        var totalPages = (int)Math.Ceiling(totalCount / (double)pageSize);

        // Apply ordering + pagination via LINQ Skip/Take (translates to SQL OFFSET/FETCH)
        var books = await query
            .OrderBy(b => b.Title) // Consistent alphabetical order across pages
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(b => new
            {
                b.ISBN, b.Title, b.Authors, b.Genre, b.Tags,
                b.Description, b.Publisher, b.PublicationYear, b.CoverImageUrl
            })
            .ToListAsync();

        return Ok(new
        {
            success    = true,
            count      = books.Count,
            totalCount,
            page,
            pageSize,
            totalPages,
            books
        });
    }

    // ─── PATCH /api/books/user/{email}/{isbn}/{condition} ─────────────────────
    // Updates the condition of a user's book listing (e.g. semi-novo → usado).
    // Checks that the new condition doesn't conflict with an existing listing.
    [HttpPatch("user/{email}/{isbn}/{condition}")]
    public async Task<IActionResult> UpdateUserBookCondition(string email, string isbn, string condition,
        [FromBody] UpdateConditionRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.NewCondition))
            return BadRequest(new { message = "Nova condição é obrigatória" });

        if (!BookConditions.All.Contains(request.NewCondition))
            return BadRequest(new { message = $"Condição inválida. Use: {string.Join(", ", BookConditions.All)}" });

        if (request.NewCondition == condition)
            return BadRequest(new { message = "A nova condição é igual à atual" });

        try
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user == null)
                return NotFound(new { message = "Utilizador não encontrado" });

            var userBook = await _context.UserBooks
                .FirstOrDefaultAsync(ub => ub.UserId == user.Id && ub.ISBN == isbn
                    && ub.Condition == condition && ub.IsActive);

            if (userBook == null)
                return NotFound(new { message = "Livro não encontrado no inventário" });

            // Prevent creating a duplicate listing in the new condition
            var conflict = await _context.UserBooks
                .FirstOrDefaultAsync(ub => ub.UserId == user.Id && ub.ISBN == isbn
                    && ub.Condition == request.NewCondition && ub.IsActive);

            if (conflict != null)
                return BadRequest(new { message = "Já tem este livro na condição selecionada" });

            userBook.Condition = request.NewCondition;
            await _context.SaveChangesAsync();

            return Ok(new { success = true, message = "Condição atualizada com sucesso" });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error updating book condition: {ex.Message}");
            return StatusCode(500, new { message = "Erro ao atualizar condição" });
        }
    }

    // ─── DELETE /api/books/user/{email}/{isbn}/{condition} ────────────────────
    // Soft-deletes a user's book listing by setting IsActive = false.
    // The book catalog entry (Books table) is NOT deleted — only the user's copy.
    [HttpDelete("user/{email}/{isbn}/{condition}")]
    public async Task<IActionResult> DeleteUserBook(string email, string isbn, string condition)
    {
        try
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user == null)
                return NotFound(new { message = "User not found" });

            var userBook = await _context.UserBooks
                .FirstOrDefaultAsync(ub => ub.UserId == user.Id && ub.ISBN == isbn && ub.Condition == condition);

            if (userBook == null)
                return NotFound(new { message = "Book not found for user" });

            // Soft delete: mark as inactive so history is preserved
            userBook.IsActive = false;
            await _context.SaveChangesAsync();

            _logger.LogInformation($"Deleted book for user: {email} - {isbn} ({condition})");
            return Ok(new { success = true, message = "Book deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error deleting book: {ex.Message}");
            return StatusCode(500, new { message = "Error deleting book" });
        }
    }

    // ─── GET /api/books/distinct?property=… ──────────────────────────────────
    // Returns all unique values for a given book property across the catalog.
    // Used by BookCatalogScreen to populate the FilterDialog checkboxes.
    // Supported properties: authors, genre, tags, conditions
    [HttpGet("distinct")]
    public async Task<IActionResult> GetDistinctValues([FromQuery] string property)
    {
        try
        {
            List<string> values = new();

            switch (property.ToLower())
            {
                case "authors":
                    // Authors are comma-separated strings — split and deduplicate server-side
                    var authorsData = await _context.Books
                        .Where(b => !string.IsNullOrEmpty(b.Authors))
                        .Select(b => b.Authors)
                        .ToListAsync();
                    values = authorsData
                        .SelectMany(a => a.Split(",").Select(x => x.Trim()))
                        .Where(a => !string.IsNullOrEmpty(a))
                        .Distinct()
                        .OrderBy(a => a)
                        .ToList();
                    break;

                case "genre":
                    // Genre is a single string per book — just deduplicate
                    var genreData = await _context.Books
                        .Where(b => !string.IsNullOrEmpty(b.Genre))
                        .Select(b => b.Genre)
                        .ToListAsync();
                    values = genreData
                        .Where(g => !string.IsNullOrEmpty(g))
                        .Distinct()
                        .OrderBy(g => g)
                        .ToList();
                    break;

                case "tags":
                    // Tags are comma-separated strings — split and deduplicate
                    var tagsData = await _context.Books
                        .Where(b => !string.IsNullOrEmpty(b.Tags))
                        .Select(b => b.Tags)
                        .ToListAsync();
                    values = tagsData
                        .SelectMany(t => t.Split(",").Select(x => x.Trim()))
                        .Where(t => !string.IsNullOrEmpty(t))
                        .Distinct()
                        .OrderBy(t => t)
                        .ToList();
                    break;

                case "conditions":
                    // Return the fixed set of allowed conditions
                    values = BookConditions.All;
                    break;

                default:
                    return BadRequest(new { message = "Invalid property" });
            }

            return Ok(new { success = true, property, values });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error getting distinct values: {ex.Message}");
            return StatusCode(500, new { message = "Error retrieving values" });
        }
    }

    // ─── GET /api/books/{isbn}/listings ──────────────────────────────────────
    // Returns all active, available UserBook records for a specific ISBN.
    // This is shown in BookDetailScreen under "Cópias Disponíveis" —
    // each listing shows who owns the book and what condition it's in,
    // with action buttons to Buy / Borrow / Trade / Message the owner.
    [HttpGet("{isbn}/listings")]
    public async Task<IActionResult> GetBookListings(string isbn)
    {
        try
        {
            var book = await _context.Books.FirstOrDefaultAsync(b => b.ISBN == isbn);
            if (book == null)
                return NotFound(new { message = "Book not found" });

            // Only return listings that are: active (not soft-deleted) AND available (not already lent)
            var listings = await _context.UserBooks
                .Where(ub => ub.ISBN == isbn && ub.IsActive && ub.Available)
                .Include(ub => ub.User) // Eager-load owner info for the listing card
                .OrderByDescending(ub => ub.DateAdded)
                .Select(ub => new BookListingDto
                {
                    ListingId  = ub.Id,
                    ISBN       = ub.ISBN,
                    Condition  = ub.Condition,
                    Available  = ub.Available,
                    Emprestado = ub.Emprestado,
                    DateAdded  = ub.DateAdded,
                    OwnerId    = ub.UserId,
                    OwnerEmail = ub.User!.Email,
                    OwnerName  = ub.User.Name
                })
                .ToListAsync();

            return Ok(new
            {
                success  = true,
                isbn,
                count    = listings.Count,
                listings
            });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error getting book listings: {ex.Message}");
            return StatusCode(500, new { message = "Error retrieving listings" });
        }
    }
}

// ─── Request / Response Models ────────────────────────────────────────────────

public class ISBNLookupRequest
{
    public string ISBN { get; set; } = string.Empty;
}

public class BookRegistrationRequest
{
    public string ISBN      { get; set; } = string.Empty;
    public string UserEmail { get; set; } = string.Empty;
    public string Condition { get; set; } = BookConditions.Novo;
    public int    Quantity  { get; set; } = 1;
}

public class UpdateConditionRequest
{
    public string NewCondition { get; set; } = string.Empty;
}
