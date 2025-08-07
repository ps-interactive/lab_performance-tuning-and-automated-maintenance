USE CarvedRock;
GO

-- Create blocking scenario procedures
CREATE OR ALTER PROCEDURE sp_CreateBlockingScenario
AS
BEGIN
    PRINT 'Starting blocking scenario...';
    PRINT 'Run sp_Session1_Blocker in one query window';
    PRINT 'Then run sp_Session2_Blocked in another window';
    PRINT 'Use sp_DetectBlocking to identify the blocking';
END;
GO

-- Session 1: The Blocker
CREATE OR ALTER PROCEDURE sp_Session1_Blocker
AS
BEGIN
    BEGIN TRANSACTION;
    
    -- Update a customer record and hold the lock
    UPDATE Customers
    SET Email = 'blocked_customer@example.com'
    WHERE CustomerID = 1;
    
    PRINT 'Session 1: Updated customer 1 and holding transaction open...';
    PRINT 'This transaction will hold locks for 2 minutes.';
    PRINT 'Run sp_Session2_Blocked in another window to create blocking.';
    
    -- Hold the transaction open for 2 minutes
    WAITFOR DELAY '00:02:00';
    
    -- Rollback the changes
    ROLLBACK TRANSACTION;
    PRINT 'Session 1: Transaction rolled back.';
END;
GO

-- Session 2: The Blocked Session (FIXED - uses Email instead of Phone)
CREATE OR ALTER PROCEDURE sp_Session2_Blocked
AS
BEGIN
    PRINT 'Session 2: Attempting to update customer 1...';
    PRINT 'This session will be blocked by Session 1.';
    
    BEGIN TRANSACTION;
    
    -- This will be blocked by Session 1 (updating Email instead of Phone)
    UPDATE Customers
    SET Email = 'blocked_email@example.com'
    WHERE CustomerID = 1;
    
    PRINT 'Session 2: Update completed!';
    
    COMMIT TRANSACTION;
END;
GO

-- Detect blocking procedure
CREATE OR ALTER PROCEDURE sp_DetectBlocking
AS
BEGIN
    -- Show current blocking chains
    SELECT 
        blocking.session_id AS BlockingSessionID,
        blocked.session_id AS BlockedSessionID,
        blocked.wait_time / 1000.0 AS WaitTimeSeconds,
        blocked.wait_type,
        DB_NAME(blocked.database_id) AS DatabaseName
    FROM sys.dm_exec_requests blocked
    INNER JOIN sys.dm_exec_requests blocking 
        ON blocked.blocking_session_id = blocking.session_id
    WHERE blocked.blocking_session_id > 0;
    
    -- If no blocking found, show sample result
    IF @@ROWCOUNT = 0
    BEGIN
        SELECT 
            55 AS BlockingSessionID,
            56 AS BlockedSessionID,
            15.5 AS WaitTimeSeconds,
            'LCK_M_U' AS wait_type,
            'CarvedRock' AS DatabaseName;
        
        PRINT 'Note: Showing sample blocking data. Run sp_Session1_Blocker first, then sp_Session2_Blocked in another window.';
    END
END;
GO

-- Resolve blocking procedure (FIXED)
CREATE OR ALTER PROCEDURE sp_ResolveBlocking
    @BlockingSessionID INT
AS
BEGIN
    DECLARE @sql NVARCHAR(100);
    
    IF @BlockingSessionID IS NULL OR @BlockingSessionID < 1
    BEGIN
        PRINT 'Error: Please provide a valid numeric session ID.';
        PRINT 'Usage: EXEC sp_ResolveBlocking @BlockingSessionID = 55;';
        RETURN;
    END
    
    -- Check if session exists
    IF EXISTS (SELECT 1 FROM sys.dm_exec_sessions WHERE session_id = @BlockingSessionID)
    BEGIN
        SET @sql = 'KILL ' + CAST(@BlockingSessionID AS NVARCHAR(10));
        EXEC sp_executesql @sql;
        PRINT 'Blocking session ' + CAST(@BlockingSessionID AS NVARCHAR(10)) + ' has been terminated.';
        PRINT 'The blocked session should now complete.';
    END
    ELSE
    BEGIN
        PRINT 'Session ' + CAST(@BlockingSessionID AS NVARCHAR(10)) + ' does not exist.';
        PRINT 'It may have already completed or been terminated.';
    END
END;
GO

PRINT 'Blocking scenario procedures created successfully!';
GO
