-- Blocking Scenario Script for Lab Exercise
USE CarvedRock;
GO

-- =====================================================
-- SESSION 1: Run this in one query window
-- This creates a blocking transaction
-- =====================================================
/*
BEGIN TRANSACTION;

UPDATE Customers
SET ModifiedDate = GETDATE()
WHERE CustomerID = 1;

-- Keep this transaction open to create blocking
-- DO NOT COMMIT YET
WAITFOR DELAY '00:02:00';  -- Hold lock for 2 minutes

ROLLBACK TRANSACTION;
*/

-- =====================================================
-- SESSION 2: Run this in another query window
-- This will be blocked by Session 1
-- =====================================================
/*
SELECT *
FROM Customers WITH (NOLOCK)
WHERE CustomerID = 1;

-- Try without NOLOCK to see blocking
SELECT *
FROM Customers
WHERE CustomerID = 1;
*/

-- =====================================================
-- MONITORING SCRIPT: Run in a third window
-- =====================================================

-- Check for blocking sessions
SELECT 
    blocking_session_id,
    session_id,
    wait_type,
    wait_time,
    wait_resource,
    transaction_id
FROM sys.dm_exec_requests
WHERE blocking_session_id > 0;
GO

-- Get details about blocking and blocked sessions
SELECT 
    tl.request_session_id AS waiting_session_id,
    wt.blocking_session_id,
    DB_NAME(tl.resource_database_id) AS database_name,
    tl.resource_type,
    tl.request_mode,
    tl.request_status,
    wt.wait_duration_ms,
    wt.wait_type,
    wt.resource_description
FROM sys.dm_tran_locks tl
INNER JOIN sys.dm_os_waiting_tasks wt ON tl.lock_owner_address = wt.resource_address
WHERE tl.request_status = 'WAIT';
GO

-- Find head blocker
WITH BlockingHierarchy AS (
    SELECT 
        session_id,
        blocking_session_id,
        0 AS level,
        CAST(session_id AS VARCHAR(MAX)) AS blocking_chain
    FROM sys.dm_exec_requests
    WHERE blocking_session_id = 0 
        AND session_id IN (SELECT blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id > 0)
    
    UNION ALL
    
    SELECT 
        r.session_id,
        r.blocking_session_id,
        bh.level + 1,
        CAST(bh.blocking_chain + ' -> ' + CAST(r.session_id AS VARCHAR(10)) AS VARCHAR(MAX))
    FROM sys.dm_exec_requests r
    INNER JOIN BlockingHierarchy bh ON r.blocking_session_id = bh.session_id
    WHERE r.blocking_session_id > 0
)
SELECT 
    session_id,
    blocking_session_id,
    level,
    blocking_chain
FROM BlockingHierarchy
ORDER BY level, session_id;
GO

-- =====================================================
-- RESOLUTION SCRIPT
-- =====================================================

-- Option 1: Kill the blocking session (use with caution)
-- First, identify the blocking session ID from the queries above
-- KILL [session_id];

-- Option 2: Use READ COMMITTED SNAPSHOT isolation
-- This prevents readers from blocking writers
/*
ALTER DATABASE CarvedRock SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO
*/

-- Option 3: Set lock timeout for the session
-- This will cause the query to fail after specified milliseconds
/*
SET LOCK_TIMEOUT 5000;  -- 5 seconds
GO
*/

-- =====================================================
-- AUTOMATED BLOCKING ALERT SETUP
-- =====================================================

-- Create a SQL Agent Alert for blocking (to be run in SSMS)
/*
USE msdb;
GO

EXEC sp_add_alert 
    @name = N'Blocking Alert',
    @message_id = 0,
    @severity = 0,
    @notification_message = N'Blocking has been detected in CarvedRock database.',
    @delay_between_responses = 300,
    @performance_condition = N'SQLServer:General Statistics|Processes blocked||>|0';

-- Create a job to capture blocking information
EXEC sp_add_job 
    @job_name = N'Capture Blocking Information',
    @enabled = 1;

EXEC sp_add_jobstep
    @job_name = N'Capture Blocking Information',
    @step_name = N'Log Blocking Details',
    @command = N'
    INSERT INTO dbo.BlockingHistory (CaptureTime, BlockingDetails)
    SELECT 
        GETDATE(),
        (SELECT * FROM sys.dm_exec_requests WHERE blocking_session_id > 0 FOR XML AUTO);',
    @database_name = N'CarvedRock';

-- Associate the job with the alert
EXEC sp_update_alert 
    @name = N'Blocking Alert',
    @job_name = N'Capture Blocking Information';
GO
*/

-- Create table to store blocking history
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'BlockingHistory')
BEGIN
    CREATE TABLE BlockingHistory (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        CaptureTime DATETIME,
        BlockingDetails XML
    );
END
GO

PRINT 'Blocking scenario scripts loaded.';
PRINT 'Instructions:';
PRINT '1. Open two query windows in SSMS';
PRINT '2. Run SESSION 1 script in first window (uncomment the code)';
PRINT '3. Quickly run SESSION 2 script in second window';
PRINT '4. Use MONITORING SCRIPT to observe blocking';
PRINT '5. Use RESOLUTION SCRIPT options to resolve blocking';
