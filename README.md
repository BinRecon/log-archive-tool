
# 🗂️ Log Archive Tool (Enhanced Version)

A robust and production-ready Bash script for archiving log files with compression, integrity checks, structured logging, and automated cleanup.

---

## 🚀 Features (Current Version)

### ✅ 1. Safe Bash Execution

* Uses strict mode:

  ```bash
  set -Eeuo pipefail
  ```
* Prevents silent failures and undefined variables

---

### 📁 2. Flexible Input

```bash
./script.sh <log-directory> [archive-directory] [retention-days]
```

* `log-directory` → مصدر logs
* `archive-directory` → default: `./log_archives`
* `retention-days` → default: `30`

---

### 📦 3. Smart Compression

* Uses `pigz` (parallel gzip) if available
* Falls back to `gzip` automatically

---

### 🗜️ 4. Archive Creation

* Creates timestamped archive:

  ```
  logs_archive_YYYYMMDD_HHMMSS.tar.gz
  ```

---

### 🔐 5. Integrity Check (Checksum)

* Generates SHA256 checksum:

  ```
  archive.tar.gz.sha256
  ```

---

### 📊 6. Structured Logging (JSONL)

* Logs stored in:

  ```
  archive_log.jsonl
  ```
* Example entry:

```json
{
  "timestamp": "2026-05-03T10:00:00Z",
  "archive": "logs_archive_20260503.tar.gz",
  "size_bytes": 123456,
  "checksum_file": "logs_archive_20260503.tar.gz.sha256"
}
```

---

### 🧹 7. Automatic Cleanup

* Deletes old archives based on retention:

```bash
find ... -mtime +<days> -delete
```

---

### 🛡️ 8. Input Validation

* Ensures log directory exists before execution

---

### ⚡ 9. Cross-Platform Support

* Handles `stat` differences (Linux/macOS)

---

## 📂 Project Structure

```
.
├── script.sh
├── log_archives/
│   ├── logs_archive_*.tar.gz
│   ├── logs_archive_*.sha256
│   └── archive_log.jsonl
```

---

## 🧪 Usage Example

```bash
chmod +x script.sh

./script.sh /var/log /backup/logs 15
```

---

## 🔧 Requirements

* `bash`
* `tar`
* `gzip` বা `pigz` (optional but recommended)
* `sha256sum`
---

## 🔮 Upcoming Features (Planned Upgrades)

### 🔒 Security

* [ ] GPG encryption (`.tar.gz.gpg`)
* [ ] Password / key-based encryption

---

### ☁️ Remote Backup

* [ ] AWS S3 upload
~~ * [ ] SCP / Rsync backup server sync ~~
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

