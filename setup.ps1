# Setup script for SQL Server Performance Tuning Lab
Write-Host "Starting SQL Server 2019 installation and lab setup..." -ForegroundColor Green

# Create directories
New-Item -ItemType Directory -Force -Path "C:\LabFiles"
New-Item -ItemType Directory -Force -Path "C:\SQLData"
New-Item -ItemType Directory -Force -Path "C:\SQLBackup"

# Download and install SQL Server 2019 Developer Edition
Write-Host "Downloading SQL Server 2019 Developer Edition..." -ForegroundColor Yellow
$sqlUrl = "https://download.microsoft.com/download/7/c/1/7c14e92e-bdcb-4f89-b7cf-93543e7112d1/SQLServer2019-DEV-x64-ENU.exe"
$sqlInstaller = "C:\LabFiles\SQLServer2019-DEV.exe"
Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlInstaller

# Extract SQL Server setup files
Write-Host "Extracting SQL Server setup files..." -ForegroundColor Yellow
Start-Process -FilePath $sqlInstaller -ArgumentList "/x:C:\LabFiles\SQLSetup" -Wait

# Create configuration file for unattended installation
$configContent = @"
[OPTIONS]
ACTION="Install"
FEATURES=SQLENGINE,CONN,BC,SDK,SSMS
INSTANCENAME="MSSQLSERVER"
SQLSYSADMINACCOUNTS="BUILTIN\Administrators"
SQLSVCACCOUNT="NT AUTHORITY\SYSTEM"
AGTSVCACCOUNT="NT AUTHORITY\SYSTEM"
SQLSVCSTARTUPTYPE="Automatic"
AGTSVCSTARTUPTYPE="Automatic"
TCPENABLED="1"
NPENABLED="1"
IACCEPTSQLSERVERLICENSETERMS="True"
QUIET="True"
SQLTEMPDBDIR="C:\SQLData"
SQLUSERDBDIR="C:\SQLData"
SQLUSERDBLOGDIR="C:\SQLData"
"@
$configContent | Out-File -FilePath "C:\LabFiles\SQLConfig.ini" -Encoding ASCII

# Install SQL Server
Write-Host "Installing SQL Server 2019 (this will take several minutes)..." -ForegroundColor Yellow
Start-Process -FilePath "C:\LabFiles\SQLSetup\setup.exe" -ArgumentList "/ConfigurationFile=C:\LabFiles\SQLConfig.ini" -Wait

# Download and install SSMS
Write-Host "Downloading SQL Server Management Studio..." -ForegroundColor Yellow
$ssmsUrl = "https://aka.ms/ssmsfullsetup"
$ssmsInstaller = "C:\LabFiles\SSMS-Setup.exe"
Invoke-WebRequest -Uri $ssmsUrl -OutFile $ssmsInstaller

Write-Host "Installing SSMS (this will take several minutes)..." -ForegroundColor Yellow
Start-Process -FilePath $ssmsInstaller -ArgumentList "/install /quiet /norestart" -Wait

# Enable SQL Server Agent
Write-Host "Configuring SQL Server services..." -ForegroundColor Yellow
Set-Service -Name SQLSERVERAGENT -StartupType Automatic
Start-Service -Name SQLSERVERAGENT

# Download database setup scripts
Write-Host "Downloading lab database scripts..." -ForegroundColor Yellow
$scriptUrls = @{
    "create_database.sql" = "https://raw.githubusercontent.com/ps-interactive/lab_performance-tuning-and-automated-maintenance/main/scripts/create_database.sql"
    "populate_data.sql" = "https://raw.githubusercontent.com/ps-interactive/lab_performance-tuning-and-automated-maintenance/main/scripts/populate_data.sql"
    "create_performance_issues.sql" = "https://raw.githubusercontent.com/ps-interactive/lab_performance-tuning-and-automated-maintenance/main/scripts/create_performance_issues.sql"
    "lab_queries.sql" = "https://raw.githubusercontent.com/ps-interactive/lab_performance-tuning-and-automated-maintenance/main/scripts/lab_queries.sql"
    "blocking_scenario.sql" = "https://raw.githubusercontent.com/ps-interactive/lab_performance-tuning-and-automated-maintenance/main/scripts/blocking_scenario.sql"
}

foreach ($script in $scriptUrls.GetEnumerator()) {
    $localPath = "C:\LabFiles\$($script.Key)"
    Invoke-WebRequest -Uri $script.Value -OutFile $localPath
}

# Wait for SQL Server to be fully ready
Write-Host "Waiting for SQL Server to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Execute database setup scripts
Write-Host "Creating CarvedRock database..." -ForegroundColor Yellow
sqlcmd -S localhost -E -i "C:\LabFiles\create_database.sql"

Write-Host "Populating database with sample data..." -ForegroundColor Yellow
sqlcmd -S localhost -E -i "C:\LabFiles\populate_data.sql"

Write-Host "Creating performance issues for lab exercises..." -ForegroundColor Yellow
sqlcmd -S localhost -E -i "C:\LabFiles\create_performance_issues.sql"

# Create desktop shortcuts
Write-Host "Creating desktop shortcuts..." -ForegroundColor Yellow
$desktop = [Environment]::GetFolderPath("Desktop")

# SSMS shortcut
$ssmsPath = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 19\Common7\IDE\Ssms.exe"
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$desktop\SQL Server Management Studio.lnk")
$Shortcut.TargetPath = $ssmsPath
$Shortcut.Save()

# Lab Files shortcut
$Shortcut = $WshShell.CreateShortcut("$desktop\Lab Files.lnk")
$Shortcut.TargetPath = "C:\LabFiles"
$Shortcut.Save()

Write-Host "Setup complete! SQL Server 2019 and the CarvedRock database are ready." -ForegroundColor Green
Write-Host "You can now connect to SQL Server using SSMS with Windows Authentication." -ForegroundColor Green
