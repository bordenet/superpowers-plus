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
    # 'wsl --status' is more reliable than 'wsl --version' for checking if WSL is active/installed
    $null = wsl --status 2>$null
    if ($LASTEXITCODE -eq 0) {
        $wslInstalled = $true
    } else {
        # Fallback to simple command check
        $null = Get-Command wsl -ErrorAction SilentlyContinue
        $wslInstalled = $?
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

# Check if a Linux distribution is installed (WSL exists but no distro = bash won't work)
Write-Host "Checking for Linux distribution..." -ForegroundColor Gray
$distroList = wsl --list --quiet 2>$null
if ([string]::IsNullOrWhiteSpace($distroList)) {
    Write-Host "ERROR: WSL is installed but no Linux distribution found." -ForegroundColor Red
    Write-Host ""
    Write-Host "You need to install a Linux distribution:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Option 1 - Install Ubuntu (recommended):" -ForegroundColor White
    Write-Host "  wsl --install -d Ubuntu" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Option 2 - See available distributions:" -ForegroundColor White
    Write-Host "  wsl --list --online" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "After installation, restart your terminal and run this script again." -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# Verify bash actually works
Write-Host "Testing WSL bash..." -ForegroundColor Gray
try {
    $bashTest = wsl bash -c "echo ok" 2>&1 | Out-String
    $bashTest = $bashTest.Trim()
} catch {
    $bashTest = "Exception: $_"
}

if ($bashTest -ne "ok") {
    Write-Host ""
    Write-Host "ERROR: WSL bash is not working properly." -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Gray
    Write-Host $bashTest -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "This usually means your Linux distro needs initialization." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Fix: Open WSL manually FIRST to complete setup:" -ForegroundColor White
    Write-Host "  1. Open Start Menu, search for 'Ubuntu' (or your distro)" -ForegroundColor Cyan
    Write-Host "  2. Let it finish 'Installing...' and create your username/password" -ForegroundColor Cyan
    Write-Host "  3. Then run this script again" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Other options:" -ForegroundColor White
    Write-Host "  - Restart WSL: wsl --shutdown" -ForegroundColor Gray
    Write-Host "  - Reinstall distro: wsl --unregister Ubuntu && wsl --install -d Ubuntu" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "WSL bash working." -ForegroundColor Green

# Get the script directory and convert to WSL path
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Use wslpath tool if available for most reliable conversion
$wslPath = $null
try {
    # Escape backslashes for bash consumption
    $escapedPath = $scriptDir -replace '\\', '\\\\'
    $wslPath = (wsl bash -c "wslpath -u '$escapedPath'" 2>$null).Trim()
    if ($LASTEXITCODE -ne 0) { $wslPath = $null }
} catch {
    $wslPath = $null
}

if ([string]::IsNullOrWhiteSpace($wslPath)) {
    # Fallback to manual regex if wslpath fails or isn't available
    $wslPath = ($scriptDir -replace '\\', '/' -replace '^([A-Za-z]):', '/mnt/$1').ToLower()
}

Write-Host "WSL Path: $wslPath" -ForegroundColor DarkGray

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

