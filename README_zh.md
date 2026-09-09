# Python 二进制编译实验

[English](README_en.md)

系统性参数扫描，比较多种编译工具链将**仅依赖标准库的 Python 项目**编译为最小独立二进制文件的效果。

## 目标项目

| 项目 | 说明 | 仓库 |
|---|---|---|
| [llm-rosetta](https://github.com/oaklight/llm-rosetta) | LLM API 网关（~50 个标准库模块，含动态 importlib） | [GitHub](https://github.com/oaklight/llm-rosetta) |
| [tinyleaf](https://github.com/oaklight/tinyleaf) | 零依赖 LaTeX 在线编辑器（~22 个标准库模块） | [GitHub](https://github.com/oaklight/tinyleaf) |

## 结论：单文件二进制排名

对于需要**单个可移植文件**的仅标准库 Python 项目，按二进制大小排名：

| 排名 | 工具 | tinyleaf | llm-rosetta | 平台 | 构建时间 |
|------|------|----------|-------------|------|---------|
| 🥇 | **Nuitka musl onefile** | **6.98 MB** ✅ | **11.62 MB** ✅ | Linux (musl) | ~2 分钟 |
| 🥈 | **PyInstaller onefile** | **7.88 MB** ✅ | 10.15 MB ❌ | Linux | ~30 秒 |
| 🥉 | **Nuitka glibc onefile** | 14.87 MB ✅ | 19.95 MB ✅ | Linux (glibc) | ~2 分钟 |
| HM | **cosmofy APE** | 38.80 MB ✅ | 39.32 MB ✅ | Linux+macOS+Windows | ~3 秒 |

> PyInstaller 构建快且体积小，但**无法处理动态 `importlib` 加载的项目**（llm-rosetta）。Nuitka 能处理所有情况。

### 何时使用哪个

- **最小二进制，仅 Linux** → Nuitka `--onefile` + musl
- **简单项目，快速构建** → PyInstaller `--onefile --strip`（需验证冒烟测试）
- **有动态导入的复杂项目** → Nuitka `--onefile`（glibc 或 musl）
- **一个二进制覆盖所有平台** → cosmofy（Cosmopolitan APE）
- **目录部署可接受** → cx_Freeze（最佳兼容性，所有冒烟测试通过）

### 不适合独立二进制的工具

| 工具 | 原因 |
|------|------|
| Cython `--embed` | 需要目标系统存在 `libpython.so`；静态链接 CI 太脆弱 |
| Shed Skin / Codon | 缺少关键标准库模块 |
| mypyc | 生成 `.so` 扩展，不是可执行文件 |
| PyOxidizer | 已废弃（~2023） |

## 详细结果

| 文档 | 内容 |
|------|------|
| [工具全景](docs/toolchain-landscape.md) | 12+ 种 Python 二进制工具的完整评估 |
| [Nuitka 结果](docs/nuitka-results.md) | 40 种参数组合 × 2 个目标，标志影响分析 |
| [PyInstaller 结果](docs/pyinstaller-results.md) | 12 种组合，strip/UPX/onedir 对比 |
| [cx_Freeze 结果](docs/cxfreeze-results.md) | 8 种组合，目录大小分析 |
| [Cython 结果](docs/cython-results.md) | 为何 `--embed` 不适合独立分发 |
| [Cosmofy 结果](docs/cosmofy-results.md) | Cosmopolitan APE 跨平台构建 |
| [方法论](docs/methodology.md) | 扫描参数、CI 设计、如何复现 |
| [术语表](docs/glossary.md) | APE、Cosmopolitan、Cranelift、LTO、musl、UPX 等 |

## 快速开始

```bash
# 使用最优 Nuitka 参数构建 tinyleaf
make nuitka-build TARGET=tinyleaf

# 构建 llm-rosetta
make nuitka-build TARGET=llm-rosetta

# 分析收集的结果
make analyze
```

## CI 工作流

- [Nuitka 扫描](../../actions/workflows/nuitka-sweep.yml) · [PyInstaller 扫描](../../actions/workflows/pyinstaller-sweep.yml) · [cx_Freeze 扫描](../../actions/workflows/cxfreeze-sweep.yml)
- [Cython 扫描](../../actions/workflows/cython-sweep.yml) · [Cosmofy 扫描](../../actions/workflows/cosmofy-sweep.yml)

## 许可证

[MIT](LICENSE)
