#!/usr/bin/env bash
# Chrome Download Monitor Script - v4 with auto-detection of total size
# Checks download status and takes appropriate action
# Usage: chrome-download-monitor.sh [job_id]

set -euo pipefail

# Configuration
CDP_PORT=9222
DOWNLOAD_DIR="$HOME/Downloads"
CRDOWNLOAD_PATTERN="*.crdownload"
JOB_ID="${1:-}"
TOTAL_SIZE_FILE="/tmp/chrome-download-total-size"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Send message via cc-connect
send_message() {
    local message="$1"
    cc-connect send --message "$message" 2>/dev/null || log "Failed to send message: $message"
}

# Check if Chrome is running on debug port
check_chrome_running() {
    ss -tlnp | grep -q ":${CDP_PORT}" 2>/dev/null
}

# Get Chrome PID
get_chrome_pid() {
    ss -tlnp | grep ":${CDP_PORT}" | awk '{print $NF}' | sed 's/.*pid=\([0-9]*\).*/\1/'
}

# Get total download size from Chrome page
get_total_size_from_chrome() {
    # Navigate to downloads page
    agent-browser --cdp $CDP_PORT open "chrome://downloads" 2>/dev/null
    sleep 2
    
    # Extract total size from download item
    local total_size
    total_size=$(agent-browser --cdp $CDP_PORT eval "var root = document.querySelector('downloads-manager').shadowRoot; var item = root.querySelector('downloads-item'); if (item && item.shadowRoot) { var text = item.shadowRoot.textContent; var match = text.match(/共 ([\\d.]+ [KMGT]B)/); match ? match[1] : 'not found' } else { 'no item' }" 2>/dev/null | tail -n1 | grep -oE '[0-9.]+ [KMGT]B' | head -1)
    
    echo "$total_size"
}

# Convert human-readable size to bytes
convert_to_bytes() {
    local size_str="$1"
    local number unit
    
    # Extract number and unit
    if [[ "$size_str" =~ ([0-9.]+)\ ([KMGT]B) ]]; then
        number="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[2]}"
    else
        echo "0"
        return
    fi
    
    # Convert to bytes using awk
    case "$unit" in
        "KB") echo "$number" | awk '{printf "%d", $1 * 1024}' ;;
        "MB") echo "$number" | awk '{printf "%d", $1 * 1024 * 1024}' ;;
        "GB") echo "$number" | awk '{printf "%d", $1 * 1024 * 1024 * 1024}' ;;
        "TB") echo "$number" | awk '{printf "%d", $1 * 1024 * 1024 * 1024 * 1024}' ;;
        *) echo "0" ;;
    esac
}

# Save total size to file
save_total_size() {
    local total_size_str="$1"
    local total_size_bytes
    total_size_bytes=$(convert_to_bytes "$total_size_str")
    echo "$total_size_bytes" > "$TOTAL_SIZE_FILE"
    log "Saved total size: $total_size_str ($total_size_bytes bytes)"
}

# Load total size from file
load_total_size() {
    if [[ -f "$TOTAL_SIZE_FILE" ]]; then
        cat "$TOTAL_SIZE_FILE"
    else
        echo "0"
    fi
}

# Check download status
check_download_status() {
    # Check for .crdownload files
    local crdownload_files
    crdownload_files=$(find "$DOWNLOAD_DIR" -name "$CRDOWNLOAD_PATTERN" 2>/dev/null)
    
    if [[ -z "$crdownload_files" ]]; then
        echo "completed"
        return
    fi
    
    # Get the first .crdownload file
    local file
    file=$(echo "$crdownload_files" | head -1)
    
    # Check if download is progressing
    local size1
    size1=$(stat --format="%s" "$file" 2>/dev/null || echo "0")
    sleep 5
    local size2
    size2=$(stat --format="%s" "$file" 2>/dev/null || echo "0")
    
    if [[ "$size1" -eq "$size2" ]]; then
        echo "interrupted"
        echo "FILE:$file"
        echo "SIZE:$size1"
    else
        echo "in_progress"
        echo "FILE:$file"
        echo "SIZE:$size2"
        echo "GROWTH:$((size2 - size1))"
    fi
}

# Resume download
resume_download() {
    log "Attempting to resume download..."
    
    # Navigate to downloads page
    agent-browser --cdp $CDP_PORT open "chrome://downloads" 2>/dev/null
    sleep 2
    
    # Click more-actions menu
    agent-browser --cdp $CDP_PORT eval "var root = document.querySelector('downloads-manager').shadowRoot; var item = root.querySelector('downloads-item'); var menuBtn = item.shadowRoot.getElementById('more-actions'); if (menuBtn) { menuBtn.click(); 'menu opened' } else { 'not found' }" 2>/dev/null
    sleep 1
    
    # Click resume button
    agent-browser --cdp $CDP_PORT eval "var root = document.querySelector('downloads-manager').shadowRoot; var item = root.querySelector('downloads-item'); var btn = item.shadowRoot.getElementById('pause-or-resume'); if (btn) { btn.click(); 'resume clicked' } else { 'not found' }" 2>/dev/null
    
    sleep 2
    log "Download resumed"
}

# Close Chrome
close_chrome() {
    log "Closing Chrome..."
    local pid
    pid=$(get_chrome_pid)
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || true
        sleep 2
    fi
    # Force kill if still running
    pkill -f "chrome.*remote-debugging-port=$CDP_PORT" 2>/dev/null || true
}

# Start Chrome with debugging
start_chrome() {
    log "Starting Chrome with debugging..."
    systemd-run --user --unit=chrome-debug-$CDP_PORT \
        --setenv=WAYLAND_DISPLAY=wayland-1 \
        --setenv=XDG_SESSION_TYPE=wayland \
        --setenv=XDG_RUNTIME_DIR=/run/user/1000 \
        --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
        $(which google-chrome-stable) \
        --remote-debugging-port=$CDP_PORT \
        --user-data-dir=$HOME/.config/chrome-automation \
        --no-first-run \
        --disable-vulkan --disable-gpu \
        --disable-software-rasterizer \
        --ozone-platform-hint=auto
    
    sleep 5
    log "Chrome started"
}

# Check if download is complete by file size
check_file_size_match() {
    local crdownload_file
    crdownload_file=$(find "$DOWNLOAD_DIR" -name "$CRDOWNLOAD_PATTERN" 2>/dev/null | head -1)
    
    if [[ -z "$crdownload_file" ]]; then
        echo "no_crdownload"
        return
    fi
    
    local current_size
    current_size=$(stat --format="%s" "$crdownload_file" 2>/dev/null || echo "0")
    
    # Load expected size from file
    local expected_size
    expected_size=$(load_total_size)
    
    if [[ "$expected_size" -gt 0 ]]; then
        # Allow 5% tolerance for rounding errors and network variations
        local tolerance=$((expected_size / 20))
        local diff=$((current_size - expected_size))
        if [[ $diff -lt 0 ]]; then diff=$((-diff)); fi
        
        if [[ "$diff" -le "$tolerance" ]]; then
            echo "match"
        else
            echo "mismatch"
            echo "CURRENT:$current_size"
            echo "EXPECTED:$expected_size"
        fi
    else
        echo "unknown"
        echo "CURRENT:$current_size"
    fi
}

# Terminate cron job
terminate_job() {
    local job_id="$1"
    if [[ -n "$job_id" ]]; then
        log "Terminating cron job $job_id..."
        cc-connect cron del "$job_id" 2>/dev/null || log "Failed to terminate job $job_id"
    fi
}

# Format bytes to human readable
format_bytes() {
    local bytes="$1"
    numfmt --to=iec "$bytes" 2>/dev/null || echo "$bytes bytes"
}

# Main monitoring logic
main() {
    log "Starting Chrome download monitor..."
    
    if check_chrome_running; then
        log "Chrome is running on port $CDP_PORT"
        
        # Get total size from Chrome and save it
        local total_size_str
        total_size_str=$(get_total_size_from_chrome)
        if [[ "$total_size_str" != "not found" && "$total_size_str" != "no item" ]]; then
            save_total_size "$total_size_str"
        fi
        
        local status
        status=$(check_download_status)
        local status_type
        status_type=$(echo "$status" | head -1)
        
        case "$status_type" in
            "in_progress")
                local file size growth
                file=$(echo "$status" | grep "FILE:" | cut -d: -f2-)
                size=$(echo "$status" | grep "SIZE:" | cut -d: -f2-)
                growth=$(echo "$status" | grep "GROWTH:" | cut -d: -f2-)
                
                log "Download in progress: $file"
                log "Current size: $size bytes"
                log "Growth in last 5s: $growth bytes"
                
                # Calculate speed (bytes per second)
                local speed=$((growth / 5))
                local speed_kbps=$((speed / 1024))
                
                # Get total size for progress calculation
                local total_size
                total_size=$(load_total_size)
                local progress="unknown"
                if [[ "$total_size" -gt 0 ]]; then
                    local percent=$((size * 100 / total_size))
                    progress="${percent}%"
                fi
                
                send_message "📥 Download in progress
File: $(basename "$file")
Current: $(format_bytes $size) / $(format_bytes $total_size) ($progress)
Speed: ${speed_kbps} KB/s
Monitoring will continue..."
                ;;
                
            "interrupted")
                local file size
                file=$(echo "$status" | grep "FILE:" | cut -d: -f2-)
                size=$(echo "$status" | grep "SIZE:" | cut -d: -f2-)
                
                log "Download interrupted: $file"
                log "Current size: $size bytes"
                
                resume_download
                
                send_message "⚠️ Download was interrupted
File: $(basename "$file")
Size: $(format_bytes $size)
Attempting to resume..."
                ;;
                
            "completed")
                log "Download completed"
                
                close_chrome
                
                send_message "✅ Download completed
Chrome has been closed.
Monitoring terminated."
                
                # If job ID provided, terminate the cron job
                if [[ -n "$JOB_ID" ]]; then
                    terminate_job "$JOB_ID"
                fi
                ;;
                
            *)
                log "Unknown download status"
                send_message "❓ Unknown download status"
                ;;
        esac
        
    else
        log "Chrome is not running"
        
        # Check file size
        local size_status
        size_status=$(check_file_size_match)
        local size_status_type
        size_status_type=$(echo "$size_status" | head -1)
        
        case "$size_status_type" in
            "match")
                log "Download appears complete (file size matches)"
                send_message "✅ Download appears complete
File size matches expected size.
Monitoring terminated."
                
                # Terminate the cron job
                if [[ -n "$JOB_ID" ]]; then
                    terminate_job "$JOB_ID"
                fi
                ;;
                
            "mismatch")
                local current expected
                current=$(echo "$size_status" | grep "CURRENT:" | cut -d: -f2-)
                expected=$(echo "$size_status" | grep "EXPECTED:" | cut -d: -f2-)
                
                log "File size mismatch: current=$current, expected=$expected"
                
                # Restart Chrome
                start_chrome
                
                # Navigate to downloads and resume
                sleep 3
                agent-browser --cdp $CDP_PORT open "chrome://downloads" 2>/dev/null
                sleep 2
                resume_download
                
                send_message "🔄 Chrome was closed abnormally
File size mismatch: $(format_bytes $current) / $(format_bytes $expected)
Chrome restarted and download resumed."
                ;;
                
            "no_crdownload")
                log "No .crdownload file found - download may be complete"
                send_message "✅ No .crdownload file found
Download may be complete.
Monitoring terminated."
                
                if [[ -n "$JOB_ID" ]]; then
                    terminate_job "$JOB_ID"
                fi
                ;;
                
            "unknown")
                log "Cannot determine file size status"
                send_message "❓ Cannot determine file size status
Starting Chrome for manual check..."
                
                start_chrome
                sleep 3
                agent-browser --cdp $CDP_PORT open "chrome://downloads" 2>/dev/null
                ;;
        esac
    fi
    
    log "Monitor check completed"
}

# Run main function
main "$@"