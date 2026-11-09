#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    ""|--restore) ;;
    *) echo "Usage: $0 [--restore]" >&2; exit 1 ;;
esac
[ "$#" -le 1 ] || { echo "Usage: $0 [--restore]" >&2; exit 1; }

command -v zig >/dev/null 2>&1 || { echo "Error: 'zig' not found in PATH" >&2; exit 1; }

VERSION="$(zig version)"
case "${VERSION}" in
    0.17.0|0.17.1) ;;
    *) echo "Error: supports Zig 0.17.0 and 0.17.1, found ${VERSION}" >&2; exit 1 ;;
esac

STD_DIR="$(zig env | awk -F'"' '/\.std_dir =/ {print $2}')"
TARGET="${STD_DIR}/http/Client.zig"
BACKUP="${TARGET}.orig"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "${STD_DIR}" ] && [ -f "${TARGET}" ] || { echo "Error: cannot locate std/http/Client.zig" >&2; exit 1; }

if [ "${1:-}" = "--restore" ]; then
    [ -f "${BACKUP}" ] || { echo "Error: backup ${BACKUP} not found" >&2; exit 1; }
    cp "${BACKUP}" "${TARGET}"
    echo "Restored original Client.zig"
    exit 0
fi

command -v patch >/dev/null 2>&1 || { echo "Error: 'patch' not found in PATH" >&2; exit 1; }

# The old installer overwrote the entire file with a 0.17.0 snapshot.
if [ "${VERSION}" != "0.17.0" ] && cmp -s "${ROOT}/Client.zig" "${TARGET}"; then
    echo "Error: old 0.17.0 snapshot detected. Restore the original ${VERSION} Client.zig first (./replace.sh --restore if its backup is intact), then rerun." >&2
    exit 1
fi

# Apply to a temporary copy so a failed hunk never changes the standard library.
WORK_ROOT="${TMPDIR:-${HOME}/tmp}/opencode"
mkdir -p "${WORK_ROOT}"
WORK="$(mktemp -d "${WORK_ROOT}/zig-maker.XXXXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
cp "${TARGET}" "${WORK}/Client.zig"
if patch --batch --forward --fuzz=0 --reject-file=- "${WORK}/Client.zig" < "${ROOT}/Client.patch" > "${WORK}/patch.log" 2>&1; then
    [ -f "${BACKUP}" ] || cp "${TARGET}" "${BACKUP}"
    cp "${WORK}/Client.zig" "${TARGET}"
    echo "Patched ${TARGET} (backup at ${BACKUP})"
elif patch --batch --reverse --fuzz=0 --dry-run "${TARGET}" < "${ROOT}/Client.patch" >/dev/null 2>&1; then
    echo "Proxy patch already applied"
else
    cat "${WORK}/patch.log" >&2
    echo "Error: incompatible Client.zig; standard library left unchanged" >&2
    exit 1
fi
