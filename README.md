# universal-tmux

Universal tmux config with hardware-aware status bar. Drop it on any machine — VPS, desktop, laptop, Jetson/Spark, Raspberry Pi — and it just works.

> Using [cmux](https://github.com/manaflow-ai/cmux/tree/main/cmux-tui) instead of tmux? See the counterpart: [universal-cmux](https://github.com/Quaerendir/universal-cmux).

## Features

- **Auto-detecting GPU stats** in status bar (Nvidia desktop/Jetson/Spark, AMD Radeon (amdgpu sysfs, ROCm fallback), Intel iGPU, Raspberry Pi VideoCore)
- **CPU & RAM** via [tmux-cpu](https://github.com/tmux-plugins/tmux-cpu) plugin
- **Load average** from `/proc` (Linux) or `sysctl` (macOS)
- **Session persistence** via [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) + [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum)
- **GUI terminal friendly** — right-click menu disabled (Termius fix), resurrect bindings on `prefix + S/R` instead of `C-s/C-r` (avoids flow control interception)
- **No theme dependencies** — minimal dark colour scheme, no Catppuccin/Powerline/etc. overhead

## Status Bar

```
 session | ... windows ... | CPU:5.2% RAM:43.1% GPU:35% vRAM:4096/8192Mi 62°C 0.82 0.65 0.71 2026-03-05 14:30 hostname
```

GPU section adapts per platform:

| Platform | Output example |
|---|---|
| Nvidia desktop/server | `GPU:35% vRAM:4096/8192Mi 62°C` |
| Nvidia Jetson/Spark (unified memory) | `GPU:12% 42°C MEM:87.4/119.7G` |
| AMD Radeon (amdgpu, via sysfs — no `rocm-smi` needed) | `GPU:28% vRAM:4096/32752Mi 65°C` |
| Several AMD GPUs | `GPU0:5% vRAM:1024/32752Mi 41°C GPU1:99% vRAM:32424/32752Mi 78°C` |
| Intel iGPU | `iGPU:1200MHz` |
| Raspberry Pi | `RPi:52.1°C 500MHz 128M` (+ `THR!` on throttling) |
| No GPU / VPS | *(empty — no clutter)* |

## Quick Install

```bash
git clone https://github.com/Quaerendir/universal-tmux.git
cd universal-tmux
bash setup-tmux.sh
```

Then inside tmux:
1. `prefix + I` (C-a, Shift+i) — install plugins via TPM
2. `prefix + r` — reload config

## Windows (psmux)

Native Windows port using [psmux](https://github.com/psmux/psmux) (tmux-compatible, no WSL). Same prefix and keybindings; see [`windows/`](windows/).

```powershell
git clone https://github.com/Quaerendir/universal-tmux.git
cd universal-tmux\windows
pwsh -File .\setup-psmux.ps1     # installs psmux via winget if missing, then deploys config
```

Differences from the Linux/macOS version:

- **No TPM / resurrect / continuum** — plugins and session save/restore are not set up.
- **Status bar** — a small background `status-daemon.ps1` samples CPU, RAM and NVIDIA GPU (`nvidia-smi`) every 5 s and pushes the text into each session's `status-right`. It is a singleton and exits by itself ~15 s after psmux is gone. AMD/Intel GPUs have no Windows CLI, so the GPU segment is simply omitted.
- **No load average** — Windows has no `/proc/loadavg` equivalent.
- Config lives in `~/.psmux.conf` (psmux also reads `~/.tmux.conf`); `status-bg`/`status-fg` are replaced by `status-style`.

## Files

| File | Description |
|---|---|
| `tmux-universal.conf` | Main tmux config (copied to `~/.tmux.conf`) |
| `gpu-stats.sh` | Universal GPU metrics script (copied to `~/.tmux/gpu-stats.sh`) |
| `setup-tmux.sh` | One-command installer with backup & TPM setup |
| `windows/psmux-universal.conf` | psmux config for Windows (copied to `~/.psmux.conf`) |
| `windows/status-daemon.ps1` | CPU/RAM/NVIDIA-GPU status-bar sampler (copied to `~/.psmux/`) |
| `windows/setup-psmux.ps1` | One-command Windows installer with backup |

## Keybindings

| Key | Action |
|---|---|
| `C-a` | Prefix (C-b also works) |
| `prefix + r` | Reload config |
| `prefix + S` | Save session (resurrect) |
| `prefix + R` | Restore session |
| `prefix + -` | Horizontal split |
| `prefix + \|` | Vertical split |
| `prefix + m` | Main-vertical layout |
| `prefix + z` / `+` | Toggle pane zoom |
| `Alt + arrows` | Pane navigation |
| `Shift + Alt + arrows` | Pane resize |
| `C-a + C-h / C-l` | Previous / next window |
| `prefix + S` (choose) | Session picker |

## Requirements

- tmux 3.2+
- git (for TPM)
- `nvidia-smi`, `rocm-smi`, `vcgencmd` etc. are optional — script auto-detects what's available

## License

MIT
