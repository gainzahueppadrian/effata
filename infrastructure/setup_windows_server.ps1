# PowerShell script to setup infrastructure on Windows Server 2022
# This script installs Docker and prepares the environment for MT5

Write-Output "Starting Infrastructure Setup..."

# 1. Install Docker
Write-Output "Installing Docker Provider..."
Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Import-PackageProvider -Name DockerMsftProvider -Force

Write-Output "Installing Docker Engine..."
Install-Package -Name docker -ProviderName DockerMsftProvider -Force

# 2. Start Docker Service
Start-Service docker
Write-Output "Docker Service Started."

# 3. Pull Python Image for Orchestrator
Write-Output "Pulling Python Image..."
docker pull python:3.9-windowsservercore-ltsc2022

# 4. Install Playwright Dependencies (Browsers)
# Note: This usually runs inside the container, but if running locally:
Write-Output "Installing Playwright Browsers (if running locally)..."
try {
    pip install playwright
    python -m playwright install
} catch {
    Write-Output "Playwright install skipped (Python might not be in PATH)"
}

# 5. Create Directory Structure
New-Item -ItemType Directory -Force -Path "C:\EffataTrading"
New-Item -ItemType Directory -Force -Path "C:\EffataTrading\Logs"

# 6. Note on MT5 Installation
Write-Output "NOTE: MetaTrader 5 Terminal must be installed manually or via silent installer."
Write-Output "Exness/ICMarkets installers do not support headless installation easily."
Write-Output "Please copy the 'EFFATA_ORCHESTRATOR' EA to MQL5/Experts folder after installation."

Write-Output "Setup Complete."
