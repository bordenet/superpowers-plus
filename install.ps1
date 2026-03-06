<# 
.SYNOPSIS
    PowerShell wrapper for superpowers-plus installer.
    
.DESCRIPTION
    This script detects WSL and runs install.sh through it.
    If WSL is not installed, provides installation guidance.
    
.EXAMPLE
    .\install.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "superpowers-plus Installer (PowerShell Wrapper)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check if WSL is available
$wslInstalled = $false
try {
    $wslVersion = wsl --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        $wslInstalled = $true
    }
} catch {
    $wslInstalled = $false
}

if (-not $wslInstalled) {
    Write-Host "ERROR: WSL (Windows Subsystem for Linux) is not installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "This installer requires WSL to run." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To install WSL:" -ForegroundColor White
    Write-Host "  1. Open PowerShell as Administrator" -ForegroundColor Gray
    Write-Host "  2. Run: wsl --install" -ForegroundColor Cyan
    Write-Host "  3. Restart your computer" -ForegroundColor Gray
    Write-Host "  4. Run this script again" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Documentation: https://learn.microsoft.com/en-us/windows/wsl/install" -ForegroundColor Blue
    Write-Host ""
    exit 1
}

Write-Host "WSL detected." -ForegroundColor Green

# Get the script directory and convert to WSL path
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$wslPath = $scriptDir -replace '\\', '/' -replace '^([A-Za-z]):', '/mnt/$1'.ToLower()

Write-Host "Running install.sh through WSL..." -ForegroundColor Yellow
Write-Host ""

# Run the bash installer through WSL
# Clone to WSL filesystem first for best results
wsl bash -c "cd '$wslPath' && ./install.sh"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Installation complete!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Installation failed with exit code $LASTEXITCODE" -ForegroundColor Red
    Write-Host ""
    Write-Host "TIP: For best results, clone this repo inside WSL:" -ForegroundColor Yellow
    Write-Host "  1. Open WSL terminal" -ForegroundColor Gray
    Write-Host "  2. Run: cd ~ && git clone https://github.com/bordenet/superpowers-plus.git" -ForegroundColor Cyan
    Write-Host "  3. Run: cd superpowers-plus && ./install.sh" -ForegroundColor Cyan
    exit $LASTEXITCODE
}

