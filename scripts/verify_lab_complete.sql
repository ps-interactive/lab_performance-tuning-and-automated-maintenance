-- Complete Lab Verification Script
-- Run this to check if everything is working correctly

USE master;
GO

PRINT '========================================';
PRINT 'LAB VERIFICATION STARTING...';
PRINT '========================================';
PRINT '';

-- Check 1: Database exists
IF DB_ID('CarvedRock') IS NOT NULL
BEGIN
    PRINT '[PASS] Database CarvedRock exists';
    
    USE CarvedRock;
    
    -- Check 2: Tables exist
    DECLARE @tableCount INT = (SELECT COUNT(*) FROM sys.tables);
    IF @tableCount >= 5
        PRINT '[PASS] Tables created: ' + CAST(@tableCount AS VARCHAR(10)) + ' tables found';
    ELSE
        PRINT '[FAIL] Only ' + CAST(@tableCount AS VARCHAR(10)) + ' tables found (expected 5+)';
    
    -- Check 3: Data exists
    DECLARE @customerCount INT = (SELECT COUNT(*) FROM Customers);
    DECLARE @orderCount INT = (SELECT COUNT(*) FROM Orders);
    DECLARE @productCount INT = (SELECT COUNT(*) FROM Products);
    
    IF @customerCount > 0
        PRINT '[PASS] Customers table has ' + CAST(@customerCount AS VARCHAR(10)) + ' rows';
    ELSE
        PRINT '[FAIL] Customers table is empty';
        
    IF @orderCount > 0
        PRINT '[PASS] Orders table has ' + CAST(@orderCount AS VARCHAR(10)) + ' rows';
    ELSE
        PRINT '[FAIL] Orders table is empty';
        
    IF @productCount > 0
        PRINT '[PASS] Products table has ' + CAST(@productCount AS VARCHAR(10)) + ' rows';
    ELSE
        PRINT '[FAIL] Products table is empty';
    
    -- Check 4: Missing indexes can be detected
    PRINT '';
    PRINT 'Checking missing index detection...';
    
    -- Drop indexes if they exist
    IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Orders_CustomerID')
        DROP INDEX IX_Orders_CustomerID ON Orders;
    IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Orders_OrderDate')
        DROP INDEX IX_Orders_OrderDate ON Orders;
    
    -- Run queries to trigger missing index detection
    DECLARE @i INT = 1;
    WHILE @i <= 5
    BEGIN
        EXEC sp_executesql N'SELECT * FROM Orders WHERE CustomerID = @id', N'@id INT', @i;
        SET @i = @i + 1;
    END
    
    -- Check if missing indexes are detected
    DECLARE @missingIndexCount INT = (
        SELECT COUNT(*) 
        FROM sys.dm_db_missing_index_details 
        WHERE database_id = DB_ID() 
        AND object_id = OBJECT_ID('Orders')
    );
    
    IF @missingIndexCount > 0
        PRINT '[PASS] Missing index detection working: ' + CAST(@missingIndexCount AS VARCHAR(10)) + ' missing indexes detected';
    ELSE
        PRINT '[WARNING] No missing indexes detected - students may need to run generate_missing_indexes.sql';
    
    -- Check 5: SQL Agent is running
    DECLARE @agentStatus VARCHAR(50);
    SELECT @agentStatus = 
        CASE 
            WHEN EXISTS (SELECT 1 FROM sys.dm_server_services WHERE servicename LIKE 'SQL Server Agent%' AND status_desc = 'Running')
            THEN '[PASS] SQL Server Agent is running'
            ELSE '[WARNING] SQL Server Agent is not running - jobs won''t work'
        END;
    PRINT @agentStatus;
    
    -- Check 6: Fragmented indexes exist
    DECLARE @fragmentedCount INT = (
        SELECT COUNT(*) 
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED')
        WHERE avg_fragmentation_in_percent > 10
        AND page_count > 100
    );
    
    IF @fragmentedCount > 0
        PRINT '[PASS] Fragmented indexes found: ' + CAST(@fragmentedCount AS VARCHAR(10)) + ' indexes';
    ELSE
        PRINT '[INFO] No fragmented indexes found (this is OK)';
    
    -- Check 7: Stored procedures exist
    DECLARE @procCount INT = (SELECT COUNT(*) FROM sys.procedures WHERE name LIKE 'sp_Get%');
    IF @procCount > 0
        PRINT '[PASS] Stored procedures created: ' + CAST(@procCount AS VARCHAR(10)) + ' procedures';
    ELSE
        PRINT '[WARNING] No stored procedures found';
END
ELSE
BEGIN
    PRINT '[FAIL] Database CarvedRock does not exist!';
    PRINT '';
    PRINT 'TO FIX: Run these scripts in order:';
    PRINT '1. C:\LabFiles\create_database.sql';
    PRINT '2. C:\LabFiles\populate_data.sql';
    PRINT '3. C:\LabFiles\create_performance_issues.sql';
END

PRINT '';
PRINT '========================================';
PRINT 'VERIFICATION COMPLETE';
PRINT '========================================';
PRINT '';
PRINT 'If any items show [FAIL] or [WARNING], refer to the fix instructions.';
PRINT 'For missing index issues, run: C:\LabFiles\generate_missing_indexes.sql';
GO
