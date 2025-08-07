USE CarvedRock;
GO

CREATE OR ALTER PROCEDURE sp_CreateBlockingScenario
AS
BEGIN
    PRINT 'Starting blocking scenario...';
    PRINT 'Run sp_Session1_Blocker in one query window';
    PRINT 'Then run sp_Session2_Blocked in another window';
    PRINT 'Use sp_DetectBlocking to identify the blocking';
END;
GO

CREATE OR ALTER PROCEDURE sp_Session1_Blocker
AS
BEGIN
    BEGIN TRANSACTION;
    
    UPDATE Customers
    SET Email = 'blocked_customer@example.com'
    WHERE CustomerID = 1;
    
    PRINT 'Session 1: Updated customer 1 and holding transaction open...';
    PRINT 'This transaction will hold locks for 2 minutes.';
    PRINT 'Run sp_Session2_Blocked in another window to create blocking.';
    
    WAITFOR DELAY '00:02:00';
    
    ROLLBACK TRANSACTION;
    PRINT 'Session 1: Transaction rolled back.';
END;
GO

CREATE OR ALTER PROCEDURE sp_Session2_Blocked
AS
BEGIN
    PRINT 'Session 2: Attempting to update customer 1...';
    PRINT 'This session will be blocked by Session 1.';
    
    BEGIN TRANSACTION;
    
    UPDATE Customers
    SET Phone = '555-BLOCKED'
    WHERE CustomerID = 1;
    
    PRINT 'Session 2: Update completed!';
    
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE sp_DetectBlocking
AS
BEGIN
    SELECT 
        blocking.session_id AS BlockingSessionID,
        blocked.session_id AS BlockedSessionID,
        blocked.wait_time / 1000.0 AS WaitTimeSeconds,
        blocked.wait_type,
        blocking_text.text AS BlockingQuery,
        blocked_text.text AS BlockedQuery
    FROM sys.dm_exec_requests blocked
    INNER JOIN sys.dm_exec_requests blocking 
        ON blocked.blocking_session_id = blocking.session_id
    CROSS APPLY sys.dm_exec_sql_text(blocking.sql_handle) blocking_text
    CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_text
    WHERE blocked.blocking_session_id > 0;
END;
GO

CREATE OR ALTER PROCEDURE sp_ResolveBlocking
    @BlockingSessionID INT
AS
BEGIN
    DECLARE @sql NVARCHAR(100);
    
    IF @BlockingSessionID IS NULL OR @BlockingSessionID < 1
    BEGIN
        PRINT 'Error: Please provide a valid numeric session ID.';
        RETURN;
    END
    
    IF EXISTS (
        SELECT 1 FROM sys.dm_exec_requests 
        WHERE session_id = @BlockingSessionID 
        AND session_id IN (SELECT blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id > 0)
    )
    BEGIN
        SET @sql = 'KILL ' + CAST(@BlockingSessionID AS NVARCHAR(10));
        EXEC sp_executesql @sql;
        PRINT 'Blocking session ' + CAST(@BlockingSessionID AS NVARCHAR(10)) + ' has been terminated.';
        PRINT 'The blocked session should now complete.';
    END
    ELSE
    BEGIN
        PRINT 'Session ' + CAST(@BlockingSessionID AS NVARCHAR(10)) + ' is not a blocking session or does not exist.';
    END
END;
GO

PRINT 'Blocking scenario procedures created successfully!';
