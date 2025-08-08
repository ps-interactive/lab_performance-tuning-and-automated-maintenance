-- Create Performance Issues for Lab Exercises
USE CarvedRock;
GO

-- Drop existing indexes to create missing index scenarios
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Orders_CustomerID')
    DROP INDEX IX_Orders_CustomerID ON Orders;
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_OrderDetails_OrderID')
    DROP INDEX IX_OrderDetails_OrderID ON OrderDetails;
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Products_CategoryID')
    DROP INDEX IX_Products_CategoryID ON Products;
GO

-- Create fragmented indexes
CREATE NONCLUSTERED INDEX IX_Customers_Email 
ON Customers(Email) 
WITH (FILLFACTOR = 50);
GO

-- Fragment the index by updating data
UPDATE Customers 
SET Email = Email + 'x'
WHERE CustomerID % 3 = 0;

UPDATE Customers 
SET Email = REPLACE(Email, 'x', '')
WHERE CustomerID % 3 = 0;
GO

-- Create a heap table (no clustered index) with lots of data
CREATE TABLE LargeHeapTable (
    ID INT,
    Data1 NVARCHAR(500),
    Data2 NVARCHAR(500),
    Data3 NVARCHAR(500),
    CreatedDate DATETIME DEFAULT GETDATE()
);
GO

-- Insert data into heap table
DECLARE @i INT = 1;
WHILE @i <= 10000
BEGIN
    INSERT INTO LargeHeapTable (ID, Data1, Data2, Data3)
    VALUES (
        @i,
        REPLICATE('A', 450),
        REPLICATE('B', 450),
        REPLICATE('C', 450)
    );
    SET @i = @i + 1;
END
GO

-- Create stored procedures with performance issues

-- Procedure with implicit conversion issue
CREATE OR ALTER PROCEDURE sp_GetCustomerOrders
    @Email NVARCHAR(100)
AS
BEGIN
    -- Intentionally using wrong data type for comparison
    SELECT o.*, c.FirstName, c.LastName
    FROM Orders o
    INNER JOIN Customers c ON o.CustomerID = c.CustomerID
    WHERE c.Email = @Email;
END
GO

-- Procedure with missing indexes
CREATE OR ALTER PROCEDURE sp_GetProductsByCategory
    @CategoryName NVARCHAR(50)
AS
BEGIN
    SELECT p.*, c.CategoryName
    FROM Products p
    INNER JOIN Categories c ON p.CategoryID = c.CategoryID
    WHERE c.CategoryName = @CategoryName
    ORDER BY p.Price DESC;
END
GO

-- Procedure with inefficient query pattern
CREATE OR ALTER PROCEDURE sp_GetTopCustomers
AS
BEGIN
    -- Using inefficient subquery instead of JOIN
    SELECT 
        c.CustomerID,
        c.FirstName,
        c.LastName,
        (SELECT COUNT(*) FROM Orders WHERE CustomerID = c.CustomerID) AS OrderCount,
        (SELECT SUM(TotalAmount) FROM Orders WHERE CustomerID = c.CustomerID) AS TotalSpent
    FROM Customers c
    ORDER BY TotalSpent DESC;
END
GO

-- Create a procedure that causes parameter sniffing issues
CREATE OR ALTER PROCEDURE sp_GetOrdersByDateRange
    @StartDate DATETIME,
    @EndDate DATETIME
AS
BEGIN
    SELECT *
    FROM Orders
    WHERE OrderDate BETWEEN @StartDate AND @EndDate
    ORDER BY OrderDate DESC;
END
GO

-- Create view with performance issues
CREATE OR ALTER VIEW vw_CustomerOrderSummary
AS
SELECT 
    c.CustomerID,
    c.FirstName,
    c.LastName,
    c.Email,
    COUNT(DISTINCT o.OrderID) AS TotalOrders,
    SUM(od.TotalPrice) AS TotalSpent,
    AVG(od.TotalPrice) AS AvgOrderValue,
    MAX(o.OrderDate) AS LastOrderDate
FROM Customers c
LEFT JOIN Orders o ON c.CustomerID = o.CustomerID
LEFT JOIN OrderDetails od ON o.OrderID = od.OrderID
GROUP BY c.CustomerID, c.FirstName, c.LastName, c.Email;
GO

-- Create table with no primary key
CREATE TABLE TempProcessingTable (
    RecordID INT,
    ProcessingStatus NVARCHAR(50),
    ProcessingData NVARCHAR(MAX),
    ProcessedDate DATETIME
);
GO

-- Insert duplicate data
DECLARE @j INT = 1;
WHILE @j <= 5000
BEGIN
    INSERT INTO TempProcessingTable VALUES
    (@j, 'Pending', 'Data for record ' + CAST(@j AS NVARCHAR(10)), NULL),
    (@j, 'Pending', 'Data for record ' + CAST(@j AS NVARCHAR(10)), NULL);
    SET @j = @j + 1;
END
GO

-- Create statistics that are out of date
UPDATE STATISTICS Orders WITH ROWCOUNT = 100;
UPDATE STATISTICS OrderDetails WITH ROWCOUNT = 100;
GO

-- Create a function that causes performance issues
CREATE OR ALTER FUNCTION fn_GetCustomerOrderTotal(@CustomerID INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Total DECIMAL(10,2);
    SELECT @Total = SUM(TotalAmount)
    FROM Orders
    WHERE CustomerID = @CustomerID;
    RETURN ISNULL(@Total, 0);
END
GO

PRINT 'Performance issues created successfully!';
PRINT 'The following issues have been introduced:';
PRINT '  - Missing indexes on foreign key columns';
PRINT '  - Fragmented indexes on Customers table';
PRINT '  - Heap table with no clustered index';
PRINT '  - Stored procedures with various performance problems';
PRINT '  - Out-of-date statistics';
PRINT '  - Inefficient views and functions';
