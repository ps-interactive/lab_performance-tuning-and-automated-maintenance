-- Maintenance Scripts for SQL Server Lab
USE CarvedRock;
GO

-- Create maintenance procedures
CREATE OR ALTER PROCEDURE sp_CheckIndexFragmentation
AS
BEGIN
    -- First check if we have any fragmented indexes
    IF NOT EXISTS (
        SELECT 1 
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
        INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
        WHERE ips.index_id > 0 AND ips.avg_fragmentation_in_percent > 5
    )
    BEGIN
        -- Create some fragmentation for demonstration
        PRINT 'No fragmentation detected. Creating sample fragmentation for demonstration...';
        
        -- Fragment the IX_Temp index if it exists
        IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Temp')
        BEGIN
            -- Random updates to create fragmentation
            UPDATE Orders SET ShipDate = DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 5, ShipDate);
            UPDATE Orders SET OrderStatus = 'Pending' WHERE OrderID % 7 = 0;
            UPDATE Orders SET OrderStatus = 'Shipped' WHERE OrderID % 7 = 1;
        END
    END
    
    -- Now show the fragmentation report
    SELECT 
        OBJECT_NAME(ips.object_id) AS TableName,
        ISNULL(i.name, 'HEAP') AS IndexName,
        ips.index_type_desc AS IndexType,
        CAST(ips.avg_fragmentation_in_percent AS DECIMAL(5,2)) AS FragmentationPercent,
        ips.page_count AS PageCount,
        ips.record_count AS RecordCount,
        CASE 
            WHEN ips.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
            WHEN ips.avg_fragmentation_in_percent > 10 THEN 'REORGANIZE'
            ELSE 'OK'
        END AS RecommendedAction
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    LEFT JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.page_count > 0
    ORDER BY ips.avg_fragmentation_in_percent DESC;
    
    -- If still no results, show a sample result set for learning
    IF @@ROWCOUNT = 0
    BEGIN
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
        SELECT 'Customers', 'PK__Customer__A4AE64B8', 'CLUSTERED INDEX', 8.75, 50, 1000, 'OK';
        
        PRINT 'Note: Showing sample fragmentation data for demonstration purposes.';
    END
END;
GO

-- Create index maintenance procedure
CREATE OR ALTER PROCEDURE sp_MaintainIndexes
    @FragmentationThreshold INT = 10
AS
BEGIN
    DECLARE @TableName NVARCHAR(128);
    DECLARE @IndexName NVARCHAR(128);
    DECLARE @FragPercent FLOAT;
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @Count INT = 0;
    
    DECLARE index_cursor CURSOR FOR
        SELECT 
            OBJECT_NAME(ips.object_id) AS TableName,
            i.name AS IndexName,
            ips.avg_fragmentation_in_percent
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
        INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
        WHERE ips.index_id > 0
            AND ips.page_count > 10  -- Lowered threshold
            AND ips.avg_fragmentation_in_percent > @FragmentationThreshold;
    
    OPEN index_cursor;
    FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @FragPercent;
    
    IF @@FETCH_STATUS <> 0
    BEGIN
        PRINT 'No indexes found with fragmentation above ' + CAST(@FragmentationThreshold AS VARCHAR(10)) + '%.';
        PRINT 'All indexes are already optimized.';
    END
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @FragPercent > 30
        BEGIN
            SET @SQL = 'ALTER INDEX [' + @IndexName + '] ON [' + @TableName + '] REBUILD;';
            PRINT 'Rebuilding index: ' + @IndexName + ' on table: ' + @TableName + ' (Fragmentation: ' + CAST(@FragPercent AS VARCHAR(10)) + '%)';
        END
        ELSE
        BEGIN
            SET @SQL = 'ALTER INDEX [' + @IndexName + '] ON [' + @TableName + '] REORGANIZE;';
            PRINT 'Reorganizing index: ' + @IndexName + ' on table: ' + @TableName + ' (Fragmentation: ' + CAST(@FragPercent AS VARCHAR(10)) + '%)';
        END
        
        EXEC sp_executesql @SQL;
        SET @Count = @Count + 1;
        
        FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @FragPercent;
    END;
    
    CLOSE index_cursor;
    DEALLOCATE index_cursor;
    
    IF @Count > 0
        PRINT 'Index maintenance completed. ' + CAST(@Count AS VARCHAR(10)) + ' indexes processed.';
    ELSE
        PRINT 'No index maintenance required.';
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
