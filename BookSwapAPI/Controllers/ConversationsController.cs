using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BookSwapAPI.Data;
using BookSwapAPI.Models;

namespace BookSwapAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ConversationsController : ControllerBase
{
    private readonly BookSwapDbContext _context;

    public ConversationsController(BookSwapDbContext context)
    {
        _context = context;
    }

    // ─────────────────────────────────────────────────────────────
    // GET /api/conversations/user/{email}
    // Returns all active conversations for a user, with last message
    // and unread count. Each item includes isInitiator flag relative
    // to the requesting user.
    // ─────────────────────────────────────────────────────────────
    [HttpGet("user/{email}")]
    public async Task<IActionResult> GetUserConversations(string email)
    {
        try
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user == null)
                return BadRequest(new { message = "Utilizador não encontrado" });

            var conversations = await _context.Conversations
                .Include(c => c.Initiator)
                .Include(c => c.Receiver)
                .Include(c => c.Book)
                .Include(c => c.Transaction)
                .Include(c => c.Messages)
                    .ThenInclude(m => m.Sender)
                .Where(c => c.Status == "Active"
                    && (c.InitiatorId == user.Id || c.ReceiverId == user.Id))
                .OrderByDescending(c => c.LastMessageAt)
                .ToListAsync();

            var result = conversations.Select(c =>
            {
                var lastMsg = c.Messages.OrderByDescending(m => m.SentAt).FirstOrDefault();
                var unreadCount = c.Messages.Count(m => m.SenderId != user.Id && !m.IsRead);

                return new
                {
                    id = c.Id,
                    bookISBN = c.BookISBN,
                    bookTitle = c.Book?.Title ?? "Livro Desconhecido",
                    bookCover = c.Book?.CoverImageUrl ?? "",
                    initiatorId = c.InitiatorId,
                    initiatorEmail = c.Initiator.Email,
                    initiatorName = c.Initiator.Name,
                    receiverId = c.ReceiverId,
                    receiverEmail = c.Receiver.Email,
                    receiverName = c.Receiver.Name,
                    transactionId = c.TransactionId,
                    transactionType = c.Transaction?.Type,
                    transactionStatus = c.Transaction?.Status,
                    status = c.Status,
                    createdAt = c.CreatedAt,
                    lastMessageAt = c.LastMessageAt,
                    lastMessageContent = lastMsg?.Content,
                    lastMessageSenderName = lastMsg?.Sender.Name,
                    lastMessageSenderId = lastMsg?.SenderId,
                    unreadCount,
                    isInitiator = c.InitiatorId == user.Id,
                    otherUserName = c.InitiatorId == user.Id ? c.Receiver.Name : c.Initiator.Name,
                    otherUserEmail = c.InitiatorId == user.Id ? c.Receiver.Email : c.Initiator.Email,
                };
            });

            return Ok(new { success = true, conversations = result });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = "Erro ao obter conversas", error = ex.Message });
        }
    }

    // ─────────────────────────────────────────────────────────────
    // GET /api/conversations/unread/{email}
    // Returns total unread message count (for badge on nav bar)
    // ─────────────────────────────────────────────────────────────
    [HttpGet("unread/{email}")]
    public async Task<IActionResult> GetUnreadCount(string email)
    {
        try
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user == null) return Ok(new { success = true, count = 0 });

            var count = await _context.Messages
                .Include(m => m.Conversation)
                .Where(m => m.Conversation.Status == "Active"
                    && (m.Conversation.InitiatorId == user.Id || m.Conversation.ReceiverId == user.Id)
                    && m.SenderId != user.Id
                    && !m.IsRead)
                .CountAsync();

            return Ok(new { success = true, count });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = "Erro", error = ex.Message });
        }
    }

    // ─────────────────────────────────────────────────────────────
    // POST /api/conversations
    // Get existing Active conversation or create a new one.
    // Archived conversations are never resumed — a new one is created.
    // ─────────────────────────────────────────────────────────────
    [HttpPost]
    public async Task<IActionResult> GetOrCreateConversation([FromBody] CreateConversationRequest request)
    {
        try
        {
            var initiator = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.InitiatorEmail);
            var receiver = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.ReceiverEmail);

            if (initiator == null || receiver == null)
                return BadRequest(new { message = "Utilizador não encontrado" });

            if (initiator.Id == receiver.Id)
                return BadRequest(new { message = "Não pode iniciar uma conversa consigo mesmo" });

            // Look for an existing Active conversation between the same pair for the same book
            var existing = await _context.Conversations
                .FirstOrDefaultAsync(c =>
                    c.Status == "Active"
                    && c.InitiatorId == initiator.Id
                    && c.ReceiverId == receiver.Id
                    && c.BookISBN == request.BookISBN);

            if (existing != null)
            {
                // Link transaction if provided and not already linked
                if (request.TransactionId.HasValue && existing.TransactionId == null)
                {
                    existing.TransactionId = request.TransactionId;
                    await _context.SaveChangesAsync();
                }
                return Ok(new { success = true, conversationId = existing.Id, isNew = false });
            }

            // Create new conversation
            var conversation = new Conversation
            {
                InitiatorId = initiator.Id,
                ReceiverId = receiver.Id,
                BookISBN = request.BookISBN,
                TransactionId = request.TransactionId,
                Status = "Active",
                CreatedAt = DateTime.UtcNow,
                LastMessageAt = DateTime.UtcNow
            };

            _context.Conversations.Add(conversation);
            await _context.SaveChangesAsync();

            // Send an automatic first message if it was started via a transaction
            if (request.TransactionId.HasValue)
            {
                var transaction = await _context.Transactions.FindAsync(request.TransactionId.Value);
                if (transaction != null)
                {
                    var autoContent = transaction.Type switch
                    {
                        "Compra" => "💰 Proposta de compra enviada.",
                        "Requisição" => "📚 Pedido de requisição enviado.",
                        "Troca" => "🔄 Proposta de troca enviada.",
                        _ => "Transação iniciada."
                    };

                    _context.Messages.Add(new Message
                    {
                        ConversationId = conversation.Id,
                        SenderId = initiator.Id,
                        Content = autoContent,
                        SentAt = DateTime.UtcNow,
                        IsRead = false
                    });
                    await _context.SaveChangesAsync();
                }
            }

            return Ok(new { success = true, conversationId = conversation.Id, isNew = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = "Erro ao criar conversa", error = ex.Message });
        }
    }

    // ─────────────────────────────────────────────────────────────
    // GET /api/conversations/{id}/messages?userEmail=&afterId=
    // Returns messages for a conversation. Marks incoming messages
    // as read. afterId enables polling — only returns messages
    // with Id > afterId.
    // ─────────────────────────────────────────────────────────────
    [HttpGet("{id}/messages")]
    public async Task<IActionResult> GetMessages(int id, [FromQuery] string userEmail, [FromQuery] int? afterId = null)
    {
        try
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == userEmail);
            if (user == null)
                return BadRequest(new { message = "Utilizador não encontrado" });

            var conversation = await _context.Conversations
                .FirstOrDefaultAsync(c => c.Id == id
                    && (c.InitiatorId == user.Id || c.ReceiverId == user.Id));

            if (conversation == null)
                return NotFound(new { message = "Conversa não encontrada" });

            var query = _context.Messages
                .Include(m => m.Sender)
                .Where(m => m.ConversationId == id);

            if (afterId.HasValue)
                query = query.Where(m => m.Id > afterId.Value);

            var messages = await query
                .OrderBy(m => m.SentAt)
                .Select(m => new
                {
                    m.Id,
                    m.SenderId,
                    senderName = m.Sender.Name,
                    senderEmail = m.Sender.Email,
                    m.Content,
                    m.SentAt,
                    m.IsRead
                })
                .ToListAsync();

            // Mark messages from the other user as read
            var unreadIncoming = await _context.Messages
                .Where(m => m.ConversationId == id && m.SenderId != user.Id && !m.IsRead)
                .ToListAsync();

            foreach (var msg in unreadIncoming)
                msg.IsRead = true;

            if (unreadIncoming.Count > 0)
                await _context.SaveChangesAsync();

            return Ok(new { success = true, messages });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = "Erro ao obter mensagens", error = ex.Message });
        }
    }

    // ─────────────────────────────────────────────────────────────
    // POST /api/conversations/{id}/messages
    // Send a message in a conversation
    // ─────────────────────────────────────────────────────────────
    [HttpPost("{id}/messages")]
    public async Task<IActionResult> SendMessage(int id, [FromBody] SendMessageRequest request)
    {
        try
        {
            var sender = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.SenderEmail);
            if (sender == null)
                return BadRequest(new { message = "Utilizador não encontrado" });

            var conversation = await _context.Conversations
                .FirstOrDefaultAsync(c => c.Id == id
                    && c.Status == "Active"
                    && (c.InitiatorId == sender.Id || c.ReceiverId == sender.Id));

            if (conversation == null)
                return NotFound(new { message = "Conversa não encontrada ou arquivada" });

            if (string.IsNullOrWhiteSpace(request.Content))
                return BadRequest(new { message = "Mensagem não pode estar vazia" });

            var message = new Message
            {
                ConversationId = id,
                SenderId = sender.Id,
                Content = request.Content.Trim(),
                SentAt = DateTime.UtcNow,
                IsRead = false
            };

            _context.Messages.Add(message);
            conversation.LastMessageAt = message.SentAt;
            await _context.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                messageId = message.Id,
                sentAt = message.SentAt
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = "Erro ao enviar mensagem", error = ex.Message });
        }
    }

    // ─────────────────────────────────────────────────────────────
    // POST /api/conversations/{id}/link-transaction
    // Links a transaction to an existing conversation
    // ─────────────────────────────────────────────────────────────
    [HttpPost("{id}/link-transaction")]
    public async Task<IActionResult> LinkTransaction(int id, [FromBody] LinkTransactionRequest request)
    {
        try
        {
            var conversation = await _context.Conversations.FindAsync(id);
            if (conversation == null)
                return NotFound(new { message = "Conversa não encontrada" });

            conversation.TransactionId = request.TransactionId;
            await _context.SaveChangesAsync();

            return Ok(new { success = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = "Erro ao ligar transação", error = ex.Message });
        }
    }
}

// ─── Request DTOs ────────────────────────────────────────────────

public class CreateConversationRequest
{
    public string InitiatorEmail { get; set; } = string.Empty;
    public string ReceiverEmail { get; set; } = string.Empty;
    public string? BookISBN { get; set; }
    public int? TransactionId { get; set; }
}

public class SendMessageRequest
{
    public string SenderEmail { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
}

public class LinkTransactionRequest
{
    public int TransactionId { get; set; }
}
