namespace BookSwapAPI.Models;

public class BookCategory
{
    public string BookISBN { get; set; } = string.Empty;
    public int CategoryId { get; set; }

    public Book Book { get; set; } = null!;
    public Category Category { get; set; } = null!;
}
