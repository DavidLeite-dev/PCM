CREATE PROCEDURE usp_CompleteTransaction
    @TransactionId INT,
    @ReceiverId    INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1) Mark the deal as completed (only if still pending)
        UPDATE Transactions
        SET    Status      = 'Completed',
               CompletedAt = GETDATE()
        WHERE  Id = @TransactionId
          AND  Status        = 'Pending';

        IF @@ROWCOUNT = 0
            THROW 50001, 'Transaction not found or not pending.', 1;

        -- 2) Flag the swapped copy as no longer available
        UPDATE ub
        SET    ub.Available  = 0,
               ub.Emprestado = 1
        FROM   UserBooks  AS ub
        JOIN   Transactions AS t ON t.UserBookId = ub.Id
        WHERE  t.TransactionId = @TransactionId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;   -- re-raise to the caller
    END CATCH
END;
