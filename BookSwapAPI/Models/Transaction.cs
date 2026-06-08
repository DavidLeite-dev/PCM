namespace BookSwapAPI.Models;

public class Transaction
{
    public int Id { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public string Type { get; set; } = string.Empty; // "Compra", "Requisição", "Troca"
    public string Status { get; set; } = string.Empty; // "Pendente", "Aceita", "Confirmada", "Rejeitada", "Cancelada"
    public string Notes { get; set; } = string.Empty;
    // Link to specific inventory record (UserBook) for the book being transacted
    public int? UserBookId { get; set; }
    // For trades: the UserBookId of the sender's offered copy
    public int? SenderUserBookId { get; set; }
    public int SenderId { get; set; }
    public int ReceiverId { get; set; }

    // Optional fields for purchase price and trade book
    public decimal? Price { get; set; }
    // legacy notes

    // Navigation properties
    public User Sender { get; set; } = null!;
    public User Receiver { get; set; } = null!;
    public UserBook? UserBook { get; set; }
    public UserBook? SenderUserBook { get; set; }
}
