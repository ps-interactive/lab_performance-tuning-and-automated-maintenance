-- Create Performance Issues for Lab Exercises
USE CarvedRock;
GO

-- First, DROP any existing indexes to ensure we have missing index scenarios
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Orders_CustomerID' AND object_id = OBJECT_ID('Orders'))
    DROP INDEX IX_Orders_CustomerID ON Orders;
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Orders_OrderDate' AND object_id = OBJECT_ID('Orders'))
    DROP INDEX IX_Orders_OrderDate ON Orders;
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_OrderDetails_OrderID' AND object_id = OBJECT_ID('OrderDetails'))
    DROP INDEX IX_OrderDetails_OrderID ON OrderDetails;
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Products_CategoryID' AND object_id = OBJECT_ID('Products'))
    DROP INDEX IX_Products_CategoryID ON Products;
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Customers_Email' AND object_id = OBJECT_ID('Customers'))
    DROP INDEX IX_Customers_Email ON Customers;
GO

-- Clear the missing index DMV cache (requires sysadmin)
DBCC FREEPROCCACHE;
GO

-- Now run queries that will generate missing index recommendations
-- These queries will be tracked by SQL Server's missing index feature

-- Query 1: This will suggest index on Orders.CustomerID
DECLARE @i INT = 1;
WHILE @i <= 5
BEGIN
    SELECT o.OrderID, o.OrderDate, o.TotalAmount
    FROM Orders o
    WHERE o.CustomerID = @i;
    SET @i = @i + 1;
END
GO

-- Query 2: This will suggest index on Orders.OrderDate
SELECT OrderID, CustomerID, TotalAmount
FROM Orders
WHERE OrderDate >= '2024-01-01'
ORDER BY OrderDate;
GO

-- Query 3: This will suggest index on Products.CategoryID
SELECT ProductID, ProductName, Price
FROM Products
WHERE CategoryID = 1;
GO

SELECT ProductID, ProductName, Price
FROM Products
WHERE CategoryID = 2;
GO

-- Query 4: This will suggest index on OrderDetails.OrderID
SELECT od.OrderDetailID, od.ProductID, od.Quantity
FROM OrderDetails od
WHERE od.OrderID IN (1, 2, 3, 4, 5);
GO

-- Query 5: Complex query that needs multiple indexes
SELECT 
    c.CustomerID,
    c.FirstName,
    c.LastName,
    COUNT(o.OrderID) as OrderCount,
    SUM(o.TotalAmount) as TotalSpent
FROM Customers c
LEFT JOIN Orders o ON c.CustomerID = o.CustomerID
WHERE o.OrderDate >= DATEADD(MONTH, -6, GETDATE())
GROUP BY c.CustomerID, c.FirstName, c.LastName;
GO

-- Run this query multiple times to increase the impact
DECLARE @j INT = 1;
WHILE @j <= 10
BEGIN
    SELECT o.*, c.FirstName, c.LastName
    FROM Orders o
    INNER JOIN Customers c ON o.CustomerID = c.CustomerID
    WHERE o.OrderDate >= DATEADD(MONTH, -3, GETDATE());
    SET @j = @j + 1;
END
GO

-- Create fragmented index for fragmentation demo
CREATE NONCLUSTERED INDEX IX_Customers_Email 
ON Customers(Email)
WITH (FILLFACTOR = 50);
GO

-- Fragment the index
UPDATE Customers SET Email = Email + 'x' WHERE CustomerID % 3 = 0;
UPDATE Customers SET Email = REPLACE(Email, 'x', '') WHERE CustomerID % 3 = 0;
GO

-- Create stored procedures with performance issues
CREATE OR ALTER PROCEDURE sp_GetCustomerOrders
    @CustomerID INT
AS
BEGIN
    -- This will benefit from index on Orders.CustomerID
    SELECT * FROM Orders WHERE CustomerID = @CustomerID;
END
GO

CREATE OR ALTER PROCEDURE sp_GetOrdersByDate
    @StartDate DATETIME
AS
BEGIN
    -- This will benefit from index on Orders.OrderDate
    SELECT * FROM Orders 
    WHERE OrderDate >= @StartDate
    ORDER BY OrderDate DESC;
END
GO

-- Execute the procedures to generate missing index stats
EXEC sp_GetCustomerOrders @CustomerID = 1;
EXEC sp_GetCustomerOrders @CustomerID = 2;
EXEC sp_GetOrdersByDate @StartDate = '2024-01-01';
GO

PRINT 'Performance issues created successfully!';
PRINT '';
PRINT 'Missing indexes have been identified for:';
PRINT '  - Orders.CustomerID';
PRINT '  - Orders.OrderDate';
PRINT '  - Products.CategoryID';
PRINT '  - OrderDetails.OrderID';
PRINT '';
PRINT 'Run the missing index DMV query to see recommendations.';
GO
