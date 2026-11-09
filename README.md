# zig-maker

[English](README.md) | [中文](README.zh.md)

A hotfix tool patching `std.http.Client` in Zig 0.17.0 and 0.17.1 to fix `zig fetch` errors caused by HTTP Proxy issues.

`Client.patch` contains the proxy changes from official Zig Pull Request [#36484](https://codeberg.org/ziglang/zig/pulls/36484). The installer applies only these changes, preserving other standard library updates. `Client.zig` is the legacy 0.17.0 reference snapshot; do not copy it into 0.17.1.

> **How it works**: In Zig 0.17+, the build runner (`maker`) is JIT-compiled on the fly via `jitCmd` whenever `zig fetch` or `zig build` is executed. By directly replacing `Client.zig` in your standard library, Zig automatically detects the source change and recompiles `maker` in seconds—no need to recompile the Zig compiler itself.

---

## Quick Start

```bash
git clone https://github.com/jiacai2050/zig-maker.git
cd zig-maker

# Auto-detect std_dir, backup original and patch (requires patch)
./replace.sh

# Restore original if needed
./replace.sh --restore
```

---

## Upgrading from the old installer

If you already copied the old `Client.zig` into Zig 0.17.1, restore its original file before applying the patch:

```bash
./replace.sh --restore
./replace.sh
```

The backup must belong to the same Zig version. If it is missing or contains the old snapshot, recover the original file from that Zig release first. The 0.17.1 HTTP APIs changed outside the proxy code, so replacing the whole file with the 0.17.0 snapshot breaks compatibility.

Repeated installation is a no-op. If the patch does not match, the installer leaves the standard library unchanged.

---

## Fixes & Feedback

This patch is based on PR [#36484](https://codeberg.org/ziglang/zig/pulls/36484), addressing:
- Protocol forwarding issues during HTTP Proxy CONNECT tunnel handshakes;
- Connection pool double-release defects during connection cleanup and TLS upgrades.

Feedback is welcome! If you encounter issues or have successful test cases under various proxies, CDNs, or private registries, please report them in the Issues.

For an in-depth explanation of the Zig 0.17 architecture and our hotfix design, see [docs/how-zig-maker-works.md](docs/how-zig-maker-works.md).
