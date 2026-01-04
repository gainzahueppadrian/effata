# PowerShell script to deploy the trading infrastructure on Windows Server 2022 (AWS LightSail/EC2)

Write-Host "Starting EFFATA HFT Trading Infrastructure Deployment..."

# 1. Install Chocolatey (Package Manager)
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# 2. Install Docker Desktop & Python
Write-Host "Installing Docker and Python..."
choco install docker-desktop -y
choco install python --version=3.11 -y
choco install git -y

# 3. Install Playwright Browsers (for Agentic AI)
Write-Host "Installing Playwright..."
& "C:\Python311\python.exe" -m pip install playwright
& "C:\Python311\python.exe" -m playwright install

# 4. Install PostgreSQL
Write-Host "Installing PostgreSQL..."
choco install postgresql -y

# 5. Setup Directory Structure
$BaseDir = "C:\EffataTrading"
New-Item -ItemType Directory -Force -Path "$BaseDir\Logs"
New-Item -ItemType Directory -Force -Path "$BaseDir\Data"
New-Item -ItemType Directory -Force -Path "$BaseDir\Experts"

# 6. Download MetaTrader 5 (Exness Example)
$MT5Url = "https://download.mql5.com/cdn/web/17926/mt5/exness5setup.exe" # Example URL
$InstallerPath = "$BaseDir\mt5setup.exe"
Write-Host "Downloading MetaTrader 5..."
Invoke-WebRequest -Uri $MT5Url -OutFile $InstallerPath

# 7. Install MetaTrader 5 (Silent Install attempt - /auto)
# Note: MT5 installers often require GUI interaction or specific config files.
# For pure automation, usually we copy a pre-installed folder or use auto-it.
# Trying standard /auto switch.
Write-Host "Installing MetaTrader 5..."
Start-Process -FilePath $InstallerPath -ArgumentList "/auto" -Wait

# 8. Setup Python Environment
Write-Host "Setting up Python Environment..."
& "C:\Python311\python.exe" -m pip install -r "$BaseDir\requirements.txt"

# 9. Clone Repository (Placeholder)
# Write-Host "Cloning Repository..."
# git clone https://github.com/your-repo/effata-hft.git $BaseDir

Write-Host "Deployment Complete. Please configure config.py and start agentic_orchestrator.py."
