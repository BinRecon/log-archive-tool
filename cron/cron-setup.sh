#!/usr/bin/env bash
# Cron Setup Script for Log Archive Tool
# Configures automated backup scheduling
# Usage: sudo bash cron/cron-setup.sh

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly MAIN_SCRIPT="$SCRIPT_DIR/log-archive-enhanced.sh"
readonly LOG_FILE="/var/log/log-archive.log"
readonly CRON_TEMP="/tmp/log-archive-cron.$$"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use: sudo $0)"
    exit 1
fi

echo "=========================================="
echo "Log Archive Tool - Cron Setup"
echo "=========================================="
echo ""

# Make main script executable
chmod +x "$MAIN_SCRIPT"
chmod +x "$SCRIPT_DIR/lib/remote-sync.sh" 2>/dev/null || true

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

echo "Configuring cron jobs..."
echo ""

# Get current crontab (if exists)
crontab -l > "$CRON_TEMP" 2>/dev/null || true

# Check if our jobs already exist
if grep -q "log-archive-enhanced.sh" "$CRON_TEMP" 2>/dev/null; then
    echo "⚠️  Log Archive cron jobs already configured"
    echo "Remove existing jobs first with: crontab -e"
    rm -f "$CRON_TEMP"
    exit 1
fi

# Add new cron jobs
cat >> "$CRON_TEMP" << 'EOF'

# Log Archive Tool - Automated Backup Schedule

# Daily backup at 2:00 AM
0 2 * * * /path/to/log-archive-enhanced.sh --log-dir /var/log --archive-dir /opt/backups/logs --sync-method rsync --remote-host backup.example.com --remote-user backup --remote-path /backups/logs --ssh-key /root/.ssh/log-backup-key --verify >> /var/log/log-archive.log 2>&1

# Weekly verification at 3:00 AM on Sunday
0 3 * * 0 /path/to/log-archive-enhanced.sh --log-dir /var/log --archive-dir /opt/backups/logs --verify --debug >> /var/log/log-archive.log 2>&1

# Monthly deep cleanup on 1st at 4:00 AM
0 4 1 * * find /opt/backups/logs -type f -name "*.tar.gz*" -mtime +30 -delete >> /var/log/log-archive.log 2>&1

EOF

# Update script paths in cron file
sed -i "s|/path/to/log-archive-enhanced.sh|$MAIN_SCRIPT|g" "$CRON_TEMP"

# Install new crontab
crontab "$CRON_TEMP"
rm -f "$CRON_TEMP"

echo "✓ Cron jobs configured:"
echo ""
echo "  • Daily backup: 2:00 AM"
echo "  • Weekly verification: 3:00 AM (Sunday)"
echo "  • Monthly cleanup: 4:00 AM (1st of month)"
echo ""
echo "Log file: $LOG_FILE"
echo ""
echo "To view configured jobs:"
echo "  crontab -l"
echo ""
echo "To edit jobs:"
echo "  crontab -e"
echo ""
echo "To remove jobs:"
echo "  crontab -r"
echo ""
echo "=========================================="
