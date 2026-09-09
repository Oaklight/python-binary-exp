# Python Binary Compilation Experiments

[中文](README_zh.md)

Systematic parameter sweep comparing compilation toolchains for producing **minimal standalone binaries** from stdlib-only Python projects.

## Target Projects

| Project | Description | Repo |
|---|---|---|
| [llm-rosetta](https://github.com/oaklight/llm-rosetta) | LLM API gateway (~50 stdlib modules, dynamic importlib) | [GitHub](https://github.com/oaklight/llm-rosetta) |
| [tinyleaf](https://github.com/oaklight/tinyleaf) | Zero-dependency LaTeX web editor (~22 stdlib modules) | [GitHub](https://github.com/oaklight/tinyleaf) |

## Verdict: Single-File Binary Ranking

For stdlib-only Python projects that need a **single portable file**, ranked by binary size:

| Rank | Tool | tinyleaf | llm-rosetta | Platforms | Build Time |
|------|------|----------|-------------|-----------|------------|
| 🥇 | **Nuitka musl onefile** | **6.98 MB** ✅ | **11.62 MB** ✅ | Linux (musl) | ~2 min |
| 🥈 | **PyInstaller onefile** | **7.88 MB** ✅ | 10.15 MB ❌ | Linux | ~30 sec |
| 🥉 | **Nuitka glibc onefile** | 14.87 MB ✅ | 19.95 MB ✅ | Linux (glibc) | ~2 min |
| HM | **cosmofy APE** | 38.80 MB ✅ | 39.32 MB ✅ | Linux+macOS+Windows | ~3 sec |

> PyInstaller is fast and small but **fails on projects with dynamic `importlib` loading** (llm-rosetta). Nuitka handles everything.

### When to use what

- **Smallest binary, Linux-only** → Nuitka `--onefile` with musl
- **Simple project, fast builds** → PyInstaller `--onefile --strip` (verify smoke test)
- **Complex project with dynamic imports** → Nuitka `--onefile` (glibc or musl)
- **One binary for all platforms** → cosmofy (Cosmopolitan APE)
- **Directory deployment is OK** → cx_Freeze (best compatibility, all smoke tests pass)

### Not viable for standalone binaries

| Tool | Why |
|------|-----|
| Cython `--embed` | Requires `libpython.so` on target; static linking too fragile for CI |
| Shed Skin / Codon | Missing critical stdlib modules |
| mypyc | Produces `.so` extensions, not executables |
| PyOxidizer | Abandoned (~2023) |

## Detailed Results

| Document | Contents |
|----------|----------|
| [Toolchain Landscape](docs/toolchain-landscape.md) | Full evaluation of 12+ Python-to-binary tools |
| [Nuitka Results](docs/nuitka-results.md) | 40 parameter combos × 2 targets, flag impact analysis |
| [PyInstaller Results](docs/pyinstaller-results.md) | 12 combos, strip/UPX/onedir comparison |
| [cx_Freeze Results](docs/cxfreeze-results.md) | 8 combos, directory size analysis |
| [Cython Results](docs/cython-results.md) | Why `--embed` doesn't work for standalone |
| [Cosmofy Results](docs/cosmofy-results.md) | Cosmopolitan APE cross-platform builds |
| [Methodology](docs/methodology.md) | Sweep parameters, CI design, how to reproduce |
| [Glossary](docs/glossary.md) | APE, Cosmopolitan, Cranelift, LTO, musl, UPX, etc. |

## Quick Start

```bash
# Build tinyleaf with optimal Nuitka flags
make nuitka-build TARGET=tinyleaf

# Build llm-rosetta
make nuitka-build TARGET=llm-rosetta

# Analyze collected results
make analyze
```

## CI Workflows

- [Nuitka Sweep](../../actions/workflows/nuitka-sweep.yml) · [PyInstaller Sweep](../../actions/workflows/pyinstaller-sweep.yml) · [cx_Freeze Sweep](../../actions/workflows/cxfreeze-sweep.yml)
- [Cython Sweep](../../actions/workflows/cython-sweep.yml) · [Cosmofy Sweep](../../actions/workflows/cosmofy-sweep.yml)

## License

[MIT](LICENSE)
