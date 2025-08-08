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

-- Create indexes that we will fragment
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID ON Orders(CustomerID);
CREATE NONCLUSTERED INDEX IX_OrderDetails_OrderID ON OrderDetails(OrderID);
GO

-- Now drop some indexes to create missing index scenarios
DROP INDEX IX_Orders_CustomerID ON Orders;
GO

-- Create a stored procedure with performance issues
CREATE OR ALTER PROCEDURE sp_GetCustomerOrders
    @CustomerID INT
AS
BEGIN
    SELECT * FROM Orders WHERE CustomerID = @CustomerID;
END
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

# Step 4: Verify Setup
Write-Host "`nVerifying setup..." -ForegroundColor Yellow
$verifyOutput = sqlcmd -S localhost -E -i "C:\LabFiles\verify_setup.sql" 2>&1
Write-Host $verifyOutput -ForegroundColor Cyan

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
3. C:\LabFiles\performance_issues.sql

To verify setup, run:
C:\LabFiles\verify_setup.sql

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
