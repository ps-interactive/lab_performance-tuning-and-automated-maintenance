# Quick Lab Setup - Downloads SQL files only
Write-Host "Downloading lab SQL files..." -ForegroundColor Green

# Create directories
New-Item -Path "C:\LabScripts" -ItemType Directory -Force | Out-Null
New-Item -Path "C:\SQLBackups" -ItemType Directory -Force | Out-Null

# Download SQL files from GitHub
$base = "https://raw.githubusercontent.com/ps-interactive/lab_performance-tuning-and-automated-maintenance/main"
$files = @(
    "create-database.sql",
    "create-performance-issues.sql",
    "create-blocking-scenario.sql",
    "maintenance-scripts.sql"
)

foreach ($file in $files) {
    $url = "$base/$file"
    $dest = "C:\LabScripts\$file"
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        Write-Host "Downloaded: $file" -ForegroundColor Green
    } catch {
        Write-Host "Failed: $file" -ForegroundColor Red
    }
}

# Create setup script
@'
-- Run each script in order
:r C:\LabScripts\create-database.sql
GO
:r C:\LabScripts\create-performance-issues.sql
GO
:r C:\LabScripts\create-blocking-scenario.sql
GO
:r C:\LabScripts\maintenance-scripts.sql
GO
PRINT 'Setup complete!';
'@ | Out-File -FilePath "C:\LabScripts\00-Setup-Lab.sql" -Encoding UTF8

# Create desktop shortcut
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:Public\Desktop\Lab Scripts.lnk")
$Shortcut.TargetPath = "C:\LabScripts"
$Shortcut.Save()

Write-Host "Setup complete! Files in C:\LabScripts" -ForegroundColor Green
