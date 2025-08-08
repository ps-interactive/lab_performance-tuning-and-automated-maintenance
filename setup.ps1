# Setup script for SQL Server Performance Tuning Lab
# This script configures the pre-installed SQL Server 2019 Developer Edition

$ErrorActionPreference = "Continue"
$logFile = "C:\LabFiles\setup_log.txt"

# Create directories
New-Item -ItemType Directory -Force -Path "C:\LabFiles"
New-Item -ItemType Directory -Force -Path "C:\SQLData"
New-Item -ItemType Directory -Force -Path "C:\SQLBackup"

# Start logging
Start-Transcript -Path $logFile -Force

Write-Host "Starting SQL Server lab setup at $(Get-Date)" -ForegroundColor Green

# Ensure SQL Server services are running
Write-Host "Checking SQL Server services..." -ForegroundColor Yellow
$sqlService = Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue
if ($sqlService) {
    if ($sqlService.Status -ne 'Running') {
        Write-Host "Starting SQL Server service..." -ForegroundColor Yellow
        Start-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 10
    }
    Write-Host "SQL Server service status: $($sqlService.Status)" -ForegroundColor Green
} else {
    Write-Host "SQL Server service not found!" -ForegroundColor Red
}

$agentService = Get-Service -Name SQLSERVERAGENT -ErrorAction SilentlyContinue
if ($agentService) {
    Set-Service -Name SQLSERVERAGENT -StartupType Automatic -ErrorAction SilentlyContinue
    if ($agentService.Status -ne 'Running') {
        Start-Service -Name SQLSERVERAGENT -ErrorAction SilentlyContinue
    }
    Write-Host "SQL Agent service status: $($agentService.Status)" -ForegroundColor Green
}

# Wait for SQL Server to be ready
Write-Host "Waiting for SQL Server to be ready..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0
$sqlReady = $false

while ($attempt -lt $maxAttempts -and -not $sqlReady) {
    try {
        $result = Invoke-Sqlcmd -Query "SELECT @@VERSION" -ServerInstance "localhost" -ErrorAction Stop
        Write-Host "SQL Server is ready!" -ForegroundColor Green
        Write-Host "SQL Version: $($result.Column1.Substring(0, 50))..." -ForegroundColor Cyan
        $sqlReady = $true
    }
    catch {
        $attempt++
        Write-Host "Waiting for SQL Server... (attempt $attempt of $maxAttempts)" -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
}

if (-not $sqlReady) {
    Write-Host "SQL Server did not become ready. Trying to continue anyway..." -ForegroundColor Red
}

# Create the database setup scripts inline (more reliable than downloading)
Write-Host "Creating database setup scripts..." -ForegroundColor Yellow

# Create Database Script
$createDbScript = @'
-- Create CarvedRock Database
USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'CarvedRock')
BEGIN
    ALTER DATABASE CarvedRock SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CarvedRock;
END
GO

CREATE DATABASE CarvedRock
ON PRIMARY 
(
    NAME = N'CarvedRock',
    FILENAME = N'C:\SQLData\CarvedRock.mdf',
    SIZE = 100MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = 10MB
)
LOG ON 
(
    NAME = N'CarvedRock_log',
    FILENAME = N'C:\SQLData\CarvedRock_log.ldf',
    SIZE = 50MB,
    MAXSIZE = 2048GB,
    FILEGROWTH = 10MB
);
GO

ALTER DATABASE CarvedRock SET RECOVERY SIMPLE;
GO

USE CarvedRock;
GO

-- Create tables
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
    CategoryID INT FOREIGN KEY REFERENCES Categories(CategoryID),
    Price DECIMAL(10,2) NOT NULL,
    StockQuantity INT NOT NULL DEFAULT 0,
    Description NVARCHAR(500),
    CreatedDate DATETIME DEFAULT GETDATE(),
    ModifiedDate DATETIME DEFAULT GETDATE()
);
GO

CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT FOREIGN KEY REFERENCES Customers(CustomerID),
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
    OrderID INT FOREIGN KEY REFERENCES Orders(OrderID),
    ProductID INT FOREIGN KEY REFERENCES Products(ProductID),
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    Discount DECIMAL(5,2) DEFAULT 0,
    TotalPrice AS (Quantity * UnitPrice * (1 - Discount/100)) PERSISTED
);
GO

PRINT 'CarvedRock database created successfully!';
GO
'@

$createDbScript | Out-File -FilePath "C:\LabFiles\create_database.sql" -Encoding UTF8

# Populate Data Script (simplified version)
$populateScript = @'
USE CarvedRock;
GO

-- Insert Categories
INSERT INTO Categories (CategoryName, Description) VALUES
('Climbing Gear', 'Equipment for rock climbing'),
('Hiking Equipment', 'Gear for hiking'),
('Camping Supplies', 'Tents and camping accessories'),
('Footwear', 'Outdoor footwear'),
('Clothing', 'Outdoor apparel');
GO

-- Insert sample Products
DECLARE @i INT = 1;
WHILE @i <= 100
BEGIN
    INSERT INTO Products (ProductName, CategoryID, Price, StockQuantity, Description)
    VALUES (
        'Product ' + CAST(@i AS NVARCHAR(10)),
        ((@i % 5) + 1),
        CAST((RAND() * 500 + 10) AS DECIMAL(10,2)),
        CAST((RAND() * 100 + 10) AS INT),
        'Description for product ' + CAST(@i AS NVARCHAR(10))
    );
    SET @i = @i + 1;
END
GO

-- Insert sample Customers
DECLARE @j INT = 1;
WHILE @j <= 1000
BEGIN
    INSERT INTO Customers (FirstName, LastName, Email, Phone, Address, City, State, ZipCode, Country)
    VALUES (
        'FirstName' + CAST(@j AS NVARCHAR(10)),
        'LastName' + CAST(@j AS NVARCHAR(10)),
        'customer' + CAST(@j AS NVARCHAR(10)) + '@example.com',
        '555-' + RIGHT('0000' + CAST(@j AS NVARCHAR(4)), 4),
        CAST(@j AS NVARCHAR(10)) + ' Main Street',
        CASE WHEN @j % 3 = 0 THEN 'Denver'
             WHEN @j % 3 = 1 THEN 'Boulder'
             ELSE 'Seattle' END,
        CASE WHEN @j % 3 = 0 THEN 'CO'
             WHEN @j % 3 = 1 THEN 'CO'
             ELSE 'WA' END,
        '12345',
        'USA'
    );
    SET @j = @j + 1;
END
GO

-- Insert sample Orders
DECLARE @k INT = 1;
WHILE @k <= 5000
BEGIN
    INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, OrderStatus, ShippingAddress, ShippingCity, ShippingState, ShippingZipCode, ShippingCountry)
    VALUES (
        CAST((RAND() * 999 + 1) AS INT),
        DATEADD(DAY, -CAST(RAND() * 365 AS INT), GETDATE()),
        CAST((RAND() * 1000 + 10) AS DECIMAL(10,2)),
        'Completed',
        CAST(@k AS NVARCHAR(10)) + ' Shipping Street',
        'Denver',
        'CO',
        '12345',
        'USA'
    );
    SET @k = @k + 1;
END
GO

PRINT 'Sample data populated successfully!';
GO
'@

$populateScript | Out-File -FilePath "C:\LabFiles\populate_data.sql" -Encoding UTF8

# Performance Issues Script
$perfIssuesScript = @'
USE CarvedRock;
GO

-- Create missing index scenarios by dropping indexes
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Orders_CustomerID')
    DROP INDEX IX_Orders_CustomerID ON Orders;
GO

-- Create fragmented index
CREATE NONCLUSTERED INDEX IX_Customers_Email 
ON Customers(Email) 
WITH (FILLFACTOR = 50);
GO

-- Create inefficient stored procedure
CREATE OR ALTER PROCEDURE sp_GetCustomerOrders
    @Email NVARCHAR(100)
AS
BEGIN
    SELECT o.*, c.FirstName, c.LastName
    FROM Orders o
    INNER JOIN Customers c ON o.CustomerID = c.CustomerID
    WHERE c.Email = @Email;
END
GO

PRINT 'Performance issues created for lab exercises';
GO
'@

$perfIssuesScript | Out-File -FilePath "C:\LabFiles\create_performance_issues.sql" -Encoding UTF8

# Lab Queries Script
$labQueriesScript = @'
-- DMV Query to find expensive queries
USE CarvedRock;
GO

SELECT TOP 10
    qs.total_worker_time/qs.execution_count AS avg_cpu_time,
    qs.execution_count,
    SUBSTRING(st.text, 1, 100) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY avg_cpu_time DESC;
GO
'@

$labQueriesScript | Out-File -FilePath "C:\LabFiles\lab_queries.sql" -Encoding UTF8

# Now execute the scripts
Write-Host "Creating CarvedRock database..." -ForegroundColor Yellow
try {
    sqlcmd -S localhost -E -i "C:\LabFiles\create_database.sql" -o "C:\LabFiles\create_output.txt" 2>&1
    Write-Host "Database creation completed" -ForegroundColor Green
    Get-Content "C:\LabFiles\create_output.txt" | Select-Object -Last 5
}
catch {
    Write-Host "Error creating database: $_" -ForegroundColor Red
}

Write-Host "Populating sample data..." -ForegroundColor Yellow
try {
    sqlcmd -S localhost -E -i "C:\LabFiles\populate_data.sql" -o "C:\LabFiles\populate_output.txt" 2>&1
    Write-Host "Data population completed" -ForegroundColor Green
    Get-Content "C:\LabFiles\populate_output.txt" | Select-Object -Last 5
}
catch {
    Write-Host "Error populating data: $_" -ForegroundColor Red
}

Write-Host "Creating performance issues..." -ForegroundColor Yellow
try {
    sqlcmd -S localhost -E -i "C:\LabFiles\create_performance_issues.sql" -o "C:\LabFiles\perf_output.txt" 2>&1
    Write-Host "Performance issues created" -ForegroundColor Green
}
catch {
    Write-Host "Error creating performance issues: $_" -ForegroundColor Red
}

# Verify database was created
Write-Host "Verifying database creation..." -ForegroundColor Yellow
try {
    $dbCheck = Invoke-Sqlcmd -Query "SELECT name FROM sys.databases WHERE name = 'CarvedRock'" -ServerInstance "localhost" -ErrorAction Stop
    if ($dbCheck) {
        Write-Host "SUCCESS: CarvedRock database exists!" -ForegroundColor Green
        
        # Get table count
        $tableCount = Invoke-Sqlcmd -Query "SELECT COUNT(*) as TableCount FROM CarvedRock.sys.tables" -ServerInstance "localhost"
        Write-Host "Database contains $($tableCount.TableCount) tables" -ForegroundColor Green
        
        # Get row counts
        $customerCount = Invoke-Sqlcmd -Query "SELECT COUNT(*) as Count FROM CarvedRock.dbo.Customers" -ServerInstance "localhost"
        $orderCount = Invoke-Sqlcmd -Query "SELECT COUNT(*) as Count FROM CarvedRock.dbo.Orders" -ServerInstance "localhost"
        Write-Host "Customers: $($customerCount.Count)" -ForegroundColor Green
        Write-Host "Orders: $($orderCount.Count)" -ForegroundColor Green
    }
    else {
        Write-Host "ERROR: CarvedRock database was not created!" -ForegroundColor Red
    }
}
catch {
    Write-Host "Error verifying database: $_" -ForegroundColor Red
}

# Create desktop shortcuts
Write-Host "Creating desktop shortcuts..." -ForegroundColor Yellow
$desktops = @(
    "C:\Users\Public\Desktop",
    "C:\Users\cloud_user\Desktop",
    "C:\Users\Default\Desktop"
)

foreach ($desktop in $desktops) {
    if (Test-Path $desktop) {
        # Lab Files shortcut
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$desktop\Lab Files.lnk")
        $Shortcut.TargetPath = "C:\LabFiles"
        $Shortcut.Save()
        
        # Lab Instructions
        $instructions = @"
SQL Server Performance Tuning Lab
==================================
Database: CarvedRock
Server: localhost
Auth: Windows Authentication

Check logs in C:\LabFiles\setup_log.txt
"@
        $instructions | Out-File -FilePath "$desktop\Lab_Instructions.txt" -Encoding UTF8
        Write-Host "Created shortcuts in $desktop" -ForegroundColor Green
    }
}

# Enable SQL Agent
Write-Host "Enabling SQL Server Agent..." -ForegroundColor Yellow
$agentScript = @"
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Agent XPs', 1;
RECONFIGURE;
"@
try {
    Invoke-Sqlcmd -Query $agentScript -ServerInstance "localhost" -ErrorAction Stop
    Write-Host "SQL Server Agent enabled" -ForegroundColor Green
}
catch {
    Write-Host "Could not enable SQL Agent: $_" -ForegroundColor Yellow
}

Stop-Transcript

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "Check log file: C:\LabFiles\setup_log.txt" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan
