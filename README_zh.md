# Python 二进制编译实验

[English](README_en.md)

系统性参数扫描，比较多种编译工具链将**仅依赖标准库的 Python 项目**编译为最小独立二进制文件的效果。本仓库同时作为实验平台和最佳编译策略的参考文档。

## 目标项目

| 项目 | 说明 | 使用的标准库模块数 | 仓库 |
|---|---|---|---|
| [llm-rosetta](https://github.com/oaklight/llm-rosetta) | LLM API 网关 | ~50 个，含 asyncio、http、ssl、sqlite3、importlib（动态加载） | [GitHub](https://github.com/oaklight/llm-rosetta) |
| [tinyleaf](https://github.com/oaklight/tinyleaf) | 零依赖 LaTeX 在线编辑器 | ~22 个，含 http.server、json、hashlib、subprocess、threading | [GitHub](https://github.com/oaklight/tinyleaf) |

两个项目运行时**仅依赖 Python 标准库**，是二进制体积优化的理想对象。

## 工具全景

我们评估了截至 2025 年 9 月所有已知的 Python 二进制编译工具链，按照对仅依赖标准库项目的适用性进行分级。

### 第一梯队：生产可用的独立二进制工具

| 工具 | 方法 | 二进制大小 | 标准库覆盖率 | 状态 |
|---|---|---|---|---|
| **Nuitka** | Python→C 转译，打包 CPython 运行时 | 7–20 MB | 100% | 活跃开发，生产可用 |
| **PyInstaller** | 冻结字节码 + 打包解释器 | 15–30 MB | 100% | 活跃开发，广泛使用 |
| **cx_Freeze** | 冻结字节码 + 打包解释器 | 15–25 MB | 100% | 活跃开发 |
| **cosmofy**（Cosmopolitan） | 将应用打包为 Actually Portable Executable | ~20–40 MB | 100%（仅限纯 Python） | 活跃开发，跨平台（Linux+macOS+Windows 单文件） |

### 第二梯队：实验性 / 尚未达到生产标准

| 工具 | 方法 | 潜在大小 | 限制 |
|---|---|---|---|
| **pon**（[can1357/pon](https://github.com/can1357/pon)） | 基于 Rust 的 AOT/JIT 编译器，Python 3.14→Cranelift→原生代码 | 可能低于 1 MB（无 CPython） | 非常早期；标准库实现不完整（缺少 `_io`、`os`、`json`、`datetime`、`importlib`） |
| **Cython `--embed`** | 转译为 C + 静态链接 libpython | 2–4 MB | 需要手动构建各平台的静态 CPython；CI 集成脆弱 |
| **Shed Skin** | 将受限 Python 转译为 C++ | 100–500 KB | 仅支持约 30 个标准库模块；缺少 `json`、`hashlib`、`threading`、`http`、`argparse`、`subprocess` |
| **Codon**（[exaloop/codon](https://github.com/exaloop/codon)） | 基于 LLVM 的 Python 重新实现 | 较小 | 约 27 个原生模块；BSL 许可证；缺少 `json`、`hashlib`、`http`、`argparse`、`subprocess` |

### 第三梯队：非独立（需要目标系统安装 Python）

| 工具 | 产物 |
|---|---|
| **mypyc** | C 扩展模块（`.so`/`.pyd`），不是可执行文件 |
| **PEX / Shiv / zipapp** | Zip 归档；需要目标系统安装 Python |

### 第四梯队：已废弃 / 仅限特定平台

| 工具 | 状态 |
|---|---|
| **PyOxidizer** | 已废弃（项目负责人约 2023 年离开） |
| **bbFreeze** | 停止维护，仅支持 Python 2 |
| **py2exe** | 仅限 Windows，几乎无人维护 |
| **py2app** | 仅限 macOS |

## 方法论

### Nuitka 参数扫描

我们在以下参数轴上对两个目标项目进行扫描，分别构建 **glibc**（原生 Ubuntu）和 **musl**（Alpine Docker）两种变体：

| 参数 | 测试值 |
|---|---|
| 模式 | `onefile`（单文件）、`standalone`（目录） |
| LTO（链接时优化） | `yes`、`no` |
| Python 标志 | `minimal`（`-O`）、`aggressive`（`-O`、`no_docstrings`、`no_warnings`、`no_annotations`、`no_asserts`） |
| 排除导入 | `standard`（测试/开发模块）、`maximal`（+ 未使用的标准库） |
| UPX 压缩 | `true`、`false` |

**每个目标共 40 种组合**（从 256 种全排列中精选）。

### Cython `--embed` 参数扫描

| 参数 | 测试值 |
|---|---|
| CC 优化级别 | `-O2`、`-Os`、`-O3` |
| LTO | `yes`、`no` |
| 去除符号 | `yes`、`no` |
| CPython 来源 | `system`（apt/apk）、`python-build-standalone`（astral-sh）、`source`（从源码编译） |
| 链接方式 | `dynamic`（动态）、`static`（静态） |
| UPX 压缩 | `true`、`false` |

**每个目标共 32 种组合**（从 576 种全排列中精选）。

### Cosmopolitan / cosmofy 扫描

| 参数 | 测试值 |
|---|---|
| 字节码编译 | `yes`、`no` |
| 目标项目 | 两个项目均测试 |

## 实验结果

### Nuitka — tinyleaf（20 次构建，全部完成）

按二进制大小升序排列。仅通过冒烟测试（`--help`）的配置被视为可用。

| 排名 | 模式 | LTO | Python 标志 | 排除导入 | UPX | Libc | 大小 (MB) | 冒烟测试 |
|------|------|-----|------------|---------|-----|------|-----------|---------|
| 1 | standalone | yes | aggressive | standard | no | musl | 6.29 | ✅ |
| 2 | standalone | yes | aggressive | standard | no | glibc | 6.31 | ✅ |
| 3 | onefile | yes | aggressive | standard | no | musl | **6.98** | ✅ |
| 4 | onefile | yes | aggressive | standard | yes | musl | 6.98 | ✅ |
| 5 | onefile | no | aggressive | standard | no | musl | 7.14 | ✅ |
| 6 | onefile | yes | minimal | standard | no | musl | 7.22 | ✅ |
| 7 | onefile | no | minimal | standard | no | musl | 7.38 | ✅ |
| 8 | onefile | yes | aggressive | standard | yes | glibc | **14.87** | ✅ |
| 9 | onefile | yes | aggressive | standard | no | glibc | 14.87 | ✅ |
| 10 | onefile | no | minimal | standard | no | glibc | 15.26 | ✅ |

> 所有 `nofollow=maximal` 配置的冒烟测试均失败——过度排除会移除 tinyleaf 实际使用的模块。

### Nuitka — llm-rosetta（20 次构建，全部完成）

| 排名 | 模式 | LTO | Python 标志 | 排除导入 | UPX | Libc | 大小 (MB) | 冒烟测试 |
|------|------|-----|------------|---------|-----|------|-----------|---------|
| 1 | onefile | yes | minimal | standard | no | musl | **11.62** | ✅ |
| 2 | onefile | no | minimal | standard | no | musl | 11.67 | ✅ |
| 3 | onefile | yes | minimal | standard | no | glibc | **19.95** | ✅ |
| 4 | onefile | no | minimal | standard | no | glibc | 19.96 | ✅ |

> **llm-rosetta 仅 `minimal` + `standard` 通过冒烟测试。** `aggressive` 标志（`no_annotations`、`no_asserts`）导致运行时崩溃，可能因为项目使用了运行时类型注解（如 `typing.get_type_hints()`）或关键的初始化断言。

### Cython `--embed` — tinyleaf（12 次构建完成）

| 配置 | 大小 | 冒烟测试 | Libc | 备注 |
|------|------|---------|------|------|
| `-Os`, lto=yes, strip=yes, dynamic | 0.02 MB | ✅ | glibc | **非独立** — 需要 `libpython3.12.so` |
| `-Os`, lto=yes, strip=yes, dynamic | 0.02 MB | ✅ | musl | **非独立** — 需要 `libpython3.12.so` |
| `-O2`, lto=no, strip=no, dynamic | 10.0 MB | ✅ | glibc | 包含调试符号；仍然非独立 |

> **关键发现：** 动态链接的 Cython 二进制文件虽然极小（~20 KB），但**不是独立的**——它依赖目标系统上的 `libpython3.x.so`。`libpython` 在 Linux/macOS/Windows 上均非默认安装。静态链接尝试大部分失败，原因是在 CI 中获取和链接静态 CPython 的复杂性。

### Cosmofy（Cosmopolitan APE）— 两个目标项目（4 次构建，2 次通过）

单个 Actually Portable Executable —— 一个二进制文件可在 Linux、macOS 和 Windows 上原生运行。

| 目标项目 | 字节码编译 | 大小 (MB) | 构建时间 | 冒烟测试 | 备注 |
|---------|-----------|-----------|---------|---------|------|
| tinyleaf | 否 | **38.80** | 3s | ✅ | 跨平台单文件 |
| llm-rosetta | 否 | **39.32** | 3s | ✅ | 跨平台单文件 |
| tinyleaf | 是 | — | — | ❌ | 字节码编译需要 CI 上的 APE 加载器 |
| llm-rosetta | 是 | — | — | ❌ | 同上 |

> Cosmopolitan Python 基础运行时约 39 MB。应用大小几乎可以忽略 —— tinyleaf 和 llm-rosetta 仅相差 0.5 MB。构建时间几乎为零，因为 cosmofy 只是将 `.py` 文件打包到 APE 的 zip 段中，而非编译。

### 跨工具链汇总（单文件，通过冒烟测试）

| 工具链 | tinyleaf | llm-rosetta | 平台 | 权衡 |
|---|---|---|---|---|
| **Nuitka onefile, musl** | **6.98 MB** | **11.62 MB** | Linux（仅 musl） | 最小二进制，仅限 musl |
| **Nuitka onefile, glibc** | 14.87 MB | 19.95 MB | Linux（glibc） | 最广泛的 Linux 兼容性 |
| **cosmofy APE** | 38.80 MB | 39.32 MB | Linux + macOS + Windows | 一个二进制，全平台 |

## 结论：单文件二进制排名

对于需要**单个可移植文件**的仅标准库 Python 项目，以下是三种可行方案，按二进制大小排名：

### 🥇 Nuitka `--onefile` + musl — 7–12 MB

最小的独立单文件。将 Python 转译为 C，打包精简的 CPython 运行时，使用 zlib 压缩全部内容。musl libc 使体积比 glibc 缩小约一半。

- tinyleaf: **6.98 MB** / llm-rosetta: **11.62 MB**
- 平台：仅 Linux（musl 链接，可在 Alpine 及大多数现代 Linux 上运行）
- 构建时间：约 2 分钟
- 适用场景：部署到 Linux 容器或服务器，且对体积敏感

### 🥈 PyInstaller `--onefile` — 8–10 MB（已 strip）

冻结字节码 + 打包 CPython 解释器。strip 后体积与 Nuitka 相当。无需 C 编译步骤，构建更快。

- tinyleaf: **7.88 MB**（glibc）/ **7.99 MB**（musl）— 冒烟测试 ✅
- llm-rosetta: **10.15 MB**（glibc）/ **10.42 MB**（musl）— 冒烟测试 ❌（动态 `importlib` 加载导致隐式导入问题）
- 构建时间：约 30 秒
- 适用场景：无复杂动态导入的标准项目；最快的构建流水线
- 注意：使用动态 `importlib` 模式的项目可能需要大量 `--hidden-import` 调优

### 🥉 Nuitka `--onefile` + glibc — 15–20 MB

同 🥇，但链接 glibc。体积更大（因为 glibc 本身更重），但兼容几乎所有 Linux 发行版。对于有动态导入的项目比 PyInstaller 更好（Nuitka 的 `--include-package` 可以处理）。

- tinyleaf: **14.87 MB** / llm-rosetta: **19.95 MB**
- 平台：仅 Linux（glibc，最广泛兼容）
- 构建时间：约 2 分钟
- 适用场景：目标 Linux 环境多样，或 PyInstaller 无法处理动态导入时

### 荣誉提名：cosmofy（Cosmopolitan APE）— ~39 MB

将 Cosmopolitan Python 运行时（约 39 MB 基线）和应用的 `.py` 文件打包为单个 Actually Portable Executable。无需编译，只是打包。一个文件可在 Linux、macOS 和 Windows 上原生运行。

- tinyleaf: **38.80 MB** / llm-rosetta: **39.32 MB**
- 平台：Linux + macOS + Windows（单个二进制）
- 构建时间：约 3 秒
- 适用场景：需要一个文件在所有平台运行，体积不是首要考虑

### 仅目录模式（非单文件）

| 工具 | 二进制 | 目录总大小 | 冒烟测试 | 备注 |
|------|--------|-----------|---------|------|
| **cx_Freeze**（tinyleaf, musl, opt=2） | 7.55 MB | **18.67 MB** | ✅ | 无 onefile 模式；需分发整个目录 |
| **cx_Freeze**（llm-rosetta, glibc, opt=2） | 6.78 MB | **39.32 MB** | ✅ | 所有冒烟测试通过（兼容性优于 PyInstaller） |
| **Nuitka `--standalone`**（tinyleaf, musl） | — | **6.29 MB** | ✅ | 最小目录输出 |

### 不适合独立分发的工具

| 工具 | 原因 |
|------|------|
| **Cython `--embed`** | 生成 20 KB 二进制但需要目标系统存在 `libpython.so`——非独立。静态链接理论上可行（约 3 MB），但需要手动构建各平台的静态 CPython，CI 集成太脆弱。 |
| **Shed Skin** | 缺少关键标准库模块（`json`、`hashlib`、`http`、`threading` 等） |
| **Codon** | 同样的标准库缺失 + BSL 商业许可证 |
| **mypyc** | 生成 `.so` 扩展模块，不是可执行文件 |
| **PyOxidizer** | 已废弃的项目 |

## 关键发现

### 1. musl 二进制文件比 glibc 小约 2 倍（Nuitka onefile 模式）

| 目标项目 | glibc onefile | musl onefile | 缩减比例 |
|---------|--------------|-------------|---------|
| tinyleaf | 14.87 MB | 6.98 MB | **53%** |
| llm-rosetta | 19.95 MB | 11.62 MB | **42%** |

musl libc 远小于 glibc，且 Nuitka 内部的 zlib 压缩在更小的负载上获得了更高的压缩比。

### 2. `aggressive` Python 标志因项目而异

| 标志 | tinyleaf | llm-rosetta |
|------|----------|-------------|
| `no_docstrings` | ✅ 安全 | ✅ 安全（已在使用） |
| `no_warnings` | ✅ 安全 | ✅ 安全（已在使用） |
| `no_annotations` | ✅ 安全 | ❌ **导致运行时崩溃** |
| `no_asserts` | ✅ 安全 | ❌ **导致运行时崩溃** |

> 添加 `no_annotations` 或 `no_asserts` 后**务必测试**。使用 Pydantic、`typing.get_type_hints()` 或初始化断言的项目会出问题。

### 3. UPX 对 Nuitka onefile 二进制文件无效

Nuitka 的 onefile 模式已使用 zlib 内部压缩负载（观测到约 28.5% 的压缩率）。UPX 无法进一步压缩已压缩的数据。UPX 仅在 `standalone` 模式下有效。

### 4. LTO 带来微小但一致的体积缩减

| 目标项目 | Libc | 无 LTO | 有 LTO | 节省 |
|---------|------|--------|--------|------|
| tinyleaf | musl | 7.38 MB | 7.22 MB | 2.2% |
| tinyleaf | glibc | 15.26 MB | 15.11 MB | 1.0% |
| llm-rosetta | musl | 11.67 MB | 11.62 MB | 0.4% |
| llm-rosetta | glibc | 19.96 MB | 19.95 MB | 0.05% |

### 5. `nofollow=maximal` 不安全

激进排除标准库模块（`logging`、`ssl`、`sqlite3`、`xml`、`ctypes`、`multiprocessing` 等）导致两个项目的冒烟测试均失败。`standard` 排除列表（测试/开发工具：`pytest`、`setuptools`、`tkinter`、`unittest`、`pydoc` 等）是安全上限。

### 7. cosmofy（Cosmopolitan APE）以体积换取通用可移植性

cosmofy 将整个 Cosmopolitan Python 运行时（约 39 MB 基线）加上应用的 `.py` 文件打包为单个 APE 二进制。产物可从同一个文件在 Linux、macOS 和 Windows 上运行——无需重新编译。构建时间几乎为零（约 3 秒），因为没有编译步骤，只是将代码打包到 APE 中。

权衡：**比 Nuitka musl onefile 大 5.5 倍**（39 MB vs 7 MB）。当跨平台分发比二进制大小更重要时选择 cosmofy。

### 6. Cython `--embed` 不适合生产级独立二进制

动态链接时 Cython 二进制文件需要目标系统存在 `libpython`。静态链接需要平台特定的静态 CPython 构建，CI 集成脆弱，且最终二进制（~2–4 MB）相比 Nuitka musl onefile（~7 MB）的体积优势不足以证明额外复杂度的合理性。

## 推荐配置

### 适用于 tinyleaf（或类似的简单纯标准库项目）

```bash
python -m nuitka \
  --onefile --lto=yes \
  --python-flag=-O \
  --python-flag=no_docstrings \
  --python-flag=no_warnings \
  --python-flag=no_annotations \
  --python-flag=no_asserts \
  --nofollow-import-to=pytest,setuptools,pip,_pytest,tkinter,unittest,pydoc,doctest,test,distutils,ensurepip,idlelib,lib2to3,turtle,turtledemo,xmlrpc,curses \
  --include-package=tinyleaf \
  entry.py
```

预期大小：**6.98 MB**（musl）、**14.87 MB**（glibc）。

### 适用于 llm-rosetta（或使用运行时注解/断言的项目）

```bash
python -m nuitka \
  --onefile --lto=yes \
  --python-flag=-O \
  --python-flag=no_docstrings \
  --python-flag=no_warnings \
  --nofollow-import-to=pytest,setuptools,pip,_pytest,tkinter,unittest,pydoc,doctest,test,distutils,ensurepip,idlelib,lib2to3,turtle,turtledemo,xmlrpc,curses \
  --include-package=llm_rosetta \
  entry.py
```

预期大小：**11.62 MB**（musl）、**19.95 MB**（glibc）。

> **不要**添加 `--python-flag=no_annotations` 或 `--python-flag=no_asserts`，除非验证二进制文件能通过冒烟测试。

## 术语表

| 术语 | 定义 |
|------|------|
| **APE** | Actually Portable Executable（真正可移植的可执行文件）—— 一种同时作为 Linux ELF、Windows PE 和 macOS Mach-O 有效的单个二进制文件格式，由 Justine Tunney 发明。 |
| **Cosmopolitan Libc** | 一种使构建 APE 二进制文件成为可能的 C 库。链接到它的程序可以从单个文件在 Linux、macOS、Windows、FreeBSD、OpenBSD 和 NetBSD 上原生运行。 |
| **cosmofy** | 使用 Cosmopolitan Python 将 Python 应用打包为 APE 二进制文件的工具。仅支持纯 Python。 |
| **Cranelift** | 用 Rust 编写的快速代码生成器（编译器后端），被 `pon` 项目使用。LLVM 的替代品，针对编译速度优化。 |
| **LTO** | 链接时优化 —— 允许编译器/链接器跨翻译单元进行优化，实现跨模块边界的死代码消除和内联。 |
| **musl** | Linux 上的轻量级 C 标准库实现，专为静态链接设计。生成的二进制文件比 glibc 更小。 |
| **glibc** | GNU C 库 —— 大多数 Linux 发行版上的标准 libc。比 musl 更大但兼容性更广。 |
| **Nuitka** | 一种 Python 编译器，将 Python 源码转译为 C，然后使用 GCC/Clang 编译。打包 CPython 运行时实现独立分发。 |
| **UPX** | Ultimate Packer for eXecutables —— 一种可执行文件压缩器。对 Nuitka onefile 无效（已经压缩），但对 standalone 模式有用。 |
| **nofollow-import-to** | Nuitka 标志，将特定模块排除在编译之外，以减小二进制大小，代价是可能出现运行时 ImportError。 |

## 仓库结构

```
.github/workflows/
  nuitka-sweep.yml          # Nuitka 参数扫描 CI
  cython-sweep.yml          # Cython --embed 参数扫描 CI
  cosmofy-sweep.yml         # Cosmopolitan/cosmofy 扫描 CI（计划中）
configs/
  nuitka_matrix.json        # Nuitka 扫描矩阵（40 种组合）
  cython_matrix.json        # Cython 扫描矩阵（32 种组合）
scripts/
  prepare_target.sh         # 克隆/安装目标项目
  build_nuitka.sh           # 参数化 Nuitka 构建
  build_cython.sh           # 参数化 Cython --embed 构建
  analyze_results.py        # 生成排名比较表
Makefile                    # 本地构建便捷命令
```

## 本地复现

```bash
# 使用 Nuitka 构建 tinyleaf（默认最优参数）
make nuitka-build TARGET=tinyleaf

# 使用 Nuitka 构建 llm-rosetta
make nuitka-build TARGET=llm-rosetta

# 对收集的结果进行分析
make analyze
```

## CI 工作流运行

- [Nuitka 扫描](../../actions/workflows/nuitka-sweep.yml)
- [Cython 扫描](../../actions/workflows/cython-sweep.yml)

## 许可证

[MIT](LICENSE)
