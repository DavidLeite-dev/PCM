-- ──────────────────────────────────────────────────────────────────────────────
-- BookSwapAPI/sql/fix_encoding.sql
--
-- One-time repair: corrects Portuguese characters that were stored as garbled
-- Windows-1252 sequences because they were manually INSERT-ed without the N''
-- prefix.
--
-- Root cause example:
--   WRONG:  INSERT INTO Transactions(Type) VALUES ('Requisição')
--   RIGHT:  INSERT INTO Transactions(Type) VALUES (N'Requisição')
--
-- Without N'', SQL Server reads the UTF-8 bytes of each accented character
-- through the Windows-1252 code page and stores the wrong Unicode values:
--   ç (U+00E7, UTF-8: C3 A7) → stored as Ã (U+00C3) + § (U+00A7)  → "Ã§"
--   ã (U+00E3, UTF-8: C3 A3) → stored as Ã (U+00C3) + £ (U+00A3)  → "Ã£"
--   ...and so on for every accented Portuguese character.
--
-- This script reverses that conversion across every text column.
-- It is safe to re-run: REPLACE() is a no-op when the pattern is absent.
--
-- Usage (sqlcmd):
--   sqlcmd -S . -d BookSwap -E -i "BookSwapAPI\sql\fix_encoding.sql"
-- ──────────────────────────────────────────────────────────────────────────────

SET NOCOUNT ON;

-- Helper function: applies all garbled → correct mappings in one call.
-- Created temporarily and dropped at the end of the script.
IF OBJECT_ID('dbo.fn_FixEncoding', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_FixEncoding;
GO

CREATE FUNCTION dbo.fn_FixEncoding(@s NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    -- Each garbled pair is: NCHAR(195) [= Ã, U+00C3] followed by the Windows-1252
    -- interpretation of the second UTF-8 byte of the original character.

    -- ── lowercase ──────────────────────────────────────────────────────────────
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(163), NCHAR(227)); -- ã  (Ã£)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(167), NCHAR(231)); -- ç  (Ã§)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(161), NCHAR(225)); -- á  (Ã¡)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(162), NCHAR(226)); -- â  (Ã¢)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(160), NCHAR(224)); -- à  (Ã )
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(169), NCHAR(233)); -- é  (Ã©)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(170), NCHAR(234)); -- ê  (Ãª)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(173), NCHAR(237)); -- í  (Ã­)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(179), NCHAR(243)); -- ó  (Ã³)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(180), NCHAR(244)); -- ô  (Ã´)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(181), NCHAR(245)); -- õ  (Ãµ)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(186), NCHAR(250)); -- ú  (Ãº)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(188), NCHAR(252)); -- ü  (Ã¼)

    -- ── uppercase ──────────────────────────────────────────────────────────────
    -- Second byte falls in 0x80–0x9F, where Windows-1252 maps to non-Latin-1 chars.
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(402),  NCHAR(195)); -- Ã  (Ãƒ  — 0x83=ƒ U+0192)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(8225), NCHAR(199)); -- Ç  (Ã‡  — 0x87=‡ U+2021)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(8240), NCHAR(201)); -- É  (Ã‰  — 0x89=‰ U+2030)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(352),  NCHAR(202)); -- Ê  (ÃŠ  — 0x8A=Š U+0160)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(129),  NCHAR(193)); -- Á  (Ã    — 0x81 undefined, stored as U+0081)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(141),  NCHAR(205)); -- Í  (Ã    — 0x8D undefined, stored as U+008D)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(8364), NCHAR(192)); -- À  (Ã€  — 0x80=€ U+20AC)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(8218), NCHAR(194)); -- Â  (Ã‚  — 0x82=‚ U+201A)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(8220), NCHAR(211)); -- Ó  (Ã"  — 0x93=" U+201C)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(8221), NCHAR(212)); -- Ô  (Ã"  — 0x94=" U+201D)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(8226), NCHAR(213)); -- Õ  (Ã•  — 0x95=• U+2022)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(353),  NCHAR(218)); -- Ú  (Ãš  — 0x9A=š U+0161)
    SET @s = REPLACE(@s, NCHAR(195)+NCHAR(339),  NCHAR(220)); -- Ü  (Ãœ  — 0x9C=œ U+0153)

    RETURN @s;
END;
GO

-- ── Transactions ──────────────────────────────────────────────────────────────
UPDATE Transactions
SET    Type   = dbo.fn_FixEncoding(Type),
       Status = dbo.fn_FixEncoding(Status),
       Notes  = dbo.fn_FixEncoding(Notes)
WHERE  Type   LIKE '%' + NCHAR(195) + '%'
    OR Status LIKE '%' + NCHAR(195) + '%'
    OR Notes  LIKE '%' + NCHAR(195) + '%';

PRINT CAST(@@ROWCOUNT AS VARCHAR(10)) + ' Transactions row(s) fixed.';

-- ── Books ─────────────────────────────────────────────────────────────────────
UPDATE Books
SET    Title       = dbo.fn_FixEncoding(Title),
       Authors     = dbo.fn_FixEncoding(Authors),
       Genre       = dbo.fn_FixEncoding(Genre),
       Tags        = dbo.fn_FixEncoding(Tags),
       Description = dbo.fn_FixEncoding(Description),
       Publisher   = dbo.fn_FixEncoding(Publisher)
WHERE  Title       LIKE '%' + NCHAR(195) + '%'
    OR Authors     LIKE '%' + NCHAR(195) + '%'
    OR Genre       LIKE '%' + NCHAR(195) + '%'
    OR Tags        LIKE '%' + NCHAR(195) + '%'
    OR Description LIKE '%' + NCHAR(195) + '%'
    OR Publisher   LIKE '%' + NCHAR(195) + '%';

PRINT CAST(@@ROWCOUNT AS VARCHAR(10)) + ' Books row(s) fixed.';

-- ── Categories ────────────────────────────────────────────────────────────────
UPDATE Categories
SET    Name = dbo.fn_FixEncoding(Name)
WHERE  Name LIKE '%' + NCHAR(195) + '%';

PRINT CAST(@@ROWCOUNT AS VARCHAR(10)) + ' Categories row(s) fixed.';

-- ── Users ─────────────────────────────────────────────────────────────────────
UPDATE Users
SET    Name    = dbo.fn_FixEncoding(Name),
       Address = dbo.fn_FixEncoding(Address)
WHERE  Name    LIKE '%' + NCHAR(195) + '%'
    OR Address LIKE '%' + NCHAR(195) + '%';

PRINT CAST(@@ROWCOUNT AS VARCHAR(10)) + ' Users row(s) fixed.';

-- ── Messages ──────────────────────────────────────────────────────────────────
UPDATE Messages
SET    Content = dbo.fn_FixEncoding(Content)
WHERE  Content LIKE '%' + NCHAR(195) + '%';

PRINT CAST(@@ROWCOUNT AS VARCHAR(10)) + ' Messages row(s) fixed.';

-- ── Conversations ─────────────────────────────────────────────────────────────
UPDATE Conversations
SET    Status = dbo.fn_FixEncoding(Status)
WHERE  Status LIKE '%' + NCHAR(195) + '%';

PRINT CAST(@@ROWCOUNT AS VARCHAR(10)) + ' Conversations row(s) fixed.';

-- ── Authors ───────────────────────────────────────────────────────────────────
UPDATE Authors
SET    Name = dbo.fn_FixEncoding(Name),
       Bio  = dbo.fn_FixEncoding(Bio)
WHERE  Name LIKE '%' + NCHAR(195) + '%'
    OR Bio  LIKE '%' + NCHAR(195) + '%';

PRINT CAST(@@ROWCOUNT AS VARCHAR(10)) + ' Authors row(s) fixed.';

-- ── UserBooks ─────────────────────────────────────────────────────────────────
UPDATE UserBooks
SET    Condition = dbo.fn_FixEncoding(Condition)
WHERE  Condition LIKE '%' + NCHAR(195) + '%';

PRINT CAST(@@ROWCOUNT AS VARCHAR(10)) + ' UserBooks row(s) fixed.';

-- ── Clean up helper function ──────────────────────────────────────────────────
DROP FUNCTION dbo.fn_FixEncoding;

PRINT 'Encoding repair complete.';
