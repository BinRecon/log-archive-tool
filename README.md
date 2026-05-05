# 🗂️ Log Archive Tool

> A robust and production-ready Bash script for archiving log files with compression, integrity checks, structured logging, automated cleanup, and remote backup support.

[![Bash](https://img.shields.io/badge/bash-5.0+-green?style=flat-square&logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![Status](https://img.shields.io/badge/status-production%20ready-brightgreen?style=flat-square)](README.md)

---

## 📋 Table of Contents

- [Features](#-features)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Usage](#-usage)
- [Configuration](#-configuration)
- [Remote Sync](#-remote-sync-scp--rsync)
- [Scheduling](#-scheduled-backups-cron)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

---

## ✨ Features

### Core Features

- **🔒 Safe Bash Execution** - Strict mode (`set -Eeuo pipefail`) prevents silent failures
- **📦 Smart Compression** - Auto-detects `pigz` (parallel gzip) or falls back to `gzip`
- **🗜️ Timestamped Archives** - Creates organized archives: `logs_archive_YYYYMMDD_HHMMSS.tar.gz`
- **🔐 Integrity Verification** - SHA256 checksums for data integrity validation
- **📊 Structured Logging** - JSONL format for easy parsing and monitoring
- **🧹 Auto Cleanup** - Configurable retention policies for old archives
- **⚡ Cross-Platform** - Works on Linux and macOS
- **🛡️ Input Validation** - Comprehensive error checking and validation

### Remote Backup Features (v2.0)

- **📤 SCP/Rsync Support** - Securely sync archives to remote servers
- **🔄 Automatic Retries** - Configurable retry logic with exponential backoff (default: 3 attempts)
- **✅ Pre-flight Checks** - SSH connectivity, remote directory, disk space validation
- **🔑 SSH Key Support** - Uses SSH keys, agents, or password authentication
- **📈 File Verification** - SHA256 checksum validation after transfer
- **🌍 Remote Cleanup** - Enforce retention policies on backup servers
- **🚨 Error Recovery** - Graceful handling of network failures
- **📝 Operation Logging** - Detailed JSON logs for monitoring and alerting

---

## 📦 Installation

### Prerequisites

```bash
# Required
bash (4.0+)
tar
gzip or pigz (optional but recommended)
sha256sum
ssh, scp (for remote sync)

# Optional
rsync (for rsync method)
```

### Install

```bash
# Clone the repository
git clone https://github.com/shuvo-halder/log-archive-tool.git
cd log-archive-tool

# Make script executable
chmod +x log-archive-enhanced.sh

# (Optional) Copy to system path
sudo cp log-archive-enhanced.sh /usr/local/bin/log-archive
```

---

## 🚀 Quick Start

### Local Archive Only

```bash
# Archive logs with default settings (30-day retention)
./log-archive-enhanced.sh --log-dir /var/log

# Archive with custom retention
./log-archive-enhanced.sh --log-dir /var/log --retention 7
```

### With Remote Backup (Rsync)

```bash
./log-archive-enhanced.sh \
    --log-dir /var/log \
    --sync-method rsync \
    --remote-host backup.example.com \
    --remote-user backup \
    --remote-path /mnt/backups/logs \
    --ssh-key ~/.ssh/backup-key
```

### With Remote Backup (SCP)

```bash
./log-archive-enhanced.sh \
    --log-dir /var/log \
    --sync-method scp \
    --remote-host 192.168.1.10 \
    --remote-user admin \
    --remote-path /home/admin/backups
```

---

## 📖 Usage

### Command Syntax

```bash
./log-archive-enhanced.sh [OPTIONS]
```

### Options

#### Required
```
-l, --log-dir <dir>              Source log directory (REQUIRED)
```

#### Archive Options
```
-a, --archive-dir <dir>          Archive output directory (default: ./log_archives)
-r, --retention <days>           Retention days for old archives (default: 30)
-v, --verify                     Verify archive after creation (tar -tzf)
```

#### Remote Sync Options
```
-s, --sync-method <method>       Sync method: 'rsync' or 'scp' (default: none)
-H, --remote-host <host>         Remote backup server hostname/IP
-u, --remote-user <user>         Remote server SSH user
-p, --remote-path <path>         Remote backup destination path
-P, --ssh-port <port>            SSH port (default: 22)
-k, --ssh-key <file>             SSH private key file path
```

#### Execution Options
```
-d, --debug                      Enable debug mode with verbose output
--dry-run                        Preview changes without executing
--timeout <seconds>              SSH operation timeout (default: 300)
--retries <count>                Number of retry attempts (default: 3)
```

#### Other
```
-h, --help                       Show help message
--version                        Show version information
```

### Examples

```bash
# Archive with verification
./log-archive-enhanced.sh --log-dir /var/log --verify

# Archive and sync via rsync with verification
./log-archive-enhanced.sh \
    --log-dir /var/log \
    --archive-dir /opt/backups/logs \
    --retention 30 \
    --sync-method rsync \
    --remote-host backup.com \
    --remote-user backup \
    --remote-path /backups/logs \
    --ssh-key ~/.ssh/backup-key \
    --verify

# Dry-run to preview operations
./log-archive-enhanced.sh \
    --log-dir /var/log \
    --sync-method rsync \
    --remote-host backup.com \
    --remote-user backup \
    --remote-path /backups \
    --dry-run

# Debug mode
./log-archive-enhanced.sh \
    --log-dir /var/log \
    --remote-host backup.com \
    --remote-user backup \
    --remote-path /backups \
    --debug
```

---

## ⚙️ Configuration

### Environment Variables

```bash
# Enable debug output
export REMOTE_SYNC_DEBUG=1

# Set SSH timeout (seconds)
export REMOTE_SYNC_TIMEOUT=600

# SSH agent socket
export SSH_AUTH_SOCK=/tmp/ssh-agent.sock

# Custom SSH options
export SSH_OPTIONS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no"
```

### SSH Key Setup

#### Generate SSH Key Pair

```bash
# Create ED25519 key (recommended)
ssh-keygen -t ed25519 \
    -f ~/.ssh/log-backup-key \
    -N "" \
    -C "log-backup@$(hostname)"

# Secure permissions
chmod 600 ~/.ssh/log-backup-key
chmod 644 ~/.ssh/log-backup-key.pub
```

#### Add to Remote Server

```bash
# Copy key to remote server
ssh-copy-id -i ~/.ssh/log-backup-key.pub backup@backup.example.com

# Or manually add to authorized_keys
cat ~/.ssh/log-backup-key.pub | ssh backup@backup.example.com \
    "cat >> ~/.ssh/authorized_keys"
```

#### Verify Connection

```bash
# Test SSH key authentication
ssh -i ~/.ssh/log-backup-key backup@backup.example.com "echo OK"

# Test with specific port
ssh -i ~/.ssh/log-backup-key -p 2222 backup@backup.example.com "echo OK"
```

---

## 🌍 Remote Sync (SCP / Rsync)

### Method Comparison

| Feature | Rsync | SCP |
|---------|-------|-----|
| **Efficiency** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Resume** | ✅ Yes | ❌ No |
| **Delta Sync** | ✅ Yes | ❌ No |
| **Simplicity** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Availability** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Security** | ✅ SSH | ✅ SSH |

**Recommendation**: Use **Rsync** for large/frequent transfers, **SCP** for simple/secure environments.

### Rsync Backup Example

```bash
#!/bin/bash
# examples/rsync-backup.sh

/path/to/log-archive-enhanced.sh \
    --log-dir /var/log \
    --archive-dir /opt/backups/logs \
    --retention 30 \
    --sync-method rsync \
    --remote-host backup.example.com \
    --remote-user backup \
    --remote-path /mnt/backups/logs \
    --ssh-key ~/.ssh/backup-key \
    --verify \
    --retries 3 \
    --timeout 600
```

### SCP Backup Example

```bash
#!/bin/bash
# examples/scp-backup.sh

/path/to/log-archive-enhanced.sh \
    --log-dir /var/log \
    --archive-dir /opt/backups/logs \
    --retention 30 \
    --sync-method scp \
    --remote-host 192.168.1.10 \
    --remote-user admin \
    --remote-path /home/admin/backups \
    --ssh-key ~/.ssh/backup-key \
    --verify
```

---

## ⏰ Scheduled Backups (Cron)

### Automatic Setup

```bash
# Interactive setup
sudo bash examples/cron-setup.sh
```

### Manual Cron Entry

```bash
# Daily backup at 2 AM
0 2 * * * /usr/local/bin/log-archive \
    --log-dir /var/log \
    --archive-dir /opt/backups/logs \
    --retention 30 \
    --sync-method rsync \
    --remote-host backup.example.com \
    --remote-user backup \
    --remote-path /backups/logs \
    --ssh-key ~/.ssh/backup-key \
    >> /var/log/log-archive.log 2>&1

# Weekly verification (Sunday 3 AM)
0 3 * * 0 /usr/local/bin/log-archive \
    --log-dir /var/log \
    --verify \
    >> /var/log/log-archive-verify.log 2>&1

# Monthly cleanup (1st at 4 AM)
0 4 1 * * /usr/local/bin/log-archive \
    --log-dir /var/log \
    --retention 30 \
    >> /var/log/log-archive-cleanup.log 2>&1
```

### Systemd Timer (Alternative)

```ini
# /etc/systemd/system/log-archive.service
[Unit]
Description=Log Archive Tool
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/log-archive --log-dir /var/log --sync-method rsync --remote-host backup.com --remote-user backup --remote-path /backups/logs
StandardOutput=journal
StandardError=journal

# /etc/systemd/system/log-archive.timer
[Unit]
Description=Log Archive Timer
Requires=log-archive.service

[Timer]
OnCalendar=daily
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable:
```bash
sudo systemctl enable log-archive.timer
sudo systemctl start log-archive.timer
sudo systemctl status log-archive.timer
```

---

## 📊 Logging and Monitoring

### Log Format

Archives are logged in **JSONL** format (one JSON object per line):

```json
{"timestamp":"2026-05-05T12:30:00+00:00","archive":"logs_archive_20260505_123000.tar.gz","size_bytes":5242880,"checksum_file":"logs_archive_20260505_123000.tar.gz.sha256","method":"local","status":"success"}
{"timestamp":"2026-05-05T12:35:45+00:00","archive":"logs_archive_20260505_123000.tar.gz","sync_method":"rsync","remote_host":"backup.example.com","remote_user":"backup","status":"success","duration_seconds":45,"transferred_bytes":5242880}
```

### Accessing Logs

```bash
# View all logs
cat archive_log.jsonl

# View last 10 entries
tail -10 archive_log.jsonl

# Filter successful rsync transfers
grep '"sync_method":"rsync"' archive_log.jsonl | grep '"status":"success"'

# Parse with jq
cat archive_log.jsonl | jq '.timestamp, .archive, .size_bytes'

# Watch logs in real-time
tail -f archive_log.jsonl
```

---

## 🧪 Testing

### Run Test Suite

```bash
bash tests/test-remote-sync.sh
```

Tests verify:
- ✅ Configuration validation
- ✅ Logging functions
- ✅ JSON log entry generation
- ✅ Script syntax
- ✅ Dependency availability
- ✅ Help/version output

### Manual Testing

```bash
# Test with dry-run
./log-archive-enhanced.sh --log-dir /var/log --dry-run

# Test with debug output
./log-archive-enhanced.sh --log-dir /var/log --debug

# Test SSH connectivity
ssh -v -i ~/.ssh/backup-key backup@backup.example.com "df -h"

# Verify archive integrity
tar -tzf logs_archive_*.tar.gz | head -20
```

---

## 🚨 Troubleshooting

### Error on line 543

**Solution**: Update to the latest version with `git pull`

```bash
git pull origin main
chmod +x log-archive-enhanced.sh
```

### SSH Connection Issues

```bash
# Test SSH connectivity
ssh -v -i ~/.ssh/backup-key backup@backup.example.com echo "OK"

# Check key permissions (should be 600)
ls -la ~/.ssh/backup-key

# Check authorized_keys on remote
ssh backup@backup.example.com cat ~/.ssh/authorized_keys

# Verify SSH_AUTH_SOCK
echo $SSH_AUTH_SOCK
```

### Remote Directory Issues

```bash
# Check remote directory exists
ssh backup@backup.example.com ls -la /path/to/backups

# Create remote directory
ssh backup@backup.example.com mkdir -p /path/to/backups

# Check permissions
ssh backup@backup.example.com ls -ld /path/to/backups
```

### Disk Space Issues

```bash
# Check local disk space
df -h /opt/backups

# Check remote disk space
ssh backup@backup.example.com df -h /path/to/backups

# Check archive size
du -sh /opt/backups/logs/logs_archive_*.tar.gz

# Reduce retention
./log-archive-enhanced.sh --log-dir /var/log --retention 7
```

### Permission Denied

```bash
# Make script executable
chmod +x log-archive-enhanced.sh

# Check SSH key permissions
chmod 600 ~/.ssh/backup-key
chmod 644 ~/.ssh/backup-key.pub

# Check remote SSH permissions
ssh backup@backup.example.com chmod 700 ~/.ssh
ssh backup@backup.example.com chmod 600 ~/.ssh/authorized_keys
```

### Debug Mode

```bash
# Enable verbose output
./log-archive-enhanced.sh \
    --log-dir /var/log \
    --remote-host backup.com \
    --remote-user backup \
    --remote-path /backups \
    --debug

# Check system logs
journalctl -u log-archive.service -f  # If using systemd
```

---

## 📈 Performance

### Typical Metrics (100MB archive)

| Operation | Time | Network |
|-----------|------|---------|
| Local Archive | 2-5s | N/A |
| Rsync Transfer | 3-7s | Low |
| SCP Transfer | 5-10s | High |
| Verification | 1-2s | N/A |

Factors affecting performance:
- Network latency
- Available bandwidth
- Server load
- Archive size
- Compression level

---

## 🔮 Roadmap

### Planned Features

- [ ] 🔒 GPG/PGP encryption support
- [ ] ☁️ AWS S3 integration
- [ ] ☁️ Azure Blob Storage
- [ ] 🔔 Slack/Telegram notifications
- [ ] 📊 Prometheus metrics exporter
- [ ] 🧠 Incremental/differential backups
- [ ] 📈 Web dashboard
- [ ] 🐳 Docker/Kubernetes support

---

## 📝 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Guidelines

- Follow existing code style
- Add tests for new features
- Update documentation
- Use meaningful commit messages

---

## 🐛 Reporting Issues

Found a bug? Please open an issue with:

- **Description**: What's the problem?
- **Steps to Reproduce**: How to trigger it?
- **Expected Behavior**: What should happen?
- **Actual Behavior**: What actually happens?
- **Environment**: OS, Bash version, etc.
- **Logs**: Error messages and debug output

---

## 📞 Support

- 📖 [Documentation](README.md)
- 🐛 [Issue Tracker](https://github.com/shuvo-halder/log-archive-tool/issues)
- 💬 [Discussions](https://github.com/shuvo-halder/log-archive-tool/discussions)

---

## 👤 Author

**Shuvo Halder**

- GitHub: [@shuvo-halder](https://github.com/shuvo-halder)
- Website: [s2deals.org](https://s2deals.org)

---

## 🙏 Acknowledgments

- Inspired by production-grade backup solutions
- Thanks to the Bash community
- Built with ❤️ for DevOps engineers

---

## 📚 Resources

- [GNU Bash Manual](https://www.gnu.org/software/bash/manual/)
- [Rsync Documentation](https://rsync.samba.org/)
- [OpenSSH Manual](https://man.openbsd.org/ssh)
- [Tar Manual](https://www.gnu.org/software/tar/manual/)

---

**Last Updated**: 2026-05-05  
**Current Version**: 2.0.0  
**Status**: ✅ Production Ready
