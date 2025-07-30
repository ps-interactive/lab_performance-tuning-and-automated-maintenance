-- Create CarvedRock Database
USE master;
GO

IF EXISTS (SELECT * FROM sys.databases WHERE name = 'CarvedRock')
    DROP DATABASE CarvedRock;
GO

CREATE DATABASE CarvedRock;
GO

USE CarvedRock;
GO

-- Create tables
CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Email NVARCHAR(100),
    Phone NVARCHAR(20),
    Address NVARCHAR(200),
    City NVARCHAR(50),
    State NVARCHAR(2),
    ZipCode NVARCHAR(10),
    CreatedDate DATETIME DEFAULT GETDATE()
);

CREATE TABLE Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(100),
    Category NVARCHAR(50),
    Price DECIMAL(10,2),
    StockQuantity INT,
    ReorderLevel INT,
    Discontinued BIT DEFAULT 0
);

CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT FOREIGN KEY REFERENCES Customers(CustomerID),
    OrderDate DATETIME DEFAULT GETDATE(),
    ShipDate DATETIME,
    TotalAmount DECIMAL(10,2),
    OrderStatus NVARCHAR(20),
    ShippingAddress NVARCHAR(200),
    ShippingCity NVARCHAR(50),
    ShippingState NVARCHAR(2),
    ShippingZip NVARCHAR(10)
);

CREATE TABLE OrderDetails (
    OrderDetailID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT FOREIGN KEY REFERENCES Orders(OrderID),
    ProductID INT FOREIGN KEY REFERENCES Products(ProductID),
    Quantity INT,
    UnitPrice DECIMAL(10,2),
    Discount DECIMAL(5,2) DEFAULT 0
);

CREATE TABLE InventoryTransactions (
    TransactionID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT FOREIGN KEY REFERENCES Products(ProductID),
    TransactionType NVARCHAR(20),
    Quantity INT,
    TransactionDate DATETIME DEFAULT GETDATE(),
    Notes NVARCHAR(500)
);

-- Insert sample data
-- Customers
DECLARE @i INT = 1;
WHILE @i <= 50000
BEGIN
    INSERT INTO Customers (FirstName, LastName, Email, Phone, Address, City, State, ZipCode)
    VALUES (
        'FirstName' + CAST(@i AS NVARCHAR(10)),
        'LastName' + CAST(@i AS NVARCHAR(10)),
        'customer' + CAST(@i AS NVARCHAR(10)) + '@example.com',
        '555-' + RIGHT('0000' + CAST(@i AS NVARCHAR(10)), 4),
        CAST(@i AS NVARCHAR(10)) + ' Main Street',
        CASE WHEN @i % 5 = 0 THEN 'Seattle'
             WHEN @i % 5 = 1 THEN 'Portland'
             WHEN @i % 5 = 2 THEN 'San Francisco'
             WHEN @i % 5 = 3 THEN 'Los Angeles'
             ELSE 'Denver' END,
        CASE WHEN @i % 5 = 0 THEN 'WA'
             WHEN @i % 5 = 1 THEN 'OR'
             WHEN @i % 5 = 2 THEN 'CA'
             WHEN @i % 5 = 3 THEN 'CA'
             ELSE 'CO' END,
        RIGHT('00000' + CAST(10000 + @i AS NVARCHAR(10)), 5)
    );
    SET @i = @i + 1;
END;

-- Products
INSERT INTO Products (ProductName, Category, Price, StockQuantity, ReorderLevel)
VALUES 
    ('Hiking Boots', 'Footwear', 129.99, 100, 20),
    ('Camping Tent 2-Person', 'Camping', 199.99, 50, 10),
    ('Climbing Rope 60m', 'Climbing', 249.99, 30, 5),
    ('Trail Running Shoes', 'Footwear', 89.99, 150, 30),
    ('Backpack 65L', 'Hiking', 179.99, 75, 15),
    ('Sleeping Bag -10C', 'Camping', 149.99, 60, 12),
    ('Carabiner Set', 'Climbing', 39.99, 200, 40),
    ('Water Filter', 'Camping', 49.99, 100, 20),
    ('Trekking Poles', 'Hiking', 79.99, 80, 16),
    ('Headlamp', 'Accessories', 34.99, 150, 30);

-- Generate Orders and OrderDetails
SET @i = 1;
WHILE @i <= 100000
BEGIN
    DECLARE @CustomerID INT = (SELECT TOP 1 CustomerID FROM Customers ORDER BY NEWID());
    DECLARE @OrderDate DATETIME = DATEADD(DAY, -RAND() * 365, GETDATE());
    DECLARE @TotalAmount DECIMAL(10,2) = 0;
    
    INSERT INTO Orders (CustomerID, OrderDate, ShipDate, OrderStatus, ShippingAddress, ShippingCity, ShippingState, ShippingZip)
    SELECT @CustomerID, @OrderDate, 
           DATEADD(DAY, RAND() * 5, @OrderDate),
           CASE WHEN RAND() > 0.9 THEN 'Pending'
                WHEN RAND() > 0.1 THEN 'Shipped'
                ELSE 'Delivered' END,
           Address, City, State, ZipCode
    FROM Customers WHERE CustomerID = @CustomerID;
    
    DECLARE @OrderID INT = SCOPE_IDENTITY();
    DECLARE @NumItems INT = CEILING(RAND() * 5);
    DECLARE @j INT = 1;
    
    WHILE @j <= @NumItems
    BEGIN
        DECLARE @ProductID INT = (SELECT TOP 1 ProductID FROM Products ORDER BY NEWID());
        DECLARE @Quantity INT = CEILING(RAND() * 5);
        DECLARE @UnitPrice DECIMAL(10,2) = (SELECT Price FROM Products WHERE ProductID = @ProductID);
        
        INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice, Discount)
        VALUES (@OrderID, @ProductID, @Quantity, @UnitPrice, CASE WHEN RAND() > 0.8 THEN 10 ELSE 0 END);
        
        SET @TotalAmount = @TotalAmount + (@Quantity * @UnitPrice);
        SET @j = @j + 1;
    END;
    
    UPDATE Orders SET TotalAmount = @TotalAmount WHERE OrderID = @OrderID;
    SET @i = @i + 1;
END;

-- Generate Inventory Transactions
SET @i = 1;
WHILE @i <= 10000
BEGIN
    INSERT INTO InventoryTransactions (ProductID, TransactionType, Quantity, TransactionDate, Notes)
    VALUES (
        (SELECT TOP 1 ProductID FROM Products ORDER BY NEWID()),
        CASE WHEN RAND() > 0.5 THEN 'Purchase' ELSE 'Sale' END,
        CEILING(RAND() * 50),
        DATEADD(DAY, -RAND() * 365, GETDATE()),
        'Transaction ' + CAST(@i AS NVARCHAR(10))
    );
    SET @i = @i + 1;
END;

PRINT 'CarvedRock database created and populated successfully!';
