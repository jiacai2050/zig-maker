# zig-maker

[![CI](https://github.com/jiacai2050/zig-maker/actions/workflows/ci.yml/badge.svg)](https://github.com/jiacai2050/zig-maker/actions/workflows/ci.yml)

[English](README.md) | [中文](README.zh.md)

针对 Zig 0.17.0 和 0.17.1 中 `std.http.Client` 因 HTTP Proxy 支持缺陷导致 `zig fetch` 异常退出的局部补丁工具。

`Client.patch` 提取自 Zig 官方 Pull Request：[#36484](https://codeberg.org/ziglang/zig/pulls/36484)。脚本仅应用代理相关改动，保留标准库其它更新。

> **原理解析**：Zig 0.17 的构建调度器 `maker` 是在运行时通过 `jitCmd` 即时编译（JIT）的。修补标准库中的 `Client.zig` 后，下次执行 `zig fetch` 或 `zig build` 时就会自动侦测变更并秒级重编 `maker`，无需重新编译整个 Zig 编译器本体。

---

## 快速开始

> [!NOTE]
> 脚本执行依赖系统的 `patch` 命令。macOS 及主流 Linux 发行版通常已默认内置；如果未安装，可按需安装：
> - **Ubuntu / Debian**: `sudo apt-get install patch`
> - **Fedora / RHEL**: `sudo dnf install patch`
> - **Arch Linux**: `sudo pacman -S patch`
> - **Alpine Linux**: `apk add patch`
> - **macOS**: `xcode-select --install` 或 `brew install gpatch`

```bash
git clone https://github.com/jiacai2050/zig-maker.git
cd zig-maker

# 自动检测 std_dir，备份原文件并打补丁
./replace.sh

# 运行测试验证（参考 Zig Cookbook HTTP GET 示例）
zig run test/http_get.zig

# 如需还原官方原版
./replace.sh --restore
```

重复执行 `./replace.sh` 具有天然幂等性，已打补丁时不会重复应用。

---

## 修复内容与反馈

本补丁源自 PR [#36484](https://codeberg.org/ziglang/zig/pulls/36484)，主要解决：
- 修复 HTTP 代理（Proxy）CONNECT 隧道在握手时的协议传递；
- 修复连接池释放及 TLS Upgrade 过程中的连接重复释放（Double-Release）缺陷。

欢迎测试试用！如果你在各种代理、CDN 或私有源环境下遇到任何问题或验证成功，欢迎在 Issue 中提供反馈。

深入了解 Zig 0.17 运行器架构与热替换方案，请阅读：[docs/how-zig-maker-works.md](docs/how-zig-maker-works.md)。
