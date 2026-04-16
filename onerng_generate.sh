#!/bin/bash
#
# OneRNG Random Data Generator for Raspberry Pi 5
# Generates 1GB of 256-bit (32-byte) random blobs from OneRNG 3.0
#
# Usage: ./onerng_generate.sh [output_directory]
#        If no directory specified, prompts to select a mounted USB drive
#

set -euo pipefail

# Configuration
TOTAL_BYTES=$((1024 * 1024 * 1024))  # 1GB total
BLOB_SIZE=32                          # 256 bits = 32 bytes
TOTAL_BLOBS=$((TOTAL_BYTES / BLOB_SIZE))  # 33,554,432 blobs
ONERNG_DEVICE="/dev/ttyACM0"          # Default OneRNG device (may vary)
BATCH_SIZE=1000                       # Blobs per progress update

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root (needed for device access)
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (sudo) for device access"
        exit 1
    fi
}

# Find and verify OneRNG device
find_onerng() {
    log_info "Searching for OneRNG device..."
    
    # Check common locations
    for dev in /dev/ttyACM0 /dev/ttyACM1 /dev/ttyUSB0 /dev/ttyUSB1; do
        if [[ -e "$dev" ]]; then
            # Check if it's a OneRNG by reading its USB info
            local devpath=$(udevadm info -q path -n "$dev" 2>/dev/null || true)
            if [[ -n "$devpath" ]]; then
                local vendor=$(cat "/sys${devpath}/../idVendor" 2>/dev/null || echo "")
                local product=$(cat "/sys${devpath}/../idProduct" 2>/dev/null || echo "")
                # OneRNG vendor ID is 1d50, product ID is 60c6
                if [[ "$vendor" == "1d50" && "$product" == "60c6" ]]; then
                    ONERNG_DEVICE="$dev"
                    log_info "Found OneRNG at $ONERNG_DEVICE"
                    return 0
                fi
            fi
        fi
    done
    
    # Fallback: check if /dev/ttyACM0 exists
    if [[ -e "/dev/ttyACM0" ]]; then
        ONERNG_DEVICE="/dev/ttyACM0"
        log_warn "Could not verify OneRNG, assuming $ONERNG_DEVICE"
        return 0
    fi
    
    log_error "OneRNG device not found. Please check connection."
    exit 1
}

# Initialize OneRNG - enable hardware RNG output
init_onerng() {
    log_info "Initializing OneRNG..."
    
    # Set serial parameters (115200 baud, 8N1)
    stty -F "$ONERNG_DEVICE" 115200 raw -echo -echoe -echok -echoctl -echoke
    
    # OneRNG command to enable random output (send 'O' to enable)
    # The OneRNG starts in "command mode" and needs to be switched to "RNG mode"
    echo -n "cmdO" > "$ONERNG_DEVICE"
    sleep 0.5
    
    # Flush any pending data
    timeout 1 cat "$ONERNG_DEVICE" > /dev/null 2>&1 || true
    
    log_info "OneRNG initialized"
}

# Find mounted removable USB drives
find_usb_drives() {
    log_info "Scanning for mounted USB drives..."
    
    local drives=()
    
    # Find mounted drives under /media or /mnt
    while IFS= read -r line; do
        local mountpoint=$(echo "$line" | awk '{print $3}')
        local device=$(echo "$line" | awk '{print $1}')
        local fstype=$(echo "$line" | awk '{print $5}')
        
        # Check if it's a USB device
        if [[ "$device" =~ ^/dev/sd[a-z] ]] || [[ "$device" =~ ^/dev/mmcblk[0-9] ]]; then
            # Exclude the boot drive (usually mmcblk0)
            if [[ ! "$device" =~ mmcblk0 ]]; then
                local size=$(df -h "$mountpoint" | tail -1 | awk '{print $2}')
                local avail=$(df -h "$mountpoint" | tail -1 | awk '{print $4}')
                drives+=("$mountpoint|$device|$fstype|$size|$avail")
            fi
        fi
    done < <(mount | grep -E "^/dev/(sd|mmcblk)")
    
    if [[ ${#drives[@]} -eq 0 ]]; then
        log_error "No mounted USB drives found."
        log_info "Please insert a USB drive and mount it, or specify output directory manually."
        log_info "Example: mount /dev/sda1 /mnt/usb"
        exit 1
    fi
    
    echo ""
    echo "Available USB drives:"
    echo "---------------------"
    local i=1
    for drive in "${drives[@]}"; do
        IFS='|' read -r mountpoint device fstype size avail <<< "$drive"
        echo "  $i) $mountpoint"
        echo "     Device: $device | FS: $fstype | Size: $size | Available: $avail"
        ((i++))
    done
    echo ""
    
    read -p "Select drive (1-${#drives[@]}): " selection
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || ((selection < 1 || selection > ${#drives[@]})); then
        log_error "Invalid selection"
        exit 1
    fi
    
    IFS='|' read -r OUTPUT_DIR _ <<< "${drives[$((selection-1))]}"
}

# Check available space
check_space() {
    local dir="$1"
    local required_kb=$((TOTAL_BYTES / 1024 + 1024))  # Add 1MB buffer
    local available_kb=$(df -k "$dir" | tail -1 | awk '{print $4}')
    
    if ((available_kb < required_kb)); then
        log_error "Insufficient space on $dir"
        log_error "Required: ~1GB, Available: $((available_kb / 1024))MB"
        exit 1
    fi
    
    log_info "Space check passed (need ~1GB, have $((available_kb / 1024))MB available)"
}

# Generate random blobs
generate_blobs() {
    local output_dir="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local blob_dir="${output_dir}/onerng_random_${timestamp}"
    
    mkdir -p "$blob_dir"
    log_info "Output directory: $blob_dir"
    log_info "Generating $TOTAL_BLOBS blobs of $BLOB_SIZE bytes each (1GB total)..."
    
    local start_time=$(date +%s)
    local count=0
    local errors=0
    
    # Generate blobs
    while ((count < TOTAL_BLOBS)); do
        # Generate filename with zero-padded number
        local filename=$(printf "blob_%08d.bin" $count)
        local filepath="${blob_dir}/${filename}"
        
        # Read 32 bytes from OneRNG
        if ! dd if="$ONERNG_DEVICE" of="$filepath" bs=$BLOB_SIZE count=1 2>/dev/null; then
            ((errors++))
            if ((errors > 10)); then
                log_error "Too many read errors. Check OneRNG connection."
                exit 1
            fi
            sleep 0.1
            continue
        fi
        
        # Verify file size
        local actual_size=$(stat -c %s "$filepath" 2>/dev/null || echo 0)
        if ((actual_size != BLOB_SIZE)); then
            rm -f "$filepath"
            ((errors++))
            continue
        fi
        
        ((count++))
        errors=0  # Reset error count on success
        
        # Progress update
        if ((count % BATCH_SIZE == 0)); then
            local elapsed=$(($(date +%s) - start_time))
            local rate=$((count * BLOB_SIZE / (elapsed + 1)))
            local percent=$((count * 100 / TOTAL_BLOBS))
            local eta=$(( (TOTAL_BLOBS - count) * (elapsed + 1) / (count + 1) ))
            
            printf "\r[%3d%%] Generated %d/%d blobs | Rate: %d bytes/sec | ETA: %dm %ds    " \
                "$percent" "$count" "$TOTAL_BLOBS" "$rate" "$((eta/60))" "$((eta%60))"
        fi
    done
    
    echo ""  # New line after progress
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    log_info "Generation complete!"
    log_info "Total time: $((total_time/3600))h $((total_time%3600/60))m $((total_time%60))s"
    log_info "Average rate: $((TOTAL_BYTES / (total_time + 1))) bytes/sec"
    log_info "Output directory: $blob_dir"
    
    # Final count
    local actual_count=$(ls -1 "${blob_dir}"/blob_*.bin 2>/dev/null | wc -l)
    local actual_total=$((actual_count * BLOB_SIZE))
    
    echo ""
    echo "=== Generation Summary ==="
    echo "Files generated: $actual_count"
    echo "Total size: $((actual_total / 1024 / 1024))MB"
    echo "Location: $blob_dir"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    # Reset OneRNG to command mode (optional)
    echo -n "cmdo" > "$ONERNG_DEVICE" 2>/dev/null || true
}

# Main
main() {
    echo "========================================"
    echo "  OneRNG Random Data Generator"
    echo "  1GB of 256-bit random blobs"
    echo "========================================"
    echo ""
    
    check_root
    find_onerng
    init_onerng
    
    # Determine output directory
    if [[ $# -ge 1 ]]; then
        OUTPUT_DIR="$1"
        if [[ ! -d "$OUTPUT_DIR" ]]; then
            log_error "Directory does not exist: $OUTPUT_DIR"
            exit 1
        fi
    else
        find_usb_drives
    fi
    
    check_space "$OUTPUT_DIR"
    
    trap cleanup EXIT
    
    generate_blobs "$OUTPUT_DIR"
    
    log_info "Done! Safely eject your USB drive before removing."
}

main "$@"
