
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

## Project URL
[Log-Archive-Tool on GitHub](https://github.com/shuvo-halder/systems/tree/main/Log-Archive-Tool)

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
  "timestamp": "2024-08-16 10:06:48",
  "archive": "logs_archive_20240816_100648.tar.gz"
}
```

---

## Future Improvements
- Add support for excluding temporary files (`*.tmp`, `*.bak`).
- Parallel compression using `pigz` for faster performance.
- Configurable logging format (CSV/JSON).
- Systemd timer integration for scheduled archiving.

---

## Author
**Shuvo Halder**  
GitHub Profile [(github.com in Bing)](https://www.bing.com/search?q="https%3A%2F%2Fgithub.com%2Fshuvo-halder")
Project URL [(Project URL)](https://roadmap.sh/projects/log-archive-tool)

