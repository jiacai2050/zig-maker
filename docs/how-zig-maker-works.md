# 基于 Zig 0.17 架构的运行器热替换实践：解决 zig fetch 代理缺陷

在 Zig 项目开发过程中，包管理器（`zig fetch` 及 `build.zig.zon` 依赖拉取）是开发者使用频率极高的基础工具。在 Zig 0.17 中，如果处于复杂的 HTTP 代理（Proxy）或企业私有镜像网络环境下，`zig fetch` 可能会频繁抛出连接异常或崩溃。

官方社区在 PR [#36484](https://codeberg.org/ziglang/zig/pulls/36484) 中给出了针对 `std.http.Client` 的关键修复。但在常规认知中，修改编译器标准库往往意味着必须全量重新编译庞大的 `zig` 二进制（动辄需要重新编译 LLVM、Clang 及 C++ 驱动，耗费半小时以上）。

本项目 [zig-maker](https://github.com/jiacai2050/zig-maker) 利用 **Zig 0.17 全新的即时自举架构**，实现了在**不重编编译器本体**的前提下，对底层运行器进行秒级热替换。本文将系统阐述其背后的架构演进原理与工程实现。

---

## 1. 现象与根源：`std.http.Client` 的代理缺陷

### 1.1 报错现象
当通过环境变量配置了代理（如 `HTTPS_PROXY`），执行依赖下载时：
```bash
$ zig fetch https://github.com/user/repo/archive/refs/tags/v1.0.0.tar.gz
Fetch
...
error: invalid HTTP response: HttpConnectionClosing
或者
error: unable to discover remote git server capabilities: TlsInitializationFailed
```
终端会连续反复打印数十次重试日志，最终异常终止。

### 1.2 源码级根因剖析
在 Zig 标准库源码 `lib/std/http/Client.zig` 中，HTTP 代理支持主要存在以下两处问题：
1. **CONNECT 隧道握手时的协议传递错误**：
   在建立代理隧道连接 `findConnection` 时，未正确继承外层请求所需的目标协议，导致后续连接复用失效；
2. **连接池清理中的 Double-Release**：
   在 TLS 升级（TLS Upgrade）与错误回滚（`errdefer`）路径中，底层连接的关闭与归还状态未做互斥标记，发生双重释放，破坏了连接池状态机，导致后续复用直接遭遇服务端挂断。

官方 PR [#36484](https://codeberg.org/ziglang/zig/pulls/36484) 对上述逻辑进行了严谨重构，修复了连接池与代理隧道的握手流程。

---

## 2. Zig 0.17 架构演进：解耦与 JIT 自举

要理解为何“替换一个源文件即可生效”，首先需要理清 Zig 0.17 在构建体系上的重大变革。

### 2.1 从静态单体到两阶段双进程
在 0.16 及更早版本中，`zig build` 的运行器（`build_runner.zig`）虽然也是动态编译的，但包管理下载器以及诸多工具逻辑仍然与主编译器紧密绑定。

在 0.17 中，构建体系被彻底解耦为两个核心组件：
- **`Maker`**：构建流程的常驻调度器，负责任务编排、文件监听（Watch）、缓存管理与依赖拉取；
- **`Configurer`**：由 `Maker` 派生的沙箱子进程，负责执行 `build.zig` 生成有向无环图（DAG），具备严格的纯函数性与缓存机制。

```mermaid
graph TD
    subgraph CLI ["Zig 主命令行入口 (src/main.zig)"]
        cmd["zig fetch / zig build"]
        jit["jitCmd 即时编译引擎"]
    end

    subgraph Runtime ["JIT 运行时产物 (~/.cache/zig/o/)"]
        maker["Maker 运行器二进制"]
    end

    subgraph StandardLib ["本地标准库 (${std_dir})"]
        client["std/http/Client.zig"]
        maker_src["compiler/Maker.zig"]
    end

    cmd --> jit
    maker_src --> jit
    client --> maker_src
    jit -- "编译并缓存" --> maker
    maker -- "execve 替换进程" --> maker

    classDef default fill:#f8f9fa,stroke:#495057;
    style CLI fill:#fff0e6,stroke:#ff9900,stroke-width:2px;
    style Runtime fill:#e6ffe6,stroke:#009900,stroke-width:2px;
    style StandardLib fill:#cce5ff,stroke:#0066cc,stroke-width:2px;
```

### 2.2 `jitCmd`：即时编译的实现机制
在 Zig 0.17 的源码 `src/main.zig:L352-L363` 中：
```zig
.build, .fetch, .init, .libc, .@"cache-cat" => {
    return jitCmd(gpa, arena, io, cmd_args, environ_map, .{
        .cmd_name = "maker",
        .root_src_path = "Maker.zig",
        .prepend_cmd = cmd,
        .prepend_zig_lib_dir_path = true,
        .prepend_global_cache_path = true,
        .prepend_zig_exe_path = true,
        .prepend_seed = true,
        .release_mode = .safe,
    });
},
```
从上面的源码可以看出：
1. `zig fetch` 和 `zig build` 并没有在单体二进制中内置固定的二进制机器码，而是全部转发给 `jitCmd`；
2. `jitCmd` 找到 `<zig_lib>/compiler/Maker.zig`，并将其与标准库一同编译为独立的可执行文件 `maker`；
3. 产物输出到全局缓存 `.cache/zig/o/<digest>/maker`；
4. 编译完成后，通过 `process.replace`（即 Unix 的 `execve`）直接替换当前主进程。

---

## 3. 热替换方案：四两拨千斤

基于 0.17 的架构特性，我们可以得出一条清晰的结论：**`Maker` 的生命周期完全依赖其依赖源文件的哈希签名**。

```
                    修改源文件 (Client.zig)
                             ↓
              源文件 Manifest Hash 改变
                             ↓
下一次执行 zig fetch 时，jitCmd 侦测到缓存失效
                             ↓
                自动重新 JIT 编译 Maker
                             ↓
               修复逻辑秒级生效，无需重编编译器
```

### 3.1 动态定位标准库：`zig env`
不同系统或版本管理工具（如 `asdf`、Homebrew、源码安装）下的 Zig 安装路径各不相同。硬编码路径不仅容易失效，还不具备可移植性。

Zig 提供了官方自省接口 `zig env`，输出结构化配置：
```zig
.{
    .zig_exe = "/path/to/bin/zig",
    .lib_dir = "/path/to/lib",
    .std_dir = "/path/to/lib/std",
    .version = "0.17.0",
    ...
}
```
通过提取 `.std_dir`，即可准确定位目标文件：
```bash
# Query active std_dir
STD_DIR=$(zig env | awk -F'"' '/\.std_dir =/ {print $2}')
TARGET="${STD_DIR}/http/Client.zig"
```

### 3.2 极简的脚本设计：`replace.sh`
在 [zig-maker](https://github.com/jiacai2050/zig-maker) 中，我们将整个热替换流程压缩至一段仅 20 余行的 Shell 脚本中，兼顾安全性与易用性：

1. **环境与版本防御**：
   `Client.zig` 依赖了 0.17 引入的全新 `std.Io` 接口体系，脚本在执行前首先严格校验 `zig version`，若非 `0.17.x` 则立即阻断，避免污染旧版本；
2. **自动原子备份**：
   在首次覆盖前，将原始文件备份为 `Client.zig.orig`；
3. **一键还原**：
   通过 `./replace.sh --restore` 即可完整恢复官方原版代码。

---

## 4. 验证与实战效果

### 4.1 替换与生效验证
在项目根目录下执行替换：
```bash
$ ./replace.sh
Replaced /path/to/0.17.0/lib/std/http/Client.zig (backup at .../Client.zig.orig)
```

通过开启 `ZIG_VERBOSE_CMD=1`，可以直观观察到 Zig 自动完成增量重编与调用的全过程：
```bash
# Enable verbose sub-process logging
$ ZIG_VERBOSE_CMD=1 zig fetch git+https://github.com/jiacai2050/zig-curl.git
info: /Users/.../.cache/zig/o/4f8a.../maker fetch ...
curl-0.5.1-P4tT4cv-AABoE4oWNFmyMed5FEwutUbxJYbWx1PWjhm7
```
原本卡死报错的依赖包瞬间完成下载与哈希校验，`build.zig.zon` 解析恢复正常。

---

## 5. 架构启示与总结

Zig 0.17 将运行器从静态二进制中剥离并改为 JIT 自举，这一架构重组带来了显著的工程收益：

1. **编译器本体更紧凑**：主编译器不再混杂臃肿的高层网络与调度逻辑；
2. **可维护性与可修补性（Patchability）大幅提升**：面对类似 HTTP 客户端、依赖拉取或构建编排层面的缺陷，开发者不再受限于官方发布周期，可以直接在源码层打补丁并秒级生效；
3. **标准库演进更平滑**：只要接口语义保持一致，上层运行器随时能享受到底层标准库重构带来的改进。

通过本项目提供的轻量工具，开发者可以在 Zig 官方正式合入并发布该 PR 之前，顺畅地在代理与私有网络环境下推进基于 Zig 0.17 的各项业务开发。
