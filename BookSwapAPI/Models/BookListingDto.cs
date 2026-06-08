namespace BookSwapAPI.Models;

/// <summary>
/// DTO representing a listing (a user's copy of a book available for transactions)
/// </summary>
public class BookListingDto
{
    public int ListingId { get; set; }  // UserBook Id
    public string ISBN { get; set; } = string.Empty;
    public string Condition { get; set; } = string.Empty;  // novo, semi-novo, usado
    public bool Available { get; set; }
    public bool Emprestado { get; set; }  // Currently lent out
    public DateTime DateAdded { get; set; }
    
    // Owner information
    public int OwnerId { get; set; }
    public string OwnerEmail { get; set; } = string.Empty;
    public string OwnerName { get; set; } = string.Empty;
}
