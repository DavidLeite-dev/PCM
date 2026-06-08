namespace BookSwapAPI.Models;

public class Conversation
{
    public int Id { get; set; }
    public int InitiatorId { get; set; }
    public int ReceiverId { get; set; }
    public string? BookISBN { get; set; }
    public int? TransactionId { get; set; }

    /// "Active" | "Archived"
    public string Status { get; set; } = "Active";

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime LastMessageAt { get; set; } = DateTime.UtcNow;
    public DateTime? ArchivedAt { get; set; }

    // Navigation
    public User Initiator { get; set; } = null!;
    public User Receiver { get; set; } = null!;
    public Book? Book { get; set; }
    public Transaction? Transaction { get; set; }
    public ICollection<Message> Messages { get; set; } = new List<Message>();
}
