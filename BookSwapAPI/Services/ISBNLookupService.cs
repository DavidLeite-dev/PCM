using System.Text.Json;
using BookSwapAPI.Models;
using BookSwapAPI.Data;
using Microsoft.EntityFrameworkCore;

namespace BookSwapAPI.Services;

/// <summary>
/// Service for looking up books by ISBN from OpenLibrary with local database fallback
/// </summary>
public interface IISBNLookupService
{
    Task<ISBNLookupResult> LookupISBNAsync(string isbn);
}

public class ISBNLookupService : IISBNLookupService
{
    private readonly HttpClient _httpClient;
    private readonly BookSwapDbContext _dbContext;
    private readonly ILogger<ISBNLookupService> _logger;

    private const string OpenLibraryBaseUrl = "https://openlibrary.org";
    private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(15);

        // Real genres for filtering - sorted by priority
        private static readonly HashSet<string> RealGenres = new(StringComparer.OrdinalIgnoreCase)
        {
            "Science Fiction", "Fantasy", "Mystery", "Romance", "Thriller", "Horror",
            "Historical Fiction", "Biography", "Memoir", "Poetry", "Drama", "Fiction",
            "Non-fiction", "Self-help", "Essay", "Adventure", "Young Adult", "Children's",
            "Dystopian Fiction", "Literary Fiction", "Crime", "Suspense", "Western",
            "Comedy", "Graphic Novel", "Short Stories", "Science", "History",
            "True Crime", "Paranormal", "Steampunk", "Romance Fiction", "Action"
        };

    public ISBNLookupService(HttpClient httpClient, BookSwapDbContext dbContext, ILogger<ISBNLookupService> logger)
    {
        _httpClient = httpClient;
        _dbContext = dbContext;
        _logger = logger;
        _httpClient.Timeout = RequestTimeout;
    }

    /// <summary>
    /// Look up a book by ISBN, trying OpenLibrary first, then falling back to local database
    /// </summary>
    public async Task<ISBNLookupResult> LookupISBNAsync(string isbn)
    {
        _logger.LogInformation($"Looking up ISBN: {isbn}");

        // Normalize ISBN
        isbn = NormalizeISBN(isbn);

        // Try OpenLibrary first
        var openLibraryResult = await TryOpenLibraryLookupAsync(isbn);
        if (openLibraryResult.Success)
        {
            _logger.LogInformation($"Found book in OpenLibrary: {openLibraryResult.Book?.Title}");

            // Store/update in local database
            await UpdateLocalDatabaseAsync(openLibraryResult.Book!);

            return openLibraryResult;
        }

        _logger.LogWarning($"OpenLibrary lookup failed: {openLibraryResult.ErrorMessage}");

        // Fall back to local database
        var localBook = await _dbContext.Books.FirstOrDefaultAsync(b => b.ISBN == isbn);
        if (localBook != null)
        {
            _logger.LogInformation($"Found book in local database: {localBook.Title}");
            return new ISBNLookupResult
            {
                Success = true,
                Source = "LocalDatabase",
                Book = localBook,
                Message = "Book found in local database (OpenLibrary API unavailable)"
            };
        }

        _logger.LogWarning($"Book not found in OpenLibrary or local database: {isbn}");
        return new ISBNLookupResult
        {
            Success = false,
            Source = "None",
            ErrorMessage = $"Nenhum livro encontrado com o ISBN {isbn}. Verifique o ISBN e tente novamente."
        };
    }

    /// <summary>
    /// Attempt to lookup a book from OpenLibrary Search API (efficient single request)
    /// </summary>
    private async Task<ISBNLookupResult> TryOpenLibraryLookupAsync(string isbn)
    {
        try
        {
            var url = $"{OpenLibraryBaseUrl}/search.json?isbn={isbn}";
            _logger.LogDebug($"Calling OpenLibrary Search API: {url}");

            var response = await _httpClient.GetAsync(url);

            if (!response.IsSuccessStatusCode)
            {
                return new ISBNLookupResult
                {
                    Success = false,
                    ErrorMessage = $"OpenLibrary returned status {response.StatusCode}"
                };
            }

            var jsonContent = await response.Content.ReadAsStringAsync();
            var searchResult = JsonSerializer.Deserialize<JsonElement>(jsonContent);

            // Search API returns results in 'docs' array
            if (!searchResult.TryGetProperty("docs", out var docsProp) || docsProp.ValueKind != JsonValueKind.Array)
            {
                return new ISBNLookupResult
                {
                    Success = false,
                    ErrorMessage = "No books found in OpenLibrary"
                };
            }

            var docsArray = docsProp.EnumerateArray().ToList();
            if (docsArray.Count == 0)
            {
                return new ISBNLookupResult
                {
                    Success = false,
                    ErrorMessage = "No books found in OpenLibrary"
                };
            }

            var book = await ParseSearchResponseAsync(docsArray.First(), isbn);
            if (book == null)
            {
                return new ISBNLookupResult
                {
                    Success = false,
                    ErrorMessage = "Could not parse OpenLibrary response"
                };
            }

            // Log what was extracted for debugging
            _logger.LogInformation($"Extracted from OpenLibrary - Title: {book.Title}, Authors: {book.Authors}, Genre: {book.Genre ?? "EMPTY"}, Tags: {(string.IsNullOrEmpty(book.Tags) ? "EMPTY" : book.Tags.Substring(0, Math.Min(100, book.Tags.Length)) + "...")}, Publisher: {book.Publisher ?? "EMPTY"}");

            return new ISBNLookupResult
            {
                Success = true,
                Source = "OpenLibrary",
                Book = book
            };
        }
        catch (HttpRequestException ex)
        {
            _logger.LogWarning($"OpenLibrary API error: {ex.Message}");
            return new ISBNLookupResult
            {
                Success = false,
                ErrorMessage = $"OpenLibrary API error: {ex.Message}"
            };
        }
        catch (JsonException ex)
        {
            _logger.LogError($"Failed to parse OpenLibrary response: {ex.Message}");
            return new ISBNLookupResult
            {
                Success = false,
                ErrorMessage = "Failed to parse OpenLibrary response"
            };
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("OpenLibrary API request timeout");
            return new ISBNLookupResult
            {
                Success = false,
                ErrorMessage = "A pesquisa demorou demasiado tempo. Verifique a ligação e tente novamente."
            };
        }
    }

    private async Task<Book?> ParseSearchResponseAsync(JsonElement doc, string isbn)
    {
        try
        {
            // Log all properties in the response to understand what's available
            var propertyNames = string.Join(", ", doc.EnumerateObject().Select(p => p.Name));
            _logger.LogInformation($"OpenLibrary response properties for ISBN {isbn}: {propertyNames}");

            var title = doc.TryGetProperty("title", out var titleProp)
                ? titleProp.GetString()
                : string.Empty;

            var authors = ExtractAuthors(doc);
            var publisher = doc.TryGetProperty("publisher", out var publishersProp) && publishersProp.ValueKind == JsonValueKind.Array
                ? (publishersProp.EnumerateArray().FirstOrDefault().GetString() ?? string.Empty)
                : string.Empty;

            var publicationYear = ExtractPublicationYear(doc);
            var coverImageUrl = ExtractCoverImageUrl(doc);

            if (string.IsNullOrEmpty(title))
            {
                _logger.LogWarning($"OpenLibrary response missing title for ISBN {isbn}");
                return null;
            }

            // Fetch work details for all subjects/tags and determine primary genre
            var genre = string.Empty;
            var tags = string.Empty;
            var description = string.Empty;
            var workKey = doc.TryGetProperty("key", out var keyProp) ? keyProp.GetString() : null;
            if (!string.IsNullOrEmpty(workKey))
            {
                _logger.LogInformation($"Fetching work details from {workKey} to get all subjects/tags");
                (genre, tags, description) = await FetchSubjectsAndGenreAsync(workKey);
            }

            return new Book
            {
                ISBN = isbn,
                Title = title,
                Authors = authors,
                Genre = genre,
                Tags = tags,
                Description = description,
                Publisher = publisher,
                PublicationYear = publicationYear,
                CoverImageUrl = coverImageUrl,
                LastUpdatedFromOpenLibrary = DateTime.UtcNow
            };
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error parsing OpenLibrary search response: {ex.Message}");
            return null;
        }
    }

    /// <summary>
    /// Extract authors from OpenLibrary Search API response
    /// Search API returns author names directly in 'author_name' array
    /// </summary>
    private string ExtractAuthors(JsonElement doc)
    {
        if (!doc.TryGetProperty("author_name", out var authorsProp) || authorsProp.ValueKind != JsonValueKind.Array)
            return string.Empty;

        var authors = new List<string>();
        foreach (var author in authorsProp.EnumerateArray())
        {
            var name = author.GetString();
            if (!string.IsNullOrEmpty(name))
                authors.Add(name);
        }

        return string.Join(", ", authors);
    }

    /// <summary>
    /// Extract publication year from OpenLibrary Search API response
    /// Search API provides 'first_publish_year' as a direct integer
    /// </summary>
    private int? ExtractPublicationYear(JsonElement doc)
    {
        if (doc.TryGetProperty("first_publish_year", out var yearProp))
        {
            if (yearProp.TryGetInt32(out var year))
            {
                return year;
            }
        }

        return null;
    }

    /// <summary>
    /// Fetch detailed genres/subjects from OpenLibrary Works API
    /// </summary>
    /// <summary>
    /// Fetch all subjects from the work endpoint and extract primary genre
    /// Returns tuple of (primaryGenre, allTagsCommaSeparated, description)
    /// </summary>
    private async Task<(string primaryGenre, string allTags, string description)> FetchSubjectsAndGenreAsync(string workKey)
    {
        try
        {
            // workKey format is like "/works/OL3140822W"
            var cleanKey = workKey.TrimStart('/');
            var workUrl = $"{OpenLibraryBaseUrl}/{cleanKey}.json";
            
            _logger.LogDebug($"Fetching work details from: {workUrl}");
            
            var response = await _httpClient.GetAsync(workUrl);
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning($"Failed to fetch work details: {response.StatusCode}");
                return (string.Empty, string.Empty, string.Empty);
            }

            var jsonContent = await response.Content.ReadAsStringAsync();
            var workData = JsonSerializer.Deserialize<JsonElement>(jsonContent);

            // Extract description
            var description = string.Empty;
            if (workData.TryGetProperty("description", out var descProp))
            {
                if (descProp.ValueKind == JsonValueKind.String)
                {
                    description = descProp.GetString() ?? string.Empty;
                }
                else if (descProp.ValueKind == JsonValueKind.Object && descProp.TryGetProperty("value", out var valueProp))
                {
                    description = valueProp.GetString() ?? string.Empty;
                }
            }

            if (!workData.TryGetProperty("subjects", out var subjectsProp) || subjectsProp.ValueKind != JsonValueKind.Array)
            {
                _logger.LogDebug("No subjects found in work data");
                return (string.Empty, string.Empty, description);
            }

            var allSubjects = new List<string>();
            foreach (var subject in subjectsProp.EnumerateArray())
            {
                if (subject.ValueKind == JsonValueKind.String)
                {
                    var subjectValue = subject.GetString();
                    if (!string.IsNullOrEmpty(subjectValue))
                        allSubjects.Add(subjectValue);
                }
            }

            // Store all subjects as tags
            var allTagsString = string.Join(", ", allSubjects);
            _logger.LogInformation($"Extracted {allSubjects.Count} total subjects/tags from work");

            // Extract primary genre using Option B logic
            var primaryGenre = ExtractPrimaryGenre(allSubjects);
            _logger.LogInformation($"Determined primary genre: '{primaryGenre}' from {allSubjects.Count} subjects");
            
            return (primaryGenre, allTagsString, description);
        }
        catch (Exception ex)
        {
            _logger.LogWarning($"Error fetching work details: {ex.Message}");
            return (string.Empty, string.Empty, string.Empty);
        }
    }

    /// <summary>
    /// Generate cover image URL from OpenLibrary
    /// Search API provides 'cover_i' (cover ID) for direct URL construction
    /// Falls back to ISBN-based URL if cover_i is not available
    /// </summary>
    private string ExtractCoverImageUrl(JsonElement doc)
    {
        // Try to get cover ID from Search API response
        if (doc.TryGetProperty("cover_i", out var coverIdProp))
        {
            if (coverIdProp.TryGetInt64(out var coverId))
            {
                return $"https://covers.openlibrary.org/b/id/{coverId}-M.jpg";
            }
        }

        // Fallback: return empty string if no cover available
        return string.Empty;
    }

    /// <summary>
    /// Update or insert book data into local database
    /// </summary>
    private async Task UpdateLocalDatabaseAsync(Book book)
    {
        try
        {
            var existingBook = await _dbContext.Books.FirstOrDefaultAsync(b => b.ISBN == book.ISBN);

            if (existingBook != null)
            {
                // Check if data is different
                if (existingBook.Title != book.Title ||
                    existingBook.Authors != book.Authors ||
                    existingBook.Genre != book.Genre ||
                    existingBook.Tags != book.Tags ||
                    existingBook.Description != book.Description)
                {
                    _logger.LogInformation($"Updating existing book: {book.ISBN}");
                    existingBook.Title = book.Title;
                    existingBook.Authors = book.Authors;
                    existingBook.Genre = book.Genre;
                    existingBook.Tags = book.Tags;
                    existingBook.Description = book.Description;
                    existingBook.Publisher = book.Publisher;
                    existingBook.PublicationYear = book.PublicationYear;
                    existingBook.CoverImageUrl = book.CoverImageUrl;
                    existingBook.LastUpdatedFromOpenLibrary = DateTime.UtcNow;
                }
            }
            else
            {
                _logger.LogInformation($"Adding new book to local database: {book.ISBN}");
                await _dbContext.Books.AddAsync(book);
            }

            await _dbContext.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error updating local database: {ex.Message}");
        }
    }

    /// <summary>
    /// Extract primary genre from subjects using Option B logic
    /// Finds the first subject that matches a known genre category
    /// </summary>
    private string ExtractPrimaryGenre(List<string> subjects)
    {
        if (subjects == null || subjects.Count == 0)
            return string.Empty;

        // First priority: exact match with real genre list
        foreach (var subject in subjects)
        {
            if (RealGenres.Contains(subject))
            {
                return subject;
            }
        }

        // Second priority: partial match (subject contains a real genre)
        foreach (var subject in subjects)
        {
            foreach (var realGenre in RealGenres)
            {
                if (subject.Contains(realGenre, StringComparison.OrdinalIgnoreCase))
                {
                    // Return the subject that contains the genre for better specificity
                    return subject;
                }
            }
        }

        // Fallback: use first subject if it looks like a genre (contains common genre keywords)
        var firstSubject = subjects.First();
        if (firstSubject.Contains("fiction", StringComparison.OrdinalIgnoreCase) ||
            firstSubject.Contains("novel", StringComparison.OrdinalIgnoreCase) ||
            firstSubject.Contains("biography", StringComparison.OrdinalIgnoreCase) ||
            firstSubject.Contains("history", StringComparison.OrdinalIgnoreCase))
        {
            return firstSubject;
        }

        // No recognisable genre found — return empty rather than a wrong default
        return string.Empty;
    }

    /// <summary>
    /// Normalize ISBN format (remove hyphens and spaces)
    /// </summary>
    private string NormalizeISBN(string isbn)
    {
        return isbn.Replace("-", "").Replace(" ", "").Trim();
    }
}

/// <summary>
/// Result of an ISBN lookup operation
/// </summary>
public class ISBNLookupResult
{
    public bool Success { get; set; }
    public string Source { get; set; } = string.Empty; // "OpenLibrary", "LocalDatabase", or "None"
    public Book? Book { get; set; }
    public string Message { get; set; } = string.Empty;
    public string ErrorMessage { get; set; } = string.Empty;
}
