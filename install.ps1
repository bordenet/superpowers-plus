<#
.SYNOPSIS
    Installs superpowers-plus on Windows (no WSL) via Git Bash; runs install.sh on macOS and Linux.

.DESCRIPTION
    On Windows the default run is a full install:

      1. Installs missing Python 3 (Python.Python.3.12) and jq (jqlang.jq)
         with winget. Git for Windows (Git.Git, provides Git Bash) and
         Node.js LTS (OpenJS.NodeJS.LTS) install machine-wide; if either is
         missing the script stops and prints the winget command (see below).
      2. Writes python3 and python3.cmd shims to ~/.local/bin (Python on
         Windows ships python.exe only) and prepends ~/.local/bin to the
         user PATH.
      3. Sets user environment variables CLAUDE_CODE_GIT_BASH_PATH (Git
         Bash location, read by Claude Code) and PYTHONUTF8=1.
      4. Runs install.sh under Git Bash, which installs skills, Claude Code
         hooks, git gates, tools, rules, and templates as on macOS/Linux.

    The script refuses to run from an elevated (administrator) PowerShell: it
    runs install.sh and other scripts from this checkout, which a non-admin can
    modify. Git for Windows and Node.js install machine-wide, so when either is
    missing the script stops and prints the winget command to run from an
    elevated PowerShell; then re-run this script from a normal one.
    SUPERPOWERS_ALLOW_ELEVATED=1 (exactly 1) lifts the refusal, for disposable
    single-user machines such as CI runners.

    On macOS and Linux this script runs bash install.sh (or uninstall.sh with
    -Uninstall) with the matching flags.

    Behavior change: earlier versions of this script were a WSL wrapper. It now
    installs natively into the Windows user profile.

    Exit codes: 0 success, 1 error (message on stderr).

.PARAMETER Categories
    Comma-separated top-level skills/ folders to install, for example
    engineering,writing. Default: all categories.

.PARAMETER SkipAugment
    Deploy to ~/.claude/skills only. Skips ~/.codex/skills, ~/.agents/skills,
    and the Augment adapter.

.PARAMETER Force
    Install even if ~/.codex/.superpowers-ecosystem names a different
    superpowers ecosystem. The existing deployment is overwritten. This only
    bypasses the ecosystem lock (SUPERPOWERS_ALLOW_FOREIGN_ECOSYSTEM=1 for
    install.sh); it does not pass --force, so local commits and untracked files
    in ~/.codex/superpowers-plus are left alone. To also reset that checkout to
    origin/main, run install.sh --force yourself.

.PARAMETER Uninstall
    Run uninstall.sh under Git Bash, then remove the python3 shims and the sp-*
    wrappers in ~/.local/bin. Installs nothing; Git Bash must already be
    present. The ~/.local/bin PATH entry, CLAUDE_CODE_GIT_BASH_PATH,
    PYTHONUTF8, and winget packages are left in place.

.PARAMETER NoPrereqInstall
    Windows only. Do not run winget; fail if a prerequisite is missing.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Categories engineering,writing

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [string[]]$Categories = @(),
    [switch]$SkipAugment,
    [switch]$Force,
    [switch]$Uninstall,
    [switch]$NoPrereqInstall
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
if (Get-Variable -Name PSStyle -ErrorAction SilentlyContinue) { $PSStyle.OutputRendering = 'PlainText' }

# -Categories a,b binds as an array from a PowerShell prompt and as "a,b" via -File.
$CategoryList = (@($Categories) -join ',')
$Ecosystem = 'superpowers-plus'
$RepoRoot = $PSScriptRoot
$OnWindows = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows

# --- macOS / Linux: delegate to install.sh ---------------------------------

if (-not $OnWindows) {
    if ($NoPrereqInstall) { Write-Warning '-NoPrereqInstall applies to Windows only; ignored.' }
    $bashArgs = New-Object System.Collections.Generic.List[string]
    if ($Uninstall) {
        # install.sh has no --uninstall; uninstall.sh takes only --yes/--verbose.
        $bashArgs.Add((Join-Path $RepoRoot 'uninstall.sh'))
        $bashArgs.Add('--yes')
    } else {
        $bashArgs.Add((Join-Path $RepoRoot 'install.sh'))
        $bashArgs.Add('--yes')
        if ($SkipAugment) { $bashArgs.Add('--skip-augment') }
        if ($CategoryList) { $bashArgs.Add('--categories'); $bashArgs.Add($CategoryList) }
        if ($Force) { $env:SUPERPOWERS_ALLOW_FOREIGN_ECOSYSTEM = '1' }
    }
    if ($VerbosePreference -eq 'Continue') { $bashArgs.Add('--verbose') }
    & bash @bashArgs
    exit $LASTEXITCODE
}

# --- Windows: Git Bash bootstrap -------------------------------------------

function Stop-Bootstrap([string]$Message) {
    [Console]::Error.WriteLine("error: $Message")
    exit 1
}

# Append machine and user PATH entries from the registry that this session
# lacks, keeping the session's own entries and order.
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $current = @($env:Path.Split(';') | Where-Object { $_ })
    $merged = New-Object System.Collections.Generic.List[string]
    foreach ($p in $current + @("$machine;$user".Split(';'))) {
        if (-not $p) { continue }
        if (-not ($merged | Where-Object { $_.TrimEnd('\') -ieq $p.TrimEnd('\') })) { $merged.Add($p) }
    }
    $env:Path = $merged -join ';'
}

# Put $Dir first on this session's PATH, so the python3 shim wins over the
# Microsoft Store python3.exe alias in WindowsApps.
function Set-SessionPathFront([string]$Dir) {
    $rest = @($env:Path.Split(';') | Where-Object { $_ -and ($_.TrimEnd('\') -ine $Dir.TrimEnd('\')) })
    $env:Path = (@($Dir) + $rest) -join ';'
}

# Runs a native command and returns Code and Output without throwing:
# PowerShell 5.1 turns redirected native stderr into a terminating error
# under ErrorActionPreference=Stop.
function Invoke-NativeQuiet([string]$Exe, [string[]]$Arguments) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $Exe @Arguments 2>$null
        $rc = $LASTEXITCODE
    } catch { $out = $null; $rc = 1 } finally { $ErrorActionPreference = $prev }
    return [pscustomobject]@{ Code = $rc; Output = (@($out) -join "`n").Trim() }
}

function Test-Elevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# winget exit codes meaning the package is already there (APPINSTALLER_CLI_ERROR_
# UPDATE_NOT_APPLICABLE 0x8A15002B, PACKAGE_ALREADY_INSTALLED 0x8A150061). Callers
# re-probe after this returns, so a package installed somewhere the probe missed
# still fails with a clear message there.
$WingetAlreadyInstalled = @(-1978335189, -1978335135)

# -MachineWide: the installer writes to Program Files and raises a UAC prompt
# when not elevated; this repo's installers must not wait for a human, so stop.
function Install-WingetPackage([string]$Id, [switch]$MachineWide) {
    if ($NoPrereqInstall) { Stop-Bootstrap "$Id is missing or too old and -NoPrereqInstall was given. Install it: winget install --id $Id -e" }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Stop-Bootstrap "$Id is missing or too old and winget is not available. Install it manually, then re-run."
    }
    if ($MachineWide -and -not (Test-Elevated)) {
        Stop-Bootstrap "$Id is missing or too old and installs machine-wide. From an elevated PowerShell run: winget install --id $Id -e   Then re-run this script from a normal PowerShell."
    }
    Write-Host "Installing $Id with winget..."
    winget install --id $Id -e --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($WingetAlreadyInstalled -contains $LASTEXITCODE) {
        Write-Host "winget reports $Id is already installed (exit $LASTEXITCODE); re-checking."
    } elseif ($LASTEXITCODE -ne 0) {
        Stop-Bootstrap "winget install --id $Id failed (exit $LASTEXITCODE)"
    }
    Update-SessionPath
}

function Find-GitBash {
    $roots = New-Object System.Collections.Generic.List[string]
    # The Git for Windows registry key is authoritative; a git.exe on PATH can
    # belong to MSYS2 or Cygwin, whose bash is not the one Claude Code expects.
    foreach ($key in @('HKLM:\SOFTWARE\GitForWindows', 'HKCU:\SOFTWARE\GitForWindows')) {
        $p = Get-ItemProperty -Path $key -Name InstallPath -ErrorAction SilentlyContinue
        if ($p) { $roots.Add($p.InstallPath) }
    }
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($git) {
        # <root>\cmd\git.exe, <root>\bin\git.exe or <root>\mingw64\bin\git.exe
        $d = Split-Path -Parent $git.Source
        $roots.Add((Split-Path -Parent $d))
        $roots.Add((Split-Path -Parent (Split-Path -Parent $d)))
    }
    if ($env:ProgramFiles) { $roots.Add((Join-Path $env:ProgramFiles 'Git')) }
    if ($env:LOCALAPPDATA) { $roots.Add((Join-Path $env:LOCALAPPDATA 'Programs\Git')) }
    foreach ($r in $roots) {
        if (-not $r) { continue }
        $bash = Join-Path $r 'bin\bash.exe'
        if (Test-Path -LiteralPath $bash -PathType Leaf) { return $bash }
    }
    return $null
}

# Minimum versions the installer documents: Python 3.8+, Node.js 18+.
function Test-PythonExe([string]$Exe) {
    $r = Invoke-NativeQuiet $Exe @('-c', 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)')
    return ($r.Code -eq 0)
}

function Test-NodeOk {
    $node = Get-Command node.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $node) { return $false }
    $r = Invoke-NativeQuiet $node.Source @('--version')
    return ($r.Code -eq 0 -and $r.Output -match '^v(\d+)\.' -and [int]$Matches[1] -ge 18)
}

# Real python.exe 3.8+, skipping the Microsoft Store stubs in WindowsApps.
function Find-Python {
    $py = Get-Command py.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($py) {
        $r = Invoke-NativeQuiet $py.Source @('-3', '-c', 'import sys; print(sys.executable)')
        $exe = "$($r.Output -split "`n" | Select-Object -First 1)".Trim()
        if ($r.Code -eq 0 -and $exe -and (Test-Path -LiteralPath $exe -PathType Leaf) -and (Test-PythonExe $exe)) { return $exe }
    }
    foreach ($c in @(Get-Command python.exe -All -ErrorAction SilentlyContinue)) {
        if (($c.Source -notmatch '\\WindowsApps\\') -and (Test-PythonExe $c.Source)) { return $c.Source }
    }
    if ($env:LOCALAPPDATA) {
        $found = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python3*\python.exe') -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Where-Object { Test-PythonExe $_.FullName } | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

# C:\Users\me\x -> /c/Users/me/x
function ConvertTo-MsysPath([string]$Path) {
    if ($Path -match '^([A-Za-z]):[\\/](.*)$') {
        return '/' + $Matches[1].ToLower() + '/' + ($Matches[2] -replace '\\', '/')
    }
    return ($Path -replace '\\', '/')
}

# Reads and writes HKCU\Environment\Path directly so %VAR% entries stay
# unexpanded and the value keeps its REG_EXPAND_SZ type.
function Add-UserPathFront([string]$Dir) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    try {
        $user = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $parts = @($user.Split(';') | Where-Object { $_ })
        $isDir = { param($p) [Environment]::ExpandEnvironmentVariables($p).TrimEnd('\') -ieq $Dir.TrimEnd('\') }
        # Already first: nothing to do. Present but not first: move it to the front.
        if ($parts.Count -gt 0 -and (& $isDir $parts[0])) { return }
        $rest = @($parts | Where-Object { -not (& $isDir $_) })
        $key.SetValue('Path', ((@($Dir) + $rest) -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString)
    } finally { $key.Close() }
    # Broadcast WM_SETTINGCHANGE so new processes see the change.
    [Environment]::SetEnvironmentVariable('SUPERPOWERS_PLUS_PATH_REFRESH', [Guid]::NewGuid().ToString(), 'User')
    [Environment]::SetEnvironmentVariable('SUPERPOWERS_PLUS_PATH_REFRESH', $null, 'User')
    Write-Host "Added $Dir to the front of the user PATH"
}

# Sets a user environment variable only when it is unset, already equal, or
# (-ExistingPath) names a path that no longer exists. Otherwise the user's value
# is kept and a warning says so (a portable Git, a deliberate PYTHONUTF8).
# Returns the user-level value in effect.
function Set-UserEnv([string]$Name, [string]$Value, [switch]$ExistingPath) {
    $old = [Environment]::GetEnvironmentVariable($Name, 'User')
    if ($old -and $old -ne $Value) {
        if ($ExistingPath -and -not (Test-Path -LiteralPath $old)) {
            Write-Warning "$Name pointed at '$old', which no longer exists; replacing it"
        } else {
            Write-Warning "$Name is already set to '$old'; keeping it (installer would use '$Value')"
            return $old
        }
    }
    if ($old -ne $Value) {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
        Write-Host "Set user environment variable $Name=$Value"
    }
    return $Value
}

$ShimMarker = 'superpowers-plus python3 shim'

# python3 for Git Bash, python3.cmd for PowerShell and CMD (PATHEXT).
function Install-Python3Shim([string]$PythonExe, [string]$BinDir) {
    # Single-quote the path for bash so a $ or backtick in it stays literal.
    $quoted = (ConvertTo-MsysPath $PythonExe).Replace("'", "'\''")
    $shims = @{
        'python3'     = "#!/usr/bin/env bash`n# $ShimMarker`nexec '$quoted' `"`$@`"`n"
        'python3.cmd' = "@rem $ShimMarker`r`n@`"$($PythonExe.Replace('%', '%%'))`" %*`r`n"
    }
    [void][IO.Directory]::CreateDirectory($BinDir)
    foreach ($name in $shims.Keys) {
        $shim = Join-Path $BinDir $name
        if ((Test-Path -LiteralPath $shim -PathType Leaf) -and -not (Select-String -LiteralPath $shim -SimpleMatch $ShimMarker -Quiet)) {
            Write-Warning "$shim exists and was not written by superpowers-plus; leaving it"
            continue
        }
        [IO.File]::WriteAllText($shim, $shims[$name], (New-Object System.Text.UTF8Encoding $false))
    }
}

function Remove-Python3Shim([string]$BinDir) {
    foreach ($name in @('python3', 'python3.cmd')) {
        $shim = Join-Path $BinDir $name
        if ((Test-Path -LiteralPath $shim -PathType Leaf) -and (Select-String -LiteralPath $shim -SimpleMatch $ShimMarker -Quiet)) {
            Remove-Item -LiteralPath $shim -Force
            Write-Host "Removed $shim"
        }
    }
}

# sp-* wrappers written by lib/install/deploy.sh on Windows. uninstall.sh removes
# them only under --purge, so -Uninstall removes the ones that exec a script in
# the managed checkout (~/.codex/superpowers-plus) and leaves any other file.
function Remove-SpWrappers([string]$BinDir) {
    if (-not (Test-Path -LiteralPath $BinDir -PathType Container)) { return }
    foreach ($f in @(Get-ChildItem -LiteralPath $BinDir -File -Filter 'sp-*' -ErrorAction SilentlyContinue)) {
        if ((Select-String -LiteralPath $f.FullName -SimpleMatch '# superpowers-plus sp-* wrapper' -Quiet) -and
            (Select-String -LiteralPath $f.FullName -SimpleMatch '/.codex/superpowers-plus/' -Quiet)) {
            Remove-Item -LiteralPath $f.FullName -Force
            Write-Host "Removed $($f.FullName)"
        }
    }
}

# install.sh runs under Git Bash and needs python3 there to be a working 3.8+
# that is the shim (not the Store alias). Check what Git Bash itself resolves.
function Assert-Python3InGitBash([string]$GitBash) {
    $which = Invoke-NativeQuiet $GitBash @('-c', 'command -v python3')
    if ($which.Code -ne 0 -or $which.Output -notlike '*/.local/bin/python3') {
        Stop-Bootstrap "python3 in Git Bash resolves to '$($which.Output)', not the shim in ~/.local/bin. Remove or rename the conflicting python3, then re-run."
    }
    $ver = Invoke-NativeQuiet $GitBash @('-c', "python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)'")
    if ($ver.Code -ne 0) {
        Stop-Bootstrap "python3 in Git Bash ($($which.Output)) is not a working Python 3.8 or newer. If ~/.local/bin/python3 was not written by superpowers-plus, remove it and re-run."
    }
}

# install.sh, uninstall.sh and the scripts they call live in this checkout,
# which a non-admin can modify; running them as administrator would hand that
# user admin rights.
if ((Test-Elevated) -and $env:SUPERPOWERS_ALLOW_ELEVATED -ne '1') {
    Stop-Bootstrap 'install.ps1 does not run from an elevated (administrator) PowerShell. Re-run it from a normal PowerShell. To install a missing Git for Windows or Node.js first, run from an elevated PowerShell: winget install --id Git.Git -e   and   winget install --id OpenJS.NodeJS.LTS -e'
}

$binDir = Join-Path $HOME '.local\bin'
# Git Bash derives HOME from HOMEDRIVE/HOMEPATH, which can point at a
# network share; the AI tools read skills from USERPROFILE.
if (-not $env:HOME) { $env:HOME = $env:USERPROFILE }
Update-SessionPath
$bashArgs = New-Object System.Collections.Generic.List[string]
if ($Uninstall) {
    $gitBash = Find-GitBash
    if (-not $gitBash) { Stop-Bootstrap 'Git Bash (bash.exe) not found. Install Git for Windows, then re-run.' }
    $bashArgs.Add((ConvertTo-MsysPath (Join-Path $RepoRoot 'uninstall.sh')))
    $bashArgs.Add('--yes')
} else {
    if (-not (Find-GitBash)) { Install-WingetPackage 'Git.Git' -MachineWide }
    $gitBash = Find-GitBash
    if (-not $gitBash) { Stop-Bootstrap 'Git Bash (bash.exe) not found after installing Git for Windows.' }
    if (-not (Test-NodeOk)) { Install-WingetPackage 'OpenJS.NodeJS.LTS' -MachineWide }
    if (-not (Test-NodeOk)) { Stop-Bootstrap 'Node.js 18 or newer not found on PATH after installing it. Open a new terminal and re-run.' }
    if (-not (Find-Python)) { Install-WingetPackage 'Python.Python.3.12' }
    $python = Find-Python
    if (-not $python) { Stop-Bootstrap 'Python 3.8 or newer (python.exe) not found after installing Python 3.' }
    if (-not (Get-Command jq.exe -ErrorAction SilentlyContinue)) { Install-WingetPackage 'jqlang.jq' }
    if (-not (Get-Command jq.exe -ErrorAction SilentlyContinue)) { Stop-Bootstrap 'jq.exe not found on PATH after installing it. Open a new terminal and re-run.' }

    Install-Python3Shim $python $binDir
    Add-UserPathFront $binDir
    $effectiveBash = Set-UserEnv 'CLAUDE_CODE_GIT_BASH_PATH' $gitBash -ExistingPath
    $env:CLAUDE_CODE_GIT_BASH_PATH = $effectiveBash
    [void](Set-UserEnv 'PYTHONUTF8' '1')
    $env:PYTHONUTF8 = '1'
    Update-SessionPath
    # The registry PATH is not enough for this run: put the shim directory first
    # on the session PATH too, ahead of the WindowsApps python3.exe alias.
    Set-SessionPathFront $binDir
    Assert-Python3InGitBash $gitBash

    $bashArgs.Add((ConvertTo-MsysPath (Join-Path $RepoRoot 'install.sh')))
    $bashArgs.Add('--yes')
    if ($SkipAugment) { $bashArgs.Add('--skip-augment') }
    if ($CategoryList) { $bashArgs.Add('--categories'); $bashArgs.Add($CategoryList) }
    # -Force only bypasses the ecosystem lock; install.sh --force would also
    # git reset --hard / clean -fd the managed checkout.
    if ($Force) { $env:SUPERPOWERS_ALLOW_FOREIGN_ECOSYSTEM = '1' }
}
if ($VerbosePreference -eq 'Continue') { $bashArgs.Add('--verbose') }
Write-Host "Running under Git Bash ($gitBash): $($bashArgs -join ' ')"
& $gitBash @bashArgs
$rc = $LASTEXITCODE
if ($rc -eq 0 -and $Uninstall) {
    Remove-Python3Shim $binDir
    Remove-SpWrappers $binDir
}
if ($rc -eq 0 -and -not $Uninstall) { Write-Host 'Open a new terminal so PATH and environment changes take effect, then restart your AI tool.' }
exit $rc
