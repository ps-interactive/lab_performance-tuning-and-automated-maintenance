-- Create Performance Issues for Lab
USE CarvedRock;
GO

-- Drop existing indexes to create performance issues
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Orders_CustomerID')
    DROP INDEX IX_Orders_CustomerID ON Orders;
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_OrderDetails_OrderID')
    DROP INDEX IX_OrderDetails_OrderID ON OrderDetails;
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_OrderDetails_ProductID')
    DROP INDEX IX_OrderDetails_ProductID ON OrderDetails;
GO

-- Create a problematic stored procedure (missing indexes, inefficient query)
CREATE OR ALTER PROCEDURE sp_GetCustomerOrderHistory
    @StartDate DATETIME,
    @EndDate DATETIME
AS
BEGIN
    -- Inefficient query with multiple issues
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
        AND c.Email LIKE '%@example.com'  -- Non-sargable condition
    GROUP BY c.FirstName, c.LastName, c.Email
    HAVING SUM(od.Quantity * od.UnitPrice) > 100
    ORDER BY TotalSpent DESC;
END;
GO

-- Create another problematic procedure with cursor usage
CREATE OR ALTER PROCEDURE sp_UpdateInventoryLevels
AS
BEGIN
    DECLARE @ProductID INT;
    DECLARE @CurrentStock INT;
    DECLARE @ReorderLevel INT;
    
    -- Inefficient cursor usage
    DECLARE product_cursor CURSOR FOR
        SELECT ProductID, StockQuantity, ReorderLevel
        FROM Products
        WHERE Discontinued = 0;
    
    OPEN product_cursor;
    
    FETCH NEXT FROM product_cursor INTO @ProductID, @CurrentStock, @ReorderLevel;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Inefficient single-row processing
        IF @CurrentStock < @ReorderLevel
        BEGIN
            UPDATE Products
            SET StockQuantity = StockQuantity + 100
            WHERE ProductID = @ProductID;
            
            INSERT INTO InventoryTransactions (ProductID, TransactionType, Quantity, Notes)
            VALUES (@ProductID, 'Reorder', 100, 'Auto-reorder triggered');
        END;
        
        FETCH NEXT FROM product_cursor INTO @ProductID, @CurrentStock, @ReorderLevel;
    END;
    
    CLOSE product_cursor;
    DEALLOCATE product_cursor;
END;
GO

-- Create a view with performance issues
CREATE OR ALTER VIEW vw_CustomerOrderSummary
AS
SELECT 
    c.CustomerID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    (SELECT COUNT(*) FROM Orders WHERE CustomerID = c.CustomerID) AS OrderCount,
    (SELECT SUM(TotalAmount) FROM Orders WHERE CustomerID = c.CustomerID) AS TotalSpent,
    (SELECT MAX(OrderDate) FROM Orders WHERE CustomerID = c.CustomerID) AS LastOrderDate
FROM Customers c;
GO

-- Create fragmented indexes
CREATE INDEX IX_Temp ON Orders(OrderDate) WITH (FILLFACTOR = 10);
GO

-- Insert more data to fragment the index
DECLARE @i INT = 1;
WHILE @i <= 10000
BEGIN
    UPDATE Orders 
    SET OrderStatus = CASE 
        WHEN OrderStatus = 'Pending' THEN 'Processing'
        WHEN OrderStatus = 'Processing' THEN 'Shipped'
        ELSE 'Delivered' 
    END
    WHERE OrderID = @i;
    
    SET @i = @i + 1;
END;
GO

-- Create statistics that are out of date
UPDATE STATISTICS Orders WITH ROWCOUNT = 1000, PAGECOUNT = 100;
UPDATE STATISTICS OrderDetails WITH ROWCOUNT = 1000, PAGECOUNT = 100;
GO

PRINT 'Performance issues created successfully!';
