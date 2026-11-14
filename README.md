# zig-maker

[![CI](https://github.com/jiacai2050/zig-maker/actions/workflows/ci.yml/badge.svg)](https://github.com/jiacai2050/zig-maker/actions/workflows/ci.yml)

[English](README.md) | [中文](README.zh.md)

A hotfix tool patching `std.http.Client` in Zig 0.17.0 and 0.17.1 to fix `zig fetch` errors caused by HTTP Proxy issues.

`Client.patch` contains the proxy changes from official Zig Pull Request [#36484](https://codeberg.org/ziglang/zig/pulls/36484). The installer applies only these changes, preserving other standard library updates.

> **How it works**: In Zig 0.17+, the build runner (`maker`) is JIT-compiled on the fly via `jitCmd` whenever `zig fetch` or `zig build` is executed. By patching `Client.zig` in your standard library, Zig automatically detects the source change and recompiles `maker` in seconds—no need to recompile the Zig compiler itself.

---

## Quick Start

> [!NOTE]
> The script depends on the system's `patch` command, which is pre-installed on macOS and most Linux distributions. If missing, install it via:
> - **Ubuntu / Debian**: `sudo apt-get install patch`
> - **Fedora / RHEL**: `sudo dnf install patch`
> - **Arch Linux**: `sudo pacman -S patch`
> - **Alpine Linux**: `apk add patch`
> - **macOS**: `xcode-select --install` or `brew install gpatch`

```bash
git clone https://github.com/jiacai2050/zig-maker.git
cd zig-maker

# Auto-detect std_dir, backup original and apply patch
./replace.sh

# Run test verification (based on Zig Cookbook HTTP GET example)
zig run test/http_get.zig

# Restore original if needed
./replace.sh --restore
```

Running `./replace.sh` repeatedly is idempotent and will not re-apply an already patched file.

---

## Fixes & Feedback

This patch is based on PR [#36484](https://codeberg.org/ziglang/zig/pulls/36484), addressing:
- Protocol forwarding issues during HTTP Proxy CONNECT tunnel handshakes;
- Connection pool double-release defects during connection cleanup and TLS upgrades.

Feedback is welcome! If you encounter issues or have successful test cases under various proxies, CDNs, or private registries, please report them in the Issues.

For an in-depth explanation of the Zig 0.17 architecture and our hotfix design, see [docs/how-zig-maker-works.md](docs/how-zig-maker-works.md).
