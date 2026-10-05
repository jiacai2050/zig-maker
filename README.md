# zig-maker

[English](README.md) | [中文](README.zh.md)

A hotfix tool replacing `std.http.Client` in Zig 0.17+ to fix `zig fetch` errors caused by HTTP Proxy issues.

The `Client.zig` in this repository originates from official Zig Pull Request: [#36484](https://codeberg.org/ziglang/zig/pulls/36484). Feel free to test it and share your feedback!

> **How it works**: In Zig 0.17+, the build runner (`maker`) is JIT-compiled on the fly via `jitCmd` whenever `zig fetch` or `zig build` is executed. By directly replacing `Client.zig` in your standard library, Zig automatically detects the source change and recompiles `maker` in seconds—no need to recompile the Zig compiler itself.

---

## Quick Start

```bash
git clone https://github.com/jiacai2050/zig-maker.git
cd zig-maker

# Auto-detect std_dir, backup original and replace
./replace.sh

# Restore original if needed
./replace.sh --restore
```

---

## Manual Installation

Locate the standard library path using `zig env` and overwrite directly:

```bash
# 1. Query active std_dir
STD_DIR=$(zig env | awk -F'"' '/\.std_dir =/ {print $2}')

# 2. Backup original Client.zig
cp "${STD_DIR}/http/Client.zig" "${STD_DIR}/http/Client.zig.orig"

# 3. Copy the fixed version
cp ./Client.zig "${STD_DIR}/http/Client.zig"
```

---

## Fixes & Feedback

This patch is based on PR [#36484](https://codeberg.org/ziglang/zig/pulls/36484), addressing:
- Protocol forwarding issues during HTTP Proxy CONNECT tunnel handshakes;
- Connection pool double-release defects during connection cleanup and TLS upgrades.

Feedback is welcome! If you encounter issues or have successful test cases under various proxies, CDNs, or private registries, please report them in the Issues.

For an in-depth explanation of the Zig 0.17 architecture and our hotfix design, see [docs/how-zig-maker-works.md](docs/how-zig-maker-works.md).
