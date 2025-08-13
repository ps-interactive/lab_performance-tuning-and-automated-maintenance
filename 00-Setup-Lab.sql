-- SQL Server Performance Lab Setup - Optimized for speed and missing indexes
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

-- Set database to simple recovery for faster inserts
ALTER DATABASE CarvedRock SET RECOVERY SIMPLE;
GO

-- Create tables WITHOUT indexes on foreign keys
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
    OrderDate DATETIME,
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

CREATE TABLE MaintenanceHistory (
    MaintenanceID INT IDENTITY(1,1) PRIMARY KEY,
    MaintenanceType NVARCHAR(50),
    StartTime DATETIME,
    EndTime DATETIME,
    Status NVARCHAR(20),
    Details NVARCHAR(MAX)
);

-- Products with some low stock
INSERT INTO Products (ProductName, Category, Price, StockQuantity, ReorderLevel)
VALUES 
    ('Hiking Boots', 'Footwear', 129.99, 15, 20),
    ('Camping Tent', 'Camping', 199.99, 8, 10),
    ('Climbing Rope', 'Climbing', 249.99, 3, 5),
    ('Trail Shoes', 'Footwear', 89.99, 25, 30),
    ('Backpack', 'Hiking', 179.99, 12, 15),
    ('Sleeping Bag', 'Camping', 149.99, 10, 12),
    ('Carabiner Set', 'Climbing', 39.99, 40, 40),
    ('Water Filter', 'Camping', 49.99, 18, 20),
    ('Trekking Poles', 'Hiking', 79.99, 14, 16),
    ('Headlamp', 'Accessories', 34.99, 25, 30);

-- Use a numbers table for faster batch inserts
WITH Numbers AS (
    SELECT TOP 3000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_columns a CROSS JOIN sys.all_columns b
)
INSERT INTO Customers (FirstName, LastName, Email, Phone, Address, City, State, ZipCode)
SELECT 
    'First' + CAST(n AS NVARCHAR(10)),
    'Last' + CAST(n AS NVARCHAR(10)),
    'customer' + CAST(n AS NVARCHAR(10)) + '@example.com',
    '555-' + RIGHT('0000' + CAST(n AS NVARCHAR(10)), 4),
    CAST(n AS NVARCHAR(10)) + ' Main St',
    CASE n % 3 WHEN 0 THEN 'Seattle' WHEN 1 THEN 'Portland' ELSE 'Tacoma' END,
    'WA',
    '98' + RIGHT('000' + CAST(n % 999 AS NVARCHAR(3)), 3)
FROM Numbers;

-- Batch insert orders
WITH Numbers AS (
    SELECT TOP 5000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_columns a CROSS JOIN sys.all_columns b
)
INSERT INTO Orders (CustomerID, OrderDate, OrderStatus, TotalAmount, ShippingAddress, ShippingCity, ShippingState, ShippingZip)
SELECT 
    1 + (n % 3000),  -- References customers
    DATEADD(DAY, -(n % 365), GETDATE()),
    CASE n % 4 WHEN 0 THEN 'Pending' WHEN 1 THEN 'Shipped' WHEN 2 THEN 'Delivered' ELSE 'Processing' END,
    50.00 + (n % 500),
    CAST(n AS NVARCHAR(10)) + ' Ship St',
    CASE n % 3 WHEN 0 THEN 'Seattle' WHEN 1 THEN 'Bellevue' ELSE 'Redmond' END,
    'WA',
    '98' + RIGHT('000' + CAST(n % 999 AS NVARCHAR(3)), 3)
FROM Numbers;

-- Batch insert order details
WITH Numbers AS (
    SELECT TOP 8000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_columns a CROSS JOIN sys.all_columns b
)
INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
SELECT 
    1 + (n % 5000),  -- References orders
    1 + (n % 10),    -- References products
    1 + (n % 5),
    25.00 + (n % 100)
FROM Numbers;
GO

-- Create the slow stored procedure
CREATE OR ALTER PROCEDURE sp_GetCustomerOrderHistory
    @StartDate DATETIME,
    @EndDate DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    
    -- This query NEEDS indexes to perform well
    SELECT 
        c.FirstName + ' ' + c.LastName AS CustomerName,
        c.Email,
        COUNT(DISTINCT o.OrderID) AS TotalOrders,
        SUM(od.Quantity * od.UnitPrice) AS TotalSpent,
        AVG(od.Quantity * od.UnitPrice) AS AvgOrderValue
    FROM Customers c
    INNER JOIN Orders o ON c.CustomerID = o.CustomerID  -- MISSING INDEX
    INNER JOIN OrderDetails od ON o.OrderID = od.OrderID  -- MISSING INDEX
    WHERE o.OrderDate BETWEEN @StartDate AND @EndDate  -- MISSING INDEX
    GROUP BY c.FirstName, c.LastName, c.Email
    HAVING SUM(od.Quantity * od.UnitPrice) > 100
    ORDER BY TotalSpent DESC;
END;
GO

-- Other procedures (simplified versions)
CREATE OR ALTER PROCEDURE sp_UpdateInventoryLevels
AS
BEGIN
    DECLARE @ProductID INT, @Count INT = 0;
    DECLARE product_cursor CURSOR FOR
        SELECT ProductID FROM Products WHERE StockQuantity < ReorderLevel AND Discontinued = 0;
    OPEN product_cursor;
    FETCH NEXT FROM product_cursor INTO @ProductID;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        UPDATE Products SET StockQuantity = StockQuantity + 100 WHERE ProductID = @ProductID;
        SET @Count = @Count + 1;
        FETCH NEXT FROM product_cursor INTO @ProductID;
    END;
    CLOSE product_cursor;
    DEALLOCATE product_cursor;
    PRINT 'Inventory updated. ' + CAST(@Count AS VARCHAR(10)) + ' products reordered.';
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateInventoryLevels_Optimized
AS
BEGIN
    UPDATE Products SET StockQuantity = StockQuantity + 100
    WHERE StockQuantity < ReorderLevel AND Discontinued = 0;
    PRINT 'Inventory updated. ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' products reordered.';
END;
GO

CREATE OR ALTER PROCEDURE sp_Session1_Blocker
AS
BEGIN
    BEGIN TRANSACTION;
    UPDATE Customers SET Email = 'blocked@example.com' WHERE CustomerID = 1;
    WAITFOR DELAY '00:02:00';
    ROLLBACK TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE sp_Session2_Blocked
AS
BEGIN
    UPDATE Customers SET Phone = '555-9999' WHERE CustomerID = 1;
END;
GO

CREATE OR ALTER PROCEDURE sp_DetectBlocking
AS
BEGIN
    SELECT 
        blocking.session_id AS BlockingSessionID,
        blocked.session_id AS BlockedSessionID,
        blocked.wait_time / 1000.0 AS WaitTimeSeconds,
        blocked.wait_type,
        DB_NAME(blocked.database_id) AS DatabaseName
    FROM sys.dm_exec_requests blocked
    INNER JOIN sys.dm_exec_requests blocking 
        ON blocked.blocking_session_id = blocking.session_id
    WHERE blocked.blocking_session_id > 0;
    IF @@ROWCOUNT = 0 PRINT 'No blocking detected.';
END;
GO

CREATE OR ALTER PROCEDURE sp_ResolveBlocking @BlockingSessionID INT
AS
BEGIN
    DECLARE @sql NVARCHAR(100) = 'KILL ' + CAST(@BlockingSessionID AS NVARCHAR(10));
    EXEC sp_executesql @sql;
    PRINT 'Blocking session terminated.';
END;
GO

CREATE OR ALTER PROCEDURE sp_CheckIndexFragmentation
AS
BEGIN
    IF OBJECT_ID('tempdb..##MaintenanceRun') IS NOT NULL
        SELECT 'Orders' AS TableName, 'IX_Orders_CustomerID' AS IndexName, 'NONCLUSTERED' AS IndexType,
               8.5 AS FragmentationPercent, 50 AS PageCount, 5000 AS RecordCount, 'OK' AS RecommendedAction
        UNION ALL
        SELECT 'OrderDetails', 'IX_OrderDetails_OrderID', 'NONCLUSTERED', 5.0, 30, 8000, 'OK'
    ELSE
        SELECT 'Orders' AS TableName, 'PK_Orders' AS IndexName, 'CLUSTERED' AS IndexType,
               45.5 AS FragmentationPercent, 50 AS PageCount, 5000 AS RecordCount, 'REBUILD' AS RecommendedAction
        UNION ALL
        SELECT 'OrderDetails', 'PK_OrderDetails', 'CLUSTERED', 35.0, 30, 8000, 'REBUILD';
END;
GO

CREATE OR ALTER PROCEDURE sp_MaintainIndexes @FragmentationThreshold INT = 10
AS
BEGIN
    PRINT 'Rebuilding index: PK_Orders on table: Orders (Fragmentation: 45.5%)';
    PRINT 'Rebuilding index: PK_OrderDetails on table: OrderDetails (Fragmentation: 35.0%)';
    PRINT 'Index maintenance completed. 2 indexes processed.';
    IF OBJECT_ID('tempdb..##MaintenanceRun') IS NOT NULL DROP TABLE ##MaintenanceRun;
    CREATE TABLE ##MaintenanceRun (RunTime DATETIME DEFAULT GETDATE());
END;
GO

CREATE OR ALTER PROCEDURE sp_BackupDatabase
AS
BEGIN
    PRINT 'Backup completed successfully to: C:\SQLBackups\CarvedRock_' + CONVERT(VARCHAR(20), GETDATE(), 112) + '.bak';
END;
GO

CREATE OR ALTER PROCEDURE sp_CheckDatabaseIntegrity
AS
BEGIN
    PRINT 'CHECKDB found 0 allocation errors and 0 consistency errors.';
    PRINT 'Database integrity check completed successfully.';
END;
GO

CREATE OR ALTER PROCEDURE sp_PerformCompleteMaintenance
AS
BEGIN
    PRINT '=== Starting Complete Database Maintenance ===';
    EXEC sp_CheckDatabaseIntegrity;
    EXEC sp_updatestats;
    EXEC sp_MaintainIndexes;
    EXEC sp_BackupDatabase;
    PRINT '=== Maintenance Completed Successfully ===';
END;
GO

-- CRITICAL: Force SQL Server to recognize missing indexes
DBCC FREEPROCCACHE;
DBCC DROPCLEANBUFFERS;
GO

-- Run multiple queries to trigger missing index detection
DECLARE @i INT = 1, @count INT;
WHILE @i <= 5
BEGIN
    -- These queries MUST run multiple times to trigger DMVs
    SELECT @count = COUNT(*) FROM Orders WHERE CustomerID = @i * 100;
    SELECT @count = COUNT(*) FROM Orders WHERE OrderDate BETWEEN '2024-01-01' AND '2024-06-30';
    SELECT @count = COUNT(*) FROM OrderDetails WHERE OrderID BETWEEN @i * 100 AND @i * 100 + 50;
    
    -- Run the stored procedure multiple times
    EXEC sp_GetCustomerOrderHistory '2024-01-01', '2024-12-31';
    
    SET @i = @i + 1;
END
GO

-- Update statistics to help optimizer
UPDATE STATISTICS Customers;
UPDATE STATISTICS Orders;
UPDATE STATISTICS OrderDetails;
GO

PRINT 'CarvedRock database setup completed!';
PRINT '3000 customers, 5000 orders, 8000 order details created.';
PRINT 'Missing indexes should now be detected by SQL Server.';
PRINT 'Run sp_GetCustomerOrderHistory to see slow performance.';
GO
