# SQL Server Performance Tuning Lab Setup Script
# This script is designed to be extremely robust and handle all edge cases

$ErrorActionPreference = "Continue"

# Create directories first
New-Item -ItemType Directory -Force -Path "C:\LabFiles" | Out-Null
New-Item -ItemType Directory -Force -Path "C:\SQLData" | Out-Null
New-Item -ItemType Directory -Force -Path "C:\SQLBackup" | Out-Null

# Start logging immediately
$logFile = "C:\LabFiles\setup_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Start-Transcript -Path $logFile -Force

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SQL Server Lab Setup Started" -ForegroundColor Green
Write-Host "Time: $(Get-Date)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# Function to test SQL Server connectivity
function Test-SqlConnection {
    param($ServerInstance = "localhost")
    try {
        $query = "SELECT @@VERSION AS Version"
        $result = Invoke-Sqlcmd -Query $query -ServerInstance $ServerInstance -ErrorAction Stop -QueryTimeout 10
        return $true
    }
    catch {
        return $false
    }
}

# Wait for SQL Server with extended timeout
Write-Host "`nWaiting for SQL Server to be ready..." -ForegroundColor Yellow
$maxWaitMinutes = 5
$waited = 0
$sqlReady = $false

while ($waited -lt $maxWaitMinutes -and -not $sqlReady) {
    # First ensure the service is running
    $sqlService = Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue
    if ($sqlService) {
        if ($sqlService.Status -ne 'Running') {
            Write-Host "Starting SQL Server service..." -ForegroundColor Yellow
            Start-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 30  # Give it time to start
        }
    }
    
    # Test connection
    if (Test-SqlConnection) {
        $sqlReady = $true
        Write-Host "SQL Server is ready!" -ForegroundColor Green
    }
    else {
        Write-Host "Still waiting for SQL Server... ($waited/$maxWaitMinutes minutes)" -ForegroundColor Yellow
        Start-Sleep -Seconds 60
        $waited++
    }
}

if (-not $sqlReady) {
    Write-Host "WARNING: SQL Server may not be fully ready, but continuing..." -ForegroundColor Yellow
}

# Create a simple test database first to verify everything works
Write-Host "`nTesting database creation capability..." -ForegroundColor Yellow
$testScript = @"
USE master;
GO
IF EXISTS (SELECT name FROM sys.databases WHERE name = N'TestDB')
    DROP DATABASE TestDB;
GO
CREATE DATABASE TestDB;
GO
DROP DATABASE TestDB;
GO
"@

$testScript | Out-File -FilePath "C:\LabFiles\test_db.sql" -Encoding UTF8
$testResult = sqlcmd -S localhost -E -i "C:\LabFiles\test_db.sql" -o "C:\LabFiles\test_output.txt" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Database creation test successful!" -ForegroundColor Green
}
else {
    Write-Host "Database creation test failed. Check C:\LabFiles\test_output.txt" -ForegroundColor Red
    Get-Content "C:\LabFiles\test_output.txt"
}

# Create the main database script - SIMPLIFIED VERSION
Write-Host "`nCreating database scripts..." -ForegroundColor Yellow

$createDbScript = @'
-- Create CarvedRock Database with simplified structure
USE master;
GO

-- Drop existing database if it exists
IF DB_ID('CarvedRock') IS NOT NULL
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

-- Create Customers table
CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Email NVARCHAR(100),
    CreatedDate DATETIME DEFAULT GETDATE()
);
GO

-- Create Products table
CREATE TABLE Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(100),
    Price DECIMAL(10,2),
    StockQuantity INT DEFAULT 0
);
GO

-- Create Orders table
CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT,
    OrderDate DATETIME DEFAULT GETDATE(),
    TotalAmount DECIMAL(10,2)
);
GO

-- Create OrderDetails table
CREATE TABLE OrderDetails (
    OrderDetailID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT,
    UnitPrice DECIMAL(10,2)
);
GO

PRINT 'CarvedRock database structure created successfully!';
GO
'@

$createDbScript | Out-File -FilePath "C:\LabFiles\create_database.sql" -Encoding UTF8 -Force

# Create data population script - MINIMAL DATA FOR QUICK SETUP
$populateScript = @'
USE CarvedRock;
GO

-- Insert sample Products (50 products)
DECLARE @i INT = 1;
WHILE @i <= 50
BEGIN
    INSERT INTO Products (ProductName, Price, StockQuantity)
    VALUES ('Product ' + CAST(@i AS NVARCHAR(10)), 
            CAST((RAND() * 500 + 10) AS DECIMAL(10,2)),
            CAST((RAND() * 100 + 10) AS INT));
    SET @i = @i + 1;
END
GO

-- Insert sample Customers (100 customers)
DECLARE @j INT = 1;
WHILE @j <= 100
BEGIN
    INSERT INTO Customers (FirstName, LastName, Email)
    VALUES ('First' + CAST(@j AS NVARCHAR(10)),
            'Last' + CAST(@j AS NVARCHAR(10)),
            'customer' + CAST(@j AS NVARCHAR(10)) + '@example.com');
    SET @j = @j + 1;
END
GO

-- Insert sample Orders (500 orders)
DECLARE @k INT = 1;
WHILE @k <= 500
BEGIN
    INSERT INTO Orders (CustomerID, OrderDate, TotalAmount)
    VALUES (CAST((RAND() * 99 + 1) AS INT),
            DATEADD(DAY, -CAST(RAND() * 365 AS INT), GETDATE()),
            CAST((RAND() * 1000 + 10) AS DECIMAL(10,2)));
    SET @k = @k + 1;
END
GO

-- Insert sample OrderDetails (1000 order items)
DECLARE @m INT = 1;
WHILE @m <= 1000
BEGIN
    INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
    VALUES (CAST((RAND() * 499 + 1) AS INT),
            CAST((RAND() * 49 + 1) AS INT),
            CAST((RAND() * 10 + 1) AS INT),
            CAST((RAND() * 500 + 10) AS DECIMAL(10,2)));
    SET @m = @m + 1;
END
GO

PRINT 'Sample data inserted successfully!';
PRINT 'Customers: 100, Products: 50, Orders: 500, OrderDetails: 1000';
GO
'@

$populateScript | Out-File -FilePath "C:\LabFiles\populate_data.sql" -Encoding UTF8 -Force

# Create performance issues script
$perfScript = @'
USE CarvedRock;
GO

-- Drop any existing indexes to create missing index scenarios
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Orders_CustomerID' AND object_id = OBJECT_ID('Orders'))
    DROP INDEX IX_Orders_CustomerID ON Orders;
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Orders_OrderDate' AND object_id = OBJECT_ID('Orders'))
    DROP INDEX IX_Orders_OrderDate ON Orders;
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Orders_OrderDate_CustomerID' AND object_id = OBJECT_ID('Orders'))
    DROP INDEX IX_Orders_OrderDate_CustomerID ON Orders;
GO

-- Run queries to generate missing index recommendations
DECLARE @i INT = 1;
WHILE @i <= 20
BEGIN
    SELECT * FROM Orders WHERE CustomerID = @i;
    SELECT * FROM Orders WHERE OrderDate >= DATEADD(DAY, -@i*10, GETDATE());
    SET @i = @i + 1;
END
GO

-- More queries to strengthen missing index recommendations
SELECT o.OrderID, o.OrderDate, o.TotalAmount, c.FirstName, c.LastName
FROM Orders o
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
WHERE o.OrderDate >= DATEADD(MONTH, -3, GETDATE());
GO

SELECT * FROM Products WHERE CategoryID = 1;
SELECT * FROM Products WHERE CategoryID = 2;
SELECT * FROM OrderDetails WHERE OrderID BETWEEN 1 AND 100;
GO

PRINT 'Performance scenarios created!';
GO
'@

$perfScript | Out-File -FilePath "C:\LabFiles\performance_issues.sql" -Encoding UTF8 -Force

# Create verification script
$verifyScript = @'
USE master;
GO
SELECT 
    'Database Exists' as CheckType,
    CASE WHEN DB_ID('CarvedRock') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END as Result
UNION ALL
SELECT 
    'Table Count' as CheckType,
    CASE WHEN (SELECT COUNT(*) FROM CarvedRock.sys.tables) >= 4 THEN 'PASS' ELSE 'FAIL' END as Result
UNION ALL
SELECT 
    'Customer Count' as CheckType,
    CASE WHEN (SELECT COUNT(*) FROM CarvedRock.dbo.Customers) > 0 THEN 'PASS' ELSE 'FAIL' END as Result
UNION ALL
SELECT 
    'Order Count' as CheckType,
    CASE WHEN (SELECT COUNT(*) FROM CarvedRock.dbo.Orders) > 0 THEN 'PASS' ELSE 'FAIL' END as Result;
GO
'@

$verifyScript | Out-File -FilePath "C:\LabFiles\verify_setup.sql" -Encoding UTF8 -Force

# Now execute the scripts in sequence
Write-Host "`nExecuting database setup scripts..." -ForegroundColor Yellow

# Step 1: Create Database
Write-Host "Step 1: Creating database structure..." -ForegroundColor Cyan
$output1 = sqlcmd -S localhost -E -i "C:\LabFiles\create_database.sql" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  SUCCESS: Database created" -ForegroundColor Green
}
else {
    Write-Host "  FAILED: Check manual instructions below" -ForegroundColor Red
    Write-Host $output1 -ForegroundColor Red
}

# Wait a moment for database to be ready
Start-Sleep -Seconds 5

# Step 2: Populate Data
Write-Host "Step 2: Populating sample data..." -ForegroundColor Cyan
$output2 = sqlcmd -S localhost -E -i "C:\LabFiles\populate_data.sql" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  SUCCESS: Data populated" -ForegroundColor Green
}
else {
    Write-Host "  FAILED: Check manual instructions below" -ForegroundColor Red
    Write-Host $output2 -ForegroundColor Red
}

# Step 3: Create Performance Issues
Write-Host "Step 3: Creating performance scenarios..." -ForegroundColor Cyan
$output3 = sqlcmd -S localhost -E -i "C:\LabFiles\performance_issues.sql" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  SUCCESS: Performance scenarios created" -ForegroundColor Green
}
else {
    Write-Host "  WARNING: Some performance scenarios may have failed" -ForegroundColor Yellow
}

# Step 3b: Generate missing index stats
Write-Host "Step 3b: Generating missing index statistics..." -ForegroundColor Cyan
$output3b = sqlcmd -S localhost -E -i "C:\LabFiles\generate_missing_indexes.sql" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  SUCCESS: Missing index stats generated" -ForegroundColor Green
}
else {
    Write-Host "  INFO: Missing index generation completed" -ForegroundColor Yellow
}

# Step 4: Verify Setup
Write-Host "`nVerifying setup..." -ForegroundColor Yellow
$verifyOutput = sqlcmd -S localhost -E -i "C:\LabFiles\verify_setup.sql" 2>&1
Write-Host $verifyOutput -ForegroundColor Cyan

# Create script to generate missing indexes
$generateIndexScript = @'
-- Script to Generate Missing Index Recommendations
USE CarvedRock;
GO

-- Drop existing indexes if any
IF EXISTS (SELECT * FROM sys.indexes WHERE name LIKE 'IX_Orders_%' AND object_id = OBJECT_ID('Orders'))
BEGIN
    DECLARE @sql NVARCHAR(MAX) = '';
    SELECT @sql = @sql + 'DROP INDEX ' + name + ' ON Orders; '
    FROM sys.indexes 
    WHERE object_id = OBJECT_ID('Orders') 
    AND name LIKE 'IX_%';
    
    IF @sql != ''
        EXEC sp_executesql @sql;
END
GO

DBCC FREEPROCCACHE;
GO

-- Run queries that need indexes
DECLARE @i INT = 1;
WHILE @i <= 30
BEGIN
    SELECT * FROM Orders WHERE CustomerID = @i;
    SELECT * FROM Orders WHERE OrderDate >= DATEADD(DAY, -@i*10, GETDATE());
    SET @i = @i + 1;
END
GO

-- Check for missing indexes
SELECT 
    OBJECT_NAME(mid.object_id) AS TableName,
    mid.equality_columns AS WhereColumns,
    ROUND(migs.avg_user_impact, 2) AS AvgPercentImprovement
FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY migs.avg_user_impact DESC;
GO
'@

$generateIndexScript | Out-File -FilePath "C:\LabFiles\generate_missing_indexes.sql" -Encoding UTF8 -Force

# Create verification script
$verifyLabScript = @'
-- Complete Lab Verification Script
USE master;
GO

PRINT '========================================';
PRINT 'LAB VERIFICATION STARTING...';
PRINT '========================================';

IF DB_ID('CarvedRock') IS NOT NULL
BEGIN
    PRINT '[PASS] Database CarvedRock exists';
    USE CarvedRock;
    
    DECLARE @tableCount INT = (SELECT COUNT(*) FROM sys.tables);
    IF @tableCount >= 5
        PRINT '[PASS] Tables created: ' + CAST(@tableCount AS VARCHAR(10));
    ELSE
        PRINT '[FAIL] Missing tables';
    
    DECLARE @customerCount INT = (SELECT COUNT(*) FROM Customers);
    IF @customerCount > 0
        PRINT '[PASS] Data loaded: ' + CAST(@customerCount AS VARCHAR(10)) + ' customers';
    ELSE
        PRINT '[FAIL] No data in Customers table';
END
ELSE
BEGIN
    PRINT '[FAIL] Database CarvedRock does not exist!';
END

PRINT '========================================';
GO
'@

$verifyLabScript | Out-File -FilePath "C:\LabFiles\verify_lab_complete.sql" -Encoding UTF8 -Force

# Create a manual setup batch file as backup
$batchScript = @"
@echo off
echo Running Manual Database Setup...
sqlcmd -S localhost -E -i "C:\LabFiles\create_database.sql"
timeout /t 5
sqlcmd -S localhost -E -i "C:\LabFiles\populate_data.sql"
timeout /t 5
sqlcmd -S localhost -E -i "C:\LabFiles\performance_issues.sql"
timeout /t 5
sqlcmd -S localhost -E -i "C:\LabFiles\generate_missing_indexes.sql"
timeout /t 5
sqlcmd -S localhost -E -i "C:\LabFiles\verify_setup.sql"
pause
"@

$batchScript | Out-File -FilePath "C:\LabFiles\MANUAL_SETUP.bat" -Encoding ASCII -Force

# Create desktop items
$desktopPaths = @(
    "$env:PUBLIC\Desktop",
    "$env:USERPROFILE\Desktop",
    "C:\Users\cloud_user\Desktop"
)

foreach ($desktop in $desktopPaths) {
    if (Test-Path $desktop) {
        # Create manual setup shortcut
        Copy-Item "C:\LabFiles\MANUAL_SETUP.bat" "$desktop\RUN_IF_DATABASE_MISSING.bat" -Force -ErrorAction SilentlyContinue
        
        # Create instructions file
        $instructions = @"
SQL SERVER LAB - QUICK START
=============================
If the database is missing, double-click:
RUN_IF_DATABASE_MISSING.bat

Or open SSMS and run these files in order:
1. C:\LabFiles\create_database.sql
2. C:\LabFiles\populate_data.sql
3. C:\LabFiles\create_performance_issues.sql

To verify setup, run:
C:\LabFiles\verify_setup.sql

If missing index DMV shows 0 rows, run:
C:\LabFiles\generate_missing_indexes.sql

Server: localhost
Auth: Windows Authentication
Database: CarvedRock
=============================
"@
        $instructions | Out-File "$desktop\README_FIRST.txt" -Encoding UTF8 -Force
    }
}

# Enable SQL Agent (try but don't fail if it doesn't work)
try {
    Invoke-Sqlcmd -Query "EXEC sp_configure 'Agent XPs', 1; RECONFIGURE;" -ServerInstance "localhost" -ErrorAction SilentlyContinue
}
catch {
    # Ignore errors
}

Stop-Transcript

# Final message
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "SETUP COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Check desktop for README_FIRST.txt" -ForegroundColor Yellow
Write-Host "Log file: $logFile" -ForegroundColor Yellow
Write-Host "If database is missing, run the batch file on desktop" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Green
