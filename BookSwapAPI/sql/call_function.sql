SELECT Id, dbo.fn_IsUserBookAvailable(Id) AS CanSwap
FROM   UserBooks;
