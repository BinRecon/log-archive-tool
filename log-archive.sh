#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "Error on line $LINENO" >&2' ERR

usage() {
    echo "Usage: $0 <log-directory> [archive-directory] [retention-days]"
    echo "Example: $0 /var/log ./log_archives 30"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

LOG_DIR="$1"
ARCHIVE_DIR="${2:-./log_archives}"
RETENTION_DAYS="${3:-30}"

if [[ ! -d "$LOG_DIR" ]]; then
    echo "Error: log directory does not exist: $LOG_DIR" >&2
    exit 1
fi

mkdir -p "$ARCHIVE_DIR"

TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
ARCHIVE_FILE="logs_archive_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${ARCHIVE_DIR}/${ARCHIVE_FILE}"
LOG_FILE="${ARCHIVE_DIR}/archive_log.jsonl"

if command -v pigz >/dev/null 2>&1; then
    COMPRESS_CMD=(pigz -9)
else
    COMPRESS_CMD=(gzip -9)
fi

echo "Creating archive: $ARCHIVE_PATH"

tar -c -I "${COMPRESS_CMD[*]}" -f "$ARCHIVE_PATH" -C "$LOG_DIR" .

sha256sum "$ARCHIVE_PATH" > "${ARCHIVE_PATH}.sha256"

SIZE_BYTES="$(stat -c%s "$ARCHIVE_PATH" 2>/dev/null || stat -f%z "$ARCHIVE_PATH")"
CREATED_AT="$(date -Iseconds)"

printf '{"timestamp":"%s","archive":"%s","size_bytes":%s,"checksum_file":"%s"}\n' \
    "$CREATED_AT" "$ARCHIVE_FILE" "$SIZE_BYTES" "${ARCHIVE_FILE}.sha256" >> "$LOG_FILE"

find "$ARCHIVE_DIR" -type f \( -name "*.tar.gz" -o -name "*.tar.gz.sha256" \) -mtime +"$RETENTION_DAYS" -delete

echo "Archive created: $ARCHIVE_PATH"
echo "Checksum created: ${ARCHIVE_PATH}.sha256"
echo "Log entry added to: $LOG_FILE"
