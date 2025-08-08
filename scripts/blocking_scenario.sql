-- Blocking Scenario Script for Lab Exercise
USE CarvedRock;
GO

-- =====================================================
-- SESSION 1: Run this in Query Window 1
-- This creates a blocking transaction
-- =====================================================
/*
BEGIN TRANSACTION;
UPDATE Customers
SET ModifiedDate = GETDATE()
WHERE CustomerID = 1;
-- Keep this window open - DO NOT COMMIT YET
*/

-- =====================================================
-- SESSION 2: Run this in Query Window 2
-- This will be blocked by Session 1
-- =====================================================
/*
SELECT * FROM Customers WHERE CustomerID = 1;
*/

-- =====================================================
-- MONITORING: Run this in Query Window 3
-- Check for blocking sessions
-- =====================================================
SELECT 
    blocking_session_id,
    session_id AS blocked_session_id,
    wait_type,
    wait_time/1000.0 AS wait_seconds
FROM sys.dm_exec_requests
WHERE blocking_session_id > 0;
GO

-- =====================================================
-- RESOLUTION: Back in Query Window 1
-- =====================================================
/*
ROLLBACK TRANSACTION;
*/

PRINT 'Blocking scenario scripts ready.';
PRINT 'Follow the instructions in comments to create and resolve blocking.';
GO
