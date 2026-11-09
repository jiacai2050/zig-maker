# zig-maker

[English](README.md) | [中文](README.zh.md)

针对 Zig 0.17.0 和 0.17.1 中 `std.http.Client` 因 HTTP Proxy 支持缺陷导致 `zig fetch` 异常退出的局部补丁工具。

`Client.patch` 提取自 Zig 官方 Pull Request：[#36484](https://codeberg.org/ziglang/zig/pulls/36484)。脚本仅应用代理相关改动，保留标准库其它更新。仓库中的 `Client.zig` 是旧版 0.17.0 参考快照，请勿复制到 0.17.1。

> **原理解析**：Zig 0.17 的构建调度器 `maker` 是在运行时通过 `jitCmd` 即时编译（JIT）的。直接替换标准库中的 `Client.zig`，下次执行 `zig fetch` 或 `zig build` 时就会自动侦测变更并秒级重编 `maker`，无需重新编译整个 Zig 编译器本体。

---

## 快速开始

```bash
git clone https://github.com/jiacai2050/zig-maker.git
cd zig-maker

# Auto-detect std_dir, backup original and patch (requires patch)
./replace.sh

# Restore original if needed
./replace.sh --restore
```

---

## 从旧版工具迁移

如果已经把旧版 `Client.zig` 复制到 Zig 0.17.1，请先恢复原文件，再应用补丁：

```bash
./replace.sh --restore
./replace.sh
```

备份必须来自同一 Zig 版本。若备份缺失或也是旧快照，请先从对应版本的发行包恢复原文件。0.17.1 在代理代码之外更新了 HTTP API，整文件覆盖为 0.17.0 快照会破坏兼容性。

重复执行不会再次打补丁；补丁无法匹配时，脚本会退出并保留标准库原文件。

---

## 修复内容与反馈

本补丁源自 PR [#36484](https://codeberg.org/ziglang/zig/pulls/36484)，主要解决：
- 修复 HTTP 代理（Proxy）CONNECT 隧道在握手时的协议传递；
- 修复连接池释放及 TLS Upgrade 过程中的连接重复释放（Double-Release）缺陷。

欢迎测试试用！如果你在各种代理、CDN 或私有源环境下遇到任何问题或验证成功，欢迎在 Issue 中提供反馈。

深入了解 Zig 0.17 运行器架构与热替换方案，请阅读：[docs/how-zig-maker-works.md](docs/how-zig-maker-works.md)。
