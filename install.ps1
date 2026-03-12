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

# Platform detection - $IsWindows, $IsMacOS, $IsLinux are automatic in PowerShell Core (6+)
# For Windows PowerShell 5.1, these don't exist, so we default to Windows
$runningOnWindows = $true
$platformName = "Windows"

if ($PSVersionTable.PSVersion.Major -ge 6) {
    if ($IsMacOS) {
        $runningOnWindows = $false
        $platformName = "macOS"
    } elseif ($IsLinux) {
        $runningOnWindows = $false
        $platformName = "Linux"
    }
}

# On macOS/Linux, just run bash directly - no WSL needed
if (-not $runningOnWindows) {
    Write-Host "Detected: $platformName" -ForegroundColor Green
    Write-Host "Running: bash ./install.sh" -ForegroundColor Gray
    Write-Host ""

    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Push-Location $scriptDir
    try {
        bash ./install.sh
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host "Installation complete!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Installation failed with exit code $exitCode" -ForegroundColor Red
    }
    exit $exitCode
}

# === Windows-specific logic below ===
Write-Host "Detected: Windows (using WSL)" -ForegroundColor Gray
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

# Check if a Linux distribution is installed and find a working one
Write-Host "Checking for Linux distribution..." -ForegroundColor Gray

# Get list of installed distros (--quiet removes the header)
$distroListRaw = wsl --list --quiet 2>&1 | Out-String
$distroList = ($distroListRaw -split "`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() -replace "`0", "" })

# Filter out Docker's internal WSL distros (they don't have bash)
$dockerDistros = @("docker-desktop", "docker-desktop-data")
$usableDistros = $distroList | Where-Object { $_ -notin $dockerDistros }
$skippedDocker = $distroList | Where-Object { $_ -in $dockerDistros }

if ($skippedDocker.Count -gt 0) {
    Write-Host "Skipping Docker distros (no bash): $($skippedDocker -join ', ')" -ForegroundColor DarkGray
}

if ($usableDistros.Count -eq 0) {
    Write-Host ""
    Write-Host "ERROR: No usable Linux distribution found." -ForegroundColor Red
    Write-Host ""
    if ($skippedDocker.Count -gt 0) {
        Write-Host "You have Docker Desktop's WSL distros, but these don't include bash." -ForegroundColor Yellow
        Write-Host "You need to install a full Linux distribution:" -ForegroundColor Yellow
    } else {
        Write-Host "You need to install a Linux distribution:" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Run this command in PowerShell (as Administrator):" -ForegroundColor White
    Write-Host "  wsl --install -d Ubuntu" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Then restart your computer and run this script again." -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "Found distros: $($usableDistros -join ', ')" -ForegroundColor DarkGray

# Find a working distro - prefer Ubuntu, then any that works
$workingDistro = $null
$preferredOrder = @("Ubuntu", "Ubuntu-22.04", "Ubuntu-20.04", "Debian", "openSUSE-Leap-15.5")

# Try preferred distros first
foreach ($preferred in $preferredOrder) {
    foreach ($distro in $usableDistros) {
        if ($distro -like "*$preferred*") {
            Write-Host "Testing distro: $distro" -ForegroundColor DarkGray
            $testResult = wsl -d $distro -- /bin/bash -c "echo ok" 2>&1 | Out-String
            if ($testResult.Trim() -eq "ok") {
                $workingDistro = $distro
                break
            }
        }
    }
    if ($workingDistro) { break }
}

# If no preferred distro works, try all of them
if (-not $workingDistro) {
    foreach ($distro in $usableDistros) {
        Write-Host "Testing distro: $distro" -ForegroundColor DarkGray
        $testResult = wsl -d $distro -- /bin/bash -c "echo ok" 2>&1 | Out-String
        if ($testResult.Trim() -eq "ok") {
            $workingDistro = $distro
            break
        }
    }
}

if (-not $workingDistro) {
    Write-Host ""
    Write-Host "ERROR: No working WSL distro found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Tested distros: $($distroList -join ', ')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "This usually means your distro needs initialization." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Fix: Open your distro manually to complete setup:" -ForegroundColor White
    Write-Host "  1. Open Start Menu, search for 'Ubuntu' (or your distro)" -ForegroundColor Cyan
    Write-Host "  2. Let it finish 'Installing...' and create your username/password" -ForegroundColor Cyan
    Write-Host "  3. Then run this script again" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or try restarting WSL:" -ForegroundColor White
    Write-Host "  wsl --shutdown" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host "Using distro: $workingDistro" -ForegroundColor Green

# Get the script directory and convert to WSL path
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Use wslpath tool for reliable Windows->WSL path conversion
$wslPath = $null
try {
    $wslPath = (wsl -d $workingDistro -- wslpath -u $scriptDir 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($wslPath)) {
        $wslPath = $null
    }
} catch {
    $wslPath = $null
}

if ([string]::IsNullOrWhiteSpace($wslPath)) {
    # Fallback to manual conversion if wslpath fails
    $driveLetter = $scriptDir.Substring(0, 1).ToLower()
    $pathRest = $scriptDir.Substring(2) -replace '\\', '/'
    $wslPath = "/mnt/$driveLetter$pathRest"
}

Write-Host "WSL Path: $wslPath" -ForegroundColor DarkGray

Write-Host "Running install.sh through WSL ($workingDistro)..." -ForegroundColor Yellow
Write-Host ""

# Run the bash installer through WSL with explicit distro and /bin/bash path
wsl -d $workingDistro -- /bin/bash -c "cd '$wslPath' && ./install.sh"

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
