-- ──────────────────────────────────────────────────────────────────────────────
-- BookSwapAPI/sql/create_tables.sql
-- Full schema creation — run this once on a brand-new, empty BookSwap database.
-- For an existing database use reset_destructive.sql instead.
--
-- Table order respects FK dependencies (parents before children).
--
-- Usage (sqlcmd):
--   sqlcmd -S . -d BookSwap -E -i "BookSwapAPI\sql\create_tables.sql"
-- ──────────────────────────────────────────────────────────────────────────────

-- ── AppSettings (no dependencies) ────────────────────────────────────────────
CREATE TABLE dbo.AppSettings (
    SettingKey   NVARCHAR(450) NOT NULL,
    SettingValue NVARCHAR(MAX) NOT NULL,
    Description  NVARCHAR(MAX) NOT NULL DEFAULT '',
    LastModified DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_AppSettings PRIMARY KEY (SettingKey)
);

-- ── Authors (no dependencies) ─────────────────────────────────────────────────
CREATE TABLE dbo.Authors (
    Id            INT           NOT NULL IDENTITY(1,1),
    Name          NVARCHAR(200) NOT NULL,
    OpenLibraryId NVARCHAR(100) NULL,
    Bio           NVARCHAR(MAX) NULL,
    CONSTRAINT PK_Authors PRIMARY KEY (Id)
);

-- ── Categories (no dependencies) ──────────────────────────────────────────────
CREATE TABLE dbo.Categories (
    Id          INT           NOT NULL IDENTITY(1,1),
    Name        NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    CONSTRAINT PK_Categories PRIMARY KEY (Id)
);

-- ── Books (no dependencies) ───────────────────────────────────────────────────
CREATE TABLE dbo.Books (
    ISBN                       NVARCHAR(20)   NOT NULL,
    Title                      NVARCHAR(1000) NOT NULL,
    Authors                    NVARCHAR(1000) NOT NULL DEFAULT '',
    Genre                      NVARCHAR(200)  NOT NULL DEFAULT '',
    Tags                       NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Description                NVARCHAR(MAX)  NULL,
    Publisher                  NVARCHAR(500)  NULL,
    PublicationYear            INT            NULL,
    CoverImageUrl              NVARCHAR(1000) NULL,
    LastUpdatedFromOpenLibrary DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Books PRIMARY KEY (ISBN)
);

-- ── Users (no dependencies) ───────────────────────────────────────────────────
CREATE TABLE dbo.Users (
    Id        INT           NOT NULL IDENTITY(1,1),
    Name      NVARCHAR(MAX) NOT NULL,
    Email     NVARCHAR(450) NOT NULL,
    Password  NVARCHAR(MAX) NOT NULL,
    Phone     NVARCHAR(MAX) NOT NULL,
    Address   NVARCHAR(MAX) NOT NULL,
    IsAdmin   BIT           NOT NULL DEFAULT 0,
    CreatedAt DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Users PRIMARY KEY (Id)
);
CREATE UNIQUE INDEX IX_Users_Email ON dbo.Users (Email);

-- ── BookAuthors (depends on Books, Authors) ───────────────────────────────────
CREATE TABLE dbo.BookAuthors (
    BookISBN NVARCHAR(20) NOT NULL,
    AuthorId INT          NOT NULL,
    CONSTRAINT PK_BookAuthors          PRIMARY KEY (BookISBN, AuthorId),
    CONSTRAINT FK_BookAuthors_Books    FOREIGN KEY (BookISBN) REFERENCES dbo.Books(ISBN)   ON DELETE CASCADE,
    CONSTRAINT FK_BookAuthors_Authors  FOREIGN KEY (AuthorId) REFERENCES dbo.Authors(Id)   ON DELETE CASCADE
);
CREATE INDEX IX_BookAuthors_AuthorId ON dbo.BookAuthors (AuthorId);

-- ── BookCategories (depends on Books, Categories) ─────────────────────────────
CREATE TABLE dbo.BookCategories (
    BookISBN   NVARCHAR(20) NOT NULL,
    CategoryId INT          NOT NULL,
    CONSTRAINT PK_BookCategories            PRIMARY KEY (BookISBN, CategoryId),
    CONSTRAINT FK_BookCategories_Books      FOREIGN KEY (BookISBN)   REFERENCES dbo.Books(ISBN)      ON DELETE CASCADE,
    CONSTRAINT FK_BookCategories_Categories FOREIGN KEY (CategoryId) REFERENCES dbo.Categories(Id)   ON DELETE CASCADE
);
CREATE INDEX IX_BookCategories_CategoryId ON dbo.BookCategories (CategoryId);

-- ── AuthTokens (depends on Users) ────────────────────────────────────────────
CREATE TABLE dbo.AuthTokens (
    Id        INT           NOT NULL IDENTITY(1,1),
    UserId    INT           NOT NULL,
    TokenHash NVARCHAR(64)  NOT NULL,
    ExpiresAt DATETIME2     NOT NULL,
    CreatedAt DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_AuthTokens          PRIMARY KEY (Id),
    CONSTRAINT FK_AuthTokens_Users    FOREIGN KEY (UserId) REFERENCES dbo.Users(Id) ON DELETE CASCADE,
    CONSTRAINT UQ_AuthTokens_TokenHash UNIQUE (TokenHash)
);
CREATE INDEX IX_AuthTokens_UserId ON dbo.AuthTokens (UserId);

-- ── UserBooks (depends on Users, Books) ───────────────────────────────────────
CREATE TABLE dbo.UserBooks (
    Id         INT           NOT NULL IDENTITY(1,1),
    UserId     INT           NOT NULL,
    ISBN       NVARCHAR(20)  NOT NULL,
    Condition  NVARCHAR(50)  NOT NULL DEFAULT 'novo',
    Quantity   INT           NOT NULL DEFAULT 1,
    Available  BIT           NOT NULL DEFAULT 1,
    Emprestado BIT           NOT NULL DEFAULT 0,
    DateAdded  DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    IsActive   BIT           NOT NULL DEFAULT 1,
    CONSTRAINT PK_UserBooks              PRIMARY KEY (Id),
    CONSTRAINT FK_UserBooks_Users        FOREIGN KEY (UserId) REFERENCES dbo.Users(Id)  ON DELETE NO ACTION,
    CONSTRAINT FK_UserBooks_Books        FOREIGN KEY (ISBN)   REFERENCES dbo.Books(ISBN) ON DELETE NO ACTION,
    CONSTRAINT UQ_UserBooks_User_ISBN_Condition UNIQUE (UserId, ISBN, Condition)
);
CREATE INDEX IX_UserBooks_ISBN   ON dbo.UserBooks (ISBN);
CREATE INDEX IX_UserBooks_UserId ON dbo.UserBooks (UserId);

-- ── Transactions (depends on UserBooks, Users) ────────────────────────────────
CREATE TABLE dbo.Transactions (
    Id               INT           NOT NULL IDENTITY(1,1),
    CreatedAt        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    Type             NVARCHAR(100) NOT NULL,
    Status           NVARCHAR(100) NOT NULL,
    Notes            NVARCHAR(MAX) NULL,
    UserBookId       INT           NULL,
    SenderUserBookId INT           NULL,
    SenderId         INT           NOT NULL,
    ReceiverId       INT           NOT NULL,
    Price            DECIMAL(10,2) NULL,
    CONSTRAINT PK_Transactions                 PRIMARY KEY (Id),
    CONSTRAINT FK_Transactions_UserBook        FOREIGN KEY (UserBookId)       REFERENCES dbo.UserBooks(Id) ON DELETE NO ACTION,
    CONSTRAINT FK_Transactions_SenderUserBook  FOREIGN KEY (SenderUserBookId) REFERENCES dbo.UserBooks(Id) ON DELETE NO ACTION,
    CONSTRAINT FK_Transactions_Sender          FOREIGN KEY (SenderId)         REFERENCES dbo.Users(Id)     ON DELETE NO ACTION,
    CONSTRAINT FK_Transactions_Receiver        FOREIGN KEY (ReceiverId)       REFERENCES dbo.Users(Id)     ON DELETE NO ACTION
);
CREATE INDEX IX_Transactions_SenderId         ON dbo.Transactions (SenderId);
CREATE INDEX IX_Transactions_ReceiverId       ON dbo.Transactions (ReceiverId);
CREATE INDEX IX_Transactions_UserBookId       ON dbo.Transactions (UserBookId);
CREATE INDEX IX_Transactions_SenderUserBookId ON dbo.Transactions (SenderUserBookId);

-- ── Conversations (depends on Books, Transactions, Users) ─────────────────────
CREATE TABLE dbo.Conversations (
    Id            INT           NOT NULL IDENTITY(1,1),
    InitiatorId   INT           NOT NULL,
    ReceiverId    INT           NOT NULL,
    BookISBN      NVARCHAR(20)  NULL,
    TransactionId INT           NULL,
    Status        NVARCHAR(100) NOT NULL DEFAULT 'active',
    CreatedAt     DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    LastMessageAt DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    ArchivedAt    DATETIME2     NULL,
    CONSTRAINT PK_Conversations              PRIMARY KEY (Id),
    CONSTRAINT FK_Conversations_Initiator    FOREIGN KEY (InitiatorId)   REFERENCES dbo.Users(Id)         ON DELETE NO ACTION,
    CONSTRAINT FK_Conversations_Receiver     FOREIGN KEY (ReceiverId)    REFERENCES dbo.Users(Id)         ON DELETE NO ACTION,
    CONSTRAINT FK_Conversations_Book         FOREIGN KEY (BookISBN)      REFERENCES dbo.Books(ISBN)       ON DELETE SET NULL,
    CONSTRAINT FK_Conversations_Transaction  FOREIGN KEY (TransactionId) REFERENCES dbo.Transactions(Id)  ON DELETE NO ACTION
);
CREATE INDEX IX_Conversations_InitiatorId   ON dbo.Conversations (InitiatorId);
CREATE INDEX IX_Conversations_ReceiverId    ON dbo.Conversations (ReceiverId);
CREATE INDEX IX_Conversations_BookISBN      ON dbo.Conversations (BookISBN);
CREATE INDEX IX_Conversations_TransactionId ON dbo.Conversations (TransactionId);

-- ── Messages (depends on Conversations, Users) ────────────────────────────────
CREATE TABLE dbo.Messages (
    Id             INT           NOT NULL IDENTITY(1,1),
    ConversationId INT           NOT NULL,
    SenderId       INT           NOT NULL,
    Content        NVARCHAR(MAX) NOT NULL,
    SentAt         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    IsRead         BIT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_Messages              PRIMARY KEY (Id),
    CONSTRAINT FK_Messages_Conversation FOREIGN KEY (ConversationId) REFERENCES dbo.Conversations(Id) ON DELETE CASCADE,
    CONSTRAINT FK_Messages_Sender       FOREIGN KEY (SenderId)       REFERENCES dbo.Users(Id)         ON DELETE NO ACTION
);
CREATE INDEX IX_Messages_ConversationId ON dbo.Messages (ConversationId);
CREATE INDEX IX_Messages_SenderId       ON dbo.Messages (SenderId);
