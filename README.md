# universal-tmux

Universal tmux config with hardware-aware status bar. Drop it on any machine — VPS, desktop, laptop, Jetson/Spark, Raspberry Pi — and it just works.

## Features

- **Auto-detecting GPU stats** in status bar (Nvidia desktop/Jetson/Spark, AMD ROCm, Intel iGPU, Raspberry Pi VideoCore)
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
| AMD (ROCm) | `GPU:28% 65°C` |
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

## Files

| File | Description |
|---|---|
| `tmux-universal.conf` | Main tmux config (copied to `~/.tmux.conf`) |
| `gpu-stats.sh` | Universal GPU metrics script (copied to `~/.tmux/gpu-stats.sh`) |
| `setup-tmux.sh` | One-command installer with backup & TPM setup |

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
