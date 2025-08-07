USE CarvedRock;
GO

-- Create problematic stored procedure that ALWAYS returns data
CREATE OR ALTER PROCEDURE sp_GetCustomerOrderHistory
    @StartDate DATETIME,
    @EndDate DATETIME
AS
BEGIN
    -- This will always return results
    SELECT 
        c.FirstName + ' ' + c.LastName AS CustomerName,
        c.Email,
        COUNT(DISTINCT o.OrderID) AS TotalOrders,
        SUM(od.Quantity * od.UnitPrice) AS TotalSpent,
        AVG(od.Quantity * od.UnitPrice) AS AvgOrderValue
    FROM Customers c
    INNER JOIN Orders o ON c.CustomerID = o.CustomerID
    INNER JOIN OrderDetails od ON o.OrderID = od.OrderID
    WHERE o.OrderDate BETWEEN @StartDate AND @EndDate
    GROUP BY c.FirstName, c.LastName, c.Email
    HAVING SUM(od.Quantity * od.UnitPrice) > 100
    ORDER BY TotalSpent DESC;
    
    -- If no results, return sample data
    IF @@ROWCOUNT = 0
    BEGIN
        SELECT 
            'John Doe' AS CustomerName,
            'john@example.com' AS Email,
            5 AS TotalOrders,
            500.00 AS TotalSpent,
            100.00 AS AvgOrderValue
        UNION ALL
        SELECT 'Jane Smith', 'jane@example.com', 3, 350.00, 116.67;
    END
END;
GO

-- Create cursor procedure
CREATE OR ALTER PROCEDURE sp_UpdateInventoryLevels
AS
BEGIN
    DECLARE @ProductID INT;
    DECLARE product_cursor CURSOR FOR
        SELECT ProductID FROM Products WHERE Discontinued = 0;
    
    OPEN product_cursor;
    FETCH NEXT FROM product_cursor INTO @ProductID;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        UPDATE Products SET StockQuantity = StockQuantity + 1 WHERE ProductID = @ProductID;
        FETCH NEXT FROM product_cursor INTO @ProductID;
    END;
    
    CLOSE product_cursor;
    DEALLOCATE product_cursor;
END;
GO

-- Create an index with fragmentation
CREATE INDEX IX_Temp ON Orders(OrderDate) WITH (FILLFACTOR = 10);
GO

-- Force some missing index suggestions
DBCC FREEPROCCACHE;
DBCC DROPCLEANBUFFERS;
GO

-- Run queries to generate missing index suggestions
SELECT * FROM Orders WHERE CustomerID = 1;
SELECT * FROM OrderDetails WHERE OrderID = 1;
GO

PRINT 'Performance issues created!';
GO
