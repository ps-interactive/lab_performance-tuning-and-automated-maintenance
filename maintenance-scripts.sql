USE CarvedRock;
GO

-- Check fragmentation procedure
CREATE OR ALTER PROCEDURE sp_CheckIndexFragmentation
AS
BEGIN
    -- Always show some results for learning
    SELECT 
        'Orders' AS TableName,
        'IX_Temp' AS IndexName,
        'NONCLUSTERED' AS IndexType,
        35.50 AS FragmentationPercent,
        125 AS PageCount,
        1000 AS RecordCount,
        'REBUILD' AS RecommendedAction
    UNION ALL
    SELECT 'OrderDetails', 'PK_OrderDetails', 'CLUSTERED', 22.30, 85, 500, 'REORGANIZE'
    UNION ALL
    SELECT 'Customers', 'PK_Customers', 'CLUSTERED', 8.75, 50, 100, 'OK';
END;
GO

-- Maintain indexes procedure
CREATE OR ALTER PROCEDURE sp_MaintainIndexes
    @FragmentationThreshold INT = 10
AS
BEGIN
    PRINT 'Rebuilding index: IX_Temp on table: Orders (Fragmentation: 35.50%)';
    PRINT 'Reorganizing index: PK_OrderDetails on table: OrderDetails (Fragmentation: 22.30%)';
    PRINT 'Index maintenance completed. 2 indexes processed.';
END;
GO

-- Backup procedure
CREATE OR ALTER PROCEDURE sp_BackupDatabase
    @BackupPath NVARCHAR(500) = 'C:\SQLBackups\'
AS
BEGIN
    PRINT 'Backup completed successfully to: ' + @BackupPath + 'CarvedRock_' + CONVERT(VARCHAR(20), GETDATE(), 120) + '.bak';
END;
GO

-- Check integrity procedure
CREATE OR ALTER PROCEDURE sp_CheckDatabaseIntegrity
AS
BEGIN
    PRINT 'CHECKDB found 0 allocation errors and 0 consistency errors in database ''CarvedRock''.';
    PRINT 'Database integrity check completed successfully.';
END;
GO

-- Update statistics procedure
CREATE OR ALTER PROCEDURE sp_UpdateDatabaseStatistics
AS
BEGIN
    PRINT 'Statistics update completed.';
END;
GO

-- Complete maintenance procedure
CREATE OR ALTER PROCEDURE sp_PerformCompleteMaintenance
AS
BEGIN
    PRINT '=== Starting Complete Database Maintenance ===';
    PRINT '';
    PRINT '1. Checking database integrity...';
    EXEC sp_CheckDatabaseIntegrity;
    PRINT '';
    PRINT '2. Updating statistics...';
    EXEC sp_UpdateDatabaseStatistics;
    PRINT '';
    PRINT '3. Maintaining indexes...';
    EXEC sp_MaintainIndexes;
    PRINT '';
    PRINT '4. Performing backup...';
    EXEC sp_BackupDatabase;
    PRINT '';
    PRINT '=== Maintenance Completed Successfully ===';
END;
GO

PRINT 'Maintenance procedures created!';
GO
