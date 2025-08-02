# SQL Server Lab Setup Script 
Write-Host "SQL Server Lab Setup - Downloading SQL Files" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

# Ensure script can run
Set-ExecutionPolicy Bypass -Scope Process -Force

# Create directories
$labPath = "C:\LabScripts"
$backupPath = "C:\SQLBackups"

if (!(Test-Path $labPath)) {
    New-Item -Path $labPath -ItemType Directory -Force | Out-Null
}
if (!(Test-Path $backupPath)) {
    New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
}

# Define the SQL files to download
$baseUrl = "https://raw.githubusercontent.com/ps-interactive/lab_performance-tuning-and-automated-maintenance/main"
$files = @(
    "create-database.sql",
    "create-performance-issues.sql", 
    "create-blocking-scenario.sql",
    "maintenance-scripts.sql"
)

# Download each SQL file
Write-Host "`nDownloading SQL files from GitHub..." -ForegroundColor Yellow
$downloadSuccess = $true

foreach ($file in $files) {
    Write-Host "Downloading $file..." -NoNewline
    $url = "$baseUrl/$file"
    $destination = Join-Path $labPath $file
    
    try {
        # Use System.Net.WebClient for more reliable downloads
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $destination)
        
        if (Test-Path $destination) {
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Host " FAILED" -ForegroundColor Red
            $downloadSuccess = $false
        }
    } catch {
        Write-Host " ERROR: $_" -ForegroundColor Red
        $downloadSuccess = $false
    }
}

# Create the main setup script that combines all files
Write-Host "`nCreating main setup script..." -ForegroundColor Yellow

$setupContent = @'
-- SQL Server Performance Tuning Lab Setup
-- This script runs all the individual SQL files to set up the lab

PRINT '================================================';
PRINT 'SQL Server Performance Tuning Lab Setup';
PRINT '================================================';
PRINT '';

-- Enable SQLCMD Mode in SSMS: Query menu > SQLCMD Mode
-- Then run this script

:r C:\LabScripts\create-database.sql
GO

:r C:\LabScripts\create-performance-issues.sql
GO

:r C:\LabScripts\create-blocking-scenario.sql
GO

:r C:\LabScripts\maintenance-scripts.sql
GO

PRINT '';
PRINT '================================================';
PRINT 'Lab setup completed successfully!';
PRINT '================================================';
'@

$setupPath = Join-Path $labPath "00-Setup-Lab.sql"
Set-Content -Path $setupPath -Value $setupContent
Write-Host "Created 00-Setup-Lab.sql" -ForegroundColor Green

# Create desktop shortcuts
Write-Host "`nCreating desktop shortcuts..." -ForegroundColor Yellow

$WshShell = New-Object -ComObject WScript.Shell

# Lab Scripts folder shortcut
$Shortcut1 = $WshShell.CreateShortcut("$env:Public\Desktop\Lab Scripts.lnk")
$Shortcut1.TargetPath = $labPath
$Shortcut1.Save()

# SSMS shortcut (if it exists)
$ssmsPath = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 18\Common7\IDE\Ssms.exe"
if (Test-Path $ssmsPath) {
    $Shortcut2 = $WshShell.CreateShortcut("$env:Public\Desktop\SSMS.lnk")
    $Shortcut2.TargetPath = $ssmsPath
    $Shortcut2.Save()
}

# Create instructions file
$instructions = @"
SQL Server Performance Tuning Lab Instructions
==============================================

Files have been downloaded to: C:\LabScripts\

Files you should see:
- 00-Setup-Lab.sql (main setup script)
- create-database.sql
- create-performance-issues.sql
- create-blocking-scenario.sql
- maintenance-scripts.sql

To set up the lab:
1. Open SQL Server Management Studio (SSMS)
2. Connect to server: . (period) or localhost
3. Open C:\LabScripts\00-Setup-Lab.sql
4. Enable SQLCMD Mode: Query menu > SQLCMD Mode
5. Execute the script (F5)

If SQLCMD mode doesn't work:
- Run each .sql file individually in order:
  1. create-database.sql
  2. create-performance-issues.sql
  3. create-blocking-scenario.sql
  4. maintenance-scripts.sql

Troubleshooting:
- Server name must be . (period) or localhost
- Do NOT use sqlLabVM as server name
- If certificate error: Options > Connection Properties > Trust server certificate
"@

$instructionsPath = Join-Path $labPath "README.txt"
Set-Content -Path $instructionsPath -Value $instructions

# Display results
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan

# Check what files are actually in the directory
Write-Host "`nFiles in C:\LabScripts:" -ForegroundColor Yellow
Get-ChildItem $labPath | Format-Table Name, Length, LastWriteTime

if ($downloadSuccess) {
    Write-Host "`nAll files downloaded successfully!" -ForegroundColor Green
    Write-Host "Opening instructions..." -ForegroundColor Yellow
    Start-Process notepad.exe $instructionsPath
} else {
    Write-Host "`nSome files failed to download!" -ForegroundColor Red
    Write-Host "Check your internet connection and try again." -ForegroundColor Yellow
    
    # Try alternative download method
    Write-Host "`nTrying alternative download method..." -ForegroundColor Yellow
    
    foreach ($file in $files) {
        $url = "$baseUrl/$file"
        $destination = Join-Path $labPath $file
        
        if (!(Test-Path $destination)) {
            Write-Host "Attempting to download $file with Invoke-WebRequest..." -NoNewline
            try {
                Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
                Write-Host " OK" -ForegroundColor Green
            } catch {
                Write-Host " FAILED" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
