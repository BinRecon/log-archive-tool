#!/usr/bin/env bash
# Log Archive Tool - Enhanced v2.0
# Robust Bash script for archiving logs with remote backup support (SCP/Rsync)
# Author: Shuvo Halder
# License: MIT

set -Eeuo pipefail

# Global configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
LOG_DIR=""
ARCHIVE_DIR="./log_archives"
RETENTION_DAYS=30
SYNC_METHOD="local"  # local, rsync, scp
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PATH=""
SSH_PORT=22
SSH_KEY=""
VERIFY_ARCHIVE=false
DEBUG_MODE=false
MAX_RETRIES=3
RETRY_DELAY=5

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ========== UTILITY FUNCTIONS ==========

log_debug() {
    [[ "$DEBUG_MODE" == true ]] && echo "[DEBUG] $*" >&2
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# JSON logging function
log_json() {
    local timestamp action status
    timestamp="$(date -Iseconds)"
    action="$1"
    status="${2:-success}"
    shift 2
    
    local json_data="{\"timestamp\":\"$timestamp\",\"action\":\"$action\",\"status\":\"$status\""
    
    while (( $# > 0 )); do
        json_data+=",\"$1\":\"$2\""
        shift 2
    done
    
    json_data+="}"
    
    echo "$json_data" >> "${ARCHIVE_DIR}/archive_log.jsonl"
    log_debug "Logged: $json_data"
}

# ========== HELP & VERSION ==========

show_help() {
    cat << EOF
${BLUE}Log Archive Tool v${SCRIPT_VERSION}${NC}

Usage: ${SCRIPT_NAME} --log-dir <directory> [OPTIONS]

REQUIRED OPTIONS:
  -l, --log-dir <dir>           Source log directory

OPTIONAL PARAMETERS:
  -a, --archive-dir <dir>       Archive output directory (default: ./log_archives)
  -r, --retention <days>        Retention days for old archives (default: 30)

REMOTE SYNC OPTIONS:
  -s, --sync-method <method>    Sync method: 'local', 'rsync', or 'scp' (default: local)
  -H, --remote-host <host>      Remote backup server hostname/IP
  -u, --remote-user <user>      Remote server SSH user
  -p, --remote-path <path>      Remote backup destination path
  -P, --ssh-port <port>         SSH port (default: 22)
  -k, --ssh-key <file>          SSH private key file

OTHER OPTIONS:
  -v, --verify                  Verify archive after creation
  -d, --debug                   Enable debug mode
  -h, --help                    Show this help message
  --version                     Show version information

EXAMPLES:

1. Local archive only:
   ${SCRIPT_NAME} --log-dir /var/log

2. Archive with Rsync backup:
   ${SCRIPT_NAME} --log-dir /var/log \\
     --sync-method rsync \\
     --remote-host backup.example.com \\
     --remote-user backup \\
     --remote-path /backups/logs \\
     --ssh-key ~/.ssh/backup-key

3. Archive with SCP backup:
   ${SCRIPT_NAME} --log-dir /var/log \\
     --sync-method scp \\
     --remote-host 192.168.1.10 \\
     --remote-user admin \\
     --remote-path /home/admin/backups

4. Debug mode:
   ${SCRIPT_NAME} --log-dir /var/log --debug --verify

EOF
}

show_version() {
    echo "Log Archive Tool v${SCRIPT_VERSION}"
    echo "Author: Shuvo Halder"
    echo "License: MIT"
}

# ========== ARGUMENT PARSING ==========

parse_arguments() {
    while (( $# > 0 )); do
        case "$1" in
            -l|--log-dir)
                LOG_DIR="$2"
                shift 2
                ;;
            -a|--archive-dir)
                ARCHIVE_DIR="$2"
                shift 2
                ;;
            -r|--retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            -s|--sync-method)
                SYNC_METHOD="$2"
                shift 2
                ;;
            -H|--remote-host)
                REMOTE_HOST="$2"
                shift 2
                ;;
            -u|--remote-user)
                REMOTE_USER="$2"
                shift 2
                ;;
            -p|--remote-path)
                REMOTE_PATH="$2"
                shift 2
                ;;
            -P|--ssh-port)
                SSH_PORT="$2"
                shift 2
                ;;
            -k|--ssh-key)
                SSH_KEY="$2"
                shift 2
                ;;
            -v|--verify)
                VERIFY_ARCHIVE=true
                shift
                ;;
            -d|--debug)
                DEBUG_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ========== VALIDATION FUNCTIONS ==========

validate_inputs() {
    # Check required parameters
    if [[ -z "$LOG_DIR" ]]; then
        log_error "Missing required parameter: --log-dir"
        show_help
        exit 1
    fi
    
    # Validate log directory
    if [[ ! -d "$LOG_DIR" ]]; then
        log_error "Log directory does not exist: $LOG_DIR"
        exit 1
    fi
    
    # Validate retention days
    if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
        log_error "Invalid retention days: $RETENTION_DAYS (must be a number)"
        exit 1
    fi
    
    # Validate sync method
    case "$SYNC_METHOD" in
        local|rsync|scp)
            :
            ;;
        *)
            log_error "Invalid sync method: $SYNC_METHOD (must be: local, rsync, or scp)"
            exit 1
            ;;
    esac
    
    # Validate remote parameters if not local
    if [[ "$SYNC_METHOD" != "local" ]]; then
        if [[ -z "$REMOTE_HOST" ]] || [[ -z "$REMOTE_USER" ]] || [[ -z "$REMOTE_PATH" ]]; then
            log_error "Missing remote parameters for sync method: $SYNC_METHOD"
            log_error "Required: --remote-host, --remote-user, --remote-path"
            exit 1
        fi
    fi
    
    log_debug "Validation passed"
    log_debug "LOG_DIR=$LOG_DIR"
    log_debug "ARCHIVE_DIR=$ARCHIVE_DIR"
    log_debug "RETENTION_DAYS=$RETENTION_DAYS"
    log_debug "SYNC_METHOD=$SYNC_METHOD"
}

check_dependencies() {
    local missing_deps=()
    
    # Essential dependencies
    for cmd in tar gzip sha256sum; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Remote sync dependencies
    if [[ "$SYNC_METHOD" == "rsync" ]] && ! command -v rsync &> /dev/null; then
        missing_deps+=("rsync")
    fi
    
    if [[ "$SYNC_METHOD" != "local" ]] && ! command -v ssh &> /dev/null; then
        missing_deps+=("ssh")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install the missing tools and try again"
        exit 1
    fi
    
    # Optional dependencies
    if command -v pigz &> /dev/null; then
        log_debug "pigz found - will use for compression"
    else
        log_debug "pigz not found - will use gzip"
    fi
}

# ========== ARCHIVE CREATION ==========

create_archive() {
    local timestamp archive_file archive_path
    
    mkdir -p "$ARCHIVE_DIR"
    
    timestamp="$(date +'%Y%m%d_%H%M%S')"
    archive_file="logs_archive_${timestamp}.tar.gz"
    archive_path="${ARCHIVE_DIR}/${archive_file}"
    
    log_info "Creating archive: $archive_path"
    
    # Determine compression command
    local compress_cmd
    if command -v pigz &> /dev/null; then
        compress_cmd="pigz -9"
    else
        compress_cmd="gzip -9"
    fi
    
    # Create tar archive
    if tar -c -I "$compress_cmd" -f "$archive_path" -C "$LOG_DIR" . 2>/dev/null; then
        log_success "Archive created: $archive_path"
    else
        log_error "Failed to create archive"
        exit 1
    fi
    
    # Generate checksum
    if sha256sum "$archive_path" > "${archive_path}.sha256"; then
        log_success "Checksum created: ${archive_path}.sha256"
    else
        log_error "Failed to create checksum"
        exit 1
    fi
    
    # Get file size
    local size_bytes
    size_bytes="$(stat -c%s "$archive_path" 2>/dev/null || stat -f%z "$archive_path")"
    
    # Verify archive if requested
    if [[ "$VERIFY_ARCHIVE" == true ]]; then
        if tar -tzf "$archive_path" > /dev/null 2>&1; then
            log_success "Archive verification passed"
            log_json "archive_verify" "success" "archive" "$archive_file"
        else
            log_error "Archive verification failed"
            log_json "archive_verify" "failed" "archive" "$archive_file"
            exit 1
        fi
    fi
    
    # Log archive creation
    log_json "archive_create" "success" "archive" "$archive_file" "size_bytes" "$size_bytes" "method" "$SYNC_METHOD"
    
    echo "$archive_path"
}

# ========== REMOTE SYNC FUNCTIONS ==========

test_remote_connection() {
    local ssh_opts="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
    
    if [[ -n "$SSH_KEY" ]]; then
        ssh_opts="$ssh_opts -i $SSH_KEY"
    fi
    
    # shellcheck disable=SC2086
    if ssh -p "$SSH_PORT" $ssh_opts "$REMOTE_USER@$REMOTE_HOST" "echo OK" &> /dev/null; then
        log_success "Remote connection verified"
        return 0
    else
        log_error "Failed to connect to remote server: $REMOTE_HOST:$SSH_PORT"
        return 1
    fi
}

prepare_remote_directory() {
    local ssh_opts="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
    
    if [[ -n "$SSH_KEY" ]]; then
        ssh_opts="$ssh_opts -i $SSH_KEY"
    fi
    
    log_info "Preparing remote directory: $REMOTE_PATH"
    
    # shellcheck disable=SC2086
    if ssh -p "$SSH_PORT" $ssh_opts "$REMOTE_USER@$REMOTE_HOST" \
        "mkdir -p $REMOTE_PATH && df -B 1G $REMOTE_PATH | awk 'NR==2 {print \$4}'" &> /dev/null; then
        log_success "Remote directory ready"
        return 0
    else
        log_error "Failed to prepare remote directory"
        return 1
    fi
}

sync_with_rsync() {
    local archive_path="$1"
    local archive_file
    archive_file="$(basename "$archive_path")"
    
    local rsync_opts="-av --checksum --progress"
    local ssh_opts="-e \"ssh -p $SSH_PORT"
    
    if [[ -n "$SSH_KEY" ]]; then
        ssh_opts="$ssh_opts -i $SSH_KEY"
    fi
    
    ssh_opts="$ssh_opts -o ConnectTimeout=10\""
    
    local attempt=1
    while (( attempt <= MAX_RETRIES )); do
        log_info "Syncing with Rsync (attempt $attempt/$MAX_RETRIES)"
        
        # shellcheck disable=SC2086
        if rsync $rsync_opts $ssh_opts \
            "$archive_path" "${archive_path}.sha256" \
            "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/" 2>&1 | tee >> "${ARCHIVE_DIR}/rsync.log"; then
            
            log_success "Rsync sync completed"
            log_json "remote_sync" "success" "method" "rsync" "archive" "$archive_file" "remote_host" "$REMOTE_HOST" "attempt" "$attempt"
            return 0
        else
            log_warn "Rsync sync failed (attempt $attempt/$MAX_RETRIES)"
            
            if (( attempt < MAX_RETRIES )); then
                log_info "Retrying in ${RETRY_DELAY} seconds..."
                sleep "$RETRY_DELAY"
            fi
        fi
        
        (( attempt++ ))
    done
    
    log_error "Rsync sync failed after $MAX_RETRIES attempts"
    log_json "remote_sync" "failed" "method" "rsync" "archive" "$archive_file" "remote_host" "$REMOTE_HOST"
    return 1
}

sync_with_scp() {
    local archive_path="$1"
    local archive_file
    archive_file="$(basename "$archive_path")"
    
    local scp_opts="-p -P $SSH_PORT"
    
    if [[ -n "$SSH_KEY" ]]; then
        scp_opts="$scp_opts -i $SSH_KEY"
    fi
    
    local attempt=1
    while (( attempt <= MAX_RETRIES )); do
        log_info "Syncing with SCP (attempt $attempt/$MAX_RETRIES)"
        
        # shellcheck disable=SC2086
        if scp $scp_opts "$archive_path" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/" 2>&1 | tee >> "${ARCHIVE_DIR}/scp.log" && \
           scp $scp_opts "${archive_path}.sha256" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/" 2>&1 >> "${ARCHIVE_DIR}/scp.log"; then
            
            log_success "SCP sync completed"
            log_json "remote_sync" "success" "method" "scp" "archive" "$archive_file" "remote_host" "$REMOTE_HOST" "attempt" "$attempt"
            return 0
        else
            log_warn "SCP sync failed (attempt $attempt/$MAX_RETRIES)"
            
            if (( attempt < MAX_RETRIES )); then
                log_info "Retrying in ${RETRY_DELAY} seconds..."
                sleep "$RETRY_DELAY"
            fi
        fi
        
        (( attempt++ ))
    done
    
    log_error "SCP sync failed after $MAX_RETRIES attempts"
    log_json "remote_sync" "failed" "method" "scp" "archive" "$archive_file" "remote_host" "$REMOTE_HOST"
    return 1
}

sync_archive() {
    local archive_path="$1"
    
    if [[ "$SYNC_METHOD" == "local" ]]; then
        log_info "Local mode - skipping remote sync"
        return 0
    fi
    
    log_info "Starting remote sync: $SYNC_METHOD"
    
    # Test connection
    if ! test_remote_connection; then
        return 1
    fi
    
    # Prepare remote directory
    if ! prepare_remote_directory; then
        return 1
    fi
    
    # Perform sync
    case "$SYNC_METHOD" in
        rsync)
            sync_with_rsync "$archive_path"
            ;;
        scp)
            sync_with_scp "$archive_path"
            ;;
    esac
}

# ========== CLEANUP FUNCTIONS ==========

cleanup_local_archives() {
    log_info "Cleaning up local archives older than $RETENTION_DAYS days"
    
    local deleted_count
    deleted_count=$(find "$ARCHIVE_DIR" -type f \( -name "*.tar.gz" -o -name "*.tar.gz.sha256" \) -mtime +"$RETENTION_DAYS" -delete 2>&1 | wc -l)
    
    log_success "Cleanup completed (up to $deleted_count files deleted)"
    log_json "cleanup" "success" "location" "local" "retention_days" "$RETENTION_DAYS"
}

cleanup_remote_archives() {
    if [[ "$SYNC_METHOD" == "local" ]]; then
        return 0
    fi
    
    log_info "Cleaning up remote archives on $REMOTE_HOST"
    
    local ssh_opts="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
    
    if [[ -n "$SSH_KEY" ]]; then
        ssh_opts="$ssh_opts -i $SSH_KEY"
    fi
    
    # shellcheck disable=SC2086
    if ssh -p "$SSH_PORT" $ssh_opts "$REMOTE_USER@$REMOTE_HOST" \
        "find $REMOTE_PATH -type f \\( -name '*.tar.gz' -o -name '*.tar.gz.sha256' \\) -mtime +$RETENTION_DAYS -delete" 2>&1; then
        
        log_success "Remote cleanup completed"
        log_json "cleanup" "success" "location" "remote" "host" "$REMOTE_HOST" "retention_days" "$RETENTION_DAYS"
    else
        log_warn "Remote cleanup may have failed"
        log_json "cleanup" "failed" "location" "remote" "host" "$REMOTE_HOST"
    fi
}

# ========== MAIN EXECUTION ==========

main() {
    local start_time
    start_time="$(date +%s)"
    
    log_info "Starting Log Archive Tool v$SCRIPT_VERSION"
    log_debug "Arguments: LOG_DIR=$LOG_DIR ARCHIVE_DIR=$ARCHIVE_DIR RETENTION_DAYS=$RETENTION_DAYS SYNC_METHOD=$SYNC_METHOD"
    
    # Validation and dependency checks
    validate_inputs
    check_dependencies
    
    # Create archive
    local archive_path
    archive_path="$(create_archive)"
    
    # Sync to remote if needed
    if ! sync_archive "$archive_path"; then
        log_error "Remote sync failed - aborting cleanup"
        exit 1
    fi
    
    # Cleanup old archives
    cleanup_local_archives
    cleanup_remote_archives
    
    # Calculate execution time
    local end_time duration
    end_time="$(date +%s)"
    duration=$((end_time - start_time))
    
    log_success "Log archive completed in ${duration}s"
    log_json "execution_complete" "success" "duration_seconds" "$duration" "archive_path" "$archive_path"
}

# ========== ENTRY POINT ==========

trap 'log_error "Script interrupted"; exit 130' INT TERM
trap 'log_error "Error on line $LINENO"; exit 1' ERR

parse_arguments "$@"
main
