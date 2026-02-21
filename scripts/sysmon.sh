#!/bin/sh
# sysmon - System monitoring tool with visual bar charts
#
# Displays CPU, RAM, SWAP, and DISK usage with colored bar charts.
# Supports macOS and Linux.

VERSION="0.1.0"
SCRIPT_NAME="sysmon"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Global variables
OS_TYPE=""
TOP_COUNT=5
INTERVAL=0.5
SHOW_TOP_CPU=true
SHOW_TOP_MEM=true

# Detect OS
detect_os() {
    OS_TYPE=$(uname)
}

# Show help
show_help() {
    _ver="${MS_INSTALLED_VERSION:-$VERSION}"
    [ "$_ver" = "dev" ] && _ver_fmt="$_ver" || _ver_fmt="v${_ver}"
    printf "%b\n" "${CYAN}${SCRIPT_NAME} ${_ver_fmt}${NC}"
    printf "Real-time system monitoring with visual bar charts\n\n"
    printf "Usage:\n"
    printf "  %b\n\n" "${CYAN}${SCRIPT_NAME}${NC}                    Display all metrics with top processes"
    printf "Options:\n"
    printf "  -h, --help         Show this help message\n"
    printf "  -v, --version      Show version information\n\n"
    printf "Features:\n"
    printf "  • CPU, Memory, SWAP, Disk usage with color-coded bars\n"
    printf "  • Top 5 processes for CPU and Memory\n"
    printf "  • Auto color coding: Green (0-60%%), Yellow (60-80%%), Red (80-100%%)\n"
    printf "  • Disk I/O monitoring (read/write speeds)\n"
    printf "  • Real-time updates (0.5s refresh)\n"
    printf "  • Cross-platform: macOS and Linux\n\n"
    printf "Example:\n"
    printf "  %b\n" "${CYAN}${SCRIPT_NAME}${NC}"
}

# Show version
show_version() {
    _ver="${MS_INSTALLED_VERSION:-$VERSION}"
    if [ "$_ver" = "dev" ]; then
        printf "%s %s\n" "$SCRIPT_NAME" "$_ver"
    else
        printf "%s v%s\n" "$SCRIPT_NAME" "$_ver"
    fi
}

# Render bar chart with auto color (fixed 40-char width)
render_bar() {
    local percent=$1
    # Cap percentage at 100 to prevent overflow
    [ "$percent" -gt 100 ] && percent=100

    # Fixed bar width (standard 80-column terminal layout)
    local width=40
    local filled=$((percent * width / 100))
    local empty=$((width - filled))

    # Auto color based on usage (0-60: green, 60-80: yellow, 80-100: red)
    local color
    if [ "$percent" -ge 80 ]; then
        color="$RED"
    elif [ "$percent" -ge 60 ]; then
        color="$YELLOW"
    else
        color="$GREEN"
    fi

    # Render bar
    printf "%b[" "$color"
    local i=0
    while [ $i -lt $filled ]; do
        printf "▓"
        i=$((i + 1))
    done
    printf "%b" "$NC"
    i=0
    while [ $i -lt $empty ]; do
        printf "░"
        i=$((i + 1))
    done
    printf "]"
}

# Clear screen (full clear)
clear_screen() {
    printf "\033[2J\033[H"
}

# Move cursor to home (for updates without flicker)
move_cursor_home() {
    printf "\033[H"
}

# Count lines in text
count_lines() {
    printf "%s" "$1" | wc -l | tr -d ' '
}

# Display all content (direct output)
display_all_content() {
    # Get version from MS or fallback
    local _ver="${MS_INSTALLED_VERSION:-${VERSION:-unknown}}"
    [ "$_ver" = "dev" ] && _ver_fmt="$_ver" || _ver_fmt="v${_ver}"

    local title="System Monitor ${_ver_fmt}"
    local subtitle="$(uname) $(uname -r) | $(date '+%H:%M:%S')"

    # Display header
    display_header "$title" "$subtitle"

    # Display all metrics with integrated top processes
    display_all_metrics

    # Display footer
    printf "\n%bPress Ctrl+C to exit%b\n" "$CYAN" "$NC"
}

# Get CPU usage (macOS)
get_cpu_usage_macos() {
    # Parse "CPU usage: X% user, Y% sys, Z% idle" from top
    local cpu_line=$(top -l 1 2>/dev/null | grep "CPU usage")
    if [ -n "$cpu_line" ]; then
        # Extract idle percentage (find the field before "% idle")
        local cpu_idle=$(echo "$cpu_line" | awk '{for(i=1;i<=NF;i++) if($i=="idle") print $(i-1)}' | tr -d '%')
        if [ -n "$cpu_idle" ] && [ "$cpu_idle" != "" ]; then
            local usage=$((100 - ${cpu_idle%.*}))
            echo "$usage"
            return
        fi
    fi

    # Fallback to iostat if top fails
    local cpu_idle=$(iostat -c 2 2>/dev/null | tail -1 | awk '{print $6}')
    if [ -n "$cpu_idle" ] && [ "$cpu_idle" != "" ]; then
        local usage=$((100 - ${cpu_idle%.*}))
        echo "$usage"
    else
        echo "0"
    fi
}

# Get CPU usage (Linux)
get_cpu_usage_linux() {
    # Read /proc/stat twice and calculate
    grep 'cpu ' /proc/stat | awk '{print ($2+$4)*100/($2+$4+$5)}' 2>/dev/null | cut -d. -f1
}

# Get CPU usage (cross-platform)
get_cpu_usage() {
    if [ "$OS_TYPE" = "Darwin" ]; then
        get_cpu_usage_macos
    else
        get_cpu_usage_linux
    fi
}

# Get memory usage (macOS)
get_memory_usage_macos() {
    local vm=$(vm_stat 2>/dev/null)
    if [ -z "$vm" ]; then
        echo "0"
        return
    fi

    local active=$(echo "$vm" | grep "Pages active" | awk '{print $3}' | tr -d '.')
    local wired=$(echo "$vm" | grep "Pages wired" | awk '{print $4}' | tr -d '.')
    local compressed=$(echo "$vm" | grep "Pages occupied by compressor" | awk '{print $5}' | tr -d '.')

    local total_mem=$(sysctl -n hw.memsize 2>/dev/null)
    local page_size=4096
    local used=$(( (active + wired + compressed) * page_size ))
    local percent=$((used * 100 / total_mem))
    echo "$percent"
}

# Get memory usage (Linux)
get_memory_usage_linux() {
    local total=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    local available=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [ -z "$total" ] || [ -z "$available" ]; then
        echo "0"
        return
    fi
    local used=$((total - available))
    local percent=$((used * 100 / total))
    echo "$percent"
}

# Get memory usage (cross-platform)
get_memory_usage() {
    if [ "$OS_TYPE" = "Darwin" ]; then
        get_memory_usage_macos
    else
        get_memory_usage_linux
    fi
}

# Get memory info with RAW data (macOS) - returns "percent|used|total"
get_memory_info_macos() {
    local vm=$(vm_stat 2>/dev/null)
    if [ -z "$vm" ]; then
        echo "0|0|0"
        return
    fi

    local active=$(echo "$vm" | grep "Pages active" | awk '{print $3}' | tr -d '.')
    local wired=$(echo "$vm" | grep "Pages wired" | awk '{print $4}' | tr -d '.')
    local compressed=$(echo "$vm" | grep "Pages occupied by compressor" | awk '{print $5}' | tr -d '.')

    local total_mem=$(sysctl -n hw.memsize 2>/dev/null)
    local page_size=4096
    local used=$(( (active + wired + compressed) * page_size ))
    local percent=$((used * 100 / total_mem))

    # Convert to GB
    local used_gb=$(awk -v u="$used" 'BEGIN {printf "%.1f", u/1024/1024/1024}')
    local total_gb=$(awk -v t="$total_mem" 'BEGIN {printf "%.1f", t/1024/1024/1024}')

    echo "$percent|$used_gb|$total_gb"
}

# Get memory info with RAW data (Linux) - returns "percent|used|total"
get_memory_info_linux() {
    local total=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    local available=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [ -z "$total" ] || [ -z "$available" ]; then
        echo "0|0|0"
        return
    fi
    local used=$((total - available))
    local percent=$((used * 100 / total))

    # Convert KB to GB
    local used_gb=$(awk -v u="$used" 'BEGIN {printf "%.1f", u/1024/1024}')
    local total_gb=$(awk -v t="$total" 'BEGIN {printf "%.1f", t/1024/1024}')

    echo "$percent|$used_gb|$total_gb"
}

# Get memory info (cross-platform)
get_memory_info() {
    if [ "$OS_TYPE" = "Darwin" ]; then
        get_memory_info_macos
    else
        get_memory_info_linux
    fi
}

# Convert size with unit to MB
convert_to_mb() {
    local value="$1"
    if echo "$value" | grep -q "G"; then
        local num=$(echo "$value" | tr -d 'G')
        awk -v n="$num" 'BEGIN {printf "%.2f", n*1024}'
    else
        echo "$value" | tr -d 'M'
    fi
}

# Get SWAP usage (macOS)
get_swap_usage_macos() {
    # Parse "vm.swapusage: total = X  used = Y  free = Z"
    local swap_line=$(sysctl vm.swapusage 2>/dev/null)
    if [ -z "$swap_line" ]; then
        echo "0"
        return
    fi

    # Extract total and used values (format: "1024.00M" or "1.5G")
    local total_raw=$(echo "$swap_line" | awk '{print $4}')
    local used_raw=$(echo "$swap_line" | awk '{print $7}')

    # Convert to MB
    local total=$(convert_to_mb "$total_raw")
    local used=$(convert_to_mb "$used_raw")

    # Check if total is zero or empty
    if [ -z "$total" ] || [ "$total" = "0" ] || [ "${total%.*}" = "0" ]; then
        echo "0"
        return
    fi

    # Calculate percentage
    local percent=$(awk -v u="$used" -v t="$total" 'BEGIN {printf "%.0f", (u*100/t)}' 2>/dev/null)

    echo "${percent:-0}"
}

# Get SWAP info with RAW data (macOS) - returns "percent|used|total"
get_swap_info_macos() {
    local swap_line=$(sysctl vm.swapusage 2>/dev/null)
    if [ -z "$swap_line" ]; then
        echo "0|0|0"
        return
    fi

    local total_raw=$(echo "$swap_line" | awk '{print $4}')
    local used_raw=$(echo "$swap_line" | awk '{print $7}')

    # Convert to MB
    local total_mb=$(convert_to_mb "$total_raw")
    local used_mb=$(convert_to_mb "$used_raw")

    if [ -z "$total_mb" ] || [ "$total_mb" = "0" ] || [ "${total_mb%.*}" = "0" ]; then
        echo "0|0|0"
        return
    fi

    local percent=$(awk -v u="$used_mb" -v t="$total_mb" 'BEGIN {printf "%.0f", (u*100/t)}' 2>/dev/null)

    # Convert to GB for display
    local used_gb=$(awk -v u="$used_mb" 'BEGIN {printf "%.1f", u/1024}')
    local total_gb=$(awk -v t="$total_mb" 'BEGIN {printf "%.1f", t/1024}')

    echo "$percent|$used_gb|$total_gb"
}

# Get SWAP usage (Linux)
get_swap_usage_linux() {
    local total=$(grep SwapTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    local free=$(grep SwapFree /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [ -z "$total" ] || [ "$total" -eq 0 ]; then
        echo "0"
        return
    fi
    local used=$((total - free))
    local percent=$((used * 100 / total))
    echo "$percent"
}

# Get SWAP info with RAW data (Linux) - returns "percent|used|total"
get_swap_info_linux() {
    local total=$(grep SwapTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    local free=$(grep SwapFree /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [ -z "$total" ] || [ "$total" -eq 0 ]; then
        echo "0|0|0"
        return
    fi
    local used=$((total - free))
    local percent=$((used * 100 / total))

    # Convert KB to GB
    local used_gb=$(awk -v u="$used" 'BEGIN {printf "%.1f", u/1024/1024}')
    local total_gb=$(awk -v t="$total" 'BEGIN {printf "%.1f", t/1024/1024}')

    echo "$percent|$used_gb|$total_gb"
}

# Get SWAP usage (cross-platform)
get_swap_usage() {
    if [ "$OS_TYPE" = "Darwin" ]; then
        get_swap_usage_macos
    else
        get_swap_usage_linux
    fi
}

# Get SWAP info (cross-platform)
get_swap_info() {
    if [ "$OS_TYPE" = "Darwin" ]; then
        get_swap_info_macos
    else
        get_swap_info_linux
    fi
}

# Get disk usage (cross-platform)
get_disk_usage() {
    if [ "$OS_TYPE" = "Darwin" ]; then
        # macOS: Use /System/Volumes/Data for actual user data
        df -h /System/Volumes/Data 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%'
    else
        df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%'
    fi
}

# Get disk IO (macOS) - returns "read_MB/s|write_MB/s"
get_disk_io_macos() {
    # iostat returns KB/t, sample twice to get rate
    local io=$(iostat -d -c 1 -w 1 2>/dev/null | tail -1 | awk '{printf "%.1f|%.1f", $3/1024, $4/1024}')
    if [ -z "$io" ]; then
        echo "0.0|0.0"
    else
        echo "$io"
    fi
}

# Get disk IO (Linux) - returns "read_MB/s|write_MB/s"
get_disk_io_linux() {
    if [ ! -f /proc/diskstats ]; then
        echo "0.0|0.0"
        return
    fi
    # Simple average from iostat
    local io=$(iostat -dx 1 2 2>/dev/null | grep -E "^(sd|nvme|vd)" | tail -1 | awk '{printf "%.1f|%.1f", $6/1024, $7/1024}')
    if [ -z "$io" ]; then
        echo "0.0|0.0"
    else
        echo "$io"
    fi
}

# Get disk IO (cross-platform)
get_disk_io() {
    if [ "$OS_TYPE" = "Darwin" ]; then
        get_disk_io_macos
    else
        get_disk_io_linux
    fi
}

# Get disk info with RAW data - returns "percent|used|total|read_io|write_io"
get_disk_info() {
    local disk_line
    if [ "$OS_TYPE" = "Darwin" ]; then
        # macOS: Use /System/Volumes/Data for actual user data
        disk_line=$(df -h /System/Volumes/Data 2>/dev/null | tail -1)
    else
        disk_line=$(df -h / 2>/dev/null | tail -1)
    fi

    local percent=$(echo "$disk_line" | awk '{print $5}' | tr -d '%')
    local used=$(echo "$disk_line" | awk '{print $3}' | tr -d 'i')  # Remove 'i' from GiB -> GB
    local total=$(echo "$disk_line" | awk '{print $2}' | tr -d 'i')

    local io=$(get_disk_io)
    local read_io=$(echo "$io" | cut -d'|' -f1)
    local write_io=$(echo "$io" | cut -d'|' -f2)

    echo "$percent|$used|$total|$read_io|$write_io"
}

# Get top processes by CPU (macOS)
get_top_processes_cpu_macos() {
    local count=$1
    ps -Ao %cpu,comm -r 2>/dev/null | head -n $((count + 1)) | tail -n "$count"
}

# Get top processes by CPU (Linux)
get_top_processes_cpu_linux() {
    local count=$1
    ps -Ao %cpu,comm --sort=-%cpu 2>/dev/null | head -n $((count + 1)) | tail -n "$count"
}

# Get top processes by CPU (cross-platform)
get_top_processes_cpu() {
    local count=$1
    if [ "$OS_TYPE" = "Darwin" ]; then
        get_top_processes_cpu_macos "$count"
    else
        get_top_processes_cpu_linux "$count"
    fi
}

# Get top processes by memory (macOS)
get_top_processes_mem_macos() {
    local count=$1
    ps -Ao %mem,comm -r 2>/dev/null | head -n $((count + 1)) | tail -n "$count"
}

# Get top processes by memory (Linux)
get_top_processes_mem_linux() {
    local count=$1
    ps -Ao %mem,comm --sort=-%mem 2>/dev/null | head -n $((count + 1)) | tail -n "$count"
}

# Get top processes by memory (cross-platform)
get_top_processes_mem() {
    local count=$1
    if [ "$OS_TYPE" = "Darwin" ]; then
        get_top_processes_mem_macos "$count"
    else
        get_top_processes_mem_linux "$count"
    fi
}

# Display header (fixed 80-column width with box style)
display_header() {
    local title="$1"
    local subtitle="$2"

    # Fixed width: 80 columns
    local border_width=78  # 80 - 2 for border characters

    # Create top border
    local top_border="┏"
    local bottom_border="┗"
    local i=0
    while [ $i -lt $border_width ]; do
        top_border="${top_border}━"
        bottom_border="${bottom_border}━"
        i=$((i + 1))
    done
    top_border="${top_border}┓"
    bottom_border="${bottom_border}┛"

    # Calculate centering for title
    local title_len=${#title}
    local content_width=76  # 80 - 4 (2 for borders, 2 for spacing)
    local left_pad=$(( (content_width - title_len) / 2 ))
    local right_pad=$(( content_width - title_len - left_pad ))

    printf "%b%s%b\n" "${CYAN}${BOLD}" "$top_border" "${NC}"
    printf "%b┃%b %*s%b%s%b%*s %b┃%b\n" \
        "${CYAN}${BOLD}" "${NC}" \
        "$left_pad" "" "${BOLD}${YELLOW}" "$title" "${NC}" \
        "$right_pad" "" \
        "${CYAN}${BOLD}" "${NC}"

    if [ -n "$subtitle" ]; then
        local subtitle_len=${#subtitle}
        local sub_left=$(( (content_width - subtitle_len) / 2 ))
        local sub_right=$(( content_width - subtitle_len - sub_left ))
        printf "%b┃%b %*s%s%*s %b┃%b\n" \
            "${CYAN}${BOLD}" "${NC}" \
            "$sub_left" "" "$subtitle" \
            "$sub_right" "" \
            "${CYAN}${BOLD}" "${NC}"
    fi

    printf "%b%s%b\n" "${CYAN}${BOLD}" "$bottom_border" "${NC}"
    printf "\n"
}

# Display metric line with optional RAW data
display_metric() {
    local label="$1"
    local percent="$2"
    local raw="$3"  # Optional: "used|total" format

    printf "%-13s %3d%% " "$label:" "$percent"
    render_bar "$percent"

    # Display RAW data if provided
    if [ -n "$raw" ]; then
        printf " %b(%s)%b" "$CYAN" "$raw" "$NC"
    fi

    printf "\n"
}

# Display compact top processes
display_top_compact() {
    local sort_by="$1"
    local count="$2"

    local processes
    if [ "$sort_by" = "CPU" ]; then
        processes=$(get_top_processes_cpu "$count")
    else
        processes=$(get_top_processes_mem "$count")
    fi

    # Fixed process name width for 80-column layout
    # Format: "    • name     XX.X%"
    local max_name_width=50

    echo "$processes" | while IFS= read -r line; do
        local usage=$(echo "$line" | awk '{print $1}')
        local comm=$(echo "$line" | awk '{print $2}')

        # Truncate long process names
        if [ ${#comm} -gt "$max_name_width" ]; then
            comm="$(printf "%.${max_name_width}s" "$comm" | sed 's/...$/.../')"
        fi

        printf "    %b•%b %-${max_name_width}s %b%6s%%%b\n" \
            "$BOLD" "$NC" "$comm" "$YELLOW" "$usage" "$NC"
    done
}

# Display all metrics with integrated top processes
display_all_metrics() {
    local mem_info=$(get_memory_info)
    local mem_percent=$(echo "$mem_info" | cut -d'|' -f1)
    local mem_used=$(echo "$mem_info" | cut -d'|' -f2)
    local mem_total=$(echo "$mem_info" | cut -d'|' -f3)

    local swap_info=$(get_swap_info)
    local swap_percent=$(echo "$swap_info" | cut -d'|' -f1)
    local swap_used=$(echo "$swap_info" | cut -d'|' -f2)
    local swap_total=$(echo "$swap_info" | cut -d'|' -f3)

    local disk_info=$(get_disk_info)
    local disk_percent=$(echo "$disk_info" | cut -d'|' -f1)
    local disk_used=$(echo "$disk_info" | cut -d'|' -f2)
    local disk_total=$(echo "$disk_info" | cut -d'|' -f3)
    local disk_read=$(echo "$disk_info" | cut -d'|' -f4)
    local disk_write=$(echo "$disk_info" | cut -d'|' -f5)

    local cpu_usage=$(get_cpu_usage)

    # CPU + Top Processes
    display_metric "CPU" "$cpu_usage"
    if [ "$SHOW_TOP_CPU" = "true" ]; then
        display_top_compact "CPU" "$TOP_COUNT"
    fi
    printf "\n"

    # Memory + SWAP (on same line)
    printf "%-13s %3d%% " "Memory:" "$mem_percent"
    render_bar "$mem_percent"
    printf " %b(%sG / %sG)%b" "$CYAN" "$mem_used" "$mem_total" "$NC"

    # Add SWAP on same line if used
    if [ "$swap_percent" -gt 1 ]; then
        printf " %b|%b SWAP: %b%sG%b" "$BOLD" "$NC" "$YELLOW" "$swap_used" "$NC"
    fi
    printf "\n"

    # Top Memory Processes
    if [ "$SHOW_TOP_MEM" = "true" ]; then
        display_top_compact "Memory" "$TOP_COUNT"
    fi
    printf "\n"

    # Disk
    display_metric "Disk (/)" "$disk_percent" "${disk_used}/${disk_total} ↓${disk_read}MB/s ↑${disk_write}MB/s"
}

# Display CPU focused
display_cpu_focused() {
    local cpu_usage=$(get_cpu_usage)

    printf "%bCPU Usage:%b\n\n" "$BOLD" "$NC"
    display_metric "Total" "$cpu_usage"
}

# Display RAM focused
display_ram_focused() {
    local mem_usage=$(get_memory_usage)
    local swap_usage=$(get_swap_usage)

    printf "%bMemory Usage:%b\n\n" "$BOLD" "$NC"
    display_metric "RAM" "$mem_usage"
    display_metric "SWAP" "$swap_usage"
}

# Display disk focused
display_disk_focused() {
    local disk_usage=$(get_disk_usage)

    printf "%bDisk Usage:%b\n\n" "$BOLD" "$NC"
    display_metric "Root (/)" "$disk_usage"
}

# Display top processes
display_top_processes() {
    local sort_by="$1"

    printf "\n%bTop %d Processes (%s):%b\n" "$BOLD" "$TOP_COUNT" "$sort_by" "$NC"

    local processes
    if [ "$sort_by" = "CPU" ]; then
        processes=$(get_top_processes_cpu "$TOP_COUNT")
    else
        processes=$(get_top_processes_mem "$TOP_COUNT")
    fi

    echo "$processes" | while IFS= read -r line; do
        local usage=$(echo "$line" | awk '{print $1}')
        local comm=$(echo "$line" | awk '{print $2}')
        printf "  %-30s %6s%%\n" "$comm" "$usage"
    done
}

# Read key (non-blocking with timeout, no echo)
read_key() {
    # Save terminal settings
    local old_stty=$(stty -g 2>/dev/null)

    # Disable echo and canonical mode
    stty -echo -icanon min 0 time 0 2>/dev/null

    # Try to read with timeout
    local key=""
    if read -t "$INTERVAL" -n 1 key 2>/dev/null; then
        # Filter out unwanted keys (enter, escape sequences, etc.)
        case "$key" in
            ""|\n|\r) key="" ;;  # Ignore enter/newlines
            $'\033') key="" ;;   # Ignore escape sequences
        esac
    fi

    # Restore terminal settings
    stty "$old_stty" 2>/dev/null

    echo "$key"
}

# Render display (buffered for minimal flicker)
render_display() {
    # Capture all content output
    local content=$(display_all_content 2>&1)

    # Complete terminal reset for clean screen
    # \033c = Full terminal reset (clears screen + scrollback + resets cursor)
    printf "\033c%b" "$content"
}

# Main display loop
monitor_loop() {
    # Trap Ctrl+C
    trap 'clear_screen; printf "\n%bExiting...%b\n" "$CYAN" "$NC"; exit 0' INT TERM

    while true; do
        # Render display
        render_display

        # Wait for next update
        sleep "$INTERVAL"
    done
}

# Parse arguments
parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help|help)
                show_help
                exit 0
                ;;
            -v|--version|version)
                show_version
                exit 0
                ;;
            *)
                printf "%bError: Unknown option: %s%b\n" "$RED" "$1" "$NC" >&2
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Main
main() {
    detect_os
    parse_arguments "$@"
    monitor_loop
}

main "$@"
