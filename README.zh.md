# zig-maker

[English](README.md) | [中文](README.zh.md)

针对 Zig 0.17+ 中 `std.http.Client` 因 HTTP Proxy 支持缺陷导致 `zig fetch` 异常退出的热替换修复工具。

仓库中的 `Client.zig` 源自 Zig 官方 Pull Request：[#36484](https://codeberg.org/ziglang/zig/pulls/36484)。欢迎试用并提供反馈！

> **原理解析**：Zig 0.17 的构建调度器 `maker` 是在运行时通过 `jitCmd` 即时编译（JIT）的。直接替换标准库中的 `Client.zig`，下次执行 `zig fetch` 或 `zig build` 时就会自动侦测变更并秒级重编 `maker`，无需重新编译整个 Zig 编译器本体。

---

## 快速开始

```bash
git clone https://github.com/jiacai2050/zig-maker.git
cd zig-maker

# Auto-detect std_dir, backup original and replace
./replace.sh

# Restore original if needed
./replace.sh --restore
```

---

## 手动操作

通过 `zig env` 提取标准库目录后直接覆盖：

```bash
# 1. Query active std_dir
STD_DIR=$(zig env | awk -F'"' '/\.std_dir =/ {print $2}')

# 2. Backup original Client.zig
cp "${STD_DIR}/http/Client.zig" "${STD_DIR}/http/Client.zig.orig"

# 3. Copy fixed version
cp ./Client.zig "${STD_DIR}/http/Client.zig"
```

---

## 修复内容与反馈

本补丁源自 PR [#36484](https://codeberg.org/ziglang/zig/pulls/36484)，主要解决：
- 修复 HTTP 代理（Proxy）CONNECT 隧道在握手时的协议传递；
- 修复连接池释放及 TLS Upgrade 过程中的连接重复释放（Double-Release）缺陷。

欢迎测试试用！如果你在各种代理、CDN 或私有源环境下遇到任何问题或验证成功，欢迎在 Issue 中提供反馈。
