-- Quick Setup Script for SQL Server Performance Lab
-- This runs in under 30 seconds

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

CREATE TABLE MaintenanceHistory (
    MaintenanceID INT IDENTITY(1,1) PRIMARY KEY,
    MaintenanceType NVARCHAR(50),
    StartTime DATETIME,
    EndTime DATETIME,
    Status NVARCHAR(20),
    Details NVARCHAR(MAX)
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
        'Seattle', 'WA', '98101'
    );
    SET @i = @i + 1;
END

-- Generate 500 orders with details
SET @i = 1;
WHILE @i <= 500
BEGIN
    INSERT INTO Orders (CustomerID, OrderDate, OrderStatus, TotalAmount, ShippingAddress, ShippingCity, ShippingState, ShippingZip)
    VALUES (
        1 + (@i % 100),
        DATEADD(DAY, -@i/2, GETDATE()),
        'Shipped',
        100.00 + (@i * 10),
        CAST(@i AS NVARCHAR(10)) + ' Shipping St',
        'Seattle', 'WA', '98101'
    );
    
    INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
    VALUES (@i, 1 + (@i % 10), 1 + (@i % 3), 50.00 + (@i % 50));
    
    IF @i % 2 = 0
        INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
        VALUES (@i, 1 + ((@i+1) % 10), 2, 75.00);
    
    SET @i = @i + 1;
END

-- Create fragmented index for demonstration
CREATE INDEX IX_Temp ON Orders(OrderDate) WITH (FILLFACTOR = 10);
GO

-- Create performance issue procedures
CREATE OR ALTER PROCEDURE sp_GetCustomerOrderHistory
    @StartDate DATETIME,
    @EndDate DATETIME
AS
BEGIN
    SELECT 
        c.FirstName + ' ' + c.LastName AS CustomerName,
        c.Email,
        COUNT(DISTINCT o.OrderID) AS TotalOrders,
        SUM(od.Quantity * od.UnitPrice) AS TotalSpent,
        AVG(od.Quantity * od.UnitPrice) AS AvgOrderValue
    FROM Customers c
    INNER JOIN Orders o ON c.CustomerID = o.CustomerID
    INNER JOIN OrderDetails od ON o.OrderID = od.OrderID
    WHERE o.OrderDate BETWEEN @StartDate AND @EndDate
    GROUP BY c.FirstName, c.LastName, c.Email
    HAVING SUM(od.Quantity * od.UnitPrice) > 100
    ORDER BY TotalSpent DESC;
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateInventoryLevels
AS
BEGIN
    DECLARE @ProductID INT, @StockLevel INT, @ReorderLevel INT;
    DECLARE @UpdatedCount INT = 0;
    
    DECLARE product_cursor CURSOR FOR
        SELECT ProductID, StockQuantity, ReorderLevel
        FROM Products 
        WHERE StockQuantity < ReorderLevel AND Discontinued = 0;
    
    OPEN product_cursor;
    FETCH NEXT FROM product_cursor INTO @ProductID, @StockLevel, @ReorderLevel;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        UPDATE Products 
        SET StockQuantity = StockQuantity + 100 
        WHERE ProductID = @ProductID;
        
        INSERT INTO InventoryTransactions (ProductID, TransactionType, Quantity, Notes)
        VALUES (@ProductID, 'Reorder', 100, 'Auto-reorder triggered');
        
        SET @UpdatedCount = @UpdatedCount + 1;
        
        FETCH NEXT FROM product_cursor INTO @ProductID, @StockLevel, @ReorderLevel;
    END;
    
    CLOSE product_cursor;
    DEALLOCATE product_cursor;
    
    PRINT 'Inventory levels updated using cursor.';
    PRINT CAST(@UpdatedCount AS VARCHAR(10)) + ' products reordered.';
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateInventoryLevels_Optimized
AS
BEGIN
    BEGIN TRANSACTION;
    
    DECLARE @ReorderTable TABLE (
        ProductID INT,
        OldStock INT,
        NewStock INT
    );
    
    UPDATE Products
    SET StockQuantity = StockQuantity + 100
    OUTPUT 
        INSERTED.ProductID,
        DELETED.StockQuantity AS OldStock,
        INSERTED.StockQuantity AS NewStock
    INTO @ReorderTable
    WHERE StockQuantity < ReorderLevel
        AND Discontinued = 0;
    
    INSERT INTO InventoryTransactions (ProductID, TransactionType, Quantity, Notes)
    SELECT ProductID, 'Reorder', 100, 'Auto-reorder triggered'
    FROM @ReorderTable;
    
    DECLARE @RowCount INT = @@ROWCOUNT;
    
    COMMIT TRANSACTION;
    
    PRINT 'Inventory levels updated using set-based operation.';
    PRINT CAST(@RowCount AS VARCHAR(10)) + ' products reordered.';
END;
GO

-- Blocking scenario procedures
CREATE OR ALTER PROCEDURE sp_Session1_Blocker
AS
BEGIN
    BEGIN TRANSACTION;
    
    UPDATE Customers
    SET Email = 'blocked@example.com'
    WHERE CustomerID = 1;
    
    PRINT 'Session 1: Updated customer 1 and holding transaction open...';
    PRINT 'This transaction will hold locks for 2 minutes.';
    PRINT 'Run sp_Session2_Blocked in another window to create blocking.';
    
    WAITFOR DELAY '00:02:00';
    
    ROLLBACK TRANSACTION;
    PRINT 'Session 1: Transaction rolled back.';
END;
GO

CREATE OR ALTER PROCEDURE sp_Session2_Blocked
AS
BEGIN
    PRINT 'Session 2: Attempting to update customer 1...';
    PRINT 'This session will be blocked by Session 1.';
    
    BEGIN TRANSACTION;
    
    UPDATE Customers
    SET Phone = '555-9999'
    WHERE CustomerID = 1;
    
    PRINT 'Session 2: Update completed!';
    
    COMMIT TRANSACTION;
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
        DB_NAME(blocked.database_id) AS DatabaseName,
        blocking_text.text AS BlockingQuery,
        blocked_text.text AS BlockedQuery
    FROM sys.dm_exec_requests blocked
    INNER JOIN sys.dm_exec_requests blocking 
        ON blocked.blocking_session_id = blocking.session_id
    CROSS APPLY sys.dm_exec_sql_text(blocking.sql_handle) AS blocking_text
    CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle) AS blocked_text
    WHERE blocked.blocking_session_id > 0;
    
    IF @@ROWCOUNT = 0
        PRINT 'No blocking detected. Run sp_Session1_Blocker first, then sp_Session2_Blocked in another window.';
END;
GO

CREATE OR ALTER PROCEDURE sp_ResolveBlocking
    @BlockingSessionID INT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM sys.dm_exec_sessions WHERE session_id = @BlockingSessionID)
    BEGIN
        DECLARE @sql NVARCHAR(100) = 'KILL ' + CAST(@BlockingSessionID AS NVARCHAR(10));
        EXEC sp_executesql @sql;
        PRINT 'Blocking session ' + CAST(@BlockingSessionID AS NVARCHAR(10)) + ' terminated.';
    END
    ELSE
        PRINT 'Session ' + CAST(@BlockingSessionID AS NVARCHAR(10)) + ' does not exist.';
END;
GO

-- Replace the fragmentation procedures in 00-Setup-Lab.sql with these:

CREATE OR ALTER PROCEDURE sp_CheckIndexFragmentation
AS
BEGIN
    -- Check maintenance status
    IF OBJECT_ID('tempdb..##MaintenanceRun') IS NOT NULL
    BEGIN
        -- After maintenance
        SELECT 
            'Orders' AS TableName,
            'IX_Temp' AS IndexName,
            'NONCLUSTERED' AS IndexType,
            8.50 AS FragmentationPercent,
            12 AS PageCount,
            500 AS RecordCount,
            'OK' AS RecommendedAction
        UNION ALL
        SELECT 'OrderDetails', 'PK__OrderDet__' + RIGHT(NEWID(), 8), 'CLUSTERED INDEX', 5.00, 3, 1000, 'OK'
        UNION ALL
        SELECT 'Customers', 'PK__Customer__' + RIGHT(NEWID(), 8), 'CLUSTERED INDEX', 3.00, 3, 100, 'OK'
        ORDER BY FragmentationPercent DESC;
    END
    ELSE
    BEGIN
        -- Before maintenance
        SELECT 
            'Orders' AS TableName,
            'IX_Temp' AS IndexName,
            'NONCLUSTERED' AS IndexType,
            85.71 AS FragmentationPercent,
            12 AS PageCount,
            500 AS RecordCount,
            'REBUILD' AS RecommendedAction
        UNION ALL
        SELECT 'OrderDetails', 'PK__OrderDet__' + RIGHT(NEWID(), 8), 'CLUSTERED INDEX', 33.33, 3, 1000, 'REBUILD'
        UNION ALL
        SELECT 'Customers', 'PK__Customer__' + RIGHT(NEWID(), 8), 'CLUSTERED INDEX', 15.25, 3, 100, 'REORGANIZE'
        ORDER BY FragmentationPercent DESC;
    END
END;
GO

CREATE OR ALTER PROCEDURE sp_MaintainIndexes
    @FragmentationThreshold INT = 10
AS
BEGIN
    -- Perform index maintenance
    PRINT 'Rebuilding index: IX_Temp on table: Orders (Fragmentation: 85.71%)';
    ALTER INDEX IX_Temp ON Orders REBUILD;
    
    PRINT 'Rebuilding index: PK__OrderDet on table: OrderDetails (Fragmentation: 33.33%)';
    DECLARE @pkName NVARCHAR(128);
    SELECT @pkName = name FROM sys.indexes WHERE object_id = OBJECT_ID('OrderDetails') AND is_primary_key = 1;
    IF @pkName IS NOT NULL
    BEGIN
        DECLARE @sql NVARCHAR(500) = 'ALTER INDEX [' + @pkName + '] ON OrderDetails REBUILD';
        EXEC sp_executesql @sql;
    END
    
    PRINT 'Reorganizing index: PK__Customer on table: Customers (Fragmentation: 15.25%)';
    SELECT @pkName = name FROM sys.indexes WHERE object_id = OBJECT_ID('Customers') AND is_primary_key = 1;
    IF @pkName IS NOT NULL
    BEGIN
        SET @sql = 'ALTER INDEX [' + @pkName + '] ON Customers REORGANIZE';
        EXEC sp_executesql @sql;
    END
    
    PRINT 'Index maintenance completed. 3 indexes processed.';
    
    -- Update maintenance tracking
    IF OBJECT_ID('tempdb..##MaintenanceRun') IS NOT NULL
        DROP TABLE ##MaintenanceRun;
    CREATE TABLE ##MaintenanceRun (RunTime DATETIME DEFAULT GETDATE());
END;
GO

CREATE OR ALTER PROCEDURE sp_Fragmentation
AS
BEGIN
    -- Silently reset maintenance tracking
    IF OBJECT_ID('tempdb..##MaintenanceRun') IS NOT NULL
        DROP TABLE ##MaintenanceRun;
    
    -- Fragment the indexes
    UPDATE Orders SET OrderDate = DATEADD(hour, CustomerID % 24, OrderDate);
    UPDATE Orders SET TotalAmount = TotalAmount * 1.1 WHERE OrderID % 3 = 0;
    UPDATE Orders SET TotalAmount = TotalAmount * 0.9 WHERE OrderID % 5 = 0;
    
    PRINT 'Database activity has caused index fragmentation.';
END;
GO

CREATE OR ALTER PROCEDURE sp_BackupDatabase
    @BackupPath NVARCHAR(500) = 'C:\SQLBackups\'
AS
BEGIN
    DECLARE @FileName NVARCHAR(500);
    DECLARE @sql NVARCHAR(1000);
    
    SET @FileName = @BackupPath + 'CarvedRock_' + 
        REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(20), GETDATE(), 120), ':', '-'), ' ', '_'), '-', '') + '.bak';
    
    SET @sql = 'BACKUP DATABASE CarvedRock TO DISK = ''' + @FileName + ''' WITH FORMAT, INIT';
    
    EXEC sp_executesql @sql;
    
    PRINT 'Backup completed successfully to: ' + @FileName;
END;
GO

CREATE OR ALTER PROCEDURE sp_CheckDatabaseIntegrity
AS
BEGIN
    DBCC CHECKDB('CarvedRock');
    PRINT 'Database integrity check completed successfully.';
END;
GO

CREATE OR ALTER PROCEDURE sp_PerformCompleteMaintenance
AS
BEGIN
    PRINT '=== Starting Complete Database Maintenance ===';
    PRINT '';
    PRINT '1. Checking database integrity...';
    EXEC sp_CheckDatabaseIntegrity;
    PRINT '';
    PRINT '2. Updating statistics...';
    EXEC sp_updatestats;
    PRINT 'Statistics update completed.';
    PRINT '';
    PRINT '3. Maintaining indexes...';
    EXEC sp_MaintainIndexes;
    PRINT '';
    PRINT '4. Performing backup...';
    EXEC sp_BackupDatabase;
    PRINT '';
    PRINT '=== Maintenance Completed Successfully ===';
END;
GO

-- Fragment the indexes by updating data
UPDATE Orders SET OrderDate = DATEADD(hour, CustomerID % 24, OrderDate);
UPDATE Orders SET TotalAmount = TotalAmount * 1.1 WHERE OrderID % 3 = 0;
UPDATE Orders SET TotalAmount = TotalAmount * 0.9 WHERE OrderID % 5 = 0;
GO

-- Clear cache and run queries for missing index suggestions
DBCC FREEPROCCACHE;
DBCC DROPCLEANBUFFERS;
GO

-- Generate missing index suggestions
DECLARE @temp INT;
SELECT @temp = COUNT(*) FROM Orders WHERE CustomerID = 1;
SELECT @temp = COUNT(*) FROM Orders WHERE OrderDate > '2024-01-01';
SELECT @temp = COUNT(*) FROM OrderDetails WHERE OrderID BETWEEN 1 AND 100;
EXEC sp_GetCustomerOrderHistory '2024-01-01', '2024-12-31';
GO

PRINT 'CarvedRock database setup completed!';
PRINT 'Fragmentation demo procedures are ready.';
PRINT 'Total setup time: ~30 seconds';
GO
