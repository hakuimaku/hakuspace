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

# 4. Extended: Root filesystem and mounted storage devices
cpu_freq_ghz="NA"
if [[ -r /proc/cpuinfo ]]; then
    freq=$(awk '/cpu MHz/ {sum+=$4; count++} END {if (count>0) printf "%.1f GHz", (sum/count)/1000}' /proc/cpuinfo 2>/dev/null || echo "")
    if [[ -n "$freq" ]]; then
        cpu_freq_ghz="$freq"
    fi
fi
echo "CPU_FREQ_GHZ=$cpu_freq_ghz"

root_used="NA"
if df_out=$(df -P / 2>/dev/null); then
    pct=$(echo "$df_out" | awk 'NR==2 {gsub("%","",$5); print $5}')
    if [[ "$pct" =~ ^[0-9]+$ ]] && [ "$pct" -ge 0 ] && [ "$pct" -le 100 ]; then
        root_used="$pct"
    fi
fi
echo "ROOT_USED_PERCENT=$root_used"

mounts_json="[]"
if command -v findmnt >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    mounts_json=$(findmnt -J -l -o TARGET,SOURCE,FSTYPE,USED,SIZE,USE% 2>/dev/null | jq -c '[.filesystems[]? | select(.target == "/" or ((.source | startswith("/dev/")) and (.source | startswith("/dev/loop") | not) and (.fstype != "devtmpfs") and (.fstype != "tmpfs"))) | {target: .target, source: .source, fstype: .fstype, used: (.used // ""), size: (.size // ""), percent: (.["use%"] | rtrimstr("%") | tonumber? // 0)}] | unique_by(.target) | sort_by(.target != "/", .target)' 2>/dev/null || echo "[]")
fi
if [[ -z "$mounts_json" || "$mounts_json" == "[]" || "$mounts_json" != *"\"target\":\"/\""* ]]; then
    if [[ "$root_used" =~ ^[0-9]+$ ]]; then
        mounts_json="[{\"target\":\"/\",\"source\":\"root\",\"fstype\":\"\",\"used\":\"\",\"size\":\"\",\"percent\":$root_used}]"
    else
        mounts_json="[]"
    fi
fi
echo "MOUNTS_JSON=$mounts_json"

# 5. Extended: GPU utilization & VRAM
gpu_percent="NA"
gpu_mem_percent="NA"
gpu_mem_used_str="NA"
gpu_backend="unsupported"

# Tier 1: /sys/class/drm/card*/device/gpu_busy_percent
max_drm_gpu=-1
drm_vram_pct=-1
drm_vram_used_str="NA"
shopt -s nullglob
drm_files=(/sys/class/drm/card*/device/gpu_busy_percent)
shopt -u nullglob

for f in "${drm_files[@]}"; do
    if [[ -r "$f" ]]; then
        val=$(cat "$f" 2>/dev/null || echo "")
        if [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -ge 0 ] && [ "$val" -le 100 ]; then
            if [ "$val" -gt "$max_drm_gpu" ]; then
                max_drm_gpu="$val"
                dev_dir=$(dirname "$f")
                if [[ -r "$dev_dir/mem_info_vram_used" && -r "$dev_dir/mem_info_vram_total" ]]; then
                    v_used=$(cat "$dev_dir/mem_info_vram_used" 2>/dev/null || echo "0")
                    v_total=$(cat "$dev_dir/mem_info_vram_total" 2>/dev/null || echo "0")
                    if [[ "$v_used" =~ ^[0-9]+$ && "$v_total" =~ ^[0-9]+$ ]] && [ "$v_total" -gt 0 ]; then
                        drm_vram_pct=$(( (v_used * 100) / v_total ))
                        v_used_mb=$(( v_used / 1048576 ))
                        if [ "$v_used_mb" -ge 1024 ]; then
                            drm_vram_used_str=$(awk "BEGIN {printf \"%.1f GB\", $v_used / 1073741824}")
                        else
                            drm_vram_used_str="${v_used_mb} MB"
                        fi
                    fi
                fi
            fi
        fi
    fi
done

if [ "$max_drm_gpu" -ge 0 ]; then
    gpu_percent="$max_drm_gpu"
    gpu_backend="drm"
    if [ "$drm_vram_pct" -ge 0 ] && [ "$drm_vram_pct" -le 100 ]; then
        gpu_mem_percent="$drm_vram_pct"
        gpu_mem_used_str="$drm_vram_used_str"
    fi
elif command -v nvidia-smi >/dev/null 2>&1; then
    # Tier 2: nvidia-smi
    max_nv_gpu=-1
    nv_vram_pct=-1
    nv_vram_used_str="NA"
    if nv_out=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null); then
        while IFS=',' read -r util used total; do
            u_val=$(echo "$util" | tr -d '[:space:]')
            m_used=$(echo "$used" | tr -d '[:space:]')
            m_total=$(echo "$total" | tr -d '[:space:]')
            if [[ "$u_val" =~ ^[0-9]+$ ]] && [ "$u_val" -ge 0 ] && [ "$u_val" -le 100 ]; then
                if [ "$u_val" -gt "$max_nv_gpu" ]; then
                    max_nv_gpu="$u_val"
                    if [[ "$m_used" =~ ^[0-9]+$ && "$m_total" =~ ^[0-9]+$ ]] && [ "$m_total" -gt 0 ]; then
                        nv_vram_pct=$(( (m_used * 100) / m_total ))
                        if [ "$m_used" -ge 1024 ]; then
                            nv_vram_used_str=$(awk "BEGIN {printf \"%.1f GB\", $m_used / 1024}")
                        else
                            nv_vram_used_str="${m_used} MB"
                        fi
                    fi
                fi
            fi
        done <<< "$nv_out"
    fi
    if [ "$max_nv_gpu" -ge 0 ]; then
        gpu_percent="$max_nv_gpu"
        gpu_backend="nvidia"
        if [ "$nv_vram_pct" -ge 0 ] && [ "$nv_vram_pct" -le 100 ]; then
            gpu_mem_percent="$nv_vram_pct"
            gpu_mem_used_str="$nv_vram_used_str"
        fi
    fi
fi

echo "GPU_PERCENT=$gpu_percent"
echo "GPU_MEM_PERCENT=$gpu_mem_percent"
echo "GPU_MEM_USED_STR=$gpu_mem_used_str"
echo "GPU_BACKEND=$gpu_backend"
