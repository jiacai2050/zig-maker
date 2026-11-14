#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STD_DIR="$(zig env | awk -F'"' '/\.std_dir =/ {print $2}')"
TARGET="${STD_DIR}/http/Client.zig"
BACKUP="${TARGET}.orig"

if [ "${1:-}" = "--restore" ]; then
    [ -f "${BACKUP}" ] || { echo "Error: backup ${BACKUP} not found" >&2; exit 1; }
    cp "${BACKUP}" "${TARGET}"
    echo "Restored original Client.zig"
    exit 0
fi

[ -f "${BACKUP}" ] || cp "${TARGET}" "${BACKUP}"
if patch -N -s -r - "${TARGET}" < "${ROOT}/Client.patch" >/dev/null 2>&1; then
    echo "Patched ${TARGET} (backup at ${BACKUP})"
else
    echo "Proxy patch already applied"
fi

