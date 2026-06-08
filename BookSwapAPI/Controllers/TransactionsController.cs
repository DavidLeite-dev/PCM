using System.Linq.Expressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BookSwapAPI.Data;
using BookSwapAPI.Helpers;
using BookSwapAPI.Models;

namespace BookSwapAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TransactionsController : ControllerBase
{
    private readonly BookSwapDbContext _context;
    private readonly ILogger<TransactionsController> _logger;

    public TransactionsController(BookSwapDbContext context, ILogger<TransactionsController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Create a new transaction (buy, borrow, or trade)
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateTransaction([FromBody] CreateTransactionRequest request)
    {
        try
        {
            // Validate transaction type
            var validTypes = new[] { "Compra", "Requisição", "Troca" };
            if (!validTypes.Contains(request.Type))
            {
                return BadRequest(new { message = "Tipo de transação inválido. Use: Compra, Requisição, ou Troca" });
            }

            // Get sender and receiver users
            var sender = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.SenderEmail);
            var receiver = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.ReceiverEmail);

            if (sender == null || receiver == null)
            {
                return BadRequest(new { message = "Utilizador não encontrado" });
            }

            if (sender.Id == receiver.Id)
            {
                return BadRequest(new { message = "Não pode realizar uma transação consigo mesmo" });
            }

            // Verify book exists and belongs to receiver
            var userBook = await _context.UserBooks
                .Include(ub => ub.Book)
                .FirstOrDefaultAsync(ub => ub.UserId == receiver.Id && ub.ISBN == request.BookISBN);

            if (userBook == null)
            {
                return BadRequest(new { message = "Livro não encontrado no inventário do utilizador" });
            }

            if (userBook.Book == null)
            {
                return BadRequest(new { message = "Informações do livro não encontradas" });
            }

            // For trades, verify the sender's book exists
            if (request.Type == "Troca")
            {
                if (string.IsNullOrEmpty(request.SenderBookISBN))
                {
                    return BadRequest(new { message = "Para trocas, é necessário especificar o livro a oferecer" });
                }
                var senderBook = await _context.UserBooks
                    .FirstOrDefaultAsync(ub => ub.UserId == sender.Id && ub.ISBN == request.SenderBookISBN && ub.IsActive);

                if (senderBook == null)
                {
                    return BadRequest(new { message = "O seu livro não foi encontrado no seu inventário" });
                }
            }

            // Create transaction (link to specific UserBook records)
            var transaction = new Transaction
            {
                Type = request.Type,
                Status = "Pendente",
                Notes = request.Notes ?? string.Empty,
                UserBookId = userBook.Id,
                SenderId = sender.Id,
                ReceiverId = receiver.Id,
                Price = request.Type == "Compra" ? request.Price : null,
                SenderUserBookId = request.Type == "Troca" ? (await _context.UserBooks
                                                .Where(ub => ub.UserId == sender.Id && ub.ISBN == request.SenderBookISBN && ub.IsActive)
                                                .Select(ub => (int?)ub.Id)
                                                .FirstOrDefaultAsync()) : null,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Transactions.Add(transaction);
            await _context.SaveChangesAsync();

            return Ok(new { message = "Transação criada com sucesso", transactionId = transaction.Id });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating transaction: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao criar transação" });
        }
    }

    /// <summary>
    /// Get all transactions for a user (sent and received)
    /// </summary>
    [HttpGet("user/{email}")]
    public async Task<IActionResult> GetUserTransactions(string email)
    {
        try
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user == null)
            {
                return NotFound(new { message = "Utilizador não encontrado" });
            }

            var transactions = await _context.Transactions
                .Include(t => t.Sender)
                .Include(t => t.Receiver)
                .Include(t => t.UserBook).ThenInclude(ub => ub!.Book)
                .Include(t => t.SenderUserBook).ThenInclude(ub => ub!.Book)
                .Where(t => t.SenderId == user.Id || t.ReceiverId == user.Id)
                .OrderByDescending(t => t.CreatedAt)
                .ToListAsync();

            var result = new List<TransactionDto>();

            foreach (var t in transactions)
            {
                var dto = new TransactionDto
                {
                    Id = t.Id,
                    Type = t.Type,
                    Status = t.Status,
                    Notes = t.Notes,
                    BookId = t.UserBook?.Book?.ISBN ?? string.Empty,
                    BookTitle = t.UserBook?.Book?.Title ?? string.Empty,
                    BookAuthor = t.UserBook?.Book?.Authors ?? string.Empty,
                    BookISBN = t.UserBook?.Book?.ISBN ?? string.Empty,
                    SenderEmail = t.Sender.Email,
                    SenderName = t.Sender.Name,
                    ReceiverEmail = t.Receiver.Email,
                    ReceiverName = t.Receiver.Name,
                    Price = t.Price,
                    TradeBookISBN = string.Empty,
                    CreatedAt = t.CreatedAt,
                    UpdatedAt = t.UpdatedAt,
                };

                if (t.Type == "Compra" && !dto.Price.HasValue && t.Notes.Contains("PRICE:"))
                {
                    var pricePart = t.Notes.Split('|')[0].Replace("PRICE:", "");
                    if (decimal.TryParse(pricePart, out var price))
                        dto.Price = price;
                }

                if (t.Type == "Troca")
                {
                    if (t.SenderUserBook?.Book != null)
                    {
                        dto.TradeBookTitle = t.SenderUserBook.Book.Title;
                        dto.TradeBookAuthor = t.SenderUserBook.Book.Authors;
                        dto.TradeBookISBN = t.SenderUserBook.Book.ISBN;
                    }
                    else if (t.Notes.Contains("TRADE_BOOK_ISBN:"))
                    {
                        var tradeISBN = t.Notes.Split('|')[0].Replace("TRADE_BOOK_ISBN:", "").Trim();
                        var tradeBook = await _context.Books.FirstOrDefaultAsync(b => b.ISBN == tradeISBN);
                        if (tradeBook != null)
                        {
                            dto.TradeBookTitle = tradeBook.Title;
                            dto.TradeBookAuthor = tradeBook.Authors;
                            dto.TradeBookISBN = tradeBook.ISBN;
                        }
                    }
                }

                result.Add(dto);
            }

            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting user transactions: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao obter transações" });
        }
    }

    /// <summary>
    /// Get transactions sent by a user
    /// </summary>
    [HttpGet("sent/{email}")]
    public async Task<IActionResult> GetSentTransactions(string email)
    {
        try
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user == null)
            {
                return NotFound(new { message = "Utilizador não encontrado" });
            }

            var transactions = await GetTransactionDtos(t => t.SenderId == user.Id);
            return Ok(transactions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting sent transactions: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao obter transações enviadas" });
        }
    }

    /// <summary>
    /// Get transactions received by a user
    /// </summary>
    [HttpGet("received/{email}")]
    public async Task<IActionResult> GetReceivedTransactions(string email)
    {
        try
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user == null)
            {
                return NotFound(new { message = "Utilizador não encontrado" });
            }

            var transactions = await GetTransactionDtos(t => t.ReceiverId == user.Id);
            return Ok(transactions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting received transactions: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao obter transações recebidas" });
        }
    }

    /// <summary>
    /// Get pending transactions received by a user (for approval)
    /// </summary>
    [HttpGet("pending/{email}")]
    public async Task<IActionResult> GetPendingTransactions(string email)
    {
        try
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user == null)
            {
                return NotFound(new { message = "Utilizador não encontrado" });
            }

            var transactions = await GetTransactionDtos(t => t.ReceiverId == user.Id && t.Status == "Pendente");
            return Ok(transactions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting pending transactions: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao obter transações pendentes" });
        }
    }

    /// <summary>
    /// Accept a transaction
    /// </summary>
    [HttpPost("{id}/accept")]
    public async Task<IActionResult> AcceptTransaction(int id)
    {
        try
        {
            _logger.LogDebug("AcceptTransaction START for transaction {Id}", id);

            var (user, tokenError) = await GetUserFromTokenAsync();
            if (tokenError != null) return tokenError;

            var transaction = await _context.Transactions
                .Include(t => t.Sender)
                .Include(t => t.Receiver)
                .Include(t => t.UserBook).ThenInclude(ub => ub.Book)
                .Include(t => t.SenderUserBook).ThenInclude(ub => ub.Book)
                .FirstOrDefaultAsync(t => t.Id == id);

            if (transaction == null)
            {
                return NotFound(new { message = "Transação não encontrada" });
            }

            _logger.LogDebug("Found transaction: Type={Type}, Status={Status}", transaction.Type, transaction.Status);

            // Only the receiver can accept
            if (transaction.ReceiverId != user!.Id)
            {
                return BadRequest(new { message = "Apenas o destinatário pode aceitar a transação" });
            }

            if (transaction.Status != "Pendente")
            {
                return BadRequest(new { message = "Apenas transações pendentes podem ser aceites" });
            }

            // Resolve the owner's UserBook and Book
            var ownerUserBook = transaction.UserBook ?? await _context.UserBooks.Include(ub => ub.Book)
                                        .FirstOrDefaultAsync(ub => ub.Id == transaction.UserBookId);
            if (ownerUserBook == null || ownerUserBook.Book == null)
            {
                return BadRequest(new { message = "Livro não encontrado" });
            }
            var book = ownerUserBook.Book;

            _logger.LogDebug("Processing {Type} transaction", transaction.Type);

            // Handle different transaction types
            if (transaction.Type == "Compra")
            {
                _logger.LogDebug("Processing COMPRA: Buyer={BuyerId}, Seller={SellerId}", transaction.SenderId, transaction.ReceiverId);

                // seller's copy is the ownerUserBook
                var sellerBook = ownerUserBook;

                // Reduce seller's quantity or mark as inactive
                if (sellerBook.Quantity > 1)
                {
                    sellerBook.Quantity--;
                }
                else
                {
                    sellerBook.IsActive = false;
                }

                // Add book to buyer (Sender) - check with same Condition
                var buyerBook = await _context.UserBooks
                    .FirstOrDefaultAsync(ub => ub.UserId == transaction.SenderId
                                            && ub.ISBN == book.ISBN
                                            && ub.Condition == sellerBook.Condition);

                if (buyerBook != null)
                {
                    buyerBook.Quantity++;
                    buyerBook.IsActive = true;
                }
                else
                {
                    var newUserBook = new UserBook
                    {
                        UserId = transaction.SenderId,
                        ISBN = book.ISBN,
                        Condition = sellerBook.Condition,
                        Quantity = 1,
                        DateAdded = DateTime.UtcNow,
                        Available = true,
                        IsActive = true
                    };
                    _context.UserBooks.Add(newUserBook);
                }

                transaction.Status = "Confirmada";

                // Cancel all other pending purchase transactions for this specific UserBook
                if (transaction.UserBookId.HasValue)
                    await CancelPendingTransactionsForUserBook(transaction.UserBookId.Value, transaction.ReceiverId, id);
            }
            else if (transaction.Type == "Requisição")
            {
                // Check if receiver already has an active borrow of this book
                var activeBorrow = await _context.Transactions
                    .Where(t => t.Type == "Requisição"
                        && t.ReceiverId == transaction.ReceiverId
                        && t.UserBookId == transaction.UserBookId
                        && (t.Status == "Aceita" || t.Status == "Confirmada")
                        && t.Id != id)
                    .FirstOrDefaultAsync();

                if (activeBorrow != null)
                {
                    return BadRequest(new { message = "Já tem este livro emprestado" });
                }

                // Sender = BORROWER (requested the borrow), Receiver = OWNER (has the book, accepts)
                // Mark owner's book as emprestado (borrowed)
                var ownerBook = ownerUserBook;
                if (ownerBook != null)
                {
                    ownerBook.Emprestado = true;
                    transaction.Status = "Aceita";

                    if (transaction.UserBookId.HasValue)
                        await CancelPendingTransactionsForUserBook(transaction.UserBookId.Value, transaction.ReceiverId, id);
                }
                else
                {
                    return BadRequest(new { message = "Livro não encontrado no proprietário" });
                }
            }
            else if (transaction.Type == "Troca")
            {
                _logger.LogDebug("Processing TROCA: Sender={SenderId}, Receiver={ReceiverId}", transaction.SenderId, transaction.ReceiverId);

                // transaction.BookISBN  = the RECEIVER's book (what the sender wants)
                // SenderBookISBN        = the SENDER's book (what the receiver gets)
                // Sender's offered copy (what they give) and Receiver's copy (what they give)
                var senderBook = transaction.SenderUserBook ?? await _context.UserBooks.FirstOrDefaultAsync(ub => ub.Id == transaction.SenderUserBookId);
                var receiverBook = ownerUserBook;

                if (senderBook == null || receiverBook == null)
                {
                    return BadRequest(new { message = "Informação do livro de troca não encontrada ou cópias não ativas" });
                }

                // Remove sender's book from sender
                if (senderBook.Quantity > 1)
                {
                    senderBook.Quantity--;
                }
                else
                {
                    senderBook.IsActive = false;
                }

                // Remove receiver's book from receiver
                if (receiverBook.Quantity > 1)
                {
                    receiverBook.Quantity--;
                }
                else
                {
                    receiverBook.IsActive = false;
                }

                // Give sender the receiver's book
                var senderGetsBook = await _context.UserBooks
                    .FirstOrDefaultAsync(ub => ub.UserId == transaction.SenderId && ub.ISBN == receiverBook.ISBN && ub.Condition == receiverBook.Condition);

                if (senderGetsBook == null)
                {
                    _context.UserBooks.Add(new UserBook
                    {
                        UserId = transaction.SenderId,
                        ISBN = receiverBook.ISBN,
                        Condition = receiverBook.Condition,
                        Quantity = 1,
                        DateAdded = DateTime.UtcNow,
                        Available = true,
                        IsActive = true
                    });
                }
                else
                {
                    senderGetsBook.Quantity++;
                    senderGetsBook.IsActive = true;
                }

                // Give receiver the sender's book
                var receiverGetsBook = await _context.UserBooks
                    .FirstOrDefaultAsync(ub => ub.UserId == transaction.ReceiverId && ub.ISBN == senderBook.ISBN && ub.Condition == senderBook.Condition);

                if (receiverGetsBook == null)
                {
                    _context.UserBooks.Add(new UserBook
                    {
                        UserId = transaction.ReceiverId,
                        ISBN = senderBook.ISBN,
                        Condition = senderBook.Condition,
                        Quantity = 1,
                        DateAdded = DateTime.UtcNow,
                        Available = true,
                        IsActive = true
                    });
                }
                else
                {
                    receiverGetsBook.Quantity++;
                    receiverGetsBook.IsActive = true;
                }

                transaction.Status = "Confirmada";

                // Cancel other pending transactions for these specific UserBook records
                if (transaction.SenderUserBookId.HasValue)
                    await CancelPendingTransactionsForUserBook(transaction.SenderUserBookId.Value, transaction.SenderId, id);
                if (transaction.UserBookId.HasValue)
                    await CancelPendingTransactionsForUserBook(transaction.UserBookId.Value, transaction.ReceiverId, id);
            }

            transaction.UpdatedAt = DateTime.UtcNow;

            _logger.LogDebug("About to SaveChangesAsync for transaction {Id}", id);
            var saveResult = await _context.SaveChangesAsync();
            _logger.LogDebug("SaveChangesAsync completed: {Count} changes saved", saveResult);

            return Ok(new { message = "Transação aceite com sucesso" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in AcceptTransaction: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao aceitar transação" });
        }
    }

    /// <summary>
    /// Reject a transaction
    /// </summary>
    [HttpPost("{id}/reject")]
    public async Task<IActionResult> RejectTransaction(int id)
    {
        try
        {
            var (user, tokenError) = await GetUserFromTokenAsync();
            if (tokenError != null) return tokenError;

            var transaction = await _context.Transactions
                .Include(t => t.Receiver)
                .FirstOrDefaultAsync(t => t.Id == id);

            if (transaction == null)
            {
                return NotFound(new { message = "Transação não encontrada" });
            }

            // Only the receiver can reject
            if (transaction.ReceiverId != user!.Id)
            {
                return BadRequest(new { message = "Apenas o destinatário pode rejeitar a transação" });
            }

            if (transaction.Status != "Pendente")
            {
                return BadRequest(new { message = "Apenas transações pendentes podem ser rejeitadas" });
            }

            transaction.Status = "Rejeitada";
            transaction.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new { message = "Transação rejeitada com sucesso" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error rejecting transaction: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao rejeitar transação" });
        }
    }

    /// <summary>
    /// Cancel a transaction (sender cancels their own pending transaction)
    /// </summary>
    [HttpPost("{id}/cancel")]
    public async Task<IActionResult> CancelTransaction(int id)
    {
        try
        {
            var (user, tokenError) = await GetUserFromTokenAsync();
            if (tokenError != null) return tokenError;

            var transaction = await _context.Transactions
                .Include(t => t.Sender)
                .FirstOrDefaultAsync(t => t.Id == id);

            if (transaction == null)
            {
                return NotFound(new { message = "Transação não encontrada" });
            }

            // Verify the user is the sender
            if (transaction.SenderId != user!.Id)
            {
                return BadRequest(new { message = "Apenas o remetente pode cancelar a transação" });
            }

            if (transaction.Status != "Pendente")
            {
                return BadRequest(new { message = "Apenas transações pendentes podem ser canceladas" });
            }

            transaction.Status = "Cancelada";
            transaction.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new { message = "Transação cancelada com sucesso" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error cancelling transaction: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao cancelar transação" });
        }
    }

    /// <summary>
    /// Get books currently borrowed by a user (Requisição with status=Aceita where they are the borrower/Sender)
    /// </summary>
    [HttpGet("borrowed/{email}")]
    public async Task<IActionResult> GetBorrowedBooks(string email)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
        if (user == null)
            return NotFound(new { message = "Utilizador não encontrado" });

        var borrowedTransactions = await _context.Transactions
            .Include(t => t.Receiver)
            .Include(t => t.UserBook).ThenInclude(ub => ub!.Book)
            .Where(t => t.Type == "Requisição" && t.Status == "Aceita" && t.SenderId == user.Id)
            .ToListAsync();

        var result = new List<object>();

        foreach (var t in borrowedTransactions)
        {
            if (t.UserBook?.Book == null) continue;

            var book = t.UserBook.Book;

            result.Add(new
            {
                transactionId = t.Id,
                ownerEmail = t.Receiver?.Email ?? "",
                ownerName = t.Receiver?.Name ?? "",
                bookData = new
                {
                    isbn = book.ISBN,
                    title = book.Title,
                    authors = book.Authors,
                    genre = book.Genre,
                    tags = book.Tags,
                    description = book.Description,
                    publisher = book.Publisher,
                    publicationYear = book.PublicationYear,
                    coverImageUrl = book.CoverImageUrl
                },
                condition = t.UserBook.Condition ?? "",
                quantity = 1,
                emprestado = true,
                isBorrowed = true
            });
        }

        return Ok(new { success = true, books = result });
    }

    /// <summary>
    /// Return a borrowed book — borrower initiates return
    /// </summary>
    [HttpPost("{id}/return")]
    public async Task<IActionResult> ReturnBook(int id)
    {
        try
        {
            var (user, tokenError) = await GetUserFromTokenAsync();
            if (tokenError != null) return tokenError;

            var transaction = await _context.Transactions
                .Include(t => t.Sender)
                .Include(t => t.Receiver)
                .FirstOrDefaultAsync(t => t.Id == id);

            if (transaction == null)
                return NotFound(new { message = "Transação não encontrada" });

            if (transaction.Type != "Requisição")
                return BadRequest(new { message = "Apenas requisições podem ser devolvidas" });

            if (transaction.Status != "Aceita")
                return BadRequest(new { message = "Apenas livros atualmente emprestados podem ser devolvidos" });

            // Verify the user is the borrower (Sender)
            if (transaction.SenderId != user!.Id)
                return BadRequest(new { message = "Apenas o utilizador que requisitou pode devolver o livro" });

            // Mark owner's book as no longer borrowed
            var ownerBook = await _context.UserBooks
                .FirstOrDefaultAsync(ub => ub.UserId == transaction.ReceiverId && ub.Id == transaction.UserBookId && ub.Emprestado);

            if (ownerBook != null)
                ownerBook.Emprestado = false;

            transaction.Status = "Confirmada";
            transaction.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new { message = "Livro devolvido com sucesso" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error returning book: {Message}", ex.Message);
            return StatusCode(500, new { message = "Erro ao devolver livro" });
        }
    }

    // Helper methods

    private async Task<List<TransactionDto>> GetTransactionDtos(Expression<Func<Transaction, bool>> predicate)
    {
        var transactions = await _context.Transactions
            .Include(t => t.Sender)
            .Include(t => t.Receiver)
            .Include(t => t.UserBook).ThenInclude(ub => ub!.Book)
            .Include(t => t.SenderUserBook).ThenInclude(ub => ub!.Book)
            .Where(predicate)
            .OrderByDescending(t => t.CreatedAt)
            .ToListAsync();

        var dtos = new List<TransactionDto>();

        foreach (var t in transactions)
        {
            var dto = new TransactionDto
            {
                Id = t.Id,
                Type = t.Type,
                Status = t.Status,
                Notes = t.Notes,
                BookId = t.UserBook?.Book?.ISBN ?? string.Empty,
                BookTitle = t.UserBook?.Book?.Title ?? string.Empty,
                BookAuthor = t.UserBook?.Book?.Authors ?? string.Empty,
                BookISBN = t.UserBook?.Book?.ISBN ?? string.Empty,
                SenderEmail = t.Sender.Email,
                SenderName = t.Sender.Name,
                ReceiverEmail = t.Receiver.Email,
                ReceiverName = t.Receiver.Name,
                CreatedAt = t.CreatedAt,
                UpdatedAt = t.UpdatedAt
            };

            if (t.Type == "Compra")
            {
                if (t.Price.HasValue)
                {
                    dto.Price = t.Price;
                }
                else if (t.Notes.Contains("PRICE:"))
                {
                    var pricePart = t.Notes.Split('|')[0].Replace("PRICE:", "");
                    if (decimal.TryParse(pricePart, out var parsedPrice))
                        dto.Price = parsedPrice;
                }
            }

            if (t.Type == "Troca")
            {
                if (t.SenderUserBook?.Book != null)
                {
                    dto.TradeBookTitle = t.SenderUserBook.Book.Title;
                    dto.TradeBookAuthor = t.SenderUserBook.Book.Authors;
                    dto.TradeBookISBN = t.SenderUserBook.Book.ISBN;
                }
                else if (t.Notes.Contains("TRADE_BOOK_ISBN:"))
                {
                    var tradeISBN = t.Notes.Split('|')[0].Replace("TRADE_BOOK_ISBN:", "").Trim();
                    var tradeBook = await _context.Books.FirstOrDefaultAsync(b => b.ISBN == tradeISBN);
                    if (tradeBook != null)
                    {
                        dto.TradeBookTitle = tradeBook.Title;
                        dto.TradeBookAuthor = tradeBook.Authors;
                        dto.TradeBookISBN = tradeBook.ISBN;
                    }
                }
            }

            dtos.Add(dto);
        }

        return dtos;
    }

    private async Task<(Models.User? User, IActionResult? Error)> GetUserFromTokenAsync()
    {
        var rawToken = TokenHelper.ExtractBearerToken(Request);
        if (rawToken == null)
            return (null, StatusCode(401, new { message = "Token de autenticação em falta" }));

        var hash = TokenHelper.HashToken(rawToken);
        var tokenRow = await _context.AuthTokens
            .Include(t => t.User)
            .FirstOrDefaultAsync(t => t.TokenHash == hash && t.ExpiresAt > DateTime.UtcNow);

        if (tokenRow?.User == null)
            return (null, StatusCode(401, new { message = "Token inválido ou expirado" }));

        return (tokenRow.User, null);
    }

    private async Task CancelPendingTransactionsForUserBook(int userBookId, int ownerId, int exceptTransactionId)
    {
        // Cancel all pending transactions that reference this exact UserBook and were initiated by the given owner
        var pendingTransactions = await _context.Transactions
            .Where(t => t.UserBookId == userBookId &&
                       t.SenderId == ownerId &&
                       t.Status == "Pendente" &&
                       t.Id != exceptTransactionId)
            .ToListAsync();

        foreach (var transaction in pendingTransactions)
        {
            transaction.Status = "Cancelada";
            transaction.UpdatedAt = DateTime.UtcNow;
        }
    }

    private string ExtractTradeBookISBN(string notes)
    {
        // Parse TRADE_BOOK_ISBN:xxxxx from notes
        var prefix = "TRADE_BOOK_ISBN:";
        var index = notes.IndexOf(prefix);
        if (index >= 0)
        {
            var startIndex = index + prefix.Length;
            var endIndex = notes.IndexOf('|', startIndex);
            if (endIndex < 0) endIndex = notes.Length;
            return notes.Substring(startIndex, endIndex - startIndex).Trim();
        }
        return string.Empty;
    }
}

// DTOs
public class CreateTransactionRequest
{
    public string Type { get; set; } = string.Empty; // "Compra", "Requisição", "Troca"
    public string SenderEmail { get; set; } = string.Empty;
    public string ReceiverEmail { get; set; } = string.Empty;
    public string BookISBN { get; set; } = string.Empty; // The book being requested/bought
    public string? SenderBookISBN { get; set; } // For trades: the book being offered
    public decimal? Price { get; set; } // For purchases
    public string? Notes { get; set; }
}

public class TransactionDto
{
    public int Id { get; set; }
    public string Type { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string Notes { get; set; } = string.Empty;
    public string BookId { get; set; } = string.Empty; // Actually the ISBN
    public string BookTitle { get; set; } = string.Empty;
    public string BookAuthor { get; set; } = string.Empty;
    public string BookISBN { get; set; } = string.Empty;
    public string SenderEmail { get; set; } = string.Empty;
    public string SenderName { get; set; } = string.Empty;
    public string ReceiverEmail { get; set; } = string.Empty;
    public string ReceiverName { get; set; } = string.Empty;
    public decimal? Price { get; set; } // For purchases
    public string? TradeBookTitle { get; set; } // For trades
    public string? TradeBookAuthor { get; set; } // For trades
    public string? TradeBookISBN { get; set; } // For trades
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
