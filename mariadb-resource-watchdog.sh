#!/usr/bin/env bash
#########################################################################
# MariaDB Resource Watchdog
# ------------------------
# Periodically monitors MariaDB CPU, memory, and connection usage.
#
# Author  : Anban Malarvendan
# Version : 2.0
#
# Requirements:
#   - Linux (procfs)
#   - mariadbd
#   - mysql client
#
# How to execute: ./mariadb_resource_watchdog.sh
#########################################################################

set -Eeuo pipefail

INTERVAL=60
LOG_DIR="/var/log/mariadb-resource-watchdog"
MYSQL_CMD="mysql"
MYSQL_OPTS="-N -s"
PID=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -i, --interval SEC     Sampling interval (default: 60)
  -l, --log-dir DIR      Log directory (default: /var/log/mariadb-resource-watchdog)
  -m, --mysql-cmd PATH   mysql client path (default: mysql)
  -h, --help             Show this help

Authentication:
  Uses mysql client defaults (~/.my.cnf).
  DO NOT hardcode credentials.

Example:
  $0 -i 30 -l /tmp/mdb_watch
EOF
}

log() {
    echo "$@" | tee -a "$LOG_FILE"
}

cleanup() {
    log "Stopping MariaDB resource watchdog."
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -l|--log-dir)
            LOG_DIR="$2"
            shift 2
            ;;
        -m|--mysql-cmd)
            MYSQL_CMD="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

command -v "$MYSQL_CMD" >/dev/null || {
    echo "mysql client not found"
    exit 1
}

PID=$(pidof mariadbd || true)
[[ -z "$PID" ]] && {
    echo "mariadbd process not running"
    exit 1
}

mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/mariadb_resource_$(hostname)_$(date +%Y%m%d_%H%M%S).log"

trap cleanup INT TERM

log "MariaDB Resource Watchdog started"
log "PID        : $PID"
log "Interval   : ${INTERVAL}s"
log "Log file   : $LOG_FILE"
log "------------------------------------------------------------"
printf "%-10s %-6s %-6s %-10s %-10s %-8s\n" \
       "TIME" "CPU%" "MEM%" "VM(MB)" "RSS(MB)" "CONNS" | tee -a "$LOG_FILE"
log "------------------------------------------------------------"


while true; do
    TIME=$(date +"%H:%M:%S")

    CPU=$(ps -p "$PID" -o %cpu= | awk '{printf "%.1f", $1}')
    MEM=$(ps -p "$PID" -o %mem= | awk '{printf "%.1f", $1}')

    VM_KB=$(awk '/VmSize/ {print $2}' /proc/"$PID"/status)
    RSS_KB=$(awk '/VmRSS/ {print $2}' /proc/"$PID"/status)

    VM_MB=$(awk "BEGIN {printf \"%.1f\", ${VM_KB:-0}/1024}")
    RSS_MB=$(awk "BEGIN {printf \"%.1f\", ${RSS_KB:-0}/1024}")

    CONNS=$(
        $MYSQL_CMD $MYSQL_OPTS \
        -e "SHOW GLOBAL STATUS LIKE 'Threads_connected';" \
        2>/dev/null | awk '{print $2}' || echo "NA"
    )

    printf "%-10s %-6s %-6s %-10s %-10s %-8s\n" \
           "$TIME" "$CPU" "$MEM" "$VM_MB" "$RSS_MB" "$CONNS" | tee -a "$LOG_FILE"

    sleep "$INTERVAL"
done
