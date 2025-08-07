USE CarvedRock;
GO

-- Create problematic stored procedure
CREATE OR ALTER PROCEDURE sp_GetCustomerOrderHistory
    @StartDate DATETIME,
    @EndDate DATETIME
AS
BEGIN
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
        AND c.Email LIKE '%@example.com'
    GROUP BY c.FirstName, c.LastName, c.Email
    HAVING SUM(od.Quantity * od.UnitPrice) > 100
    ORDER BY TotalSpent DESC;
END;
GO

-- Create cursor-based procedure
CREATE OR ALTER PROCEDURE sp_UpdateInventoryLevels
AS
BEGIN
    DECLARE @ProductID INT;
    DECLARE @CurrentStock INT;
    DECLARE @ReorderLevel INT;
    
    DECLARE product_cursor CURSOR FOR
        SELECT ProductID, StockQuantity, ReorderLevel
        FROM Products
        WHERE Discontinued = 0;
    
    OPEN product_cursor;
    FETCH NEXT FROM product_cursor INTO @ProductID, @CurrentStock, @ReorderLevel;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
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

-- Create fragmented index with low fillfactor
CREATE INDEX IX_Temp ON Orders(OrderDate) WITH (FILLFACTOR = 10);
GO

PRINT 'Performance issues created successfully!';
