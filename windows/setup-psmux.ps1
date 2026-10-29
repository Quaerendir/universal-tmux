# setup-psmux.ps1
# Quick deploy of the universal tmux config on Windows via psmux (native tmux for Windows).
# Usage (PowerShell 7+, from the windows\ folder):  pwsh -File .\setup-psmux.ps1

$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot

Write-Host '=== Psmux Universal Setup ==='

# 1. Check / install psmux
if (-not (Get-Command psmux -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error 'psmux not installed and winget not found. Install psmux from https://github.com/psmux/psmux'
    }
    Write-Host 'Installing psmux (winget: marlocarlo.psmux)...'
    winget install --id marlocarlo.psmux --exact --accept-package-agreements --accept-source-agreements
    Write-Host 'Installed. Open a NEW terminal so psmux/tmux are on PATH, then re-run this script.'
    return
}
Write-Host "psmux: $((psmux --version | Select-Object -First 1))"

# 2. Backup existing config
$conf = Join-Path $env:USERPROFILE '.psmux.conf'
if (Test-Path $conf) {
    $bak = "$conf.bak.$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item $conf $bak
    Write-Host "Backup: $conf -> $bak"
}

# 3. Copy files
Copy-Item (Join-Path $src 'psmux-universal.conf') $conf -Force
Write-Host "Config -> $conf"

$dir = Join-Path $env:USERPROFILE '.psmux'   # psmux keeps its own runtime files here too
New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item (Join-Path $src 'status-daemon.ps1') (Join-Path $dir 'status-daemon.ps1') -Force
Copy-Item (Join-Path $src 'hwinfo-gpus.ps1') (Join-Path $dir 'hwinfo-gpus.ps1') -Force
Write-Host "Status daemon -> $dir\status-daemon.ps1"

# 4. Summary
Write-Host ''
Write-Host '=== DONE ==='
Write-Host ''
Write-Host 'Next steps:'
Write-Host '  1. Start psmux (or: tmux kill-server; tmux) - the status daemon starts from the config'
Write-Host '  2. prefix + r - reload config'
Write-Host ''
Write-Host 'Keybindings are the same as on Linux (prefix C-a, Alt+arrows, prefix + - / |, ...).'
Write-Host 'No TPM/resurrect on Windows; status bar shows CPU / RAM / NVIDIA GPU (via nvidia-smi) + date + host.'
