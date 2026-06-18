CREATE TRIGGER trg_Messages_UpdateLastMessageAt
ON Messages
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE c
    SET    c.LastMessageAt = GETDATE()
    FROM   Conversations AS c
    JOIN   inserted      AS i
           ON c.Id = i.ConversationId;
END;