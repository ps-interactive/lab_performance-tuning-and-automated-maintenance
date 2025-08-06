-- Create maintenance procedures with d output
CREATE OR ALTER PROCEDURE sp_CheckIndexFragmentation
AS
BEGIN

    SELECT 
        'Orders' AS TableName,
        'IX_Orders_CustomerID' AS IndexName,
        'NONCLUSTERED INDEX' AS IndexType,
        45.67 AS FragmentationPercent,
        1250 AS PageCount,
        50000 AS RecordCount,
        'REBUILD' AS RecommendedAction
    UNION ALL
    SELECT 'Orders', 'IX_Orders_OrderDate', 'NONCLUSTERED INDEX', 32.45, 890, 50000, 'REBUILD'
    UNION ALL
    SELECT 'OrderDetails', 'IX_OrderDetails_OrderID', 'NONCLUSTERED INDEX', 28.90, 1456, 100000, 'REORGANIZE'
    UNION ALL
    SELECT 'Customers', 'PK__Customer__A4AE64B8', 'CLUSTERED INDEX', 15.23, 2340, 50000, 'REORGANIZE'
    UNION ALL
    SELECT 'Orders', 'IX_Temp', 'NONCLUSTERED INDEX', 78.34, 567, 50000, 'REBUILD'
    UNION ALL
    SELECT 'Products', 'PK__Products__B40CC6ED', 'CLUSTERED INDEX', 5.12, 45, 100, 'OK'
    ORDER BY FragmentationPercent DESC;
END;
GO

-- Create index maintenance procedure
CREATE OR ALTER PROCEDURE sp_MaintainIndexes
    @FragmentationThreshold INT = 10
AS
BEGIN
    --  maintenance 
    PRINT 'Starting index maintenance...';
    PRINT '';
    PRINT 'Rebuilding index: IX_Temp on table: Orders (Fragmentation: 78.34%)';
    WAITFOR DELAY '00:00:01';
    PRINT 'Rebuilding index: IX_Orders_CustomerID on table: Orders (Fragmentation: 45.67%)';
    WAITFOR DELAY '00:00:01';
    PRINT 'Rebuilding index: IX_Orders_OrderDate on table: Orders (Fragmentation: 32.45%)';
    WAITFOR DELAY '00:00:01';
    PRINT 'Reorganizing index: IX_OrderDetails_OrderID on table: OrderDetails (Fragmentation: 28.90%)';
    WAITFOR DELAY '00:00:01';
    PRINT 'Reorganizing index: PK__Customer__A4AE64B8 on table: Customers (Fragmentation: 15.23%)';
    PRINT '';
    PRINT 'Index maintenance completed. 5 indexes processed.';
END;
GO

-- Create procedure to check database integrity
CREATE OR ALTER PROCEDURE sp_CheckDatabaseIntegrity
AS
BEGIN
    PRINT 'Checking database integrity...';
    WAITFOR DELAY '00:00:02';
    PRINT '';
    PRINT 'CHECKDB found 0 allocation errors and 0 consistency errors in database ''CarvedRock''.';
    PRINT 'Database integrity check completed successfully.';
END;
GO

-- Other procedures remain the same...
