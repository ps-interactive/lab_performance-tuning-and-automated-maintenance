-- Populate CarvedRock Database with Sample Data
USE CarvedRock;
GO

-- Insert Categories
INSERT INTO Categories (CategoryName, Description) VALUES
('Climbing Gear', 'Equipment for rock climbing'),
('Hiking Equipment', 'Gear for hiking'),
('Camping Supplies', 'Tents and camping accessories'),
('Footwear', 'Outdoor footwear'),
('Clothing', 'Outdoor apparel');
GO

-- Insert Products (100 products)
DECLARE @i INT = 1;
WHILE @i <= 100
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

-- Insert Customers (500 customers)
DECLARE @j INT = 1;
WHILE @j <= 500
BEGIN
    INSERT INTO Customers (FirstName, LastName, Email, Phone, Address, City, State, ZipCode, Country)
    VALUES (
        'FirstName' + CAST(@j AS NVARCHAR(10)),
        'LastName' + CAST(@j AS NVARCHAR(10)),
        'customer' + CAST(@j AS NVARCHAR(10)) + '@example.com',
        '555-0100',
        CAST(@j AS NVARCHAR(10)) + ' Main Street',
        'Denver',
        'CO',
        '80202',
        'USA'
    );
    SET @j = @j + 1;
END
GO

-- Insert Orders (1000 orders)
DECLARE @k INT = 1;
WHILE @k <= 1000
BEGIN
    INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, OrderStatus, ShippingAddress, ShippingCity, ShippingState, ShippingZipCode, ShippingCountry)
    VALUES (
        CAST((RAND() * 499 + 1) AS INT),
        DATEADD(DAY, -CAST(RAND() * 365 AS INT), GETDATE()),
        CAST((RAND() * 1000 + 10) AS DECIMAL(10,2)),
        'Completed',
        CAST(@k AS NVARCHAR(10)) + ' Shipping Street',
        'Denver',
        'CO',
        '80202',
        'USA'
    );
    SET @k = @k + 1;
END
GO

-- Insert Order Details (2000 order items)
DECLARE @m INT = 1;
WHILE @m <= 2000
BEGIN
    INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice, Discount)
    VALUES (
        CAST((RAND() * 999 + 1) AS INT),
        CAST((RAND() * 99 + 1) AS INT),
        CAST((RAND() * 10 + 1) AS INT),
        CAST((RAND() * 500 + 10) AS DECIMAL(10,2)),
        0
    );
    SET @m = @m + 1;
END
GO

PRINT 'Sample data populated successfully!';
PRINT 'Categories: 5';
PRINT 'Products: 100';
PRINT 'Customers: 500';
PRINT 'Orders: 1000';
PRINT 'Order Details: 2000';
GO
