#!/bin/bash
set -e
trap 'echo " Error occurred at line $LINENO"; exit 1' ERR

if [ $# -lt 1 ]; then
    echo "Usage: $0 <log-directory> [archive-directory]"
    exit 1
fi

LOG_DIR="$1"
ARCHIVE_DIR="${2:-./log_archives}"
mkdir -p "$ARCHIVE_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ARCHIVE_FILE="logs_archive_${TIMESTAMP}.tar.gz"

if command -v pigz >/dev/null; then
    COMPRESS="--use-compress-program=pigz"
else
    COMPRESS="-z"
fi

tar -c $COMPRESS -f "${ARCHIVE_DIR}/${ARCHIVE_FILE}" -C "$LOG_DIR" .

LOG_FILE="${ARCHIVE_DIR}/archive_log.json"
echo "{\"timestamp\":\"$(date +'%Y-%m-%d %H:%M:%S')\",\"archive\":\"${ARCHIVE_FILE}\"}" >> "$LOG_FILE"

# Cleanup old archives (30 days)
find "$ARCHIVE_DIR" -type f -name "*.tar.gz" -mtime +30 -delete

echo " Archive created: ${ARCHIVE_DIR}/${ARCHIVE_FILE}"
echo " Log entry added to: ${LOG_FILE}"
