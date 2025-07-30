# SQL Server Performance Tuning Lab Setup Script
Write-Host "Starting SQL Server lab setup..." -ForegroundColor Green

# Install SQL Server 2019 Developer Edition
Write-Host "Downloading SQL Server 2019..." -ForegroundColor Yellow
$sqlDownloadPath = "C:\SQLServer2019-DEV.exe"
Invoke-WebRequest -Uri "https://download.microsoft.com/download/7/c/1/7c14e92e-bdcb-4f89-b7cf-93543e7112d1/SQLServer2019-DEV-x64-ENU.exe" -OutFile $sqlDownloadPath

# Extract SQL Server setup files
Write-Host "Extracting SQL Server setup files..." -ForegroundColor Yellow
$sqlExtractPath = "C:\SQLServerSetup"
Start-Process -FilePath $sqlDownloadPath -ArgumentList "/u /x:$sqlExtractPath" -Wait

# Install SQL Server silently
Write-Host "Installing SQL Server 2019..." -ForegroundColor Yellow
$installArgs = @(
    "/ConfigurationFile=C:\SQLServerSetup\ConfigurationFile.ini",
    "/Q",
    "/IACCEPTSQLSERVERLICENSETERMS",
    "/ACTION=Install",
    "/FEATURES=SQLENGINE,TOOLS",
    "/INSTANCENAME=MSSQLSERVER",
    "/SQLSYSADMINACCOUNTS=`"BUILTIN\Administrators`"",
    "/AGTSVCSTARTUPTYPE=Automatic"
)

# Create configuration file for SQL Server installation
$configContent = @"
[OPTIONS]
ACTION="Install"
FEATURES=SQLENGINE,TOOLS
INSTANCENAME="MSSQLSERVER"
SQLSYSADMINACCOUNTS="BUILTIN\Administrators"
AGTSVCSTARTUPTYPE="Automatic"
SQLSVCSTARTUPTYPE="Automatic"
TCPENABLED="1"
NPENABLED="1"
IACCEPTSQLSERVERLICENSETERMS="True"
"@
Set-Content -Path "$sqlExtractPath\ConfigurationFile.ini" -Value $configContent

# Run SQL Server setup
Start-Process -FilePath "$sqlExtractPath\Setup.exe" -ArgumentList $installArgs -Wait

# Download and install SSMS
Write-Host "Downloading SQL Server Management Studio..." -ForegroundColor Yellow
$ssmsUrl = "https://aka.ms/ssmsfullsetup"
$ssmsPath = "C:\SSMS-Setup.exe"
Invoke-WebRequest -Uri $ssmsUrl -OutFile $ssmsPath

Write-Host "Installing SSMS..." -ForegroundColor Yellow
Start-Process -FilePath $ssmsPath -ArgumentList "/install", "/quiet", "/norestart" -Wait

# Create CarvedRock database and populate with sample data
Write-Host "Setting up CarvedRock database..." -ForegroundColor Yellow

# Wait for SQL Server to be ready
Start-Sleep -Seconds 30

# Create setup scripts directory
New-Item -Path "C:\LabScripts" -ItemType Directory -Force

# Download database setup scripts from GitHub
$baseUrl = "https://raw.githubusercontent.com/ps-interactive/lab_performance-tuning-and-automated-maintenance/main"
$scripts = @(
    "create-database.sql",
    "create-performance-issues.sql",
    "create-blocking-scenario.sql",
    "maintenance-scripts.sql"
)

foreach ($script in $scripts) {
    Invoke-WebRequest -Uri "$baseUrl/$script" -OutFile "C:\LabScripts\$script"
}

# Execute database setup
sqlcmd -S localhost -E -i "C:\LabScripts\create-database.sql"
sqlcmd -S localhost -E -i "C:\LabScripts\create-performance-issues.sql"

# Enable SQL Server Agent
Set-Service -Name "SQLSERVERAGENT" -StartupType Automatic
Start-Service -Name "SQLSERVERAGENT"

# Create desktop shortcuts
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\SQL Server Management Studio.lnk")
$Shortcut.TargetPath = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 19\Common7\IDE\Ssms.exe"
$Shortcut.Save()

$Shortcut2 = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Lab Scripts.lnk")
$Shortcut2.TargetPath = "C:\LabScripts"
$Shortcut2.Save()

Write-Host "Lab setup completed successfully!" -ForegroundColor Green
Write-Host "You can now connect to SQL Server using SSMS with Windows Authentication" -ForegroundColor Cyan
