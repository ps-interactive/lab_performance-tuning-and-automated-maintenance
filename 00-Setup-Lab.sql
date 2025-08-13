-- SQL Server Performance Lab Setup - Creates REAL performance issues
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

-- Create tables WITHOUT any indexes initially (except PKs)
CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY NONCLUSTERED,  -- Use nonclustered to cause fragmentation
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

-- Orders table WITHOUT CustomerID index (this will cause performance issues)
CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY NONCLUSTERED,  -- Nonclustered to allow fragmentation
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

-- OrderDetails WITHOUT OrderID index
CREATE TABLE OrderDetails (
    OrderDetailID INT IDENTITY(1,1) PRIMARY KEY NONCLUSTERED,
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
    ('Hiking Boots', 'Footwear', 129.99, 15, 20),  -- Low stock to trigger reorder
    ('Camping Tent 2-Person', 'Camping', 199.99, 8, 10),
    ('Climbing Rope 60m', 'Climbing', 249.99, 3, 5),
    ('Trail Running Shoes', 'Footwear', 89.99, 25, 30),
    ('Backpack 65L', 'Hiking', 179.99, 12, 15),
    ('Sleeping Bag -10C', 'Camping', 149.99, 10, 12),
    ('Carabiner Set', 'Climbing', 39.99, 40, 40),
    ('Water Filter', 'Camping', 49.99, 18, 20),
    ('Trekking Poles', 'Hiking', 79.99, 14, 16),
    ('Headlamp', 'Accessories', 34.99, 25, 30);

-- Generate MORE data for realistic performance issues (5000 customers, 10000 orders)
DECLARE @i INT = 1;
PRINT 'Creating 5000 customers...';

WHILE @i <= 5000
BEGIN
    INSERT INTO Customers (FirstName, LastName, Email, Phone, Address, City, State, ZipCode)
    VALUES (
        'FirstName' + CAST(@i AS NVARCHAR(10)),
        'LastName' + CAST(@i AS NVARCHAR(10)),
        'customer' + CAST(@i AS NVARCHAR(10)) + '@example.com',
        '555-' + RIGHT('0000' + CAST(@i AS NVARCHAR(10)), 4),
        CAST(@i AS NVARCHAR(10)) + ' Main Street',
        CASE WHEN @i % 3 = 0 THEN 'Seattle' WHEN @i % 3 = 1 THEN 'Portland' ELSE 'Tacoma' END,
        'WA', 
        '98' + RIGHT('000' + CAST(@i % 999 AS NVARCHAR(3)), 3)
    );
    
    IF @i % 1000 = 0 PRINT 'Created ' + CAST(@i AS VARCHAR(10)) + ' customers...';
    SET @i = @i + 1;
END

-- Generate 10000 orders with varying dates
SET @i = 1;
PRINT 'Creating 10000 orders...';

WHILE @i <= 10000
BEGIN
    DECLARE @custId INT = 1 + (@i % 5000);
    DECLARE @orderDate DATETIME = DATEADD(DAY, -(@i % 365), GETDATE());
    
    INSERT INTO Orders (CustomerID, OrderDate, OrderStatus, TotalAmount, ShippingAddress, ShippingCity, ShippingState, ShippingZip)
    VALUES (
        @custId,
        @orderDate,
        CASE WHEN @i % 4 = 0 THEN 'Pending' WHEN @i % 4 = 1 THEN 'Shipped' WHEN @i % 4 = 2 THEN 'Delivered' ELSE 'Processing' END,
        50.00 + (@i % 500),
        CAST(@i AS NVARCHAR(10)) + ' Shipping St',
        'Seattle', 'WA', '98101'
    );
    
    -- Add 2-3 order details per order
    INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
    VALUES (@i, 1 + (@i % 10), 1 + (@i % 5), 25.00 + (@i % 100));
    
    IF @i % 2 = 0
        INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
        VALUES (@i, 1 + ((@i+3) % 10), 1 + (@i % 3), 35.00 + (@i % 75));
    
    IF @i % 3 = 0
        INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
        VALUES (@i, 1 + ((@i+5) % 10), 2, 45.00 + (@i % 50));
    
    IF @i % 2000 = 0 PRINT 'Created ' + CAST(@i AS VARCHAR(10)) + ' orders...';
    SET @i = @i + 1;
END

PRINT 'Data creation completed.';
GO

-- Create the problematic stored procedure (WITHOUT proper indexes)
CREATE OR ALTER PROCEDURE sp_GetCustomerOrderHistory
    @StartDate DATETIME,
    @EndDate DATETIME
AS
BEGIN
    -- Intentionally inefficient query that will benefit from indexes
    SELECT 
        c.FirstName + ' ' + c.LastName AS CustomerName,
        c.Email,
        COUNT(DISTINCT o.OrderID) AS TotalOrders,
        SUM(od.Quantity * od.UnitPrice) AS TotalSpent,
        AVG(od.Quantity * od.UnitPrice) AS AvgOrderValue
    FROM Customers c
    INNER JOIN Orders o ON c.CustomerID = o.CustomerID  -- No index on Orders.CustomerID
    INNER JOIN OrderDetails od ON o.OrderID = od.OrderID  -- No index on OrderDetails.OrderID
    WHERE o.OrderDate BETWEEN @StartDate AND @EndDate  -- No index on OrderDate
    GROUP BY c.FirstName, c.LastName, c.Email
    HAVING SUM(od.Quantity * od.UnitPrice) > 100
    ORDER BY TotalSpent DESC;
END;
GO

-- Create cursor-based procedure for comparison
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

-- Optimized version
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

-- Blocking procedures
CREATE OR ALTER PROCEDURE sp_Session1_Blocker
AS
BEGIN
    BEGIN TRANSACTION;
    UPDATE Customers SET Email = 'blocked@example.com' WHERE CustomerID = 1;
    PRINT 'Session 1: Updated customer 1 and holding transaction open...';
    PRINT 'This transaction will hold locks for 2 minutes.';
    WAITFOR DELAY '00:02:00';
    ROLLBACK TRANSACTION;
    PRINT 'Session 1: Transaction rolled back.';
END;
GO

CREATE OR ALTER PROCEDURE sp_Session2_Blocked
AS
BEGIN
    PRINT 'Session 2: Attempting to update customer 1...';
    BEGIN TRANSACTION;
    UPDATE Customers SET Phone = '555-9999' WHERE CustomerID = 1;
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
        PRINT 'No blocking detected.';
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
        PRINT 'Session does not exist.';
END;
GO

-- Maintenance procedures that show actual fragmentation
CREATE OR ALTER PROCEDURE sp_CheckIndexFragmentation
AS
BEGIN
    -- Check real fragmentation
    SELECT 
        OBJECT_NAME(ips.object_id) AS TableName,
        i.name AS IndexName,
        i.type_desc AS IndexType,
        ips.avg_fragmentation_in_percent AS FragmentationPercent,
        ips.page_count AS PageCount,
        ips.record_count AS RecordCount,
        CASE 
            WHEN ips.avg_fragmentation_in_percent > 30 AND ips.page_count > 8 THEN 'REBUILD'
            WHEN ips.avg_fragmentation_in_percent > 10 AND ips.page_count > 8 THEN 'REORGANIZE'
            ELSE 'OK'
        END AS RecommendedAction
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE i.name IS NOT NULL
        AND ips.alloc_unit_type_desc = 'IN_ROW_DATA'
    ORDER BY ips.avg_fragmentation_in_percent DESC;
END;
GO

CREATE OR ALTER PROCEDURE sp_MaintainIndexes
    @FragmentationThreshold INT = 10
AS
BEGIN
    DECLARE @TableName NVARCHAR(128), @IndexName NVARCHAR(128);
    DECLARE @FragPercent FLOAT, @sql NVARCHAR(500);
    DECLARE @Count INT = 0;
    
    DECLARE index_cursor CURSOR FOR
        SELECT 
            OBJECT_NAME(ips.object_id),
            i.name,
            ips.avg_fragmentation_in_percent
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
        INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
        WHERE ips.avg_fragmentation_in_percent > @FragmentationThreshold
            AND ips.page_count > 8
            AND i.name IS NOT NULL;
    
    OPEN index_cursor;
    FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @FragPercent;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @FragPercent > 30
        BEGIN
            SET @sql = 'ALTER INDEX [' + @IndexName + '] ON [' + @TableName + '] REBUILD';
            PRINT 'Rebuilding index: ' + @IndexName + ' on table: ' + @TableName + ' (Fragmentation: ' + CAST(@FragPercent AS VARCHAR(10)) + '%)';
        END
        ELSE
        BEGIN
            SET @sql = 'ALTER INDEX [' + @IndexName + '] ON [' + @TableName + '] REORGANIZE';
            PRINT 'Reorganizing index: ' + @IndexName + ' on table: ' + @TableName + ' (Fragmentation: ' + CAST(@FragPercent AS VARCHAR(10)) + '%)';
        END
        
        EXEC sp_executesql @sql;
        SET @Count = @Count + 1;
        
        FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @FragPercent;
    END;
    
    CLOSE index_cursor;
    DEALLOCATE index_cursor;
    
    IF @Count = 0
        PRINT 'No indexes require maintenance.';
    ELSE
        PRINT 'Index maintenance completed. ' + CAST(@Count AS VARCHAR(10)) + ' indexes processed.';
END;
GO

-- Other maintenance procedures
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
    DBCC CHECKDB('CarvedRock') WITH NO_INFOMSGS;
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

-- Create a fragmented index for demonstration
CREATE NONCLUSTERED INDEX IX_Temp ON Orders(ShippingCity) WITH (FILLFACTOR = 10);
GO

-- Fragment the indexes by doing updates
UPDATE Orders SET TotalAmount = TotalAmount * 1.01 WHERE OrderID % 10 = 0;
UPDATE Orders SET ShippingCity = 'Bellevue' WHERE OrderID % 50 = 0;
UPDATE Orders SET ShippingCity = 'Redmond' WHERE OrderID % 75 = 0;
GO

-- Clear cache and run queries to generate missing index suggestions
DBCC FREEPROCCACHE;
DBCC DROPCLEANBUFFERS;
GO

-- Run queries that will definitely generate missing index suggestions
DECLARE @Count INT;

-- These queries NEED indexes
SELECT @Count = COUNT(*) FROM Orders WHERE CustomerID = 100;  -- Needs index on CustomerID
SELECT @Count = COUNT(*) FROM Orders WHERE OrderDate BETWEEN '2024-01-01' AND '2024-12-31';  -- Needs index on OrderDate  
SELECT @Count = COUNT(*) FROM OrderDetails WHERE OrderID = 500;  -- Needs index on OrderID

-- Run the problematic stored procedure to generate more index suggestions
EXEC sp_GetCustomerOrderHistory '2024-01-01', '2024-12-31';
GO

PRINT '';
PRINT '==============================================';
PRINT 'CarvedRock database setup completed!';
PRINT '==============================================';
PRINT 'Database contains:';
PRINT '  - 5,000 customers';
PRINT '  - 10,000 orders';  
PRINT '  - ~20,000 order details';
PRINT '  - Missing indexes on Orders.CustomerID, Orders.OrderDate, OrderDetails.OrderID';
PRINT '  - Fragmented indexes ready for maintenance';
PRINT '';
PRINT 'The sp_GetCustomerOrderHistory procedure will now show:';
PRINT '  - Execution time of several seconds';
PRINT '  - Missing index warnings in execution plan';
PRINT '  - High-cost table scans';
PRINT '';
PRINT 'Total setup time: ~60-90 seconds';
GO
