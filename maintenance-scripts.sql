-- Maintenance Scripts for SQL Server Lab
USE CarvedRock;
GO

-- Create maintenance procedures
CREATE OR ALTER PROCEDURE sp_CheckIndexFragmentation
AS
BEGIN
    SELECT 
        OBJECT_NAME(ips.object_id) AS TableName,
        i.name AS IndexName,
        ips.index_type_desc AS IndexType,
        ips.avg_fragmentation_in_percent AS FragmentationPercent,
        ips.page_count AS PageCount,
        ips.record_count AS RecordCount,
        CASE 
            WHEN ips.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
            WHEN ips.avg_fragmentation_in_percent > 10 THEN 'REORGANIZE'
            ELSE 'OK'
        END AS RecommendedAction
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.index_id > 0
        AND ips.page_count > 100
    ORDER BY ips.avg_fragmentation_in_percent DESC;
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
    
    DECLARE index_cursor CURSOR FOR
        SELECT 
            OBJECT_NAME(ips.object_id) AS TableName,
            i.name AS IndexName,
            ips.avg_fragmentation_in_percent
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
        INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
        WHERE ips.index_id > 0
            AND ips.page_count > 100
            AND ips.avg_fragmentation_in_percent > @FragmentationThreshold;
    
    OPEN index_cursor;
    FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @FragPercent;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @FragPercent > 30
        BEGIN
            SET @SQL = 'ALTER INDEX [' + @IndexName + '] ON [' + @TableName + '] REBUILD;';
            PRINT 'Rebuilding index: ' + @IndexName + ' on table: ' + @TableName;
        END
        ELSE
        BEGIN
            SET @SQL = 'ALTER INDEX [' + @IndexName + '] ON [' + @TableName + '] REORGANIZE;';
            PRINT 'Reorganizing index: ' + @IndexName + ' on table: ' + @TableName;
        END
        
        EXEC sp_executesql @SQL;
        
        FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @FragPercent;
    END;
    
    CLOSE index_cursor;
    DEALLOCATE index_cursor;
    
    PRINT 'Index maintenance completed.';
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
    DBCC CHECKDB('CarvedRock') WITH NO_INFOMSGS;
    PRINT 'Database integrity check completed.';
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
