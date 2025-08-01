-- Create CarvedRock Database
USE master;
GO

-- Drop database if it exists
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'CarvedRock')
BEGIN
    ALTER DATABASE CarvedRock SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CarvedRock;
END
GO

-- Create new database
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
GO

-- Insert sample products first
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
GO

-- Generate customers (reduced to 5000 for faster setup)
PRINT 'Generating 5000 customers...';
DECLARE @i INT = 1;
WHILE @i <= 5000
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
    
    -- Print progress every 1000 records
    IF @i % 1000 = 0
        PRINT 'Created ' + CAST(@i AS NVARCHAR(10)) + ' customers...';
    
    SET @i = @i + 1;
END
GO

-- Generate orders (reduced to 10000 for faster setup)
PRINT 'Generating 10000 orders...';
DECLARE @i INT = 1;
DECLARE @CustomerID INT;
DECLARE @OrderDate DATETIME;
DECLARE @OrderID INT;
DECLARE @ProductID INT;
DECLARE @Quantity INT;
DECLARE @UnitPrice DECIMAL(10,2);

WHILE @i <= 10000
BEGIN
    -- Random customer
    SET @CustomerID = 1 + ABS(CHECKSUM(NEWID())) % 5000;
    SET @OrderDate = DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE());
    
    INSERT INTO Orders (CustomerID, OrderDate, ShipDate, OrderStatus, ShippingAddress, ShippingCity, ShippingState, ShippingZip)
    SELECT @CustomerID, @OrderDate, 
           DATEADD(DAY, 1 + ABS(CHECKSUM(NEWID())) % 5, @OrderDate),
           CASE WHEN ABS(CHECKSUM(NEWID())) % 10 > 8 THEN 'Pending'
                WHEN ABS(CHECKSUM(NEWID())) % 10 > 1 THEN 'Shipped'
                ELSE 'Delivered' END,
           Address, City, State, ZipCode
    FROM Customers WHERE CustomerID = @CustomerID;
    
    SET @OrderID = SCOPE_IDENTITY();
    
    -- Add 1-3 items per order
    DECLARE @NumItems INT = 1 + ABS(CHECKSUM(NEWID())) % 3;
    DECLARE @j INT = 1;
    
    WHILE @j <= @NumItems
    BEGIN
        SET @ProductID = 1 + ABS(CHECKSUM(NEWID())) % 10;
        SET @Quantity = 1 + ABS(CHECKSUM(NEWID())) % 5;
        SELECT @UnitPrice = Price FROM Products WHERE ProductID = @ProductID;
        
        INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice, Discount)
        VALUES (@OrderID, @ProductID, @Quantity, @UnitPrice, 
                CASE WHEN ABS(CHECKSUM(NEWID())) % 10 > 7 THEN 10 ELSE 0 END);
        
        SET @j = @j + 1;
    END;
    
    -- Update order total
    UPDATE Orders 
    SET TotalAmount = (
        SELECT SUM(Quantity * UnitPrice * (1 - Discount/100.0))
        FROM OrderDetails 
        WHERE OrderID = @OrderID
    )
    WHERE OrderID = @OrderID;
    
    -- Print progress every 2000 records
    IF @i % 2000 = 0
        PRINT 'Created ' + CAST(@i AS NVARCHAR(10)) + ' orders...';
    
    SET @i = @i + 1;
END
GO

PRINT 'CarvedRock database created successfully!';
PRINT 'Customers: 5,000';
PRINT 'Orders: 10,000';
PRINT 'Products: 10';
