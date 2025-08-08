-- Populate CarvedRock Database with Sample Data
USE CarvedRock;
GO

-- Insert Categories
INSERT INTO Categories (CategoryName, Description) VALUES
('Climbing Gear', 'Equipment for rock climbing and mountaineering'),
('Hiking Equipment', 'Gear for hiking and backpacking'),
('Camping Supplies', 'Tents, sleeping bags, and camping accessories'),
('Footwear', 'Hiking boots, climbing shoes, and outdoor footwear'),
('Clothing', 'Outdoor apparel and accessories');
GO

-- Insert Products
DECLARE @i INT = 1;
WHILE @i <= 500
BEGIN
    INSERT INTO Products (ProductName, CategoryID, Price, StockQuantity, Description)
    VALUES (
        'Product ' + CAST(@i AS NVARCHAR(10)),
        ((@i % 5) + 1),
        CAST((RAND() * 500 + 10) AS DECIMAL(10,2)),
        CAST((RAND() * 100 + 10) AS INT),
        'Description for product ' + CAST(@i AS NVARCHAR(10))
    );
    SET @i = @i + 1;
END
GO

-- Insert Customers
DECLARE @j INT = 1;
DECLARE @FirstNames TABLE (Name NVARCHAR(50));
DECLARE @LastNames TABLE (Name NVARCHAR(50));

INSERT INTO @FirstNames VALUES 
('John'), ('Jane'), ('Michael'), ('Sarah'), ('David'), 
('Emma'), ('Chris'), ('Lisa'), ('Robert'), ('Mary'),
('James'), ('Patricia'), ('William'), ('Jennifer'), ('Richard');

INSERT INTO @LastNames VALUES 
('Smith'), ('Johnson'), ('Williams'), ('Brown'), ('Jones'),
('Garcia'), ('Miller'), ('Davis'), ('Rodriguez'), ('Martinez'),
('Hernandez'), ('Lopez'), ('Gonzalez'), ('Wilson'), ('Anderson');

WHILE @j <= 10000
BEGIN
    INSERT INTO Customers (FirstName, LastName, Email, Phone, Address, City, State, ZipCode, Country)
    VALUES (
        (SELECT TOP 1 Name FROM @FirstNames ORDER BY NEWID()),
        (SELECT TOP 1 Name FROM @LastNames ORDER BY NEWID()),
        'customer' + CAST(@j AS NVARCHAR(10)) + '@example.com',
        '555-' + RIGHT('0000' + CAST(CAST(RAND() * 10000 AS INT) AS NVARCHAR(4)), 4),
        CAST(@j AS NVARCHAR(10)) + ' Main Street',
        CASE WHEN @j % 5 = 0 THEN 'Denver'
             WHEN @j % 5 = 1 THEN 'Boulder'
             WHEN @j % 5 = 2 THEN 'Seattle'
             WHEN @j % 5 = 3 THEN 'Portland'
             ELSE 'San Francisco' END,
        CASE WHEN @j % 5 = 0 THEN 'CO'
             WHEN @j % 5 = 1 THEN 'CO'
             WHEN @j % 5 = 2 THEN 'WA'
             WHEN @j % 5 = 3 THEN 'OR'
             ELSE 'CA' END,
        RIGHT('00000' + CAST(CAST(RAND() * 100000 AS INT) AS NVARCHAR(5)), 5),
        'USA'
    );
    SET @j = @j + 1;
END
GO

-- Insert Orders
DECLARE @k INT = 1;
DECLARE @OrderDate DATETIME;
WHILE @k <= 50000
BEGIN
    SET @OrderDate = DATEADD(DAY, -CAST(RAND() * 365 AS INT), GETDATE());
    
    INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, OrderStatus, ShippingAddress, ShippingCity, ShippingState, ShippingZipCode, ShippingCountry)
    VALUES (
        CAST((RAND() * 9999 + 1) AS INT),
        @OrderDate,
        CAST((RAND() * 1000 + 10) AS DECIMAL(10,2)),
        CASE WHEN @k % 4 = 0 THEN 'Completed'
             WHEN @k % 4 = 1 THEN 'Shipped'
             WHEN @k % 4 = 2 THEN 'Processing'
             ELSE 'Pending' END,
        CAST(@k AS NVARCHAR(10)) + ' Shipping Street',
        CASE WHEN @k % 5 = 0 THEN 'Denver'
             WHEN @k % 5 = 1 THEN 'Boulder'
             WHEN @k % 5 = 2 THEN 'Seattle'
             WHEN @k % 5 = 3 THEN 'Portland'
             ELSE 'San Francisco' END,
        CASE WHEN @k % 5 = 0 THEN 'CO'
             WHEN @k % 5 = 1 THEN 'CO'
             WHEN @k % 5 = 2 THEN 'WA'
             WHEN @k % 5 = 3 THEN 'OR'
             ELSE 'CA' END,
        RIGHT('00000' + CAST(CAST(RAND() * 100000 AS INT) AS NVARCHAR(5)), 5),
        'USA'
    );
    SET @k = @k + 1;
END
GO

-- Insert Order Details
DECLARE @m INT = 1;
DECLARE @OrderCount INT = (SELECT COUNT(*) FROM Orders);
WHILE @m <= 100000
BEGIN
    INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice, Discount)
    VALUES (
        CAST((RAND() * (@OrderCount - 1) + 1) AS INT),
        CAST((RAND() * 499 + 1) AS INT),
        CAST((RAND() * 10 + 1) AS INT),
        CAST((RAND() * 500 + 10) AS DECIMAL(10,2)),
        CASE WHEN @m % 10 = 0 THEN 10
             WHEN @m % 20 = 0 THEN 15
             ELSE 0 END
    );
    SET @m = @m + 1;
END
GO

-- Insert Inventory data
INSERT INTO Inventory (ProductID, WarehouseLocation, Quantity, LastRestockDate, ReorderLevel, ReorderQuantity)
SELECT 
    ProductID,
    CASE WHEN ProductID % 3 = 0 THEN 'Warehouse A'
         WHEN ProductID % 3 = 1 THEN 'Warehouse B'
         ELSE 'Warehouse C' END,
    CAST((RAND(CHECKSUM(NEWID())) * 200 + 10) AS INT),
    DATEADD(DAY, -CAST(RAND(CHECKSUM(NEWID())) * 30 AS INT), GETDATE()),
    CAST((RAND(CHECKSUM(NEWID())) * 20 + 5) AS INT),
    CAST((RAND(CHECKSUM(NEWID())) * 100 + 20) AS INT)
FROM Products;
GO

-- Insert Reviews
DECLARE @n INT = 1;
WHILE @n <= 5000
BEGIN
    INSERT INTO Reviews (ProductID, CustomerID, Rating, ReviewText, ReviewDate)
    VALUES (
        CAST((RAND() * 499 + 1) AS INT),
        CAST((RAND() * 9999 + 1) AS INT),
        CAST((RAND() * 4 + 1) AS INT),
        'This is review number ' + CAST(@n AS NVARCHAR(10)) + '. Great product!',
        DATEADD(DAY, -CAST(RAND() * 180 AS INT), GETDATE())
    );
    SET @n = @n + 1;
END
GO

-- Insert data into OrderHistory (bad design table)
INSERT INTO OrderHistory (OrderData, ProcessedFlag, ProcessedDate)
SELECT 
    CONCAT('Order:', OrderID, ',Customer:', CustomerID, ',Date:', OrderDate, ',Amount:', TotalAmount),
    CASE WHEN OrderID % 3 = 0 THEN 1 ELSE 0 END,
    CASE WHEN OrderID % 3 = 0 THEN OrderDate ELSE NULL END
FROM Orders;
GO

-- Update statistics
UPDATE STATISTICS Customers WITH FULLSCAN;
UPDATE STATISTICS Products WITH FULLSCAN;
UPDATE STATISTICS Orders WITH FULLSCAN;
UPDATE STATISTICS OrderDetails WITH FULLSCAN;
GO

PRINT 'Sample data populated successfully!';
PRINT 'Database contains:';
PRINT CONCAT('  Customers: ', (SELECT COUNT(*) FROM Customers));
PRINT CONCAT('  Products: ', (SELECT COUNT(*) FROM Products));
PRINT CONCAT('  Orders: ', (SELECT COUNT(*) FROM Orders));
PRINT CONCAT('  Order Details: ', (SELECT COUNT(*) FROM OrderDetails));
