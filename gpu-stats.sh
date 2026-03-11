#!/bin/bash
# ~/.tmux/gpu-stats.sh
# Universal GPU metrics for tmux status bar
# Auto-detect: Nvidia (desktop/Jetson/Spark), AMD, Intel, Raspberry Pi, macOS
#
# Output: GPU:XX% [vRAM or unified MEM info] XX°C
# On machines without GPU: silent exit (no status bar clutter)

# --- NVIDIA (desktop/server with dedicated vRAM) ---
if command -v nvidia-smi &>/dev/null; then
    # Check if memory query works (fails on Tegra/Jetson/Spark)
    mem_check=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1)

    if [[ "$mem_check" =~ ^[0-9]+$ ]]; then
        # Desktop/server GPU — full query
        nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu \
            --format=csv,noheader,nounits 2>/dev/null | head -1 | awk -F', ' '{
            printf "GPU:%s%% vRAM:%s/%sMi %s°C", $1, $2, $3, $4
        }'
    else
        # Tegra/Jetson/Spark — unified memory, no vRAM query available
        read -r gpu_util gpu_temp <<< $(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
            --format=csv,noheader,nounits 2>/dev/null | head -1 | awk -F', ' '{print $1, $2}')

        mem_total=$(awk '/^MemTotal/ {printf "%.1f", $2/1048576}' /proc/meminfo)
        mem_avail=$(awk '/^MemAvailable/ {printf "%.1f", $2/1048576}' /proc/meminfo)
        mem_used=$(awk -v t="$mem_total" -v a="$mem_avail" 'BEGIN{printf "%.1f", t-a}')

        printf "GPU:%s%% %s°C MEM:%s/%sG" "${gpu_util:-?}" "${gpu_temp:-?}" "${mem_used}" "${mem_total}"
    fi
    exit 0
fi

# --- AMD (ROCm) ---
if command -v rocm-smi &>/dev/null; then
    gpu_util=$(rocm-smi --showuse 2>/dev/null | awk '/GPU use/ {gsub(/%/,""); print $NF}' | head -1)
    gpu_temp=$(rocm-smi --showtemp 2>/dev/null | awk '/Temperature.*edge/ {print $NF}' | head -1)

    printf "GPU:%s%% %s°C" "${gpu_util:-?}" "${gpu_temp:-?}"
    exit 0
fi

# --- Intel GPU (xe/i915) ---
if [ -f /sys/class/drm/card0/gt/gt0/rps_cur_freq_mhz ]; then
    freq=$(cat /sys/class/drm/card0/gt/gt0/rps_cur_freq_mhz 2>/dev/null)
    printf "iGPU:%sMHz" "${freq:-?}"
    exit 0
fi

# --- Raspberry Pi (VideoCore IV/VI) ---
if command -v vcgencmd &>/dev/null; then
    # GPU temp (= SoC temp on RPi)
    gpu_temp=$(vcgencmd measure_temp 2>/dev/null | grep -oP '[0-9.]+')

    # GPU clock in MHz
    gpu_freq=$(vcgencmd measure_clock core 2>/dev/null | awk -F'=' '{printf "%.0f", $2/1000000}')

    # Throttling status (bits 0-3: under-voltage, freq cap, throttled, soft temp limit)
    throttle_raw=$(vcgencmd get_throttled 2>/dev/null | awk -F'=' '{print $2}')
    throttle_msg=""
    if [ "$throttle_raw" != "0x0" ] && [ -n "$throttle_raw" ]; then
        throttle_msg=" THR!"
    fi

    # GPU allocated memory from firmware split
    gpu_mem=$(vcgencmd get_mem gpu 2>/dev/null | grep -oP '[0-9]+')

    printf "RPi:%s°C %sMHz %sM%s" "${gpu_temp:-?}" "${gpu_freq:-?}" "${gpu_mem:-?}" "${throttle_msg}"
    exit 0
fi

# --- macOS (Apple Silicon) ---
if [[ "$(uname)" == "Darwin" ]]; then
    # powermetrics requires sudo — skip in tmux
    exit 0
fi

# --- No GPU detected — silent exit ---
exit 0
