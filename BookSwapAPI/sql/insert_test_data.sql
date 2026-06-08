-- ================================================================
-- BookSwap – Full Test Data
-- ================================================================
-- Admin:       admin@bookswap.pt  / admin123
-- Test users:  [name]@email.pt    / teste123
--
-- What this creates
--   • 4 new users  (Ana, Pedro, Maria, João)
--   • 12 real books with Open Library cover images
--   • 20 UserBook listings spread across all 5 users
--   • 5 PENDING transactions where ADMIN is the RECEIVER
--       → go to the Admin Panel to accept or deny each one
--       → verify that book ownership switches on acceptance
--   • 4 COMPLETED historical transactions (Confirmada / Rejeitada)
--
-- Safe to re-run: every insert is guarded by IF NOT EXISTS.
-- ================================================================

BEGIN TRANSACTION;

DECLARE @Hash NVARCHAR(MAX) = '$2a$11$EAXtM5sM0Yf7g08YT7L.veaWyFcLr8EMDV7YLQZObr77YQ9UXebhK'; -- teste123
DECLARE @Now  DATETIME2     = GETUTCDATE();

-- ────────────────────────────────────────────────────────────────────
-- 1. USERS
-- ────────────────────────────────────────────────────────────────────

-- Back-fill contact info on the seed admin (required columns may be empty)
UPDATE Users
SET Phone     = CASE WHEN Phone   = '' OR Phone   IS NULL THEN '+351 910 000 001'         ELSE Phone   END,
    Address   = CASE WHEN Address = '' OR Address IS NULL THEN 'Rua do Admin, 1, Lisboa'  ELSE Address END,
    UpdatedAt = @Now
WHERE Email = 'admin@bookswap.pt';

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'ana.silva@email.pt')
    INSERT INTO Users (Name, Email, Password, Phone, Address, IsAdmin, CreatedAt, UpdatedAt)
    VALUES ('Ana Silva', 'ana.silva@email.pt', @Hash,
            '+351 912 345 678', 'Rua das Flores, 22, Porto', 0, DATEADD(day,-30,@Now), @Now);

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'pedro.costa@email.pt')
    INSERT INTO Users (Name, Email, Password, Phone, Address, IsAdmin, CreatedAt, UpdatedAt)
    VALUES ('Pedro Costa', 'pedro.costa@email.pt', @Hash,
            '+351 933 456 789', 'Av. da Liberdade, 55, Lisboa', 0, DATEADD(day,-25,@Now), @Now);

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'maria.ferreira@email.pt')
    INSERT INTO Users (Name, Email, Password, Phone, Address, IsAdmin, CreatedAt, UpdatedAt)
    VALUES ('Maria Ferreira', 'maria.ferreira@email.pt', @Hash,
            '+351 965 678 901', 'Largo do Chiado, 8, Lisboa', 0, DATEADD(day,-20,@Now), @Now);

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'joao.santos@email.pt')
    INSERT INTO Users (Name, Email, Password, Phone, Address, IsAdmin, CreatedAt, UpdatedAt)
    VALUES ('João Santos', 'joao.santos@email.pt', @Hash,
            '+351 914 789 012', 'Rua do Comércio, 14, Coimbra', 0, DATEADD(day,-15,@Now), @Now);

DECLARE @AdminId INT = (SELECT Id FROM Users WHERE Email = 'admin@bookswap.pt');
DECLARE @AnaId   INT = (SELECT Id FROM Users WHERE Email = 'ana.silva@email.pt');
DECLARE @PedroId INT = (SELECT Id FROM Users WHERE Email = 'pedro.costa@email.pt');
DECLARE @MariaId INT = (SELECT Id FROM Users WHERE Email = 'maria.ferreira@email.pt');
DECLARE @JoaoId  INT = (SELECT Id FROM Users WHERE Email = 'joao.santos@email.pt');

-- ────────────────────────────────────────────────────────────────────
-- 2. BOOKS  (12 real titles, real Open Library cover URLs)
-- ────────────────────────────────────────────────────────────────────
MERGE Books AS T
USING (VALUES
  ('9780747532743',
   'Harry Potter and the Philosopher''s Stone', 'J.K. Rowling',
   'Fantasy', 'magic, wizards, Hogwarts, adventure, school',
   'Orphaned as an infant, Harry Potter discovers on his eleventh birthday that he is a wizard and has been accepted to Hogwarts School of Witchcraft and Wizardry. A rich world of magic, friendship, and courage awaits.',
   'Bloomsbury', 1997, 'https://covers.openlibrary.org/b/isbn/9780747532743-L.jpg'),

  ('9780261103252',
   'The Lord of the Rings', 'J.R.R. Tolkien',
   'Fantasy', 'epic, Middle-earth, quest, adventure, mythology',
   'A hobbit named Frodo Baggins must leave the Shire and venture into the perilous world beyond, carrying the One Ring of Power that must be destroyed before it falls into the hands of the Dark Lord Sauron.',
   'Allen & Unwin', 1968, 'https://covers.openlibrary.org/b/isbn/9780261103252-L.jpg'),

  ('9780451524935',
   '1984', 'George Orwell',
   'Dystopian Fiction', 'dystopia, surveillance, totalitarianism, political, classic',
   'In a totalitarian future, Winston Smith secretly rebels against the Party and its omnipresent leader Big Brother. One of the most compelling tales of political oppression ever written.',
   'Signet Classics', 1949, 'https://covers.openlibrary.org/b/isbn/9780451524935-L.jpg'),

  ('9780441013593',
   'Dune', 'Frank Herbert',
   'Science Fiction', 'space, desert, politics, ecology, epic, saga',
   'Set on the desert planet Arrakis, this is the story of Paul Atreides who will become the messianic Muad''Dib. A masterwork of science fiction with deep ecological and political themes.',
   'Ace Books', 1965, 'https://covers.openlibrary.org/b/isbn/9780441013593-L.jpg'),

  ('9780756404079',
   'The Name of the Wind', 'Patrick Rothfuss',
   'Fantasy', 'magic, music, adventure, storytelling, university',
   'The riveting first-person narrative of Kvothe, who grows up to be the most notorious wizard his world has ever seen, told by the man himself on the first day of a three-day account of his life.',
   'DAW Books', 2007, 'https://covers.openlibrary.org/b/isbn/9780756404079-L.jpg'),

  ('9780330258647',
   'The Hitchhiker''s Guide to the Galaxy', 'Douglas Adams',
   'Science Fiction', 'humor, space, adventure, comedy, classic, British',
   'Seconds before the Earth is demolished for a hyperspace bypass, Arthur Dent is plucked off the planet by his friend Ford Prefect. An absurd, brilliant comedy about the universe and everything in it.',
   'Pan Books', 1979, 'https://covers.openlibrary.org/b/isbn/9780330258647-L.jpg'),

  ('9780307474278',
   'The Da Vinci Code', 'Dan Brown',
   'Mystery', 'thriller, conspiracy, history, religion, art, cryptography',
   'Harvard symbologist Robert Langdon is pulled into a deadly game of secrets when the curator of the Louvre is found murdered, his body surrounded by baffling symbols.',
   'Doubleday', 2003, 'https://covers.openlibrary.org/b/isbn/9780307474278-L.jpg'),

  ('9780061935466',
   'To Kill a Mockingbird', 'Harper Lee',
   'Fiction', 'classic, race, justice, childhood, American South, morality',
   'Through the eyes of Scout Finch we witness the crisis of conscience that erupts in a small Southern town when her father, lawyer Atticus Finch, defends a black man falsely accused of a crime.',
   'Harper Perennial', 1960, 'https://covers.openlibrary.org/b/isbn/9780061935466-L.jpg'),

  ('9780061122415',
   'The Alchemist', 'Paulo Coelho',
   'Fiction', 'philosophy, journey, dreams, self-discovery, fable',
   'A young Andalusian shepherd travels from Spain to the Egyptian desert in search of treasure. His journey reveals the secrets of the universe and the importance of following one''s Personal Legend.',
   'HarperOne', 1988, 'https://covers.openlibrary.org/b/isbn/9780061122415-L.jpg'),

  ('9780060850524',
   'Brave New World', 'Aldous Huxley',
   'Dystopian Fiction', 'dystopia, future, technology, society, classic, science fiction',
   'In a future World State, citizens are engineered and conditioned for their social roles. Bernard Marx challenges this perfect society when he brings home a savage from a reservation.',
   'Harper Perennial', 1932, 'https://covers.openlibrary.org/b/isbn/9780060850524-L.jpg'),

  ('9780140449136',
   'Crime and Punishment', 'Fyodor Dostoevsky',
   'Fiction', 'classic, psychology, morality, Russia, crime, redemption',
   'Raskolnikov, a destitute former student in St. Petersburg, commits a murder believing himself above conventional morality. His psychological torment forms one of literature''s deepest explorations of guilt.',
   'Penguin Classics', 1866, 'https://covers.openlibrary.org/b/isbn/9780140449136-L.jpg'),

  ('9780156012195',
   'The Little Prince', 'Antoine de Saint-Exupéry',
   'Fiction', 'classic, children, philosophy, wonder, friendship, fable',
   'A pilot stranded in the desert meets a young prince from a tiny asteroid. Their conversations reveal profound truths about love, loneliness, and what matters most in life.',
   'Mariner Books', 1943, 'https://covers.openlibrary.org/b/isbn/9780156012195-L.jpg')
) AS S(ISBN, Title, Authors, Genre, Tags, Description, Publisher, PublicationYear, CoverImageUrl)
ON T.ISBN = S.ISBN
WHEN NOT MATCHED THEN
    INSERT (ISBN, Title, Authors, Genre, Tags, Description, Publisher, PublicationYear, CoverImageUrl, LastUpdatedFromOpenLibrary)
    VALUES (S.ISBN, S.Title, S.Authors, S.Genre, S.Tags, S.Description,
            S.Publisher, S.PublicationYear, S.CoverImageUrl, @Now);

-- ────────────────────────────────────────────────────────────────────
-- 3. USER BOOKS
--    Unique index: (UserId, ISBN, Condition)
-- ────────────────────────────────────────────────────────────────────

-- ── Admin ──────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@AdminId AND ISBN='9780747532743' AND Condition='Bom')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@AdminId,'9780747532743','Bom',1,1,0,DATEADD(day,-60,@Now),1);

IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@AdminId AND ISBN='9780451524935' AND Condition='Novo')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@AdminId,'9780451524935','Novo',1,1,0,DATEADD(day,-55,@Now),1);

IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@AdminId AND ISBN='9780441013593' AND Condition='Bom')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@AdminId,'9780441013593','Bom',1,1,0,DATEADD(day,-50,@Now),1);

IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@AdminId AND ISBN='9780061122415' AND Condition='Novo')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@AdminId,'9780061122415','Novo',2,1,0,DATEADD(day,-45,@Now),1);

IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@AdminId AND ISBN='9780061935466' AND Condition='Bom')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@AdminId,'9780061935466','Bom',1,1,0,DATEADD(day,-40,@Now),1);

-- ── Ana ────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@AnaId AND ISBN='9780261103252' AND Condition='Novo')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@AnaId,'9780261103252','Novo',1,1,0,DATEADD(day,-28,@Now),1);

IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@AnaId AND ISBN='9780756404079' AND Condition='Bom')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@AnaId,'9780756404079','Bom',1,1,0,DATEADD(day,-26,@Now),1);

-- Note: Ana's BNW will be deactivated in the completed T8 transaction below
IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@AnaId AND ISBN='9780060850524' AND Condition='Usado')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@AnaId,'9780060850524','Usado',1,1,0,DATEADD(day,-24,@Now),1);

-- ── Pedro ──────────────────────────────────────────────────────────
-- Note: Pedro's HGG will be deactivated in the completed T6 transaction below
IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@PedroId AND ISBN='9780330258647' AND Condition='Bom')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@PedroId,'9780330258647','Bom',1,1,0,DATEADD(day,-23,@Now),1);

IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@PedroId AND ISBN='9780307474278' AND Condition='Usado')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@PedroId,'9780307474278','Usado',1,1,0,DATEADD(day,-22,@Now),1);

IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@PedroId AND ISBN='9780140449136' AND Condition='Novo')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@PedroId,'9780140449136','Novo',1,1,0,DATEADD(day,-21,@Now),1);

-- Pedro's Harry Potter — offered in trade T5 with admin (still pending)
IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@PedroId AND ISBN='9780747532743' AND Condition='Bom')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@PedroId,'9780747532743','Bom',1,1,0,DATEADD(day,-20,@Now),1);

-- ── Maria ──────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@MariaId AND ISBN='9780061935466' AND Condition='Bom')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@MariaId,'9780061935466','Bom',1,1,0,DATEADD(day,-19,@Now),1);

-- Maria's Little Prince — offered in trade T3 with admin (still pending)
IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@MariaId AND ISBN='9780156012195' AND Condition='Novo')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@MariaId,'9780156012195','Novo',1,1,0,DATEADD(day,-18,@Now),1);

IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@MariaId AND ISBN='9780451524935' AND Condition='Usado')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@MariaId,'9780451524935','Usado',1,1,0,DATEADD(day,-17,@Now),1);

-- ── João ───────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@JoaoId AND ISBN='9780307474278' AND Condition='Bom')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@JoaoId,'9780307474278','Bom',1,1,0,DATEADD(day,-14,@Now),1);

IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@JoaoId AND ISBN='9780061122415' AND Condition='Usado')
    INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
    VALUES (@JoaoId,'9780061122415','Usado',1,1,0,DATEADD(day,-13,@Now),1);

-- ── Capture UserBook IDs for transaction FKs ────────────────────────
DECLARE @UB_Admin_HP    INT = (SELECT Id FROM UserBooks WHERE UserId=@AdminId AND ISBN='9780747532743' AND Condition='Bom');
DECLARE @UB_Admin_1984  INT = (SELECT Id FROM UserBooks WHERE UserId=@AdminId AND ISBN='9780451524935' AND Condition='Novo');
DECLARE @UB_Admin_Dune  INT = (SELECT Id FROM UserBooks WHERE UserId=@AdminId AND ISBN='9780441013593' AND Condition='Bom');
DECLARE @UB_Admin_Alch  INT = (SELECT Id FROM UserBooks WHERE UserId=@AdminId AND ISBN='9780061122415' AND Condition='Novo');
DECLARE @UB_Admin_Mockb INT = (SELECT Id FROM UserBooks WHERE UserId=@AdminId AND ISBN='9780061935466' AND Condition='Bom');
DECLARE @UB_Ana_NotW    INT = (SELECT Id FROM UserBooks WHERE UserId=@AnaId   AND ISBN='9780756404079' AND Condition='Bom');
DECLARE @UB_Ana_BNW     INT = (SELECT Id FROM UserBooks WHERE UserId=@AnaId   AND ISBN='9780060850524' AND Condition='Usado');
DECLARE @UB_Pedro_HGG   INT = (SELECT Id FROM UserBooks WHERE UserId=@PedroId AND ISBN='9780330258647' AND Condition='Bom');
DECLARE @UB_Pedro_CaP   INT = (SELECT Id FROM UserBooks WHERE UserId=@PedroId AND ISBN='9780140449136' AND Condition='Novo');
DECLARE @UB_Pedro_HP    INT = (SELECT Id FROM UserBooks WHERE UserId=@PedroId AND ISBN='9780747532743' AND Condition='Bom');
DECLARE @UB_Maria_LP    INT = (SELECT Id FROM UserBooks WHERE UserId=@MariaId AND ISBN='9780156012195' AND Condition='Novo');

-- ────────────────────────────────────────────────────────────────────
-- 4. TRANSACTIONS
-- ────────────────────────────────────────────────────────────────────

-- ════════════════════════════════════════════════════════
-- PENDING — admin is the RECEIVER on all five
-- Log in as admin@bookswap.pt and use the Admin Panel
-- (Transactions → Pending) to accept or deny each one.
-- Accepting a Compra/Troca will transfer book ownership.
-- ════════════════════════════════════════════════════════

-- T1 │ Ana wants to BUY Harry Potter from Admin  (8.50 €)
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@AnaId AND ReceiverId=@AdminId
                 AND UserBookId=@UB_Admin_HP AND Status='Pendente')
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(hour,-3,@Now), DATEADD(hour,-3,@Now),
            'Compra', 'Pendente',
            'Olá! Gostava de comprar o Harry Potter. Ainda está disponível?',
            @UB_Admin_HP, NULL, @AnaId, @AdminId, 8.50);

-- T2 │ Pedro wants to BORROW 1984 from Admin
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@PedroId AND ReceiverId=@AdminId
                 AND UserBookId=@UB_Admin_1984 AND Status='Pendente')
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(hour,-6,@Now), DATEADD(hour,-6,@Now),
            'Requisição', 'Pendente',
            'Bom dia! Poderia emprestar-me o 1984? Devolvo em duas semanas.',
            @UB_Admin_1984, NULL, @PedroId, @AdminId, NULL);

-- T3 │ Maria wants to TRADE her Little Prince for Admin's Dune
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@MariaId AND ReceiverId=@AdminId
                 AND UserBookId=@UB_Admin_Dune AND Status='Pendente')
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(hour,-12,@Now), DATEADD(hour,-12,@Now),
            'Troca', 'Pendente',
            'Tenho O Principezinho em Como Novo. Faria uma troca pelo Duna?',
            @UB_Admin_Dune, @UB_Maria_LP, @MariaId, @AdminId, NULL);

-- T4 │ João wants to BUY The Alchemist from Admin  (6.00 €)
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@JoaoId AND ReceiverId=@AdminId
                 AND UserBookId=@UB_Admin_Alch AND Status='Pendente')
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(day,-1,@Now), DATEADD(day,-1,@Now),
            'Compra', 'Pendente',
            'Interesse em comprar O Alquimista. O preço pedido é razoável.',
            @UB_Admin_Alch, NULL, @JoaoId, @AdminId, 6.00);

-- T5 │ Pedro wants to TRADE his Harry Potter for Admin's To Kill a Mockingbird
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@PedroId AND ReceiverId=@AdminId
                 AND UserBookId=@UB_Admin_Mockb AND Status='Pendente')
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(day,-2,@Now), DATEADD(day,-2,@Now),
            'Troca', 'Pendente',
            'Ofereço o meu Harry Potter (Bom Estado) em troca do To Kill a Mockingbird.',
            @UB_Admin_Mockb, @UB_Pedro_HP, @PedroId, @AdminId, NULL);

-- ════════════════════════════════════════════════════════
-- COMPLETED — historical records
-- These already reflect the final ownership state.
-- ════════════════════════════════════════════════════════

-- T6 │ João bought HGG from Pedro  (Compra, Confirmada)
--    Pedro's HGG copy → deactivated; João gains it
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@JoaoId AND ReceiverId=@PedroId
                 AND UserBookId=@UB_Pedro_HGG AND Status='Confirmada')
BEGIN
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(day,-10,@Now), DATEADD(day,-9,@Now),
            'Compra', 'Confirmada',
            'Ótima transação! Livro muito bem conservado.',
            @UB_Pedro_HGG, NULL, @JoaoId, @PedroId, 7.00);

    -- Ownership transfer: Pedro loses the copy
    UPDATE UserBooks SET IsActive=0, Quantity=0 WHERE Id=@UB_Pedro_HGG;

    -- João gains the copy (same Condition = 'Bom')
    IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@JoaoId AND ISBN='9780330258647' AND Condition='Bom')
        INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
        VALUES (@JoaoId,'9780330258647','Bom',1,1,0,DATEADD(day,-9,@Now),1);
END;

-- T7 │ Ana borrowed Crime and Punishment from Pedro, now returned
--    (Requisição, Confirmada → returned, Pedro's copy back to Emprestado=0)
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@AnaId AND ReceiverId=@PedroId
                 AND UserBookId=@UB_Pedro_CaP AND Status='Confirmada')
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(day,-20,@Now), DATEADD(day,-5,@Now),
            'Requisição', 'Confirmada',
            'Devolvido atempadamente e em perfeito estado. Obrigada!',
            @UB_Pedro_CaP, NULL, @AnaId, @PedroId, NULL);

-- T8 │ Pedro bought Brave New World from Ana  (Compra, Confirmada)
--    Ana's BNW copy → deactivated; Pedro gains it
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@PedroId AND ReceiverId=@AnaId
                 AND UserBookId=@UB_Ana_BNW AND Status='Confirmada')
BEGIN
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(day,-12,@Now), DATEADD(day,-11,@Now),
            'Compra', 'Confirmada',
            'Excelente! Livro em bom estado como descrito.',
            @UB_Ana_BNW, NULL, @PedroId, @AnaId, 5.50);

    -- Ownership transfer: Ana loses the copy
    UPDATE UserBooks SET IsActive=0, Quantity=0 WHERE Id=@UB_Ana_BNW;

    -- Pedro gains the copy (same Condition = 'Usado')
    IF NOT EXISTS (SELECT 1 FROM UserBooks WHERE UserId=@PedroId AND ISBN='9780060850524' AND Condition='Usado')
        INSERT INTO UserBooks (UserId,ISBN,Condition,Quantity,Available,Emprestado,DateAdded,IsActive)
        VALUES (@PedroId,'9780060850524','Usado',1,1,0,DATEADD(day,-11,@Now),1);
END;

-- T9 │ Maria tried to BORROW The Name of the Wind from Ana — rejected
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@MariaId AND ReceiverId=@AnaId
                 AND UserBookId=@UB_Ana_NotW AND Status='Rejeitada')
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(day,-8,@Now), DATEADD(day,-7,@Now),
            'Requisição', 'Rejeitada',
            'Desculpe, já está emprestado a um familiar por agora.',
            @UB_Ana_NotW, NULL, @MariaId, @AnaId, NULL);

-- ════════════════════════════════════════════════════════
-- HISTORICAL — older transactions for bar-chart months 2–5
-- No ownership transfer needed; Status covers the intent.
-- ════════════════════════════════════════════════════════

-- T-hist1 │ João tried to buy HP from Admin 5 months ago — Rejeitada
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@JoaoId AND ReceiverId=@AdminId
                 AND UserBookId=@UB_Admin_HP AND Status='Rejeitada')
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(month,-5,@Now), DATEADD(month,-5,@Now),
            'Compra', 'Rejeitada',
            'Olá, gostava de comprar o Harry Potter.',
            @UB_Admin_HP, NULL, @JoaoId, @AdminId, 9.00);

-- T-hist2 │ Maria borrowed 1984 from Admin 4 months ago — Confirmada (returned)
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@MariaId AND ReceiverId=@AdminId
                 AND UserBookId=@UB_Admin_1984 AND Status='Confirmada')
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(month,-4,@Now), DATEADD(day,-100,@Now),
            'Requisição', 'Confirmada',
            'Devolvido com antecedência. Excelente livro!',
            @UB_Admin_1984, NULL, @MariaId, @AdminId, NULL);

-- T-hist3 │ Ana tried to buy Dune from Admin 3.5 months ago — Rejeitada
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@AnaId AND ReceiverId=@AdminId
                 AND UserBookId=@UB_Admin_Dune AND Status='Rejeitada')
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(day,-107,@Now), DATEADD(day,-106,@Now),
            'Compra', 'Rejeitada',
            'Reservado para outra pessoa, lamento.',
            @UB_Admin_Dune, NULL, @AnaId, @AdminId, 11.00);

-- T-hist4 │ Pedro borrowed To Kill a Mockingbird from Admin 3 months ago — Confirmada (returned)
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@PedroId AND ReceiverId=@AdminId
                 AND UserBookId=@UB_Admin_Mockb AND Status='Confirmada')
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(month,-3,@Now), DATEADD(day,-75,@Now),
            'Requisição', 'Confirmada',
            'Devolvido em perfeito estado. Muito obrigado!',
            @UB_Admin_Mockb, NULL, @PedroId, @AdminId, NULL);

-- T-hist5 │ João tried to buy The Alchemist from Admin 2 months ago — Rejeitada
IF NOT EXISTS (SELECT 1 FROM Transactions
               WHERE SenderId=@JoaoId AND ReceiverId=@AdminId
                 AND UserBookId=@UB_Admin_Alch AND Status='Rejeitada')
    INSERT INTO Transactions
        (CreatedAt, UpdatedAt, Type, Status, Notes,
         UserBookId, SenderUserBookId, SenderId, ReceiverId, Price)
    VALUES (DATEADD(month,-2,@Now), DATEADD(month,-2,@Now),
            'Compra', 'Rejeitada',
            'Preço acima do orçamento disponível.',
            @UB_Admin_Alch, NULL, @JoaoId, @AdminId, 6.50);

COMMIT TRANSACTION;

-- ────────────────────────────────────────────────────────────────────
-- Summary
-- ────────────────────────────────────────────────────────────────────
SELECT 'Users'        AS [Table], COUNT(*) AS [Rows] FROM Users        UNION ALL
SELECT 'Books',        COUNT(*) FROM Books                             UNION ALL
SELECT 'UserBooks',    COUNT(*) FROM UserBooks                         UNION ALL
SELECT 'Transactions', COUNT(*) FROM Transactions
ORDER BY [Table];

SELECT
    t.Id,
    t.Type,
    t.Status,
    s.Name  AS Sender,
    r.Name  AS Receiver,
    b.Title AS Book,
    t.Price,
    CAST(t.CreatedAt AS DATE) AS [Date]
FROM Transactions t
JOIN Users  s ON s.Id = t.SenderId
JOIN Users  r ON r.Id = t.ReceiverId
LEFT JOIN UserBooks ub ON ub.Id = t.UserBookId
LEFT JOIN Books     b  ON b.ISBN = ub.ISBN
ORDER BY t.Status DESC, t.CreatedAt DESC;
