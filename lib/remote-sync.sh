#!/usr/bin/env bash
# Remote Sync Library for Log Archive Tool
# Provides reusable functions for SCP/Rsync operations
# Author: Shuvo Halder
# License: MIT

set -Eeuo pipefail

# Configuration
readonly REMOTE_SYNC_TIMEOUT="${REMOTE_SYNC_TIMEOUT:-3600}"
readonly REMOTE_SYNC_DEBUG="${REMOTE_SYNC_DEBUG:-0}"
readonly MAX_RETRIES="${MAX_RETRIES:-3}"
readonly RETRY_DELAY="${RETRY_DELAY:-5}"

# ========== LOGGING FUNCTIONS ==========

_remote_sync_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message" >&2
}

remote_sync_debug() {
    [[ "$REMOTE_SYNC_DEBUG" == "1" ]] && _remote_sync_log "DEBUG" "$@"
}

remote_sync_info() {
    _remote_sync_log "INFO" "$@"
}

remote_sync_warn() {
    _remote_sync_log "WARN" "$@"
}

remote_sync_error() {
    _remote_sync_log "ERROR" "$@"
}

# ========== VALIDATION FUNCTIONS ==========

validate_ssh_host() {
    local host="$1"
    local user="$2"
    local port="${3:-22}"
    local key="${4:-}"
    
    local ssh_opts="-o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
    
    if [[ -n "$key" ]]; then
        ssh_opts="$ssh_opts -i $key"
    fi
    
    remote_sync_debug "Testing SSH connection: $user@$host:$port"
    
    # shellcheck disable=SC2086
    if ssh -p "$port" $ssh_opts "$user@$host" "echo 'SSH OK'" &> /dev/null; then
        remote_sync_info "SSH connection validated"
        return 0
    else
        remote_sync_error "SSH connection failed to $user@$host:$port"
        return 1
    fi
}

validate_remote_directory() {
    local host="$1"
    local user="$2"
    local path="$3"
    local port="${4:-22}"
    local key="${5:-}"
    
    local ssh_opts="-o ConnectTimeout=10 -o BatchMode=yes"
    
    if [[ -n "$key" ]]; then
        ssh_opts="$ssh_opts -i $key"
    fi
    
    remote_sync_debug "Validating remote directory: $path on $host"
    
    # shellcheck disable=SC2086
    if ssh -p "$port" $ssh_opts "$user@$host" "[[ -d $path ]]" 2>/dev/null; then
        remote_sync_info "Remote directory validated: $path"
        return 0
    else
        remote_sync_warn "Remote directory does not exist: $path (will attempt to create)"
        
        # Try to create directory
        # shellcheck disable=SC2086
        if ssh -p "$port" $ssh_opts "$user@$host" "mkdir -p $path" 2>/dev/null; then
            remote_sync_info "Remote directory created: $path"
            return 0
        else
            remote_sync_error "Failed to create remote directory: $path"
            return 1
        fi
    fi
}

check_remote_disk_space() {
    local host="$1"
    local user="$2"
    local path="$3"
    local required_gb="${4:-1}"
    local port="${5:-22}"
    local key="${6:-}"
    
    local ssh_opts="-o ConnectTimeout=10 -o BatchMode=yes"
    
    if [[ -n "$key" ]]; then
        ssh_opts="$ssh_opts -i $key"
    fi
    
    remote_sync_debug "Checking remote disk space on $host:$path"
    
    # shellcheck disable=SC2086
    local available_gb
    available_gb=$(ssh -p "$port" $ssh_opts "$user@$host" \
        "df -B 1G \"$path\" 2>/dev/null | awk 'NR==2 {print \$4}' || echo 0" 2>/dev/null) || available_gb=0
    
    if (( available_gb >= required_gb )); then
        remote_sync_info "Disk space check passed: ${available_gb}GB available (required: ${required_gb}GB)"
        return 0
    else
        remote_sync_error "Insufficient disk space: ${available_gb}GB available (required: ${required_gb}GB)"
        return 1
    fi
}

# ========== FILE VERIFICATION ==========

verify_remote_checksum() {
    local host="$1"
    local user="$2"
    local remote_path="$3"
    local archive_file="$4"
    local local_checksum="$5"
    local port="${6:-22}"
    local key="${7:-}"
    
    local ssh_opts="-o ConnectTimeout=10 -o BatchMode=yes"
    
    if [[ -n "$key" ]]; then
        ssh_opts="$ssh_opts -i $key"
    fi
    
    remote_sync_debug "Verifying remote checksum for $archive_file"
    
    # shellcheck disable=SC2086
    local remote_checksum
    remote_checksum=$(ssh -p "$port" $ssh_opts "$user@$host" \
        "sha256sum $remote_path/$archive_file 2>/dev/null | awk '{print \$1}' || echo 'NOT_FOUND'" 2>/dev/null) || remote_checksum="ERROR"
    
    if [[ "$local_checksum" == "$remote_checksum" ]]; then
        remote_sync_info "Checksum verified: $archive_file"
        return 0
    else
        remote_sync_error "Checksum mismatch for $archive_file"
        remote_sync_error "Local: $local_checksum"
        remote_sync_error "Remote: $remote_checksum"
        return 1
    fi
}

# ========== RSYNC OPERATIONS ==========

rsync_transfer() {
    local local_file="$1"
    local host="$2"
    local user="$3"
    local remote_path="$4"
    local port="${5:-22}"
    local key="${6:-}"
    
    local rsync_opts="-av --checksum --progress --timeout=300"
    local ssh_opts="-e \"ssh -p $port"
    
    if [[ -n "$key" ]]; then
        ssh_opts="$ssh_opts -i $key"
    fi
    
    ssh_opts="$ssh_opts -o BatchMode=yes -o StrictHostKeyChecking=accept-new\""
    
    remote_sync_debug "Starting Rsync transfer: $local_file"
    
    local attempt=1
    while (( attempt <= MAX_RETRIES )); do
        remote_sync_info "Rsync attempt $attempt/$MAX_RETRIES"
        
        # shellcheck disable=SC2086
        if rsync $rsync_opts $ssh_opts "$local_file" "$user@$host:$remote_path/" 2>&1; then
            remote_sync_info "Rsync transfer completed successfully"
            return 0
        else
            remote_sync_warn "Rsync transfer failed (attempt $attempt/$MAX_RETRIES)"
            
            if (( attempt < MAX_RETRIES )); then
                remote_sync_info "Retrying in ${RETRY_DELAY}s..."
                sleep "$RETRY_DELAY"
            fi
        fi
        
        (( attempt++ ))
    done
    
    remote_sync_error "Rsync transfer failed after $MAX_RETRIES attempts"
    return 1
}

# ========== SCP OPERATIONS ==========

scp_transfer() {
    local local_file="$1"
    local host="$2"
    local user="$3"
    local remote_path="$4"
    local port="${5:-22}"
    local key="${6:-}"
    
    local scp_opts="-p -P $port"
    
    if [[ -n "$key" ]]; then
        scp_opts="$scp_opts -i $key"
    fi
    
    remote_sync_debug "Starting SCP transfer: $local_file"
    
    local attempt=1
    while (( attempt <= MAX_RETRIES )); do
        remote_sync_info "SCP attempt $attempt/$MAX_RETRIES"
        
        # shellcheck disable=SC2086
        if scp $scp_opts "$local_file" "$user@$host:$remote_path/" 2>&1; then
            remote_sync_info "SCP transfer completed successfully"
            return 0
        else
            remote_sync_warn "SCP transfer failed (attempt $attempt/$MAX_RETRIES)"
            
            if (( attempt < MAX_RETRIES )); then
                remote_sync_info "Retrying in ${RETRY_DELAY}s..."
                sleep "$RETRY_DELAY"
            fi
        fi
        
        (( attempt++ ))
    done
    
    remote_sync_error "SCP transfer failed after $MAX_RETRIES attempts"
    return 1
}

# ========== COMBINED OPERATIONS ==========

rsync_backup() {
    local archive_file="$1"
    local checksum_file="$2"
    local host="$3"
    local user="$4"
    local remote_path="$5"
    local port="${6:-22}"
    local key="${7:-}"
    
    remote_sync_info "Starting Rsync backup: $archive_file"
    
    # Validate connection
    if ! validate_ssh_host "$host" "$user" "$port" "$key"; then
        return 1
    fi
    
    # Validate remote directory
    if ! validate_remote_directory "$host" "$user" "$remote_path" "$port" "$key"; then
        return 1
    fi
    
    # Get file size in GB (rough estimate)
    local size_gb
    size_gb=$(( $(stat -c%s "$archive_file" 2>/dev/null || stat -f%z "$archive_file") / 1073741824 + 1 ))
    
    # Check disk space
    if ! check_remote_disk_space "$host" "$user" "$remote_path" "$size_gb" "$port" "$key"; then
        return 1
    fi
    
    # Transfer archive
    if ! rsync_transfer "$archive_file" "$host" "$user" "$remote_path" "$port" "$key"; then
        return 1
    fi
    
    # Transfer checksum
    if ! rsync_transfer "$checksum_file" "$host" "$user" "$remote_path" "$port" "$key"; then
        remote_sync_warn "Failed to transfer checksum file"
    fi
    
    remote_sync_info "Rsync backup completed successfully"
    return 0
}

scp_backup() {
    local archive_file="$1"
    local checksum_file="$2"
    local host="$3"
    local user="$4"
    local remote_path="$5"
    local port="${6:-22}"
    local key="${7:-}"
    
    remote_sync_info "Starting SCP backup: $archive_file"
    
    # Validate connection
    if ! validate_ssh_host "$host" "$user" "$port" "$key"; then
        return 1
    fi
    
    # Validate remote directory
    if ! validate_remote_directory "$host" "$user" "$remote_path" "$port" "$key"; then
        return 1
    fi
    
    # Get file size in GB
    local size_gb
    size_gb=$(( $(stat -c%s "$archive_file" 2>/dev/null || stat -f%z "$archive_file") / 1073741824 + 1 ))
    
    # Check disk space
    if ! check_remote_disk_space "$host" "$user" "$remote_path" "$size_gb" "$port" "$key"; then
        return 1
    fi
    
    # Transfer archive
    if ! scp_transfer "$archive_file" "$host" "$user" "$remote_path" "$port" "$key"; then
        return 1
    fi
    
    # Transfer checksum
    if ! scp_transfer "$checksum_file" "$host" "$user" "$remote_path" "$port" "$key"; then
        remote_sync_warn "Failed to transfer checksum file"
    fi
    
    remote_sync_info "SCP backup completed successfully"
    return 0
}

# ========== CLEANUP OPERATIONS ==========

cleanup_remote_archives() {
    local host="$1"
    local user="$2"
    local remote_path="$3"
    local retention_days="${4:-30}"
    local port="${5:-22}"
    local key="${6:-}"
    
    local ssh_opts="-o ConnectTimeout=10 -o BatchMode=yes"
    
    if [[ -n "$key" ]]; then
        ssh_opts="$ssh_opts -i $key"
    fi
    
    remote_sync_info "Cleaning up remote archives older than $retention_days days"
    
    # shellcheck disable=SC2086
    if ssh -p "$port" $ssh_opts "$user@$host" \
        "find $remote_path -type f \\( -name '*.tar.gz' -o -name '*.tar.gz.sha256' \\) -mtime +$retention_days -delete" 2>/dev/null; then
        
        remote_sync_info "Remote cleanup completed"
        return 0
    else
        remote_sync_warn "Remote cleanup may have failed or nothing to delete"
        return 1
    fi
}

# Export functions for use in other scripts
export -f remote_sync_debug remote_sync_info remote_sync_warn remote_sync_error
export -f validate_ssh_host validate_remote_directory check_remote_disk_space
export -f verify_remote_checksum rsync_transfer scp_transfer
export -f rsync_backup scp_backup cleanup_remote_archives
