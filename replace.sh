#!/usr/bin/env bash
set -euo pipefail

command -v zig >/dev/null 2>&1 || { echo "Error: 'zig' not found in PATH" >&2; exit 1; }

VERSION="$(zig version)"
case "${VERSION}" in
    0.17*) ;;
    *) echo "Error: requires Zig 0.17.x, found ${VERSION}" >&2; exit 1 ;;
esac

STD_DIR="$(zig env | awk -F'"' '/\.std_dir =/ {print $2}')"
TARGET="${STD_DIR}/http/Client.zig"
BACKUP="${TARGET}.orig"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/Client.zig"

if [ "${1:-}" = "--restore" ]; then
    [ -f "${BACKUP}" ] || { echo "Error: backup ${BACKUP} not found" >&2; exit 1; }
    cp "${BACKUP}" "${TARGET}"
    echo "Restored original Client.zig"
    exit 0
fi

[ -f "${BACKUP}" ] || cp "${TARGET}" "${BACKUP}"
cp "${SRC}" "${TARGET}"
echo "Replaced ${TARGET} (backup at ${BACKUP})"
