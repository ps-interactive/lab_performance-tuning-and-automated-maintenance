# SQL Server Performance Tuning Lab Setup Script - Simplified
Write-Host "Starting SQL Server lab setup..." -ForegroundColor Green

# Create lab directories
New-Item -Path "C:\LabScripts" -ItemType Directory -Force
New-Item -Path "C:\SQLBackups" -ItemType Directory -Force

# Create a simple test script to verify setup
$testScript = @"
Write-Host 'Lab setup script executed successfully!' -ForegroundColor Green
Write-Host 'SQL Server needs to be installed manually for this lab.' -ForegroundColor Yellow
Write-Host 'Please install SQL Server 2019 Developer Edition and SSMS.' -ForegroundColor Yellow
"@

Set-Content -Path "C:\LabScripts\test-setup.ps1" -Value $testScript

# Create desktop shortcuts to lab folders
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:Public\Desktop\Lab Scripts.lnk")
$Shortcut.TargetPath = "C:\LabScripts"
$Shortcut.Save()

$Shortcut2 = $WshShell.CreateShortcut("$env:Public\Desktop\SQL Backups.lnk")
$Shortcut2.TargetPath = "C:\SQLBackups"
$Shortcut2.Save()

# Download SQL Server and SSMS installers
Write-Host "Downloading SQL Server 2019 installer..." -ForegroundColor Yellow
$sqlInstallerUrl = "https://go.microsoft.com/fwlink/?linkid=866662"
$sqlInstallerPath = "C:\LabScripts\SQL2019-SSEI-Dev.exe"

try {
    Invoke-WebRequest -Uri $sqlInstallerUrl -OutFile $sqlInstallerPath -UseBasicParsing
    Write-Host "SQL Server installer downloaded to: $sqlInstallerPath" -ForegroundColor Green
} catch {
    Write-Host "Failed to download SQL Server installer: $_" -ForegroundColor Red
}

Write-Host "Downloading SSMS installer..." -ForegroundColor Yellow
$ssmsUrl = "https://aka.ms/ssmsfullsetup"
$ssmsPath = "C:\LabScripts\SSMS-Setup.exe"

try {
    Invoke-WebRequest -Uri $ssmsUrl -OutFile $ssmsPath -UseBasicParsing
    Write-Host "SSMS installer downloaded to: $ssmsPath" -ForegroundColor Green
} catch {
    Write-Host "Failed to download SSMS installer: $_" -ForegroundColor Red
}

# Create a simple setup instructions file
$instructions = @"
SQL Server Lab Setup Instructions
==================================

1. Install SQL Server 2019:
   - Run C:\LabScripts\SQL2019-SSEI-Dev.exe
   - Choose "Basic" installation
   - Accept the license terms
   - Wait for installation to complete

2. Install SQL Server Management Studio:
   - Run C:\LabScripts\SSMS-Setup.exe
   - Follow the installation wizard

3. After installation:
   - Open SSMS
   - Connect to localhost using Windows Authentication
   - The lab scripts will be available in C:\LabScripts

Lab scripts will be downloaded after SQL Server is installed.
"@

Set-Content -Path "C:\LabScripts\Setup-Instructions.txt" -Value $instructions

# Open the instructions file
Start-Process notepad.exe "C:\LabScripts\Setup-Instructions.txt"

Write-Host "Initial setup completed!" -ForegroundColor Green
Write-Host "Please follow the instructions in the opened file to complete SQL Server installation." -ForegroundColor Yellow
