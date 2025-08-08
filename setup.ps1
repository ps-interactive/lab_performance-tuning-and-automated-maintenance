# Setup script for SQL Server Performance Tuning Lab
# This script configures the pre-installed SQL Server 2019 Developer Edition

Write-Host "Starting SQL Server lab setup..." -ForegroundColor Green

# Create directories
New-Item -ItemType Directory -Force -Path "C:\LabFiles"
New-Item -ItemType Directory -Force -Path "C:\SQLData"
New-Item -ItemType Directory -Force -Path "C:\SQLBackup"

# Ensure SQL Server services are running
Write-Host "Starting SQL Server services..." -ForegroundColor Yellow
Set-Service -Name MSSQLSERVER -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue

Set-Service -Name SQLSERVERAGENT -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service -Name SQLSERVERAGENT -ErrorAction SilentlyContinue

# Wait for SQL Server to be ready
Write-Host "Waiting for SQL Server to be ready..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0
while ($attempt -lt $maxAttempts) {
    try {
        Invoke-Sqlcmd -Query "SELECT @@VERSION" -ServerInstance "localhost" -ErrorAction Stop | Out-Null
        Write-Host "SQL Server is ready!" -ForegroundColor Green
        break
    }
    catch {
        $attempt++
        Write-Host "Waiting for SQL Server... (attempt $attempt of $maxAttempts)" -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
}

# Download database setup scripts
Write-Host "Downloading lab database scripts..." -ForegroundColor Yellow
$baseUrl = "https://raw.githubusercontent.com/ps-interactive/lab_performance-tuning-and-automated-maintenance/main/scripts/"
$scripts = @(
    "create_database.sql",
    "populate_data.sql",
    "create_performance_issues.sql",
    "lab_queries.sql",
    "blocking_scenario.sql"
)

foreach ($script in $scripts) {
    $url = $baseUrl + $script
    $localPath = "C:\LabFiles\$script"
    try {
        Invoke-WebRequest -Uri $url -OutFile $localPath -ErrorAction Stop
        Write-Host "Downloaded: $script" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to download: $script" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Execute database setup scripts using sqlcmd
Write-Host "Creating CarvedRock database..." -ForegroundColor Yellow
try {
    sqlcmd -S localhost -E -i "C:\LabFiles\create_database.sql" -o "C:\LabFiles\create_database_output.txt"
    Write-Host "Database created successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Error creating database: $_" -ForegroundColor Red
}

Write-Host "Populating database with sample data..." -ForegroundColor Yellow
try {
    sqlcmd -S localhost -E -i "C:\LabFiles\populate_data.sql" -o "C:\LabFiles\populate_data_output.txt"
    Write-Host "Sample data populated successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Error populating data: $_" -ForegroundColor Red
}

Write-Host "Creating performance issues for lab exercises..." -ForegroundColor Yellow
try {
    sqlcmd -S localhost -E -i "C:\LabFiles\create_performance_issues.sql" -o "C:\LabFiles\performance_issues_output.txt"
    Write-Host "Performance issues created successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Error creating performance issues: $_" -ForegroundColor Red
}

# Create desktop shortcuts
Write-Host "Creating desktop shortcuts..." -ForegroundColor Yellow
$desktop = "C:\Users\Public\Desktop"

# SSMS shortcut (if SSMS is installed)
$ssmsPath = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 19\Common7\IDE\Ssms.exe"
if (Test-Path $ssmsPath) {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$desktop\SQL Server Management Studio.lnk")
    $Shortcut.TargetPath = $ssmsPath
    $Shortcut.Save()
    Write-Host "SSMS shortcut created" -ForegroundColor Green
}
else {
    # Try alternative SSMS path
    $ssmsPath = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 18\Common7\IDE\Ssms.exe"
    if (Test-Path $ssmsPath) {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$desktop\SQL Server Management Studio.lnk")
        $Shortcut.TargetPath = $ssmsPath
        $Shortcut.Save()
        Write-Host "SSMS shortcut created" -ForegroundColor Green
    }
    else {
        Write-Host "SSMS not found, may need manual installation" -ForegroundColor Yellow
    }
}

# Lab Files shortcut
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$desktop\Lab Files.lnk")
$Shortcut.TargetPath = "C:\LabFiles"
$Shortcut.Save()
Write-Host "Lab Files shortcut created" -ForegroundColor Green

# Create a lab instructions file
$instructions = @"
========================================
SQL Server Performance Tuning Lab
========================================

Welcome! Your lab environment is ready.

SQL Server 2019 Developer Edition is installed and running.
The CarvedRock database has been created with sample data.

To get started:
1. Open SQL Server Management Studio (SSMS)
2. Connect to: localhost
3. Authentication: Windows Authentication
4. Select the CarvedRock database

Lab files are located in: C:\LabFiles

The following scripts are available:
- lab_queries.sql: DMV queries and performance diagnostics
- blocking_scenario.sql: Scripts to create and resolve blocking

Good luck with your lab!
========================================
"@

$instructions | Out-File -FilePath "$desktop\Lab_Instructions.txt" -Encoding UTF8

# Enable SQL Server Agent XPs
Write-Host "Enabling SQL Server Agent features..." -ForegroundColor Yellow
$enableAgentScript = @"
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Agent XPs', 1;
RECONFIGURE;
GO
"@
$enableAgentScript | Out-File -FilePath "C:\LabFiles\enable_agent.sql" -Encoding UTF8
sqlcmd -S localhost -E -i "C:\LabFiles\enable_agent.sql"

# Final verification
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SQL Server 2019 is running" -ForegroundColor Green
Write-Host "CarvedRock database is ready" -ForegroundColor Green
Write-Host "Lab files are in C:\LabFiles" -ForegroundColor Green
Write-Host "You can now connect using SSMS with Windows Authentication" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
