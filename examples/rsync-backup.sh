#!/usr/bin/env bash
# Example: Rsync Backup Configuration
# This script demonstrates production-grade Rsync backup setup
# Usage: ./examples/rsync-backup.sh

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly MAIN_SCRIPT="$SCRIPT_DIR/log-archive-enhanced.sh"

# ========== CONFIGURATION ==========

# Local settings
LOG_DIR="/var/log"
ARCHIVE_DIR="/opt/backups/logs"
RETENTION_DAYS=30

# Remote backup server
REMOTE_HOST="backup.example.com"
REMOTE_USER="backup"
REMOTE_PATH="/mnt/backups/logs"
SSH_PORT=22
SSH_KEY="$HOME/.ssh/log-backup-key"

# Rsync settings
SYNC_METHOD="rsync"

# Optional features
VERIFY_ARCHIVE=true
DEBUG_MODE=false

# ========== EXECUTION ==========

echo "=========================================="
echo "Log Archive Tool - Rsync Backup Example"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Local log directory: $LOG_DIR"
echo "  Archive directory: $ARCHIVE_DIR"
echo "  Retention: $RETENTION_DAYS days"
echo ""
echo "Remote server:"
echo "  Host: $REMOTE_HOST:$SSH_PORT"
echo "  User: $REMOTE_USER"
echo "  Path: $REMOTE_PATH"
echo "  SSH Key: $SSH_KEY"
echo ""

# Build command
CMD="$MAIN_SCRIPT"
CMD="$CMD --log-dir $LOG_DIR"
CMD="$CMD --archive-dir $ARCHIVE_DIR"
CMD="$CMD --retention $RETENTION_DAYS"
CMD="$CMD --sync-method $SYNC_METHOD"
CMD="$CMD --remote-host $REMOTE_HOST"
CMD="$CMD --remote-user $REMOTE_USER"
CMD="$CMD --remote-path $REMOTE_PATH"
CMD="$CMD --ssh-port $SSH_PORT"
CMD="$CMD --ssh-key $SSH_KEY"

if [[ "$VERIFY_ARCHIVE" == true ]]; then
    CMD="$CMD --verify"
fi

if [[ "$DEBUG_MODE" == true ]]; then
    CMD="$CMD --debug"
fi

echo "Executing: $CMD"
echo ""

# Make scripts executable
chmod +x "$MAIN_SCRIPT"

# Run the script
eval "$CMD"

exit_code=$?

echo ""
echo "=========================================="
if [[ $exit_code -eq 0 ]]; then
    echo "✓ Backup completed successfully"
else
    echo "✗ Backup failed with exit code: $exit_code"
fi
echo "=========================================="

exit $exit_code
