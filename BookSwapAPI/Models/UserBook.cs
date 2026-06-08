namespace BookSwapAPI.Models;

/// <summary>
/// Links users to books with condition and quantity tracking
/// </summary>
public class UserBook
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string ISBN { get; set; } = string.Empty;
    public string Condition { get; set; } = BookConditions.Novo; // novo, semi-novo, usado
    public int Quantity { get; set; } = 1;
    public bool Available { get; set; } = true; // Whether the book is available for transactions
    public bool Emprestado { get; set; } = false; // Whether the book is currently lent out
    public DateTime DateAdded { get; set; } = DateTime.UtcNow;
    public bool IsActive { get; set; } = true; // Soft delete

    // Foreign Keys
    public User? User { get; set; }
    public Book? Book { get; set; }
}
