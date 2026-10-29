# hwinfo-gpus.ps1 -- shared by status-daemon.ps1 (psmux) and, via powershell.exe, by gpu-stats.sh in WSL.
# Get-HwinfoGpus reads the HWiNFO64 Shared Memory (SM2) block and returns one string per discrete GPU:
#   "GPU0 3% 3.8G 37C 17W"  (util, dedicated VRAM, hotspot temp, board power; missing metrics omitted)
# Needs HWiNFO running with "Shared Memory Support" ON; returns nothing otherwise.
# ASCII only on purpose: it is piped to Windows PowerShell 5.1 on stdin, which would misread UTF-8.
$deg = [string][char]0xB0

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
            if ($g.ContainsKey('temp')) { $s += " $([math]::Round($g.temp))${deg}C" }
            if ($g.ContainsKey('pwr'))  { $s += " $([math]::Round($g.pwr))W" }
            $s
        }
    } finally { $mmf.Dispose() }
}
