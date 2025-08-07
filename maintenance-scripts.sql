USE CarvedRock;
GO

-- Drop table if exists to avoid error
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'MaintenanceHistory')
    DROP TABLE MaintenanceHistory;
GO

CREATE TABLE MaintenanceHistory (
    MaintenanceID INT IDENTITY(1,1) PRIMARY KEY,
    MaintenanceType NVARCHAR(50),
    StartTime DATETIME,
    EndTime DATETIME,
    Status NVARCHAR(20),
    Details NVARCHAR(MAX)
);
GO

-- Create procedures with simulated results
CREATE OR ALTER PROCEDURE sp_CheckIndexFragmentation
AS
BEGIN
    -- Always show some fragmentation for demonstration
    SELECT 
        'Orders' AS TableName,
        'IX_Temp' AS IndexName,
        'NONCLUSTERED INDEX' AS IndexType,
        35.50 AS FragmentationPercent,
        125 AS PageCount,
        1000 AS RecordCount,
        'REBUILD' AS RecommendedAction
    UNION ALL
    SELECT 'OrderDetails', 'IX_OrderDetails_OrderID', 'NONCLUSTERED INDEX', 22.30, 85, 2500, 'REORGANIZE'
    UNION ALL
    SELECT 'Customers', 'PK__Customer__A4AE64B8', 'CLUSTERED INDEX', 15.75, 50, 1000, 'REORGANIZE'
    UNION ALL
    SELECT 'Orders', 'IX_Orders_CustomerID', 'NONCLUSTERED INDEX', 8.25, 45, 1500, 'OK'
    UNION ALL
    SELECT 'Products', 'PK__Products__B40CC6ED', 'CLUSTERED INDEX', 2.10, 25, 10, 'OK';
    
    PRINT 'Index fragmentation analysis complete.';
END;
GO

CREATE OR ALTER PROCEDURE sp_MaintainIndexes
    @FragmentationThreshold INT = 10
AS
BEGIN
    -- Simulate index maintenance
    PRINT 'Starting index maintenance...';
    PRINT '';
    PRINT 'Rebuilding index: IX_Temp on table: Orders (Fragmentation: 35.50%)';
    WAITFOR DELAY '00:00:01';
    PRINT 'Index rebuilt successfully.';
    PRINT '';
    PRINT 'Reorganizing index: IX_OrderDetails_OrderID on table: OrderDetails (Fragmentation: 22.30%)';
    WAITFOR DELAY '00:00:01';
    PRINT 'Index reorganized successfully.';
    PRINT '';
    PRINT 'Reorganizing index: PK__Customer__A4AE64B8 on table: Customers (Fragmentation: 15.75%)';
    WAITFOR DELAY '00:00:01';
    PRINT 'Index reorganized successfully.';
    PRINT '';
    PRINT 'Index maintenance completed. 3 indexes processed.';
END;
GO

CREATE OR ALTER PROCEDURE sp_BackupDatabase
    @BackupPath NVARCHAR(500) = 'C:\SQLBackups\'
AS
BEGIN
    DECLARE @FileName NVARCHAR(500);
    DECLARE @DateString NVARCHAR(20);
    
    SET @DateString = REPLACE(CONVERT(NVARCHAR(20), GETDATE(), 120), ':', '-');
    SET @FileName = @BackupPath + 'CarvedRock_' + @DateString + '.bak';
    
    PRINT 'Starting backup...';
    PRINT 'Backup location: ' + @FileName;
    WAITFOR DELAY '00:00:02';
    PRINT 'Backup completed successfully!';
END;
GO

CREATE OR ALTER PROCEDURE sp_CheckDatabaseIntegrity
AS
BEGIN
    PRINT 'Checking database integrity...';
    WAITFOR DELAY '00:00:01';
    PRINT 'CHECKDB found 0 allocation errors and 0 consistency errors in database ''CarvedRock''.';
    PRINT 'Database integrity check completed successfully.';
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateDatabaseStatistics
AS
BEGIN
    PRINT 'Updating database statistics...';
    WAITFOR DELAY '00:00:01';
    PRINT 'Statistics update completed successfully.';
END;
GO

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

PRINT 'Maintenance procedures created successfully!';
GO
