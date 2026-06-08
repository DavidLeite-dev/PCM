namespace BookSwapAPI.Models;

/// <summary>
/// Book catalog - stores raw book data from OpenLibrary (no user-specific data)
/// Acts as a cache for ISBN lookups
/// </summary>
public class Book
{
    public string ISBN { get; set; } = string.Empty; // Primary Key
    public string Title { get; set; } = string.Empty;
    public string Authors { get; set; } = string.Empty; // Comma-separated
    public string Genre { get; set; } = string.Empty; // Primary genre (single)
    public string Tags { get; set; } = string.Empty; // All subjects/tags - comma-separated for searching
    public string Description { get; set; } = string.Empty; // Book description from OpenLibrary
    public string Publisher { get; set; } = string.Empty;
    public int? PublicationYear { get; set; }
    public string CoverImageUrl { get; set; } = string.Empty;
    public DateTime LastUpdatedFromOpenLibrary { get; set; } = DateTime.UtcNow;

    // Navigation
    public ICollection<UserBook> UserBooks { get; set; } = new List<UserBook>();
    public ICollection<BookAuthor> BookAuthors { get; set; } = new List<BookAuthor>();
    public ICollection<BookCategory> BookCategories { get; set; } = new List<BookCategory>();
}

/// <summary>
/// Book conditions
/// </summary>
public static class BookConditions
{
    public const string Novo = "novo"; // New
    public const string SemiNovo = "semi-novo"; // Like new
    public const string Usado = "usado"; // Used

    public static List<string> All => new() { Novo, SemiNovo, Usado };
}
