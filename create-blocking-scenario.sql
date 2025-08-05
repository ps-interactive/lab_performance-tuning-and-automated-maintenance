-- Script to create a blocking scenario
USE CarvedRock;
GO

-- Create stored procedures for simulating blocking
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

-- Session 2: The Blocked Session
CREATE OR ALTER PROCEDURE sp_Session2_Blocked
AS
BEGIN
    PRINT 'Session 2: Attempting to update customer 1...';
    PRINT 'This session will be blocked by Session 1.';
    
    BEGIN TRANSACTION;
    
    -- This will be blocked by Session 1
    UPDATE Customers
    SET Phone = '555-BLOCKED'
    WHERE CustomerID = 1;
    
    PRINT 'Session 2: Update completed!';
    
    COMMIT TRANSACTION;
END;
GO

-- Procedure to detect blocking
CREATE OR ALTER PROCEDURE sp_DetectBlocking
AS
BEGIN
    -- Show current blocking chains
    SELECT 
        blocking.session_id AS BlockingSessionID,
        blocked.session_id AS BlockedSessionID,
        blocked.wait_time / 1000.0 AS WaitTimeSeconds,
        blocked.wait_type,
        blocking_text.text AS BlockingQuery,
        blocked_text.text AS BlockedQuery,
        DB_NAME(blocked.database_id) AS DatabaseName
    FROM sys.dm_exec_requests blocked
    INNER JOIN sys.dm_exec_requests blocking 
        ON blocked.blocking_session_id = blocking.session_id
    CROSS APPLY sys.dm_exec_sql_text(blocking.sql_handle) blocking_text
    CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_text
    WHERE blocked.blocking_session_id > 0;
    
    -- Show lock information
    SELECT 
        tl.request_session_id AS SessionID,
        tl.resource_type AS ResourceType,
        tl.resource_database_id AS DatabaseID,
        tl.resource_associated_entity_id AS EntityID,
        tl.request_mode AS LockMode,
        tl.request_status AS Status,
        es.host_name AS HostName,
        es.program_name AS ProgramName,
        st.text AS QueryText
    FROM sys.dm_tran_locks tl
    INNER JOIN sys.dm_exec_sessions es ON tl.request_session_id = es.session_id
    INNER JOIN sys.dm_exec_connections ec ON es.session_id = ec.session_id
    CROSS APPLY sys.dm_exec_sql_text(ec.most_recent_sql_handle) st
    WHERE tl.resource_database_id = DB_ID('CarvedRock')
    ORDER BY tl.request_session_id;
END;
GO

-- Procedure to kill blocking sessions (for lab purposes)
CREATE OR ALTER PROCEDURE sp_ResolveBlocking
    @BlockingSessionID INT
AS
BEGIN
    DECLARE @sql NVARCHAR(100);
    
    -- Validate the session ID is a number
    IF @BlockingSessionID IS NULL OR @BlockingSessionID < 1
    BEGIN
        PRINT 'Error: Please provide a valid numeric session ID.';
        PRINT 'Usage: EXEC sp_ResolveBlocking @BlockingSessionID = 55;';
        RETURN;
    END
    
    -- Verify the session exists and is blocking
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
        
        -- Show current blocking sessions to help
        IF EXISTS (SELECT 1 FROM sys.dm_exec_requests WHERE blocking_session_id > 0)
        BEGIN
            PRINT '';
            PRINT 'Current blocking sessions:';
            SELECT DISTINCT blocking_session_id AS BlockingSessionID
            FROM sys.dm_exec_requests 
            WHERE blocking_session_id > 0;
        END
        ELSE
        BEGIN
            PRINT 'No blocking sessions found at this time.';
        END
    END
END;
GO

PRINT 'Blocking scenario procedures created successfully!';
PRINT 'Use sp_CreateBlockingScenario for instructions.';
