-- Lab Queries for Performance Tuning Exercises
-- First verify the database exists
SELECT name FROM sys.databases WHERE name = 'CarvedRock';
GO

USE CarvedRock;
GO

-- =====================================================
-- SECTION 1: DMV Queries for Performance Analysis
-- =====================================================

-- Query 1: Find top 10 most expensive queries by CPU (simplified)
SELECT TOP 10
    qs.total_worker_time AS total_cpu_time,
    qs.execution_count,
    SUBSTRING(st.text, 1, 100) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.total_worker_time DESC;
GO

-- Query 2: Find missing indexes
SELECT 
    migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) AS improvement_measure,
    'CREATE INDEX [IX_' + LEFT(PARSENAME(mid.statement, 1), 32) + '_'
    + REPLACE(REPLACE(REPLACE(ISNULL(mid.equality_columns, ''), ', ', '_'), '[', ''), ']', '') 
    + CASE
        WHEN mid.inequality_columns IS NOT NULL THEN '_' + REPLACE(REPLACE(REPLACE(mid.inequality_columns, ', ', '_'), '[', ''), ']', '')
        ELSE ''
    END + ']'
    + ' ON ' + mid.statement
    + ' (' + ISNULL(mid.equality_columns, '')
    + CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END
    + ISNULL(mid.inequality_columns, '')
    + ')'
    + ISNULL(' INCLUDE (' + mid.included_columns + ')', '') AS create_index_statement,
    migs.*,
    mid.database_id,
    mid.[object_id]
FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY improvement_measure DESC;
GO

-- Query 3: Check index fragmentation
SELECT 
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name AS IndexName,
    ips.index_type_desc,
    ips.avg_fragmentation_in_percent,
    ips.page_count,
    CASE 
        WHEN ips.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
        WHEN ips.avg_fragmentation_in_percent > 10 THEN 'REORGANIZE'
        ELSE 'OK'
    END AS Recommendation
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 10
    AND ips.page_count > 1000
ORDER BY ips.avg_fragmentation_in_percent DESC;
GO

-- Query 4: Find blocking queries
SELECT 
    blocking.session_id AS blocking_session_id,
    blocked.session_id AS blocked_session_id,
    blocked.wait_time/1000 AS wait_time_seconds,
    blocked.wait_type,
    blocking_text.text AS blocking_query,
    blocked_text.text AS blocked_query
FROM sys.dm_exec_requests blocked
INNER JOIN sys.dm_exec_requests blocking ON blocked.blocking_session_id = blocking.session_id
CROSS APPLY sys.dm_exec_sql_text(blocking.sql_handle) blocking_text
CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_text
WHERE blocked.blocking_session_id > 0;
GO

-- Query 5: Check wait statistics
SELECT TOP 10
    wait_type,
    wait_time_ms / 1000.0 AS wait_time_sec,
    CAST(100.0 * wait_time_ms / SUM(wait_time_ms) OVER() AS DECIMAL(5,2)) AS wait_pct,
    waiting_tasks_count
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
    'CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE',
    'SLEEP_TASK', 'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH',
    'WAITFOR', 'LOGMGR_QUEUE', 'CHECKPOINT_QUEUE',
    'REQUEST_FOR_DEADLOCK_SEARCH', 'XE_TIMER_EVENT',
    'BROKER_TO_FLUSH', 'BROKER_TASK_STOP', 'CLR_MANUAL_EVENT',
    'CLR_AUTO_EVENT', 'DISPATCHER_QUEUE_SEMAPHORE',
    'FT_IFTS_SCHEDULER_IDLE_WAIT', 'XE_DISPATCHER_WAIT',
    'XE_DISPATCHER_JOIN', 'BROKER_EVENTHANDLER',
    'TRACEWRITE', 'FT_IFTSHC_MUTEX', 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
    'DIRTY_PAGE_POLL', 'HADR_FILESTREAM_IOMGR_IOCOMPLETION'
)
ORDER BY wait_time_ms DESC;
GO

-- =====================================================
-- SECTION 2: Problem Queries to Diagnose
-- =====================================================

-- Problem Query 1: Missing Index Example
SELECT 
    o.OrderID,
    o.OrderDate,
    o.TotalAmount,
    c.FirstName,
    c.LastName,
    c.Email
FROM Orders o
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
WHERE o.OrderDate >= DATEADD(MONTH, -3, GETDATE())
ORDER BY o.TotalAmount DESC;
GO

-- Problem Query 2: Inefficient Subquery
SELECT 
    p.ProductName,
    p.Price,
    (SELECT COUNT(*) FROM OrderDetails WHERE ProductID = p.ProductID) AS TimesSold,
    (SELECT AVG(Rating) FROM Reviews WHERE ProductID = p.ProductID) AS AvgRating
FROM Products p
WHERE p.CategoryID IN (1, 2, 3);
GO

-- Problem Query 3: Function in WHERE clause
SELECT *
FROM Orders
WHERE YEAR(OrderDate) = 2024
    AND MONTH(OrderDate) = 6;
GO

-- Problem Query 4: Implicit Conversion
DECLARE @CustomerID NVARCHAR(10) = '1234';
SELECT *
FROM Orders
WHERE CustomerID = @CustomerID;
GO

-- Problem Query 5: Large Result Set without filtering
SELECT *
FROM OrderDetails od
INNER JOIN Orders o ON od.OrderID = o.OrderID
INNER JOIN Products p ON od.ProductID = p.ProductID
INNER JOIN Customers c ON o.CustomerID = c.CustomerID;
GO

-- =====================================================
-- SECTION 3: Index Maintenance Scripts
-- =====================================================

-- Script to rebuild all fragmented indexes
DECLARE @TableName NVARCHAR(255);
DECLARE @IndexName NVARCHAR(255);
DECLARE @SQL NVARCHAR(MAX);

DECLARE index_cursor CURSOR FOR
SELECT 
    OBJECT_NAME(ips.object_id),
    i.name
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 30
    AND ips.page_count > 1000
    AND i.name IS NOT NULL;

OPEN index_cursor;
FETCH NEXT FROM index_cursor INTO @TableName, @IndexName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = 'ALTER INDEX [' + @IndexName + '] ON [' + @TableName + '] REBUILD;';
    PRINT @SQL;
    -- EXEC sp_executesql @SQL;  -- Uncomment to execute
    FETCH NEXT FROM index_cursor INTO @TableName, @IndexName;
END

CLOSE index_cursor;
DEALLOCATE index_cursor;
GO

-- =====================================================
-- SECTION 4: SQL Agent Job Creation Scripts
-- =====================================================

-- Create a maintenance job (to be executed via SSMS)
/*
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'CarvedRock_Daily_Maintenance',
    @enabled = 1,
    @description = N'Daily maintenance tasks for CarvedRock database';

EXEC dbo.sp_add_jobstep
    @job_name = N'CarvedRock_Daily_Maintenance',
    @step_name = N'Check Database Integrity',
    @command = N'DBCC CHECKDB(''CarvedRock'') WITH NO_INFOMSGS;',
    @database_name = N'CarvedRock';

EXEC dbo.sp_add_jobstep
    @job_name = N'CarvedRock_Daily_Maintenance',
    @step_name = N'Rebuild Indexes',
    @command = N'ALTER INDEX ALL ON Customers REBUILD;
                ALTER INDEX ALL ON Products REBUILD;
                ALTER INDEX ALL ON Orders REBUILD;',
    @database_name = N'CarvedRock';

EXEC dbo.sp_add_jobstep
    @job_name = N'CarvedRock_Daily_Maintenance',
    @step_name = N'Update Statistics',
    @command = N'UPDATE STATISTICS Customers WITH FULLSCAN;
                UPDATE STATISTICS Products WITH FULLSCAN;
                UPDATE STATISTICS Orders WITH FULLSCAN;',
    @database_name = N'CarvedRock';

EXEC dbo.sp_add_schedule
    @schedule_name = N'Daily_2AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 020000;

EXEC dbo.sp_attach_schedule
    @job_name = N'CarvedRock_Daily_Maintenance',
    @schedule_name = N'Daily_2AM';

EXEC dbo.sp_add_jobserver
    @job_name = N'CarvedRock_Daily_Maintenance',
    @server_name = @@SERVERNAME;
GO
*/
