// ═══════════════════════════════════════════════════════════════════════════════
// FILE: Data/BookSwapDbContext.cs
// PURPOSE: EF Core database context — declares all tables and configures relationships.
//
// QUICK REFERENCE  (DbSet = one SQL table)
//   Users          → registered users
//   Books          → catalog of book titles (keyed by ISBN)
//   UserBooks      → user's copy of a book (condition + quantity) — the "listing"
//   AuthTokens     → active session tokens (hashed)
//   Transactions   → buy / borrow / trade requests between users
//   Conversations  → chat threads linked to a transaction + book
//   Messages       → individual chat messages within a conversation
//   AppSettings    → key-value config table (e.g. AllowDuplicateBooks)
//   Authors        → normalised author entities (linked via BookAuthors)
//   Categories     → normalised category entities (linked via BookCategories)
//   BookAuthors    → many-to-many: Book ↔ Author
//   BookCategories → many-to-many: Book ↔ Category
//
// KEY RELATIONSHIPS
//   UserBook  → User (cascade delete)
//   UserBook  → Book (cascade delete)
//   UserBook  unique index: (UserId, ISBN, Condition) — one entry per user/book/condition
//   Transaction → Sender (NoAction), Receiver (NoAction) — avoids multiple cascade paths
//   Transaction → UserBook (optional), SenderUserBook (optional)
//   Conversation → Initiator, Receiver (NoAction)
//   Conversation → Book (SetNull on delete), Transaction (NoAction)
//   Message → Conversation (cascade), Sender (NoAction)
//   AuthToken → User (cascade)
//   User.Email → unique index
// ═══════════════════════════════════════════════════════════════════════════════

using Microsoft.EntityFrameworkCore;
using BookSwapAPI.Models;

namespace BookSwapAPI.Data;

public class BookSwapDbContext : DbContext
{
    public BookSwapDbContext(DbContextOptions<BookSwapDbContext> options) : base(options)
    {
    }

    // ─── Tables (DbSets) ──────────────────────────────────────────────────────
    public DbSet<User>         Users          { get; set; }
    public DbSet<Book>         Books          { get; set; }
    public DbSet<UserBook>     UserBooks      { get; set; } // Each user's copy of a book
    public DbSet<AppSetting>   AppSettings    { get; set; }
    public DbSet<Transaction>  Transactions   { get; set; }
    public DbSet<Author>       Authors        { get; set; }
    public DbSet<Category>     Categories     { get; set; }
    public DbSet<BookAuthor>   BookAuthors    { get; set; }
    public DbSet<BookCategory> BookCategories { get; set; }
    public DbSet<Conversation> Conversations  { get; set; }
    public DbSet<Message>      Messages       { get; set; }
    public DbSet<AuthToken>    AuthTokens     { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // ── Book: keyed by ISBN (string PK instead of int) ───────────────────
        modelBuilder.Entity<Book>()
            .HasKey(b => b.ISBN);

        // ── AppSetting: keyed by setting name (string PK) ────────────────────
        modelBuilder.Entity<AppSetting>()
            .HasKey(s => s.SettingKey);

        // ── UserBook: user's copy of a book ───────────────────────────────────
        modelBuilder.Entity<UserBook>()
            .HasKey(ub => ub.Id);

        // Each UserBook belongs to one User
        modelBuilder.Entity<UserBook>()
            .HasOne(ub => ub.User)
            .WithMany(u => u.UserBooks)
            .HasForeignKey(ub => ub.UserId)
            .OnDelete(DeleteBehavior.Cascade); // Delete UserBooks when User is deleted

        // Each UserBook references one Book catalog entry
        modelBuilder.Entity<UserBook>()
            .HasOne(ub => ub.Book)
            .WithMany(b => b.UserBooks)
            .HasForeignKey(ub => ub.ISBN)
            .OnDelete(DeleteBehavior.Cascade); // Delete UserBooks when Book is deleted

        // Unique constraint: one entry per (User, ISBN, Condition) combination.
        // A user can have the same book in different conditions (novo + usado)
        // but not two entries for the same condition.
        modelBuilder.Entity<UserBook>()
            .HasIndex(ub => new { ub.UserId, ub.ISBN, ub.Condition })
            .IsUnique();

        // ── Transaction: buy/borrow/trade request ─────────────────────────────
        // NoAction on both FK relations to avoid the "multiple cascade paths" SQL Server error.
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

        // Receiver's UserBook (the book being requested)
        modelBuilder.Entity<Transaction>()
            .HasOne(t => t.UserBook)
            .WithMany()
            .HasForeignKey(t => t.UserBookId)
            .OnDelete(DeleteBehavior.NoAction);

        // Sender's UserBook (only set for Trade transactions — the book offered in exchange)
        modelBuilder.Entity<Transaction>()
            .HasOne(t => t.SenderUserBook)
            .WithMany()
            .HasForeignKey(t => t.SenderUserBookId)
            .OnDelete(DeleteBehavior.NoAction);

        // ── Author / Category (normalised lookup tables) ───────────────────────
        modelBuilder.Entity<Author>().HasKey(a => a.Id);
        modelBuilder.Entity<Category>().HasKey(c => c.Id);

        // Book ↔ Author many-to-many via BookAuthors join table
        modelBuilder.Entity<BookAuthor>()
            .HasKey(ba => new { ba.BookISBN, ba.AuthorId });
        modelBuilder.Entity<BookAuthor>()
            .HasOne(ba => ba.Book)
            .WithMany(b => b.BookAuthors)
            .HasForeignKey(ba => ba.BookISBN)
            .OnDelete(DeleteBehavior.Cascade);

        // Book ↔ Category many-to-many via BookCategories join table
        modelBuilder.Entity<BookCategory>()
            .HasKey(bc => new { bc.BookISBN, bc.CategoryId });
        modelBuilder.Entity<BookCategory>()
            .HasOne(bc => bc.Book)
            .WithMany(b => b.BookCategories)
            .HasForeignKey(bc => bc.BookISBN)
            .OnDelete(DeleteBehavior.Cascade);

        // ── Conversation: chat thread between two users about a book ───────────
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

        // Book reference is optional (conversation can exist without a book)
        modelBuilder.Entity<Conversation>()
            .HasOne(c => c.Book)
            .WithMany()
            .HasForeignKey(c => c.BookISBN)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.SetNull); // Nullify FK if book is deleted

        // Transaction reference is optional (conversation can be opened before a transaction)
        modelBuilder.Entity<Conversation>()
            .HasOne(c => c.Transaction)
            .WithMany()
            .HasForeignKey(c => c.TransactionId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.NoAction);

        // ── User: unique email ─────────────────────────────────────────────────
        modelBuilder.Entity<User>()
            .HasIndex(u => u.Email)
            .IsUnique();

        // ── AuthToken: linked to one user; deleted when user is deleted ────────
        modelBuilder.Entity<AuthToken>()
            .HasOne(at => at.User)
            .WithMany(u => u.AuthTokens)
            .HasForeignKey(at => at.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // ── Message: belongs to a Conversation, sent by a User ────────────────
        modelBuilder.Entity<Message>()
            .HasOne(m => m.Conversation)
            .WithMany(c => c.Messages)
            .HasForeignKey(m => m.ConversationId)
            .OnDelete(DeleteBehavior.Cascade); // Delete messages when conversation is deleted

        modelBuilder.Entity<Message>()
            .HasOne(m => m.Sender)
            .WithMany()
            .HasForeignKey(m => m.SenderId)
            .OnDelete(DeleteBehavior.NoAction);
    }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        base.OnConfiguring(optionsBuilder);
        // Suppress EF Core 8 lazy-loading warning — we use explicit .Include() everywhere
        optionsBuilder.ConfigureWarnings(w =>
            w.Ignore(Microsoft.EntityFrameworkCore.Diagnostics.CoreEventId.DetachedLazyLoadingWarning));
    }
}
