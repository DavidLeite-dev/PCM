-- ──────────────────────────────────────────────────────────────────────────────
-- BookSwapAPI/sql/purge_data.sql
-- Deletes ALL rows from every table while keeping the schema intact.
-- Identity seeds are reset so the next insert starts at Id = 1.
--
-- Use this to return the database to a blank-slate state without
-- dropping and recreating tables.
--
-- IMPORTANT: After running this script the admin user will not exist.
-- Either start the API (DbInitializer.SeedAsync re-creates it automatically)
-- or run insert_test_data.sql (which back-fills the admin's contact info but
-- does NOT create the admin account — start the API first).
--
-- Usage (sqlcmd):
--   sqlcmd -S . -d BookSwap -E -i "BookSwapAPI\sql\purge_data.sql"
-- ──────────────────────────────────────────────────────────────────────────────

SET NOCOUNT ON;

BEGIN TRANSACTION;

-- ── Delete in FK-safe order (children before parents) ────────────────────────

DELETE FROM dbo.Messages;
DELETE FROM dbo.Conversations;
DELETE FROM dbo.Transactions;
DELETE FROM dbo.UserBooks;
DELETE FROM dbo.BookAuthors;
DELETE FROM dbo.BookCategories;
DELETE FROM dbo.AuthTokens;
DELETE FROM dbo.Books;
DELETE FROM dbo.Authors;
DELETE FROM dbo.Categories;
DELETE FROM dbo.AppSettings;
DELETE FROM dbo.Users;

COMMIT TRANSACTION;

-- ── Reset identity seeds so next inserts start at 1 ─────────────────────────
DBCC CHECKIDENT ('dbo.Messages',      RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Conversations', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Transactions',  RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.UserBooks',     RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.AuthTokens',    RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Authors',       RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Categories',    RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Users',         RESEED, 0) WITH NO_INFOMSGS;

PRINT 'Database purged. Start the API to re-seed the admin account.';
