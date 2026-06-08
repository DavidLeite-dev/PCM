namespace BookSwapAPI.Models;

public class BookAuthor
{
    public string BookISBN { get; set; } = string.Empty;
    public int AuthorId { get; set; }

    public Book Book { get; set; } = null!;
    public Author Author { get; set; } = null!;
}
