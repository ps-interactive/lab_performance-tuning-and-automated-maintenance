USE CarvedRock;
GO

-- Create problematic stored procedure that will actually return data
CREATE OR ALTER PROCEDURE sp_GetCustomerOrderHistory
    @StartDate DATETIME,
    @EndDate DATETIME
AS
BEGIN
    -- This will always return data for demonstration
    IF NOT EXISTS (
        SELECT 1 FROM Orders 
        WHERE OrderDate BETWEEN @StartDate AND @EndDate
    )
    BEGIN
        -- Use all data if date range has no matches
        SELECT 
            c.FirstName + ' ' + c.LastName AS CustomerName,
            c.Email,
            COUNT(DISTINCT o.OrderID) AS TotalOrders,
            SUM(od.Quantity * od.UnitPrice) AS TotalSpent,
            AVG(od.Quantity * od.UnitPrice) AS AvgOrderValue
        FROM Customers c
        INNER JOIN Orders o ON c.CustomerID = o.CustomerID
        INNER JOIN OrderDetails od ON o.OrderID = od.OrderID
        WHERE c.Email LIKE '%@example.com'
        GROUP BY c.FirstName, c.LastName, c.Email
        HAVING SUM(od.Quantity * od.UnitPrice) > 100
        ORDER BY TotalSpent DESC;
    END
    ELSE
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
        HAVING SUM(od.Qua
