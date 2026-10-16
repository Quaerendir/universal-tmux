# ~/.psmux/status-daemon.ps1
# Windows counterpart of universal-tmux status-right (tmux-cpu + gpu-stats.sh).
# One long-lived background pwsh samples CPU/RAM/GPU every 5 s and writes ~/.psmux/status.txt;
# the status bar just `type`s that file (spawning pwsh per refresh costs ~2 s, CIM is slow).
# Singleton (named mutex); exits by itself once no psmux server has been running for ~15 s.
#
# Output: CPU:xx% RAM:xx% GPU:xx% vRAM:used/totalMi xx°C <date> <host>   (with #[fg=..] codes)
# GPU part: NVIDIA via nvidia-smi; AMD/Intel have no Windows CLI -> silent (like "No GPU" on Linux).
# No load average: Windows has no equivalent of /proc/loadavg.

$ErrorActionPreference = 'SilentlyContinue'
$mutex = [System.Threading.Mutex]::new($false, 'Local\psmux-status-daemon')
if (-not $mutex.WaitOne(0)) { return }   # already running

$dir  = Join-Path $env:USERPROFILE '.psmux'
$file = Join-Path $dir 'status.txt'
$tmp  = Join-Path $dir 'status.tmp'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$hasNv = [bool](Get-Command nvidia-smi -ErrorAction SilentlyContinue)

$cpuCounter = [Diagnostics.PerformanceCounter]::new('Processor Information', '% Processor Utility', '_Total')
$null = $cpuCounter.NextValue()
$idle = 0

while ($true) {
    if (Get-Process psmux, pmux, tmux -ErrorAction SilentlyContinue) { $idle = 0 }
    elseif (++$idle -ge 3) { break }

    $cpu = [math]::Min(100, [math]::Round($cpuCounter.NextValue(), 1))

    $os  = Get-CimInstance Win32_OperatingSystem
    $ram = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100, 1)

    $gpu = ''
    if ($hasNv) {
        $q = nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>$null | Select-Object -First 1
        if ($q) {
            $f = $q -split ',\s*'
            if ($f.Count -ge 4 -and $f[1] -match '^\d+$') { $gpu = "GPU:$($f[0])% vRAM:$($f[1])/$($f[2])Mi $($f[3])°C" }
            elseif ($f.Count -ge 1)                       { $gpu = "GPU:$($f[0])%" }
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
