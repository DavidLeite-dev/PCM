using Microsoft.EntityFrameworkCore;
using BookSwapAPI.Models;

namespace BookSwapAPI.Data;

public class BookSwapDbContext : DbContext
{
    public BookSwapDbContext(DbContextOptions<BookSwapDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users { get; set; }
    public DbSet<Book> Books { get; set; }
    public DbSet<UserBook> UserBooks { get; set; }
    public DbSet<AppSetting> AppSettings { get; set; }
    public DbSet<Transaction> Transactions { get; set; }
    public DbSet<Author> Authors { get; set; }
    public DbSet<Category> Categories { get; set; }
    public DbSet<BookAuthor> BookAuthors { get; set; }
    public DbSet<BookCategory> BookCategories { get; set; }
    public DbSet<Conversation> Conversations { get; set; }
    public DbSet<Message> Messages { get; set; }
    public DbSet<AuthToken> AuthTokens { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Book configuration
        modelBuilder.Entity<Book>()
            .HasKey(b => b.ISBN);

        // AppSetting configuration
        modelBuilder.Entity<AppSetting>()
            .HasKey(s => s.SettingKey);

        // UserBook relationships
        modelBuilder.Entity<UserBook>()
            .HasKey(ub => ub.Id);

        modelBuilder.Entity<UserBook>()
            .HasOne(ub => ub.User)
            .WithMany(u => u.UserBooks)
            .HasForeignKey(ub => ub.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<UserBook>()
            .HasOne(ub => ub.Book)
            .WithMany(b => b.UserBooks)
            .HasForeignKey(ub => ub.ISBN)
            .OnDelete(DeleteBehavior.Cascade);

        // Create unique constraint: user can have one entry per ISBN+Condition combination
        // But this allows duplicates if AllowDuplicateBooks is true
        modelBuilder.Entity<UserBook>()
            .HasIndex(ub => new { ub.UserId, ub.ISBN, ub.Condition })
            .IsUnique();

        // Transaction relationships - NoAction to avoid multiple cascade paths
        modelBuilder.Entity<Transaction>()
            .HasOne(t => t.Sender)
            .WithMany()
            .HasForeignKey(t => t.SenderId)
            .OnDelete(DeleteBehavior.NoAction);

        modelBuilder.Entity<Transaction>()
            .HasOne(t => t.Receiver)
            .WithMany()
            .HasForeignKey(t => t.ReceiverId)
            .OnDelete(DeleteBehavior.NoAction);

        // Prefer linking transactions to a specific UserBook (inventory record)
        modelBuilder.Entity<Transaction>()
            .HasOne(t => t.UserBook)
            .WithMany()
            .HasForeignKey(t => t.UserBookId)
            .OnDelete(DeleteBehavior.NoAction);

        // For trades we may reference the sender's UserBook record as well
        modelBuilder.Entity<Transaction>()
            .HasOne(t => t.SenderUserBook)
            .WithMany()
            .HasForeignKey(t => t.SenderUserBookId)
            .OnDelete(DeleteBehavior.NoAction);

        // Authors/Categories relationships
        modelBuilder.Entity<Author>().HasKey(a => a.Id);
        modelBuilder.Entity<Category>().HasKey(c => c.Id);

        modelBuilder.Entity<BookAuthor>()
            .HasKey(ba => new { ba.BookISBN, ba.AuthorId });
        modelBuilder.Entity<BookAuthor>()
            .HasOne(ba => ba.Book)
            .WithMany(b => b.BookAuthors)
            .HasForeignKey(ba => ba.BookISBN)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<BookCategory>()
            .HasKey(bc => new { bc.BookISBN, bc.CategoryId });
        modelBuilder.Entity<BookCategory>()
            .HasOne(bc => bc.Book)
            .WithMany(b => b.BookCategories)
            .HasForeignKey(bc => bc.BookISBN)
            .OnDelete(DeleteBehavior.Cascade);

        // Conversation relationships
        modelBuilder.Entity<Conversation>()
            .HasOne(c => c.Initiator)
            .WithMany()
            .HasForeignKey(c => c.InitiatorId)
            .OnDelete(DeleteBehavior.NoAction);

        modelBuilder.Entity<Conversation>()
            .HasOne(c => c.Receiver)
            .WithMany()
            .HasForeignKey(c => c.ReceiverId)
            .OnDelete(DeleteBehavior.NoAction);

        modelBuilder.Entity<Conversation>()
            .HasOne(c => c.Book)
            .WithMany()
            .HasForeignKey(c => c.BookISBN)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.SetNull);

        modelBuilder.Entity<Conversation>()
            .HasOne(c => c.Transaction)
            .WithMany()
            .HasForeignKey(c => c.TransactionId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.NoAction);

        // User unique email constraint
        modelBuilder.Entity<User>()
            .HasIndex(u => u.Email)
            .IsUnique();

        // AuthToken relationships
        modelBuilder.Entity<AuthToken>()
            .HasOne(at => at.User)
            .WithMany(u => u.AuthTokens)
            .HasForeignKey(at => at.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // Message relationships
        modelBuilder.Entity<Message>()
            .HasOne(m => m.Conversation)
            .WithMany(c => c.Messages)
            .HasForeignKey(m => m.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Message>()
            .HasOne(m => m.Sender)
            .WithMany()
            .HasForeignKey(m => m.SenderId)
            .OnDelete(DeleteBehavior.NoAction);
    }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        base.OnConfiguring(optionsBuilder);
        // Warning configuration for EF Core 8.0 compatibility
        optionsBuilder.ConfigureWarnings(w => 
            w.Ignore(Microsoft.EntityFrameworkCore.Diagnostics.CoreEventId.DetachedLazyLoadingWarning));
    }
}
