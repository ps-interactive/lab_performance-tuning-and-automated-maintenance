# SQL Server Lab Setup - Downloads setup script from GitHub
Write-Host "Setting up SQL Server Lab Environment..." -ForegroundColor Green

# Create directories
$labPath = "C:\LabScripts"
$backupPath = "C:\SQLBackups"

New-Item -Path $labPath -ItemType Directory -Force | Out-Null
New-Item -Path $backupPath -ItemType Directory -Force | Out-Null

# Download the setup script from GitHub
$url = "https://raw.githubusercontent.com/ps-interactive/lab_performance-tuning-and-automated-maintenance/main/00-Setup-Lab.sql"
$destination = Join-Path $labPath "00-Setup-Lab.sql"

try {
    Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
    Write-Host "Setup script downloaded successfully to C:\LabScripts\00-Setup-Lab.sql" -ForegroundColor Green
} catch {
    Write-Host "Download failed. Please download manually from GitHub." -ForegroundColor Red
}

# Create desktop shortcuts
$WshShell = New-Object -ComObject WScript.Shell

# Lab Scripts folder shortcut
$Shortcut1 = $WshShell.CreateShortcut("$env:Public\Desktop\Lab Scripts.lnk")
$Shortcut1.TargetPath = $labPath
$Shortcut1.Save()

# SSMS shortcut
$ssmsPath = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 18\Common7\IDE\Ssms.exe"
if (Test-Path $ssmsPath) {
    $Shortcut2 = $WshShell.CreateShortcut("$env:Public\Desktop\SSMS.lnk")
    $Shortcut2.TargetPath = $ssmsPath
    $Shortcut2.Save()
}

Write-Host "Setup complete! Open SSMS and run C:\LabScripts\00-Setup-Lab.sql" -ForegroundColor Green
