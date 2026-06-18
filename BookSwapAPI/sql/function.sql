CREATE FUNCTION dbo.fn_IsUserBookAvailable (@UserBookId INT)
RETURNS BIT
AS
BEGIN
    DECLARE @IsAvailable BIT;

    SELECT @IsAvailable =
        CASE WHEN ub.Available = 1
              AND ub.Emprestado = 0
              AND ub.Quantity  > 0
             THEN 1 ELSE 0 END
    FROM UserBooks AS ub
    WHERE ub.Id = @UserBookId;

    RETURN ISNULL(@IsAvailable, 0);   -- unknown copy → not available
END;
