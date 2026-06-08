-- BookSwap Database - Full Schema Creation
-- Run this on an empty BookSwap database.

-- AppSettings (no dependencies)
CREATE TABLE AppSettings (
    SettingKey   NVARCHAR(450) NOT NULL,
    SettingValue NVARCHAR(MAX) NOT NULL,
    Description  NVARCHAR(MAX) NOT NULL,
    LastModified DATETIME2     NOT NULL,
    CONSTRAINT PK_AppSettings PRIMARY KEY (SettingKey)
);

-- Authors (no dependencies)
CREATE TABLE Authors (
    Id            INT           NOT NULL IDENTITY(1,1),
    Name          NVARCHAR(MAX) NOT NULL,
    OpenLibraryId NVARCHAR(MAX) NULL,
    Bio           NVARCHAR(MAX) NULL,
    CONSTRAINT PK_Authors PRIMARY KEY (Id)
);

-- Books (no dependencies)
CREATE TABLE Books (
    ISBN                        NVARCHAR(450) NOT NULL,
    Title                       NVARCHAR(MAX) NOT NULL,
    Authors                     NVARCHAR(MAX) NOT NULL,
    Genre                       NVARCHAR(MAX) NOT NULL,
    Tags                        NVARCHAR(MAX) NOT NULL,
    Description                 NVARCHAR(MAX) NOT NULL,
    Publisher                   NVARCHAR(MAX) NOT NULL,
    PublicationYear             INT           NULL,
    CoverImageUrl               NVARCHAR(MAX) NOT NULL,
    LastUpdatedFromOpenLibrary  DATETIME2     NOT NULL,
    CONSTRAINT PK_Books PRIMARY KEY (ISBN)
);

-- Categories (no dependencies)
CREATE TABLE Categories (
    Id   INT           NOT NULL IDENTITY(1,1),
    Name NVARCHAR(MAX) NOT NULL,
    CONSTRAINT PK_Categories PRIMARY KEY (Id)
);

-- Users (no dependencies)
CREATE TABLE Users (
    Id        INT           NOT NULL IDENTITY(1,1),
    Name      NVARCHAR(MAX) NOT NULL,
    Email     NVARCHAR(MAX) NOT NULL,
    Password  NVARCHAR(MAX) NOT NULL,
    Phone     NVARCHAR(MAX) NOT NULL,
    Address   NVARCHAR(MAX) NOT NULL,
    IsAdmin   BIT           NOT NULL,
    CreatedAt DATETIME2     NOT NULL,
    UpdatedAt DATETIME2     NOT NULL,
    CONSTRAINT PK_Users PRIMARY KEY (Id)
);

-- BookAuthors (depends on Books, Authors)
CREATE TABLE BookAuthors (
    BookISBN NVARCHAR(450) NOT NULL,
    AuthorId INT           NOT NULL,
    CONSTRAINT PK_BookAuthors      PRIMARY KEY (BookISBN, AuthorId),
    CONSTRAINT FK_BookAuthors_Books   FOREIGN KEY (BookISBN) REFERENCES Books(ISBN)   ON DELETE CASCADE,
    CONSTRAINT FK_BookAuthors_Authors FOREIGN KEY (AuthorId) REFERENCES Authors(Id)   ON DELETE CASCADE
);
CREATE INDEX IX_BookAuthors_AuthorId ON BookAuthors(AuthorId);

-- BookCategories (depends on Books, Categories)
CREATE TABLE BookCategories (
    BookISBN   NVARCHAR(450) NOT NULL,
    CategoryId INT           NOT NULL,
    CONSTRAINT PK_BookCategories        PRIMARY KEY (BookISBN, CategoryId),
    CONSTRAINT FK_BookCategories_Books      FOREIGN KEY (BookISBN)   REFERENCES Books(ISBN)      ON DELETE CASCADE,
    CONSTRAINT FK_BookCategories_Categories FOREIGN KEY (CategoryId) REFERENCES Categories(Id)   ON DELETE CASCADE
);
CREATE INDEX IX_BookCategories_CategoryId ON BookCategories(CategoryId);

-- AuthTokens (depends on Users)
CREATE TABLE AuthTokens (
    Id        INT           NOT NULL IDENTITY(1,1),
    UserId    INT           NOT NULL,
    TokenHash NVARCHAR(MAX) NOT NULL,
    ExpiresAt DATETIME2     NOT NULL,
    CreatedAt DATETIME2     NOT NULL,
    CONSTRAINT PK_AuthTokens       PRIMARY KEY (Id),
    CONSTRAINT FK_AuthTokens_Users FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE
);
CREATE INDEX IX_AuthTokens_UserId ON AuthTokens(UserId);

-- UserBooks (depends on Users, Books)
CREATE TABLE UserBooks (
    Id        INT           NOT NULL IDENTITY(1,1),
    UserId    INT           NOT NULL,
    ISBN      NVARCHAR(450) NOT NULL,
    Condition NVARCHAR(450) NOT NULL,
    Quantity  INT           NOT NULL,
    Available BIT           NOT NULL,
    Emprestado BIT          NOT NULL,
    DateAdded DATETIME2     NOT NULL,
    IsActive  BIT           NOT NULL,
    CONSTRAINT PK_UserBooks       PRIMARY KEY (Id),
    CONSTRAINT FK_UserBooks_Users FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE,
    CONSTRAINT FK_UserBooks_Books FOREIGN KEY (ISBN)   REFERENCES Books(ISBN) ON DELETE CASCADE
);
CREATE INDEX IX_UserBooks_ISBN ON UserBooks(ISBN);
CREATE UNIQUE INDEX IX_UserBooks_UserId_ISBN_Condition ON UserBooks(UserId, ISBN, Condition);

-- Transactions (depends on UserBooks, Users)
CREATE TABLE Transactions (
    Id               INT            NOT NULL IDENTITY(1,1),
    CreatedAt        DATETIME2      NOT NULL,
    UpdatedAt        DATETIME2      NOT NULL,
    Type             NVARCHAR(MAX)  NOT NULL,
    Status           NVARCHAR(MAX)  NOT NULL,
    Notes            NVARCHAR(MAX)  NOT NULL,
    UserBookId       INT            NULL,
    SenderUserBookId INT            NULL,
    SenderId         INT            NOT NULL,
    ReceiverId       INT            NOT NULL,
    Price            DECIMAL(18,2)  NULL,
    CONSTRAINT PK_Transactions                 PRIMARY KEY (Id),
    CONSTRAINT FK_Transactions_UserBooks       FOREIGN KEY (UserBookId)       REFERENCES UserBooks(Id),
    CONSTRAINT FK_Transactions_SenderUserBooks FOREIGN KEY (SenderUserBookId) REFERENCES UserBooks(Id),
    CONSTRAINT FK_Transactions_Sender          FOREIGN KEY (SenderId)         REFERENCES Users(Id),
    CONSTRAINT FK_Transactions_Receiver        FOREIGN KEY (ReceiverId)       REFERENCES Users(Id)
);
CREATE INDEX IX_Transactions_SenderId         ON Transactions(SenderId);
CREATE INDEX IX_Transactions_ReceiverId       ON Transactions(ReceiverId);
CREATE INDEX IX_Transactions_UserBookId       ON Transactions(UserBookId);
CREATE INDEX IX_Transactions_SenderUserBookId ON Transactions(SenderUserBookId);

-- Conversations (depends on Books, Transactions, Users)
CREATE TABLE Conversations (
    Id            INT           NOT NULL IDENTITY(1,1),
    InitiatorId   INT           NOT NULL,
    ReceiverId    INT           NOT NULL,
    BookISBN      NVARCHAR(450) NULL,
    TransactionId INT           NULL,
    Status        NVARCHAR(MAX) NOT NULL,
    CreatedAt     DATETIME2     NOT NULL,
    LastMessageAt DATETIME2     NOT NULL,
    ArchivedAt    DATETIME2     NULL,
    CONSTRAINT PK_Conversations               PRIMARY KEY (Id),
    CONSTRAINT FK_Conversations_Initiator     FOREIGN KEY (InitiatorId)   REFERENCES Users(Id),
    CONSTRAINT FK_Conversations_Receiver      FOREIGN KEY (ReceiverId)    REFERENCES Users(Id),
    CONSTRAINT FK_Conversations_Books         FOREIGN KEY (BookISBN)      REFERENCES Books(ISBN)        ON DELETE SET NULL,
    CONSTRAINT FK_Conversations_Transactions  FOREIGN KEY (TransactionId) REFERENCES Transactions(Id)
);
CREATE INDEX IX_Conversations_InitiatorId   ON Conversations(InitiatorId);
CREATE INDEX IX_Conversations_ReceiverId    ON Conversations(ReceiverId);
CREATE INDEX IX_Conversations_BookISBN      ON Conversations(BookISBN);
CREATE INDEX IX_Conversations_TransactionId ON Conversations(TransactionId);

-- Messages (depends on Conversations, Users)
CREATE TABLE Messages (
    Id             INT           NOT NULL IDENTITY(1,1),
    ConversationId INT           NOT NULL,
    SenderId       INT           NOT NULL,
    Content        NVARCHAR(MAX) NOT NULL,
    SentAt         DATETIME2     NOT NULL,
    IsRead         BIT           NOT NULL,
    CONSTRAINT PK_Messages              PRIMARY KEY (Id),
    CONSTRAINT FK_Messages_Conversation FOREIGN KEY (ConversationId) REFERENCES Conversations(Id) ON DELETE CASCADE,
    CONSTRAINT FK_Messages_Sender       FOREIGN KEY (SenderId)       REFERENCES Users(Id)
);
CREATE INDEX IX_Messages_ConversationId ON Messages(ConversationId);
CREATE INDEX IX_Messages_SenderId       ON Messages(SenderId);

CREATE UNIQUE INDEX IX_Users_Email ON Users(Email);
