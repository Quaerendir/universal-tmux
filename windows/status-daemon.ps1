# ~/.psmux/status-daemon.ps1
# Windows counterpart of universal-tmux status-right (tmux-cpu + gpu-stats.sh).
# One long-lived background pwsh samples CPU/RAM/GPU every 5 s and writes ~/.psmux/status.txt;
# the status bar just `type`s that file (spawning pwsh per refresh costs ~2 s, CIM is slow).
# Singleton (named mutex); exits by itself once no psmux server has been running for ~15 s.
#
# Output: CPU:xx% RAM:xx% GPU0 xx% x.xG xx°C xxxW GPU1 ... <date> <host>   (with #[fg=..] codes)
# GPU sources, first that works wins:
#   1. HWiNFO64 Shared Memory (SM2) -> every discrete AMD/NVIDIA card: util, VRAM, hotspot temp, board power.
#      Needs HWiNFO running with "Shared Memory Support" ON. Labels are matched in EN + PL.
#   2. nvidia-smi (only if it really talks to a driver; a leftover nvidia-smi.exe without driver is ignored).
# Neither available -> no GPU part (like "No GPU" on Linux).
# No load average: Windows has no equivalent of /proc/loadavg.

$ErrorActionPreference = 'SilentlyContinue'
$mutex = [System.Threading.Mutex]::new($false, 'Local\psmux-status-daemon')
if (-not $mutex.WaitOne(0)) { return }   # already running

$dir  = Join-Path $env:USERPROFILE '.psmux'
$file = Join-Path $dir 'status.txt'
$tmp  = Join-Path $dir 'status.tmp'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$hasNv = [bool](Get-Command nvidia-smi -ErrorAction SilentlyContinue)

Add-Type -AssemblyName System.Core

$cpuCounter = [Diagnostics.PerformanceCounter]::new('Processor Information', '% Processor Utility', '_Total')
$null = $cpuCounter.NextValue()
$idle = 0

# Label patterns per metric (HWiNFO labels follow its UI language).
$rxUtil = '^(GPU Utilization|Wykorzystanie GPU)$'
$rxTemp = '^(GPU Hot Spot Temperature|Temperatura gor.cego punktu GPU|Temperatura GPU|GPU Temperature)$'   # hotspot preferred
$rxHot  = 'Hot Spot|gor.cego punktu'
$rxPwr  = '^(Total Board Power \(TBP\)|GPU Power|Total Graphics Power \(TGP\))$'
$rxVram = '^(GPU D3D Memory Dedicated|Dedykowana pami.. GPU D3D)$'

function Get-HwinfoGpus {
    try {
        $mmf = [System.IO.MemoryMappedFiles.MemoryMappedFile]::OpenExisting('Global\HWiNFO_SENS_SM2', [System.IO.MemoryMappedFiles.MemoryMappedFileRights]::Read)
    } catch { return @() }
    try {
        $va = $mmf.CreateViewAccessor(0, 0, [System.IO.MemoryMappedFiles.MemoryMappedFileAccess]::Read)
        if ($va.ReadUInt32(0) -ne 0x53695748) { return @() }   # 0x44414544 = HWiNFO closed
        $offS = $va.ReadUInt32(20); $szS = $va.ReadUInt32(24); $nS = $va.ReadUInt32(28)
        $offR = $va.ReadUInt32(32); $szR = $va.ReadUInt32(36); $nR = $va.ReadUInt32(40)
        $str = {
            param($pos, $len)
            $b = New-Object byte[] $len; [void]$va.ReadArray($pos, $b, 0, $len)
            $e = [Array]::IndexOf($b, [byte]0); if ($e -lt 0) { $e = $len }
            [Text.Encoding]::UTF8.GetString($b, 0, $e)
        }
        # sensor index -> GPU slot, for discrete cards only ("dGPU [#0]: ...")
        $slot = @{}
        for ($i = 0; $i -lt $nS; $i++) {
            if ((& $str ($offS + $i * $szS + 8 + 128) 128) -match '^dGPU \[#(\d+)\]') { $slot[$i] = [int]$Matches[1] }
        }
        $gpus = @{}
        for ($i = 0; $i -lt $nR; $i++) {
            $p = $offR + $i * $szR
            $si = [int]$va.ReadUInt32($p + 4)
            if (-not $slot.ContainsKey($si)) { continue }
            $label = & $str ($p + 12 + 128) 128
            $val = $va.ReadDouble($p + 12 + 272)
            $g = $gpus[$slot[$si]]; if (-not $g) { $g = @{}; $gpus[$slot[$si]] = $g }
            switch ($va.ReadUInt32($p)) {
                1 { if ($label -match $rxTemp -and (-not $g.ContainsKey('temp') -or $label -match $rxHot)) { $g.temp = $val } }
                5 { if ($label -match $rxPwr -and -not $g.ContainsKey('pwr')) { $g.pwr = $val } }
                7 { if ($label -match $rxUtil) { $g.util = $val } }
                8 { if ($label -match $rxVram) { $g.vram = $val } }
            }
        }
        $gpus.GetEnumerator() | Sort-Object Name | ForEach-Object {
            $g = $_.Value
            $s = "GPU$($_.Name)"
            if ($g.ContainsKey('util')) { $s += " $([math]::Round($g.util))%" }
            if ($g.ContainsKey('vram')) { $s += " $([math]::Round($g.vram / 1024, 1))G" }
            if ($g.ContainsKey('temp')) { $s += " $([math]::Round($g.temp))°C" }
            if ($g.ContainsKey('pwr'))  { $s += " $([math]::Round($g.pwr))W" }
            $s
        }
    } finally { $mmf.Dispose() }
}

while ($true) {
    if (Get-Process psmux, pmux, tmux -ErrorAction SilentlyContinue) { $idle = 0 }
    elseif (++$idle -ge 3) { break }

    $cpu = [math]::Min(100, [math]::Round($cpuCounter.NextValue(), 1))

    $os  = Get-CimInstance Win32_OperatingSystem
    $ram = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100, 1)

    $gpu = @(Get-HwinfoGpus) -join ' '
    if (-not $gpu -and $hasNv) {
        $q = nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>$null | Select-Object -First 1
        if ($LASTEXITCODE -eq 0 -and $q) {
            $f = $q -split ',\s*'
            if ($f.Count -ge 4 -and $f[1] -match '^\d+$') { $gpu = "GPU:$($f[0])% vRAM:$($f[1])/$($f[2])Mi $($f[3])°C" }
        }
    }

    $out = "#[fg=cyan]CPU:$cpu% #[fg=magenta]RAM:$ram% "
    if ($gpu) { $out += "#[fg=yellow]$gpu " }
    $out += "#[fg=colour39]$(Get-Date -Format 'yyyy-MM-dd HH:mm') #[fg=colour117]$env:COMPUTERNAME"

    [System.IO.File]::WriteAllText($tmp, $out, $utf8)
    Move-Item $tmp $file -Force

    # Push into every session's status-right (psmux runs one server per session).
    # Not relying on #() in the status bar: it is not documented as supported.
    foreach ($s in (psmux ls -F '#S' 2>$null)) {
        if ($s) { psmux set-option -t $s status-right $out 2>$null | Out-Null }
    }

    Start-Sleep -Seconds 5
}
$mutex.ReleaseMutex()
