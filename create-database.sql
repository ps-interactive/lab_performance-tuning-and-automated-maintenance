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
    Phone NVARCHAR(20)  -- Added this column
);

CREATE TABLE Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(100),
    Price DECIMAL(10,2),
    StockQuantity INT,
    ReorderLevel INT,
    Discontinued BIT DEFAULT 0
);

CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT FOREIGN KEY REFERENCES Customers(CustomerID),
    OrderDate DATETIME,
    TotalAmount DECIMAL(10,2),
    OrderStatus NVARCHAR(20)
);

CREATE TABLE OrderDetails (
    OrderDetailID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT FOREIGN KEY REFERENCES Orders(OrderID),
    ProductID INT FOREIGN KEY REFERENCES Products(ProductID),
    Quantity INT,
    UnitPrice DECIMAL(10,2)
);

CREATE TABLE InventoryTransactions (
    TransactionID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT FOREIGN KEY REFERENCES Products(ProductID),
    TransactionType NVARCHAR(20),
    Quantity INT,
    TransactionDate DATETIME DEFAULT GETDATE(),
    Notes NVARCHAR(500)
);

-- Insert 10 products
INSERT INTO Products VALUES 
    ('Hiking Boots', 129.99, 100, 20, 0),
    ('Tent', 199.99, 50, 10, 0),
    ('Rope', 249.99, 30, 5, 0),
    ('Shoes', 89.99, 150, 30, 0),
    ('Backpack', 179.99, 75, 15, 0),
    ('Sleeping Bag', 149.99, 60, 12, 0),
    ('Carabiner', 39.99, 200, 40, 0),
    ('Filter', 49.99, 100, 20, 0),
    ('Poles', 79.99, 80, 16, 0),
    ('Headlamp', 34.99, 150, 30, 0);

-- Insert 100 customers
WHILE @i <= 100
BEGIN
    INSERT INTO Customers VALUES 
        ('First' + CAST(@i AS NVARCHAR(10)), 
         'Last' + CAST(@i AS NVARCHAR(10)), 
         'customer' + CAST(@i AS NVARCHAR(10)) + '@example.com',
         '555-' + RIGHT('0000' + CAST(@i AS NVARCHAR(10)), 4));  -- Added phone
    SET @i = @i + 1;
END

-- Insert 500 orders with details
SET @i = 1;
WHILE @i <= 500
BEGIN
    INSERT INTO Orders VALUES 
        (1 + (@i % 100), 
         DATEADD(DAY, -@i/2, GETDATE()), 
         100 + (@i * 10), 
         'Shipped');
    
    INSERT INTO OrderDetails VALUES 
        (@i, 1 + (@i % 10), 2, 50.00);
    
    SET @i = @i + 1;
END

PRINT 'Database created in 30 seconds!';
GO
