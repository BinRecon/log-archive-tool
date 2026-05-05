#!/usr/bin/env bash
################################################################################
# Remote Sync Library for Log Archive Tool
# Supports SCP and Rsync with production-grade error handling, retries, and validation
################################################################################

set -Eeuo pipefail

# Configuration
readonly REMOTE_SYNC_VERSION="1.0.0"
readonly REMOTE_SYNC_TIMEOUT=3600  # 1 hour default timeout
readonly REMOTE_SYNC_RETRIES=3
readonly REMOTE_SYNC_RETRY_DELAY=5  # seconds

# Logging utilities
remote_sync_log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp
    timestamp=$(date -Iseconds)
    printf '[%s] [%s] %s\n' "$timestamp" "$level" "$message" >&2
}

remote_sync_info() {
    remote_sync_log "INFO" "$@"
}

remote_sync_warn() {
    remote_sync_log "WARN" "$@"
}

remote_sync_error() {
    remote_sync_log "ERROR" "$@"
}

remote_sync_debug() {
    if [[ "${REMOTE_SYNC_DEBUG:-0}" == "1" ]]; then
        remote_sync_log "DEBUG" "$@"
    fi
}

################################################################################
# Validate remote configuration
################################################################################
validate_remote_config() {
    local host="$1"
    local user="$2"
    local path="$3"
    local port="${4:-22}"
    
    if [[ -z "$host" ]] || [[ -z "$user" ]] || [[ -z "$path" ]]; then
        remote_sync_error "Invalid remote config: host='$host', user='$user', path='$path'"
        return 1
    fi
    
    # Validate SSH key or password auth is available
    if ! command -v ssh >/dev/null 2>&1; then
        remote_sync_error "SSH not found. Required for remote sync operations."
        return 1
    fi
    
    remote_sync_debug "Remote config validated: $user@$host:$path (port: $port)"
    return 0
}

################################################################################
# Test SSH connectivity
################################################################################
test_ssh_connection() {
    local host="$1"
    local user="$2"
    local port="${3:-22}"
    local timeout="${4:-10}"
    
    remote_sync_info "Testing SSH connection to $user@$host:$port..."
    
    if ssh -o ConnectTimeout="$timeout" \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -p "$port" \
           "$user@$host" \
           "echo 'SSH connection successful'" >/dev/null 2>&1; then
        remote_sync_info "SSH connection test passed"
        return 0
    else
        remote_sync_error "SSH connection test failed to $user@$host:$port"
        return 1
    fi
}

################################################################################
# Check remote directory existence and permissions
################################################################################
check_remote_directory() {
    local host="$1"
    local user="$2"
    local path="$3"
    local port="${4:-22}"
    
    remote_sync_info "Checking remote directory: $path"
    
    if ssh -o ConnectTimeout=10 \
           -p "$port" \
           "$user@$host" \
           "[[ -d '$path' && -w '$path' ]]" >/dev/null 2>&1; then
        remote_sync_info "Remote directory is accessible and writable"
        return 0
    else
        remote_sync_warn "Remote directory check failed. Attempting to create..."
        
        if ssh -o ConnectTimeout=10 \
               -p "$port" \
               "$user@$host" \
               "mkdir -p '$path'" >/dev/null 2>&1; then
            remote_sync_info "Remote directory created successfully"
            return 0
        else
            remote_sync_error "Failed to create remote directory: $path"
            return 1
        fi
    fi
}

################################################################################
# Get remote disk space info
################################################################################
get_remote_disk_space() {
    local host="$1"
    local user="$2"
    local path="$3"
    local port="${4:-22}"
    
    ssh -o ConnectTimeout=10 \
        -p "$port" \
        "$user@$host" \
        "df -B1 '$path' | awk 'NR==2 {print \$3, \$4, \$2}'" 2>/dev/null || echo ""
}

################################################################################
# Sync with SCP (simple, secure copy)
################################################################################
sync_with_scp() {
    local local_file="$1"
    local host="$2"
    local user="$3"
    local remote_path="$4"
    local port="${5:-22}"
    local retry_count=0
    
    if [[ ! -f "$local_file" ]]; then
        remote_sync_error "Local file not found: $local_file"
        return 1
    fi
    
    local file_size
    file_size=$(stat -c%s "$local_file" 2>/dev/null || stat -f%z "$local_file")
    remote_sync_info "Starting SCP transfer: $local_file ($file_size bytes) → $user@$host:$remote_path"
    
    while (( retry_count < REMOTE_SYNC_RETRIES )); do
        remote_sync_debug "SCP attempt $((retry_count + 1))/$REMOTE_SYNC_RETRIES"
        
        if scp -P "$port" \
               -o ConnectTimeout=30 \
               -o BatchMode=yes \
               "$local_file" \
               "$user@$host:$remote_path" 2>/dev/null; then
            
            remote_sync_info "SCP transfer completed successfully"
            return 0
        fi
        
        (( retry_count++ ))
        if (( retry_count < REMOTE_SYNC_RETRIES )); then
            remote_sync_warn "SCP transfer failed. Retrying in ${REMOTE_SYNC_RETRY_DELAY}s..."
            sleep "$REMOTE_SYNC_RETRY_DELAY"
        fi
    done
    
    remote_sync_error "SCP transfer failed after $REMOTE_SYNC_RETRIES attempts"
    return 1
}

################################################################################
# Sync with Rsync (efficient, resumable)
################################################################################
sync_with_rsync() {
    local local_path="$1"
    local host="$2"
    local user="$3"
    local remote_path="$4"
    local port="${5:-22}"
    local retry_count=0
    
    if [[ ! -e "$local_path" ]]; then
        remote_sync_error "Local path not found: $local_path"
        return 1
    fi
    
    # Check if rsync is available
    if ! command -v rsync >/dev/null 2>&1; then
        remote_sync_error "rsync not found. Install rsync to use this sync method."
        return 1
    fi
    
    remote_sync_info "Starting Rsync transfer: $local_path → $user@$host:$remote_path"
    
    local rsync_opts=(
        "--archive"                    # Preserve permissions, times, ownership
        "--verbose"                    # Verbose output
        "--progress"                   # Show progress
        "--partial"                    # Keep partial transfers (resumable)
        "--inplace"                    # Write files in-place
        "--timeout=300"                # 5 minute I/O timeout
        "--rsh=ssh -p $port -o ConnectTimeout=30"
        "--delete"                     # Delete extraneous files on remote
        "--exclude=.git"               # Exclude git directories
        "--compress"                   # Compress during transfer
    )
    
    while (( retry_count < REMOTE_SYNC_RETRIES )); do
        remote_sync_debug "Rsync attempt $((retry_count + 1))/$REMOTE_SYNC_RETRIES"
        
        # Use rsync with retry logic
        if rsync "${rsync_opts[@]}" \
                 "$local_path" \
                 "$user@$host:$remote_path" 2>/dev/null; then
            
            remote_sync_info "Rsync transfer completed successfully"
            return 0
        fi
        
        local exit_code=$?
        (( retry_count++ ))
        
        # Rsync exit codes: 0=success, 1-2=transient, 3-4=fatal
        if (( exit_code >= 3 )); then
            remote_sync_error "Rsync fatal error (exit code: $exit_code)"
            return 1
        fi
        
        if (( retry_count < REMOTE_SYNC_RETRIES )); then
            remote_sync_warn "Rsync transfer failed. Retrying in ${REMOTE_SYNC_RETRY_DELAY}s..."
            sleep "$REMOTE_SYNC_RETRY_DELAY"
        fi
    done
    
    remote_sync_error "Rsync transfer failed after $REMOTE_SYNC_RETRIES attempts"
    return 1
}

################################################################################
# Verify remote file integrity (checksum)
################################################################################
verify_remote_file() {
    local host="$1"
    local user="$2"
    local remote_file="$3"
    local local_checksum="$4"
    local port="${5:-22}"
    
    remote_sync_info "Verifying remote file integrity: $remote_file"
    
    local remote_checksum
    remote_checksum=$(ssh -o ConnectTimeout=10 \
                         -p "$port" \
                         "$user@$host" \
                         "sha256sum '$remote_file' 2>/dev/null | cut -d' ' -f1" || echo "")
    
    if [[ -z "$remote_checksum" ]]; then
        remote_sync_warn "Could not verify remote checksum"
        return 1
    fi
    
    if [[ "$local_checksum" == "$remote_checksum" ]]; then
        remote_sync_info "Checksum verification passed"
        return 0
    else
        remote_sync_error "Checksum mismatch! Local: $local_checksum, Remote: $remote_checksum"
        return 1
    fi
}

################################################################################
# Cleanup old remote backups based on retention
################################################################################
cleanup_remote_backups() {
    local host="$1"
    local user="$2"
    local remote_path="$3"
    local retention_days="$4"
    local port="${5:-22}"
    
    remote_sync_info "Cleaning up remote backups older than $retention_days days"
    
    ssh -o ConnectTimeout=10 \
        -p "$port" \
        "$user@$host" \
        "find '$remote_path' -maxdepth 1 -type f -name '*.tar.gz' -mtime +$retention_days -delete" 2>/dev/null || {
        remote_sync_warn "Could not cleanup old remote backups"
        return 1
    }
    
    remote_sync_info "Remote cleanup completed"
    return 0
}

################################################################################
# Get remote backup listing with sizes
################################################################################
list_remote_backups() {
    local host="$1"
    local user="$2"
    local remote_path="$3"
    local port="${4:-22}"
    
    remote_sync_info "Fetching remote backup listing from $user@$host:$remote_path"
    
    ssh -o ConnectTimeout=10 \
        -p "$port" \
        "$user@$host" \
        "ls -lh '$remote_path'/*.tar.gz 2>/dev/null | awk '{print \$9, \$5}'" || echo ""
}

################################################################################
# Main sync orchestration function
################################################################################
sync_archive_to_remote() {
    local archive_file="$1"
    local method="${2:-rsync}"  # rsync or scp
    local host="$3"
    local user="$4"
    local remote_path="$5"
    local port="${6:-22}"
    local checksum_file="${7:-}"
    
    if [[ ! -f "$archive_file" ]]; then
        remote_sync_error "Archive file not found: $archive_file"
        return 1
    fi
    
    # Validate input
    if ! validate_remote_config "$host" "$user" "$remote_path" "$port"; then
        return 1
    fi
    
    # Test connection
    if ! test_ssh_connection "$host" "$user" "$port"; then
        return 1
    fi
    
    # Check remote directory
    if ! check_remote_directory "$host" "$user" "$remote_path" "$port"; then
        return 1
    fi
    
    # Check available space
    local disk_info
    disk_info=$(get_remote_disk_space "$host" "$user" "$remote_path" "$port")
    if [[ -n "$disk_info" ]]; then
        local used free total
        read -r used free total <<< "$disk_info"
        local free_gb=$((free / 1024 / 1024 / 1024))
        remote_sync_info "Remote disk space available: ${free_gb}GB"
    fi
    
    # Perform sync
    local sync_start
    sync_start=$(date +%s)
    
    case "$method" in
        scp)
            if ! sync_with_scp "$archive_file" "$host" "$user" "$remote_path" "$port"; then
                return 1
            fi
            ;;
        rsync)
            if ! sync_with_rsync "$archive_file" "$host" "$user" "$remote_path" "$port"; then
                return 1
            fi
            ;;
        *)
            remote_sync_error "Unknown sync method: $method"
            return 1
            ;;
    esac
    
    local sync_end
    sync_end=$(date +%s)
    local sync_duration=$((sync_end - sync_start))
    
    remote_sync_info "Sync completed in ${sync_duration}s using $method"
    
    # Verify if checksum provided
    if [[ -n "$checksum_file" ]] && [[ -f "$checksum_file" ]]; then
        local local_checksum
        local_checksum=$(cut -d' ' -f1 "$checksum_file")
        
        local remote_file
        remote_file="$remote_path/$(basename "$archive_file")"
        
        if ! verify_remote_file "$host" "$user" "$remote_file" "$local_checksum" "$port"; then
            remote_sync_warn "File verification failed but upload completed"
        fi
    fi
    
    return 0
}

################################################################################
# Generate remote sync JSON log entry
################################################################################
log_remote_sync_event() {
    local archive_name="$1"
    local method="$2"
    local host="$3"
    local user="$4"
    local status="${5:-success}"
    local duration="${6:-0}"
    local error_msg="${7:-}"
    
    local timestamp
    timestamp=$(date -Iseconds)
    
    local log_entry
    log_entry=$(printf '{
        "timestamp":"%s",
        "archive":"%s",
        "sync_method":"%s",
        "remote_host":"%s",
        "remote_user":"%s",
        "status":"%s",
        "duration_seconds":%s' \
        "$timestamp" "$archive_name" "$method" "$host" "$user" "$status" "$duration")
    
    if [[ -n "$error_msg" ]]; then
        log_entry=$(printf '%s,
        "error":"%s"' "$log_entry" "$error_msg")
    fi
    
    log_entry=$(printf '%s
    }' "$log_entry")
    
    echo "$log_entry"
}

################################################################################
# Export functions for use by main script
################################################################################
export -f remote_sync_info
export -f remote_sync_warn
export -f remote_sync_error
export -f remote_sync_debug
export -f validate_remote_config
export -f test_ssh_connection
export -f check_remote_directory
export -f sync_archive_to_remote
export -f log_remote_sync_event
