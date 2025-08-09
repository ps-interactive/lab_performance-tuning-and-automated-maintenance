# Quick SQL Server Lab Setup - Downloads single setup script
Write-Host "Setting up SQL Server Lab Environment..." -ForegroundColor Green

# Create directories
$labPath = "C:\LabScripts"
$backupPath = "C:\SQLBackups"

New-Item -Path $labPath -ItemType Directory -Force | Out-Null
New-Item -Path $backupPath -ItemType Directory -Force | Out-Null

# Download the complete setup script from GitHub
$url = "https://raw.githubusercontent.com/ps-interactive/lab_performance-tuning-and-automated-maintenance/main/00-Setup-Lab.sql"
$destination = Join-Path $labPath "00-Setup-Lab.sql"

try {
    Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
    Write-Host "Setup script downloaded successfully" -ForegroundColor Green
    Write-Host "Location: $destination" -ForegroundColor Yellow
} catch {
    Write-Host "Failed to download from GitHub: $_" -ForegroundColor Red
    Write-Host "Creating local copy of setup script..." -ForegroundColor Yellow
    
    # If GitHub is unavailable, create the script locally
    # This is a fallback - the full script content would go here
    $fallbackContent = @"
-- Lab Setup Script
-- This is a fallback if GitHub is unreachable
-- The full 00-Setup-Lab.sql content would be embedded here
PRINT 'Please download the setup script from GitHub manually';
"@
    Set-Content -Path $destination -Value $fallbackContent
}

# Create desktop shortcuts
try {
    $WshShell = New-Object -ComObject WScript.Shell
    
    # Lab Scripts folder shortcut
    $Shortcut1 = $WshShell.CreateShortcut("$env:Public\Desktop\Lab Scripts.lnk")
    $Shortcut1.TargetPath = $labPath
    $Shortcut1.IconLocation = "shell32.dll,3"
    $Shortcut1.Save()
    Write-Host "Created Lab Scripts shortcut on desktop" -ForegroundColor Green
    
    # SSMS shortcut (multiple possible locations)
    $ssmsPaths = @(
        "${env:ProgramFiles(x86)}\Microsoft SQL Server Management Studio 18\Common7\IDE\Ssms.exe",
        "${env:ProgramFiles(x86)}\Microsoft SQL Server Management Studio 19\Common7\IDE\Ssms.exe",
        "${env:ProgramFiles}\Microsoft SQL Server Management Studio 18\Common7\IDE\Ssms.exe",
        "${env:ProgramFiles}\Microsoft SQL Server Management Studio 19\Common7\IDE\Ssms.exe"
    )
    
    foreach ($ssmsPath in $ssmsPaths) {
        if (Test-Path $ssmsPath) {
            $Shortcut2 = $WshShell.CreateShortcut("$env:Public\Desktop\SSMS.lnk")
            $Shortcut2.TargetPath = $ssmsPath
            $Shortcut2.Save()
            Write-Host "Created SSMS shortcut on desktop" -ForegroundColor Green
            break
        }
    }
} catch {
    Write-Host "Could not create desktop shortcuts: $_" -ForegroundColor Yellow
}

# Display completion message
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Lab Environment Setup Complete!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Open SSMS from the desktop shortcut" -ForegroundColor White
Write-Host "2. Connect to server: . (period) or localhost" -ForegroundColor White
Write-Host "3. Open file: $destination" -ForegroundColor White
Write-Host "4. Execute the script (F5) to create the database" -ForegroundColor White
Write-Host ""
Write-Host "Setup script location: $destination" -ForegroundColor Green
Write-Host "Backup folder: $backupPath" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
