-- Script to Generate Missing Index Recommendations
-- Run this if the missing index DMV returns 0 rows

USE CarvedRock;
GO

PRINT 'Generating missing index recommendations...';
PRINT 'This will take about 10 seconds...';
GO

-- Clear procedure cache to reset missing index stats
DBCC FREEPROCCACHE WITH NO_INFOMSGS;
GO

-- Generate need for index on Orders.CustomerID
SELECT * FROM Orders WHERE CustomerID = 1;
SELECT * FROM Orders WHERE CustomerID = 5;
SELECT * FROM Orders WHERE CustomerID = 10;
SELECT * FROM Orders WHERE CustomerID = 15;
SELECT * FROM Orders WHERE CustomerID = 20;
GO

-- Generate need for index on Orders.OrderDate
SELECT * FROM Orders WHERE OrderDate >= '2024-01-01' ORDER BY OrderDate;
SELECT * FROM Orders WHERE OrderDate >= '2024-06-01' ORDER BY OrderDate;
SELECT * FROM Orders WHERE OrderDate BETWEEN '2024-01-01' AND '2024-12-31';
GO

-- Generate need for composite index
SELECT o.OrderID, o.OrderDate, o.TotalAmount, c.FirstName, c.LastName
FROM Orders o
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
WHERE o.OrderDate >= DATEADD(MONTH, -6, GETDATE());
GO 10  -- Run 10 times

-- Generate need for index on Products.CategoryID
SELECT * FROM Products WHERE CategoryID = 1;
SELECT * FROM Products WHERE CategoryID = 2;
SELECT * FROM Products WHERE CategoryID = 3;
GO

-- Generate need for index on OrderDetails.OrderID
SELECT * FROM OrderDetails WHERE OrderID = 1;
SELECT * FROM OrderDetails WHERE OrderID = 10;
SELECT * FROM OrderDetails WHERE OrderID = 100;
GO

PRINT '';
PRINT 'Queries completed! Now checking for missing indexes...';
PRINT '';
GO

-- Check the results
SELECT 
    'Orders.' + ISNULL(mid.equality_columns, mid.inequality_columns) AS MissingIndexOn,
    ROUND(migs.avg_user_impact, 2) AS PercentImprovement,
    migs.user_seeks + migs.user_scans AS TimesNeeded
FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
    AND OBJECT_NAME(mid.object_id) = 'Orders'
ORDER BY migs.avg_user_impact DESC;

IF @@ROWCOUNT = 0
BEGIN
    PRINT 'No missing indexes found yet. Try running this script again.';
    PRINT 'Or manually create these indexes:';
    PRINT '  CREATE INDEX IX_Orders_CustomerID ON Orders(CustomerID);';
    PRINT '  CREATE INDEX IX_Orders_OrderDate ON Orders(OrderDate);';
END
ELSE
BEGIN
    PRINT '';
    PRINT 'Missing indexes found! The DMV query in the lab guide should now show results.';
END
GO
