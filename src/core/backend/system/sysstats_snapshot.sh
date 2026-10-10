#!/usr/bin/env bash
# Headless system statistics snapshot collector.
# Emits key=value lines on stdout. Read-only and non-interactive.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: sysstats_snapshot.sh [OPTIONS]

Options:
    --extended    Emit additional metrics (ROOT_USED_PERCENT, GPU_PERCENT, GPU_BACKEND)
    -h, --help    Show this help message
EOF
}

extended=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --extended)
            extended=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "sysstats_snapshot.sh: unknown option or argument '$1'" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# 1. CPU counters (/proc/stat)
cpu_total=0
cpu_idle=0
if [[ -r /proc/stat ]]; then
    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat || true
    user=${user:-0}
    nice=${nice:-0}
    system=${system:-0}
    idle=${idle:-0}
    iowait=${iowait:-0}
    irq=${irq:-0}
    softirq=${softirq:-0}
    steal=${steal:-0}
    idle_time=$((idle + iowait))
    non_idle_time=$((user + nice + system + irq + softirq + steal))
    cpu_total=$((idle_time + non_idle_time))
    cpu_idle=$idle_time
fi

# 2. RAM (/proc/meminfo)
mem_total="NA"
mem_available="NA"
if [[ -r /proc/meminfo ]]; then
    while IFS=': ' read -r key val _; do
        case "$key" in
            MemTotal) mem_total="$val" ;;
            MemAvailable) mem_available="$val" ;;
        esac
    done < /proc/meminfo
fi

# 3. Temperature (/sys/class/thermal/thermal_zone0/temp)
temp_millic="NA"
if [[ -r /sys/class/thermal/thermal_zone0/temp ]]; then
    val=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "")
    if [[ "$val" =~ ^[0-9]+$ ]]; then
        temp_millic="$val"
    fi
fi

# Emit basic fields
echo "CPU_TOTAL=$cpu_total"
echo "CPU_IDLE=$cpu_idle"
echo "MEM_TOTAL_KB=$mem_total"
echo "MEM_AVAILABLE_KB=$mem_available"
echo "TEMP_MILLIC=$temp_millic"

if [[ $extended -eq 0 ]]; then
    exit 0
fi

# 4. Extended: Root filesystem (/ used percentage via df -P /)
root_used="NA"
if df_out=$(df -P / 2>/dev/null); then
    pct=$(echo "$df_out" | awk 'NR==2 {gsub("%","",$5); print $5}')
    if [[ "$pct" =~ ^[0-9]+$ ]] && [ "$pct" -ge 0 ] && [ "$pct" -le 100 ]; then
        root_used="$pct"
    fi
fi
echo "ROOT_USED_PERCENT=$root_used"

# 5. Extended: GPU utilization
gpu_percent="NA"
gpu_backend="unsupported"

# Tier 1: /sys/class/drm/card*/device/gpu_busy_percent
max_drm_gpu=-1
shopt -s nullglob
drm_files=(/sys/class/drm/card*/device/gpu_busy_percent)
shopt -u nullglob

for f in "${drm_files[@]}"; do
    if [[ -r "$f" ]]; then
        val=$(cat "$f" 2>/dev/null || echo "")
        if [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -ge 0 ] && [ "$val" -le 100 ]; then
            if [ "$val" -gt "$max_drm_gpu" ]; then
                max_drm_gpu="$val"
            fi
        fi
    fi
done

if [ "$max_drm_gpu" -ge 0 ]; then
    gpu_percent="$max_drm_gpu"
    gpu_backend="drm"
elif command -v nvidia-smi >/dev/null 2>&1; then
    # Tier 2: nvidia-smi
    max_nv_gpu=-1
    if nv_out=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null); then
        while read -r line; do
            val=$(echo "$line" | tr -d '[:space:]')
            if [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -ge 0 ] && [ "$val" -le 100 ]; then
                if [ "$val" -gt "$max_nv_gpu" ]; then
                    max_nv_gpu="$val"
                fi
            fi
        done <<< "$nv_out"
    fi
    if [ "$max_nv_gpu" -ge 0 ]; then
        gpu_percent="$max_nv_gpu"
        gpu_backend="nvidia"
    fi
fi

echo "GPU_PERCENT=$gpu_percent"
echo "GPU_BACKEND=$gpu_backend"
