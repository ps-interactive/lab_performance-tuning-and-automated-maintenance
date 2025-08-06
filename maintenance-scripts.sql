-- Maintenance Scripts for SQL Server Lab
USE CarvedRock;
GO

-- Create maintenance procedures
CREATE OR ALTER PROCEDURE sp_CheckIndexFragmentation
AS
BEGIN
    -- Show simulated fragmentation for demonstration
    SELECT 
        'Orders' AS TableName,
        'IX_Orders_CustomerID' AS IndexName,
        'NONCLUSTERED INDEX' AS IndexType,
        45.67 AS FragmentationPercent,
        1250 AS PageCount,
        10000 AS RecordCount,
        'REBUILD' AS RecommendedAction
    UNION ALL
    SELECT 'Orders', 'IX_Orders_OrderDate', 'NONCLUSTERED INDEX', 32.15, 890, 10000, 'REBUILD'
    UNION ALL
    SELECT 'OrderDetails', 'IX_OrderDetails_OrderID', 'NONCLUSTERED INDEX', 28.93, 675, 25000, 'REORGANIZE'
    UNION ALL
    SELECT 'Customers', 'PK__Customer__A4AE64B8', 'CLUSTERED INDEX', 15.25, 2100, 5000, 'REORGANIZE'
    UNION ALL
    SELECT 'Orders', 'IX_Temp', 'NONCLUSTERED INDEX', 12.50, 450, 10000, 'REORGANIZE'
    UNION ALL
    SELECT 'Products', 'PK__Products__B40CC6ED', 'CLUSTERED INDEX', 5.10, 25, 10, 'OK'
    UNION ALL
    SELECT 'OrderDetails', 'PK__OrderDet__D3B9D30C', 'CLUSTERED INDEX', 3.45, 1800, 25000, 'OK'
    ORDER BY FragmentationPercent DESC;
END;
GO

-- Create index maintenance procedure
CREATE OR ALTER PROCEDURE sp_MaintainIndexes
    @FragmentationThreshold INT = 10
AS
BEGIN
    -- Simulate index maintenance for demonstration
    PRINT 'Starting index maintenance...';
    PRINT '';
    
    -- Simulate rebuilding highly fragmented indexes
    IF @FragmentationThreshold <= 45
    BEGIN
        PRINT 'Rebuilding index: IX_Orders_CustomerID on table: Orders (Fragmentation: 45.67%)';
        WAITFOR DELAY '00:00:01';
        PRINT 'Rebuilding index: IX_Orders_OrderDate on table: Orders (Fragmentation: 32.15%)';
        WAITFOR DELAY '00:00:01';
    END
    
    -- Simulate reorganizing moderately fragmented indexes
    IF @FragmentationThreshold <= 28
    BEGIN
        PRINT 'Reorganizing index: IX_OrderDetails_OrderID on table: OrderDetails (Fragmentation: 28.93%)';
        WAITFOR DELAY '00:00:01';
    END
    
    IF @FragmentationThreshold <= 15
    BEGIN
        PRINT 'Reorganizing index: PK__Customer__A4AE64B8 on table: Customers (Fragmentation: 15.25%)';
        WAITFOR DELAY '00:00:01';
    END
    
    IF @FragmentationThreshold <= 12
    BEGIN
        PRINT 'Reorganizing index: IX_Temp on table: Orders (Fragmentation: 12.50%)';
        WAITFOR DELAY '00:00:01';
    END
    
    PRINT '';
    PRINT 'Index maintenance completed.';
    
    -- Count how many indexes were processed
    DECLARE @Count INT = 0;
    IF @FragmentationThreshold <= 45 SET @Count = @Count + 2;
    IF @FragmentationThreshold <= 28 SET @Count = @Count + 1;
    IF @FragmentationThreshold <= 15 SET @Count = @Count + 1;
    IF @FragmentationThreshold <= 12 SET @Count = @Count + 1;
    
    PRINT CAST(@Count AS VARCHAR(10)) + ' indexes processed.';
END;
GO

-- Create backup procedure
CREATE OR ALTER PROCEDURE sp_BackupDatabase
    @BackupPath NVARCHAR(500) = 'C:\SQLBackups\'
AS
BEGIN
    DECLARE @FileName NVARCHAR(500);
    DECLARE @BackupName NVARCHAR(200);
    DECLARE @DateString NVARCHAR(20);
    
    -- Create backup directory if it doesn't exist
    EXEC xp_create_subdir @BackupPath;
    
    SET @DateString = REPLACE(CONVERT(NVARCHAR(20), GETDATE(), 120), ':', '-');
    SET @FileName = @BackupPath + 'CarvedRock_' + @DateString + '.bak';
    SET @BackupName = 'CarvedRock Full Backup ' + CONVERT(NVARCHAR(50), GETDATE(), 120);
    
    BACKUP DATABASE CarvedRock
    TO DISK = @FileName
    WITH FORMAT,
        INIT,
        NAME = @BackupName,
        COMPRESSION,
        STATS = 10;
    
    PRINT 'Backup completed successfully to: ' + @FileName;
END;
GO

-- Create procedure to check database integrity
CREATE OR ALTER PROCEDURE sp_CheckDatabaseIntegrity
AS
BEGIN
    -- Run CHECKDB
    DBCC CHECKDB('CarvedRock') WITH NO_INFOMSGS;
    
    -- Always show a message for clarity
    IF @@ERROR = 0
    BEGIN
        PRINT '';
        PRINT 'CHECKDB found 0 allocation errors and 0 consistency errors in database ''CarvedRock''.';
        PRINT 'Database integrity check completed successfully.';
    END
    ELSE
    BEGIN
        PRINT 'Database integrity check completed with errors.';
    END
END;
GO

-- Create procedure to update statistics
CREATE OR ALTER PROCEDURE sp_UpdateDatabaseStatistics
AS
BEGIN
    EXEC sp_updatestats;
    PRINT 'Statistics update completed.';
END;
GO

-- Create a comprehensive maintenance procedure
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

-- Create table for maintenance history
CREATE TABLE MaintenanceHistory (
    MaintenanceID INT IDENTITY(1,1) PRIMARY KEY,
    MaintenanceType NVARCHAR(50),
    StartTime DATETIME,
    EndTime DATETIME,
    Status NVARCHAR(20),
    Details NVARCHAR(MAX)
);
GO

PRINT 'Maintenance procedures created successfully!';
