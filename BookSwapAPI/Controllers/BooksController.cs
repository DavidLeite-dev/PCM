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
        _context = context;
        _isbnLookupService = isbnLookupService;
        _settingService = settingService;
        _logger = logger;
    }

    /// <summary>
    /// Look up a book by ISBN
    /// </summary>
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
            source = result.Source,
            book = new
            {
                isbn = result.Book?.ISBN,
                title = result.Book?.Title,
                authors = result.Book?.Authors,
                genre = result.Book?.Genre,
                tags = result.Book?.Tags,
                description = result.Book?.Description,
                publisher = result.Book?.Publisher,
                publicationYear = result.Book?.PublicationYear,
                coverImageUrl = result.Book?.CoverImageUrl
            }
        });
    }

    /// <summary>
    /// Register a book for a user with a specific condition
    /// </summary>
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
            // Validate condition
            if (!BookConditions.All.Contains(request.Condition))
            {
                return BadRequest(new { message = $"Invalid condition. Must be one of: {string.Join(", ", BookConditions.All)}" });
            }

            // Get user
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.UserEmail);
            if (user == null)
            {
                return NotFound(new { message = "User not found" });
            }

            // Book must already exist in the local DB (populated by the /lookup step)
            var normalizedIsbn = request.ISBN.Replace("-", "").Replace(" ", "").Trim();
            var catalogBook = await _context.Books.FirstOrDefaultAsync(b => b.ISBN == normalizedIsbn);
            if (catalogBook == null)
            {
                return NotFound(new { message = "Book not found in catalog. Please look up the ISBN first." });
            }

            // Check duplicate settings
            var allowDuplicates = await _settingService.GetBoolSettingAsync(AppSettingKeys.AllowDuplicateBooks);

            // Check if user already has this book with same condition (active or soft-deleted)
            var existingUserBook = await _context.UserBooks
                .FirstOrDefaultAsync(ub => ub.UserId == user.Id && ub.ISBN == normalizedIsbn && ub.Condition == request.Condition);

            if (existingUserBook != null)
            {
                if (existingUserBook.IsActive)
                {
                    if (!allowDuplicates)
                    {
                        return BadRequest(new { message = "Já tem este livro nesta condição" });
                    }
                    // Increment quantity on the active record
                    existingUserBook.Quantity += request.Quantity;
                    _logger.LogInformation($"Updated quantity for user book: {user.Email} - {normalizedIsbn} ({request.Condition})");
                }
                else
                {
                    // Re-activate the soft-deleted record
                    existingUserBook.IsActive = true;
                    existingUserBook.Quantity = request.Quantity;
                    existingUserBook.DateAdded = DateTime.UtcNow;
                    _logger.LogInformation($"Re-activated soft-deleted book for user: {user.Email} - {normalizedIsbn} ({request.Condition})");
                }
            }
            else
            {
                // Create new user book entry
                var userBook = new UserBook
                {
                    UserId = user.Id,
                    ISBN = normalizedIsbn,
                    Condition = request.Condition,
                    Quantity = request.Quantity,
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
                    isbn = catalogBook.ISBN,
                    title = catalogBook.Title,
                    authors = catalogBook.Authors,
                    condition = request.Condition,
                    quantity = existingUserBook?.Quantity ?? request.Quantity
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error registering book: {ex.Message}");
            return StatusCode(500, new { message = "Error registering book" });
        }
    }

    /// <summary>
    /// Get all books for a user
    /// </summary>
    [HttpGet("user/{email}")]
    public async Task<IActionResult> GetUserBooks(string email)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
        if (user == null)
        {
            return NotFound(new { message = "User not found" });
        }

        var userBooks = await _context.UserBooks
            .Where(ub => ub.UserId == user.Id && ub.IsActive)
            .Include(ub => ub.Book)
            .OrderByDescending(ub => ub.DateAdded)
            .ToListAsync();

        // Flatten the response: one entry per condition with full book data
        var flattenedBooks = userBooks
            .Select(ub => new
            {
                bookData = new
                {
                    isbn = ub.Book!.ISBN,
                    title = ub.Book.Title,
                    authors = ub.Book.Authors,
                    genre = ub.Book!.Genre,
                    tags = ub.Book.Tags,
                    description = ub.Book.Description,
                    publisher = ub.Book.Publisher,
                    publicationYear = ub.Book.PublicationYear,
                    coverImageUrl = ub.Book.CoverImageUrl
                },
                condition = ub.Condition,
                quantity = ub.Quantity,
                emprestado = ub.Emprestado
            })
            .ToList();

        return Ok(new { success = true, books = flattenedBooks });
    }

    /// <summary>
    /// Search books in the catalog by title, author, genre, or tags with pagination
    /// </summary>
    [HttpGet("search")]
    public async Task<IActionResult> SearchBooks(
        [FromQuery] string? title,
        [FromQuery] string? author,
        [FromQuery] string? genre,
        [FromQuery] string? tags,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 25)
    {
        // Validate pagination parameters
        if (page < 1) page = 1;
        if (pageSize < 1) pageSize = 25;
        if (pageSize > 100) pageSize = 100; // Max 100 items per page

        var query = _context.Books.AsQueryable();

        if (!string.IsNullOrWhiteSpace(title))
        {
            query = query.Where(b => b.Title.Contains(title));
        }

        if (!string.IsNullOrWhiteSpace(author))
        {
            query = query.Where(b => b.Authors.Contains(author));
        }

        if (!string.IsNullOrWhiteSpace(genre))
        {
            query = query.Where(b => b.Genre.Contains(genre));
        }

        if (!string.IsNullOrWhiteSpace(tags))
        {
            query = query.Where(b => b.Tags.Contains(tags));
        }

        // Get total count before pagination
        var totalCount = await query.CountAsync();
        var totalPages = (int)Math.Ceiling(totalCount / (double)pageSize);

        // Apply pagination
        var books = await query
            .OrderBy(b => b.Title) // Ensure consistent ordering
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(b => new
            {
                b.ISBN,
                b.Title,
                b.Authors,
                b.Genre,
                b.Tags,
                b.Description,
                b.Publisher,
                b.PublicationYear,
                b.CoverImageUrl
            })
            .ToListAsync();

        return Ok(new
        {
            success = true,
            count = books.Count,
            totalCount,
            page,
            pageSize,
            totalPages,
            books
        });
    }

    /// <summary>
    /// Update the condition of a user's book listing
    /// </summary>
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

            // Check that new condition doesn't already exist for this user+ISBN
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

    /// <summary>
    /// Delete a user's book by ISBN and condition
    /// </summary>
    [HttpDelete("user/{email}/{isbn}/{condition}")]
    public async Task<IActionResult> DeleteUserBook(string email, string isbn, string condition)
    {
        try
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user == null)
            {
                return NotFound(new { message = "User not found" });
            }

            var userBook = await _context.UserBooks
                .FirstOrDefaultAsync(ub => ub.UserId == user.Id && ub.ISBN == isbn && ub.Condition == condition);
            
            if (userBook == null)
            {
                return NotFound(new { message = "Book not found for user" });
            }

            // Soft delete: mark as inactive instead of hard delete
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

    /// <summary>
    /// Get distinct values for a book property (for filtering)
    /// </summary>
    [HttpGet("distinct")]
    public async Task<IActionResult> GetDistinctValues([FromQuery] string property)
    {
        try
        {
            List<string> values = new();

            switch (property.ToLower())
            {
                case "authors":
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

    /// <summary>
    /// Get all available listings for a specific book ISBN
    /// </summary>
    [HttpGet("{isbn}/listings")]
    public async Task<IActionResult> GetBookListings(string isbn)
    {
        try
        {
            // Check if book exists
            var book = await _context.Books.FirstOrDefaultAsync(b => b.ISBN == isbn);
            if (book == null)
            {
                return NotFound(new { message = "Book not found" });
            }

            // Get all user books (listings) for this ISBN that are active
            var listings = await _context.UserBooks
                .Where(ub => ub.ISBN == isbn && ub.IsActive && ub.Available)
                .Include(ub => ub.User)
                .OrderByDescending(ub => ub.DateAdded)
                .Select(ub => new BookListingDto
                {
                    ListingId = ub.Id,
                    ISBN = ub.ISBN,
                    Condition = ub.Condition,
                    Available = ub.Available,
                    Emprestado = ub.Emprestado,
                    DateAdded = ub.DateAdded,
                    OwnerId = ub.UserId,
                    OwnerEmail = ub.User!.Email,
                    OwnerName = ub.User.Name
                })
                .ToListAsync();

            return Ok(new
            {
                success = true,
                isbn,
                count = listings.Count,
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

public class ISBNLookupRequest
{
    public string ISBN { get; set; } = string.Empty;
}

public class BookRegistrationRequest
{
    public string ISBN { get; set; } = string.Empty;
    public string UserEmail { get; set; } = string.Empty;
    public string Condition { get; set; } = BookConditions.Novo;
    public int Quantity { get; set; } = 1;
}

public class UpdateConditionRequest
{
    public string NewCondition { get; set; } = string.Empty;
}
