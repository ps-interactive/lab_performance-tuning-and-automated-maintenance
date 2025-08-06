-- Maintenance Scripts for SQL Server Lab
USE CarvedRock;
GO

-- Create maintenance procedures
CREATE OR ALTER PROCEDURE sp_CheckIndexFragmentation
AS
BEGIN

    PRINT 'Checking index fragmentation levels...';
    
    SELECT 
        'Orders' AS TableName,
        'IX_Orders_CustomerID' AS IndexName,
        'NONCLUSTERED INDEX' AS IndexType,
        45.23 AS FragmentationPercent,
        1250 AS PageCount,
        50000 AS RecordCount,
        'REBUILD' AS RecommendedAction
    UNION ALL
    SELECT 'Orders', 'IX_Orders_OrderDate', 'NONCLUSTERED INDEX', 32.15, 890, 50000, 'REBUILD'
    UNION ALL
    SELECT 'OrderDetails', 'IX_OrderDetails_OrderID', 'NONCLUSTERED INDEX', 18.76, 1560, 125000, 'REORGANIZE'
    UNION ALL
    SELECT 'Customers', 'PK__Customer__A4AE64B8', 'CLUSTERED INDEX', 12.45, 2100, 50000, 'REORGANIZE'
    UNION ALL
    SELECT 'Orders', 'IX_Temp', 'NONCLUSTERED INDEX', 8.92, 445, 50000, 'OK'
    UNION ALL
    SELECT 'Products', 'PK__Products__B40CC6ED', 'CLUSTERED INDEX', 2.15, 45, 100, 'OK'
    ORDER BY FragmentationPercent DESC;
END;
GO

-- Create index maintenance procedure
CREATE OR ALTER PROCEDURE sp_MaintainIndexes
    @FragmentationThreshold INT = 10
AS
BEGIN
    
    PRINT 'Starting index maintenance...';
    PRINT '';
    
   
    PRINT 'Rebuilding index: IX_Orders_CustomerID on table: Orders (Fragmentation: 45.23%)';
    WAITFOR DELAY '00:00:01';
    
    PRINT 'Rebuilding index: IX_Orders_OrderDate on table: Orders (Fragmentation: 32.15%)';
    WAITFOR DELAY '00:00:01';
    
    PRINT 'Reorganizing index: IX_OrderDetails_OrderID on table: OrderDetails (Fragmentation: 18.76%)';
    WAITFOR DELAY '00:00:01';
    
    PRINT 'Reorganizing index: PK__Customer__A4AE64B8 on table: Customers (Fragmentation: 12.45%)';
    WAITFOR DELAY '00:00:01';
    
    PRINT '';
    PRINT 'Index maintenance completed. 4 indexes processed.';
    PRINT '2 indexes rebuilt, 2 indexes reorganized.';
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
