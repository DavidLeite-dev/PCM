-- Destructive reset script: drops and recreates only targeted tables.
-- KEEP the Users table intact (only users data is preserved).
-- Run with caution in development only.
--
-- Usage (sqlcmd):
--   sqlcmd -S . -d BookSwap -E -i "BookSwapAPI\sql\reset_destructive.sql"

SET NOCOUNT ON;

BEGIN TRANSACTION;


-- Drop dependents first (FK order)
IF OBJECT_ID('dbo.Messages','U') IS NOT NULL DROP TABLE dbo.Messages;
IF OBJECT_ID('dbo.Conversations','U') IS NOT NULL DROP TABLE dbo.Conversations;
IF OBJECT_ID('dbo.Transactions','U') IS NOT NULL DROP TABLE dbo.Transactions;
IF OBJECT_ID('dbo.UserBooks','U') IS NOT NULL DROP TABLE dbo.UserBooks;
IF OBJECT_ID('dbo.BookAuthors','U') IS NOT NULL DROP TABLE dbo.BookAuthors;
IF OBJECT_ID('dbo.BookCategories','U') IS NOT NULL DROP TABLE dbo.BookCategories;
IF OBJECT_ID('dbo.Books','U') IS NOT NULL DROP TABLE dbo.Books;
IF OBJECT_ID('dbo.Authors','U') IS NOT NULL DROP TABLE dbo.Authors;
IF OBJECT_ID('dbo.Categories','U') IS NOT NULL DROP TABLE dbo.Categories;
IF OBJECT_ID('dbo.AuthTokens','U') IS NOT NULL DROP TABLE dbo.AuthTokens;
IF OBJECT_ID('dbo.AppSettings','U') IS NOT NULL DROP TABLE dbo.AppSettings;
-- ── AuthTokens ──────────────────────────────────────────────────────────────
CREATE TABLE dbo.AuthTokens (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL,
    TokenHash NVARCHAR(64) NOT NULL,
    ExpiresAt DATETIME2 NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_AuthTokens_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id) ON DELETE CASCADE,
    CONSTRAINT UQ_AuthTokens_TokenHash UNIQUE (TokenHash)
);

-- ── AppSettings ──────────────────────────────────────────────────────────────
CREATE TABLE dbo.AppSettings (
    SettingKey NVARCHAR(450) NOT NULL PRIMARY KEY,
    SettingValue NVARCHAR(MAX) NOT NULL,
    Description NVARCHAR(MAX) NOT NULL DEFAULT '',
    LastModified DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- ── Authors ─────────────────────────────────────────────────────────────────
CREATE TABLE dbo.Authors (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    OpenLibraryId NVARCHAR(100) NULL,
    Bio NVARCHAR(MAX) NULL
);

-- ── Categories ──────────────────────────────────────────────────────────────
CREATE TABLE dbo.Categories (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX) NULL
);

-- ── Books (catalog cache) ────────────────────────────────────────────────────
CREATE TABLE dbo.Books (
    ISBN NVARCHAR(20) NOT NULL PRIMARY KEY,
    Title NVARCHAR(1000) NOT NULL,
    Authors NVARCHAR(1000) NOT NULL DEFAULT '',
    Genre NVARCHAR(200) NOT NULL DEFAULT '',
    Tags NVARCHAR(MAX) NOT NULL DEFAULT '',
    Description NVARCHAR(MAX) NULL,
    Publisher NVARCHAR(500) NULL,
    PublicationYear INT NULL,
    CoverImageUrl NVARCHAR(1000) NULL,
    LastUpdatedFromOpenLibrary DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- ── Join tables ──────────────────────────────────────────────────────────────
CREATE TABLE dbo.BookAuthors (
    BookISBN NVARCHAR(20) NOT NULL,
    AuthorId INT NOT NULL,
    CONSTRAINT PK_BookAuthors PRIMARY KEY (BookISBN, AuthorId),
    CONSTRAINT FK_BookAuthors_Books FOREIGN KEY (BookISBN) REFERENCES dbo.Books(ISBN) ON DELETE CASCADE,
    CONSTRAINT FK_BookAuthors_Authors FOREIGN KEY (AuthorId) REFERENCES dbo.Authors(Id) ON DELETE CASCADE
);

CREATE TABLE dbo.BookCategories (
    BookISBN NVARCHAR(20) NOT NULL,
    CategoryId INT NOT NULL,
    CONSTRAINT PK_BookCategories PRIMARY KEY (BookISBN, CategoryId),
    CONSTRAINT FK_BookCategories_Books FOREIGN KEY (BookISBN) REFERENCES dbo.Books(ISBN) ON DELETE CASCADE,
    CONSTRAINT FK_BookCategories_Categories FOREIGN KEY (CategoryId) REFERENCES dbo.Categories(Id) ON DELETE CASCADE
);

-- ── UserBooks (inventory) ────────────────────────────────────────────────────
CREATE TABLE dbo.UserBooks (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL,
    ISBN NVARCHAR(20) NOT NULL,
    Condition NVARCHAR(50) NOT NULL DEFAULT 'novo',
    Quantity INT NOT NULL DEFAULT 1,
    Available BIT NOT NULL DEFAULT 1,
    Emprestado BIT NOT NULL DEFAULT 0,
    DateAdded DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_UserBooks_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id) ON DELETE NO ACTION,
    CONSTRAINT FK_UserBooks_Books FOREIGN KEY (ISBN) REFERENCES dbo.Books(ISBN) ON DELETE NO ACTION,
    CONSTRAINT UQ_UserBooks_User_ISBN_Condition UNIQUE (UserId, ISBN, Condition)
);

-- ── Transactions ─────────────────────────────────────────────────────────────
CREATE TABLE dbo.Transactions (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    Type NVARCHAR(100) NOT NULL,
    Status NVARCHAR(100) NOT NULL,
    Notes NVARCHAR(MAX) NULL,
    UserBookId INT NULL,
    SenderUserBookId INT NULL,
    SenderId INT NOT NULL,
    ReceiverId INT NOT NULL,
    Price DECIMAL(10,2) NULL,
    CONSTRAINT FK_Transactions_UserBook FOREIGN KEY (UserBookId) REFERENCES dbo.UserBooks(Id) ON DELETE NO ACTION,
    CONSTRAINT FK_Transactions_SenderUserBook FOREIGN KEY (SenderUserBookId) REFERENCES dbo.UserBooks(Id) ON DELETE NO ACTION,
    CONSTRAINT FK_Transactions_Sender FOREIGN KEY (SenderId) REFERENCES dbo.Users(Id) ON DELETE NO ACTION,
    CONSTRAINT FK_Transactions_Receiver FOREIGN KEY (ReceiverId) REFERENCES dbo.Users(Id) ON DELETE NO ACTION
);

-- ── Conversations ────────────────────────────────────────────────────────────
CREATE TABLE dbo.Conversations (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    InitiatorId INT NOT NULL,
    ReceiverId INT NOT NULL,
    BookISBN NVARCHAR(20) NULL,
    TransactionId INT NULL,
    Status NVARCHAR(100) NOT NULL DEFAULT 'active',
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    LastMessageAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    ArchivedAt DATETIME2 NULL,
    CONSTRAINT FK_Conversations_Initiator FOREIGN KEY (InitiatorId) REFERENCES dbo.Users(Id) ON DELETE NO ACTION,
    CONSTRAINT FK_Conversations_Receiver FOREIGN KEY (ReceiverId) REFERENCES dbo.Users(Id) ON DELETE NO ACTION,
    CONSTRAINT FK_Conversations_Book FOREIGN KEY (BookISBN) REFERENCES dbo.Books(ISBN) ON DELETE SET NULL,
    CONSTRAINT FK_Conversations_Transaction FOREIGN KEY (TransactionId) REFERENCES dbo.Transactions(Id) ON DELETE NO ACTION
);

-- ── Messages ─────────────────────────────────────────────────────────────────
CREATE TABLE dbo.Messages (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ConversationId INT NOT NULL,
    SenderId INT NOT NULL,
    Content NVARCHAR(MAX) NOT NULL,
    SentAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    IsRead BIT NOT NULL DEFAULT 0,
    CONSTRAINT FK_Messages_Conversation FOREIGN KEY (ConversationId) REFERENCES dbo.Conversations(Id) ON DELETE CASCADE,
    CONSTRAINT FK_Messages_Sender FOREIGN KEY (SenderId) REFERENCES dbo.Users(Id) ON DELETE NO ACTION
);

-- Clear migration history so EF doesn't complain about stale entries
IF OBJECT_ID('dbo.__EFMigrationsHistory','U') IS NOT NULL
    DELETE FROM dbo.__EFMigrationsHistory;

COMMIT TRANSACTION;

PRINT 'Destructive reset complete. Users table was NOT modified.';
