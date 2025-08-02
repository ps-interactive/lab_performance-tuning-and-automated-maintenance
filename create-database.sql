-- Create CarvedRock Database 
USE master;
GO

IF EXISTS (SELECT * FROM sys.databases WHERE name = 'CarvedRock')
BEGIN
    ALTER DATABASE CarvedRock SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CarvedRock;
END
GO

CREATE DATABASE CarvedRock;
GO

USE CarvedRock;
GO

-- Create all tables at once
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

-- Insert products
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

-- FAST customer generation using set-based insert (100 customers only)
WITH Numbers AS (
    SELECT TOP 100 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
)
INSERT INTO Customers (FirstName, LastName, Email, Phone, Address, City, State, ZipCode)
SELECT 
    'FirstName' + CAST(n AS NVARCHAR(10)),
    'LastName' + CAST(n AS NVARCHAR(10)),
    'customer' + CAST(n AS NVARCHAR(10)) + '@example.com',
    '555-' + RIGHT('0000' + CAST(n AS NVARCHAR(10)), 4),
    CAST(n AS NVARCHAR(10)) + ' Main Street',
    CASE n % 5
        WHEN 0 THEN 'Seattle'
        WHEN 1 THEN 'Portland'
        WHEN 2 THEN 'San Francisco'
        WHEN 3 THEN 'Los Angeles'
        ELSE 'Denver'
    END,
    CASE n % 5
        WHEN 0 THEN 'WA'
        WHEN 1 THEN 'OR'
        WHEN 2 THEN 'CA'
        WHEN 3 THEN 'CA'
        ELSE 'CO'
    END,
    RIGHT('00000' + CAST(10000 + n AS NVARCHAR(10)), 5)
FROM Numbers;
GO

-- FAST order generation (500 orders only)
DECLARE @i INT = 1;
WHILE @i <= 500
BEGIN
    INSERT INTO Orders (CustomerID, OrderDate, ShipDate, OrderStatus, TotalAmount)
    VALUES (
        1 + ABS(CHECKSUM(NEWID())) % 100,
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE()),
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 360, GETDATE()),
        'Shipped',
        100 + ABS(CHECKSUM(NEWID())) % 900
    );
    
    -- Add one order detail per order
    INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
    VALUES (
        @i,
        1 + ABS(CHECKSUM(NEWID())) % 10,
        1 + ABS(CHECKSUM(NEWID())) % 5,
        50 + ABS(CHECKSUM(NEWID())) % 150
    );
    
    SET @i = @i + 1;
END
GO

PRINT 'CarvedRock database created!';
PRINT 'Customers: 100, Orders: 500, Products: 10';
