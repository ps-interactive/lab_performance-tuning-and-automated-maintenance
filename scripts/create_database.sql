-- Create CarvedRock Database
USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'CarvedRock')
BEGIN
    ALTER DATABASE CarvedRock SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CarvedRock;
END
GO

CREATE DATABASE CarvedRock;
GO

USE CarvedRock;
GO

-- Create simple tables without foreign keys
CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    Phone NVARCHAR(20),
    Address NVARCHAR(200),
    City NVARCHAR(50),
    State NVARCHAR(2),
    ZipCode NVARCHAR(10),
    Country NVARCHAR(50),
    CreatedDate DATETIME DEFAULT GETDATE(),
    ModifiedDate DATETIME DEFAULT GETDATE()
);
GO

CREATE TABLE Categories (
    CategoryID INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName NVARCHAR(50) NOT NULL,
    Description NVARCHAR(200)
);
GO

CREATE TABLE Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(100) NOT NULL,
    CategoryID INT,
    Price DECIMAL(10,2) NOT NULL,
    StockQuantity INT NOT NULL DEFAULT 0,
    Description NVARCHAR(500),
    CreatedDate DATETIME DEFAULT GETDATE(),
    ModifiedDate DATETIME DEFAULT GETDATE()
);
GO

CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT,
    OrderDate DATETIME DEFAULT GETDATE(),
    TotalAmount DECIMAL(10,2),
    OrderStatus NVARCHAR(20) DEFAULT 'Pending',
    ShippingAddress NVARCHAR(200),
    ShippingCity NVARCHAR(50),
    ShippingState NVARCHAR(2),
    ShippingZipCode NVARCHAR(10),
    ShippingCountry NVARCHAR(50)
);
GO

CREATE TABLE OrderDetails (
    OrderDetailID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    Discount DECIMAL(5,2) DEFAULT 0
);
GO

PRINT 'CarvedRock database created successfully!';
GO
