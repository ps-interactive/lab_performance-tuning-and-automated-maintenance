-- Create CarvedRock Database (FAST VERSION - 30 seconds)
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

-- Generate 100 customers
DECLARE @i INT = 1;
WHILE @i <= 100
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
END

-- Generate 500 orders with proper dates
SET @i = 1;
DECLARE @CustomerID INT, @OrderDate DATETIME, @OrderID INT;
WHILE @i <= 500
BEGIN
    SET @CustomerID = 1 + ABS(CHECKSUM(NEWID())) % 100;
    SET @OrderDate = DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE());
    
    INSERT INTO Orders (CustomerID, OrderDate, ShipDate, OrderStatus, ShippingAddress, ShippingCity, ShippingState, ShippingZip)
    SELECT @CustomerID, @OrderDate, 
           DATEADD(DAY, 1 + ABS(CHECKSUM(NEWID())) % 5, @OrderDate),
           CASE WHEN @i % 10 = 0 THEN 'Pending' ELSE 'Shipped' END,
           Address, City, State, ZipCode
    FROM Customers WHERE CustomerID = @CustomerID;
    
    SET @OrderID = SCOPE_IDENTITY();
    
    -- Add 1-3 items per order
    DECLARE @j INT = 1, @NumItems INT = 1 + ABS(CHECKSUM(NEWID())) % 3;
    WHILE @j <= @NumItems
    BEGIN
        INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice, Discount)
        VALUES (@OrderID, 1 + ABS(CHECKSUM(NEWID())) % 10, 
                1 + ABS(CHECKSUM(NEWID())) % 5,
                50 + ABS(CHECKSUM(NEWID())) % 150, 0);
        SET @j = @j + 1;
    END;
    
    -- Update order total
    UPDATE Orders 
    SET TotalAmount = (SELECT SUM(Quantity * UnitPrice) FROM OrderDetails WHERE OrderID = @OrderID)
    WHERE OrderID = @OrderID;
    
    SET @i = @i + 1;
END

PRINT 'CarvedRock database created (100 customers, 500 orders)';
GO
