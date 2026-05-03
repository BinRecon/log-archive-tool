
# Log Archive Tool

A simple command-line utility to compress and archive log files into a timestamped `.tar.gz` file.  
It helps keep your system logs organized, backed up, and easy to manage.

---

## Features
- Accepts a log directory as an argument.
- Compresses logs into a `.tar.gz` archive.
- Stores archives in a dedicated directory (`log_archives/` by default).
- Automatically names archives with a timestamp (e.g., `logs_archive_20240816_100648.tar.gz`).
- Logs every archive creation in `archive_log.json` (structured log format).
- Optional cleanup of old archives (default: 30 days).

---

## 🔧 Requirements

* `bash`
* `tar`
* `gzip` বা `pigz` (optional but recommended)
* `sha256sum`

---

## Installation

Clone the repository:
```bash
git clone https://github.com/shuvo-halder/systems.git
cd systems/Log-Archive-Tool
```

Make the script executable:
```bash
chmod +x log-archive
```

Move it into your `$PATH` (optional):
```bash
sudo mv log-archive /usr/local/bin/
```

---

## Usage

Basic usage:
```bash
log-archive <log-directory>
```

Example:
```bash
log-archive /var/log
```

This will:
- Create `log_archives/` if it doesn’t exist.
- Generate a file like:
  ```
  logs_archive_20240816_100648.tar.gz
  ```
- Append a log entry to:
  ```
  log_archives/archive_log.json
  ```

---

## Optional Arguments
You can extend the script to accept more arguments:

```bash
log-archive <log-directory> [archive-directory] [retention-days]
```

- `<log-directory>` → Directory containing logs (required).
- `[archive-directory]` → Where to store archives (default: `./log_archives`).
- `[retention-days]` → Delete archives older than N days (default: 30).

---

## Example Log Entry
```json
{
    "timestamp": "2026-05-03T10:00:00Z",
    "archive": "logs_archive_20260503.tar.gz",
    "size_bytes": 123456,
    "checksum_file": "logs_archive_20260503.tar.gz.sha256"
}
```

---

## 🔮 Upcoming Features (Planned Upgrades)

### 🔒 Security

* [ ] GPG encryption (`.tar.gz.gpg`)
* [ ] Password / key-based encryption

---

### ☁️ Remote Backup

* [ ] AWS S3 upload
* [ ] SCP / Rsync backup server sync
* [ ] Multi-destination backup

---

### 📊 Observability

* [ ] Hostname tracking
* [ ] Detailed metrics (duration, compression ratio)
* [ ] Prometheus exporter (advanced)

---

### 🔔 Alerting

* [ ] Telegram notification
* [ ] Slack webhook integration
* [ ] Email alerts

---

### ⚙️ Config Management

* [ ] `.env` or config file support
* [ ] CLI flags (`--retention`, `--encrypt`, etc.)

---

### 🧠 Smart Backup

* [ ] Incremental backups (`.snar`)
* [ ] Differential backup strategy

---

### 🧹 Advanced Cleanup

* [ ] Max archive count limit
* [ ] Max disk usage threshold

---

### 🧪 Reliability

* [ ] Archive verification (`tar -tzf`)
* [ ] Retry mechanism on failure

---

### ⏱️ Scheduling & Safety

* [ ] Cron-ready setup guide
* [ ] Lock file (prevent duplicate runs)

---

### 🧰 Developer Experience

* [ ] Dry-run mode
* [ ] Debug/verbose mode
* [ ] Colored CLI output

---

## 🧠 Future Vision

This tool can evolve into:

* A **lightweight backup agent**
* A **DevOps log retention system**
* Or a **centralized backup service (with API + dashboard)**

---

## 🤝 Contribution Ideas

* Convert to Go for better performance
* Add REST API
* Add web dashboard
* Dockerize the tool

---

## Author
**Shuvo Halder**  
GitHub Profile [(github.com in Bing)](https://www.bing.com/search?q="https%3A%2F%2Fgithub.com%2Fshuvo-halder")

