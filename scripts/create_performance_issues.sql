-- Create Performance Issues for Lab Exercises
USE CarvedRock;
GO

-- Create a basic index then fragment it
CREATE NONCLUSTERED INDEX IX_Customers_Email 
ON Customers(Email);
GO

-- Update data to create fragmentation
UPDATE Customers 
SET Email = Email + 'x'
WHERE CustomerID % 3 = 0;
GO

UPDATE Customers 
SET Email = REPLACE(Email, 'x', '')
WHERE CustomerID % 3 = 0;
GO

-- Create stored procedures with performance issues
CREATE OR ALTER PROCEDURE sp_GetCustomerOrders
    @Email NVARCHAR(100)
AS
BEGIN
    -- Missing index on Email
    SELECT o.*, c.FirstName, c.LastName
    FROM Orders o
    INNER JOIN Customers c ON o.CustomerID = c.CustomerID
    WHERE c.Email = @Email;
END
GO

CREATE OR ALTER PROCEDURE sp_GetProductsByCategory
    @CategoryID INT
AS
BEGIN
    -- Missing index on CategoryID
    SELECT *
    FROM Products
    WHERE CategoryID = @CategoryID;
END
GO

PRINT 'Performance issues created successfully!';
PRINT 'Issues introduced:';
PRINT '  - Fragmented index on Customers.Email';
PRINT '  - Missing indexes on foreign keys';
PRINT '  - Stored procedures without optimal indexes';
GO
