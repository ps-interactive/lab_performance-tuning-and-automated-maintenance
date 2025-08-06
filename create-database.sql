-- Quick setup - only essential data
USE master;
GO

IF EXISTS (SELECT * FROM sys.databases WHERE name = 'CarvedRock')
    DROP DATABASE CarvedRock;
GO

CREATE DATABASE CarvedRock;
GO

USE CarvedRock;
GO

-- Create tables (same as before)
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

-- Insert only essential data (10 seconds max)
INSERT INTO Products (ProductName, Category, Price, StockQuantity, ReorderLevel)
VALUES 
    ('Hiking Boots', 'Footwear', 129.99, 100, 20),
    ('Camping Tent', 'Camping', 199.99, 50, 10),
    ('Climbing Rope', 'Climbing', 249.99, 30, 5),
    ('Trail Shoes', 'Footwear', 89.99, 150, 30),
    ('Backpack 65L', 'Hiking', 179.99, 75, 15),
    ('Sleeping Bag', 'Camping', 149.99, 60, 12),
    ('Carabiner Set', 'Climbing', 39.99, 200, 40),
    ('Water Filter', 'Camping', 49.99, 100, 20),
    ('Trekking Poles', 'Hiking', 79.99, 80, 16),
    ('Headlamp', 'Accessories', 34.99, 150, 30);

-- Create 100 customers only
DECLARE @i INT = 1;
WHILE @i <= 100
BEGIN
    INSERT INTO Customers (FirstName, LastName, Email)
    VALUES ('Customer', CAST(@i AS NVARCHAR(10)), 'customer' + CAST(@i AS NVARCHAR(10)) + '@example.com');
    SET @i = @i + 1;
END;

-- Create 200 orders only
SET @i = 1;
WHILE @i <= 200
BEGIN
    INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, OrderStatus)
    VALUES (1 + (@i % 100), DATEADD(DAY, -@i, GETDATE()), @i * 10.5, 'Shipped');
    
    INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
    VALUES (@i, 1 + (@i % 10), 1 + (@i % 5), 50 + (@i % 100));
    
    SET @i = @i + 1;
END;

PRINT 'CarvedRock database created (quick setup - 100 customers, 200 orders)';
GO
