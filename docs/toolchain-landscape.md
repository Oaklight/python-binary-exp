# Toolchain Landscape

[← Back to README](../README_en.md)

Full evaluation of every known Python-to-binary toolchain as of September 2025, assessed for viability with stdlib-only projects.

## Tier 1: Production-Ready Standalone Binary Tools

| Tool | Approach | Binary Size | Stdlib Coverage | Single-File? | Status |
|---|---|---|---|---|---|
| **Nuitka** | Transpile Python→C, bundle CPython | 7–20 MB | 100% | Yes (`--onefile`) | Active, production-ready |
| **PyInstaller** | Freeze bytecode + bundle interpreter | 8–23 MB | 100% | Yes (`--onefile`) | Active, widely used |
| **cx_Freeze** | Freeze bytecode + bundle interpreter | 19–40 MB (dir) | 100% | No (directory only) | Active |
| **cosmofy** | Bundle app into Cosmopolitan APE | ~39 MB | 100% (pure-Python) | Yes | Active, cross-platform |

### Nuitka

Python-to-C transpiler that compiles your code with GCC/Clang, then bundles the CPython runtime. Performs whole-program analysis, dead code elimination via `--nofollow-import-to`, and LTO. `--onefile` mode compresses the standalone directory into a self-extracting binary.

**Strengths:** smallest binaries (musl), handles dynamic imports via `--include-package` and `--include-data-dir`, mature CI story.
**Weaknesses:** slow builds (~2 min), larger glibc binaries.

### PyInstaller

Freezes Python bytecode and bundles the CPython interpreter without C compilation. `--onefile` packs everything into a self-extracting archive. `--strip` removes debug symbols for significant size reduction.

**Strengths:** fast builds (~30 sec), small stripped binaries, large community.
**Weaknesses:** struggles with dynamic `importlib` patterns — requires manual `--hidden-import` for each dynamically loaded module. Failed smoke test on llm-rosetta.

### cx_Freeze

Similar to PyInstaller but produces a directory (no onefile mode). Uses a `setup.py`-style API with `Executable` objects.

**Strengths:** best compatibility — all smoke tests passed on both projects. `optimize=2` removes docstrings and asserts.
**Weaknesses:** no single-file output. Directory sizes are 19–40 MB.

### cosmofy (Cosmopolitan)

Bundles your `.py` files into a Cosmopolitan Python APE (Actually Portable Executable). No compilation — just packaging. The result runs natively on Linux, macOS, and Windows from one file.

**Strengths:** cross-platform single file, near-instant builds (~3 sec), pure-Python focus.
**Weaknesses:** ~39 MB baseline (Cosmopolitan Python runtime is large), pure-Python only (no C extensions).

## Tier 2: Experimental / Not Yet Production-Ready

| Tool | Approach | Potential Size | Limitation |
|---|---|---|---|
| **pon** ([can1357/pon](https://github.com/can1357/pon)) | Rust AOT/JIT, Python 3.14→Cranelift→native | Sub-1 MB | Very early; stdlib incomplete |
| **Cython `--embed`** | Transpile to C + link libpython | 2–4 MB (static) | Manual static CPython builds per platform |
| **Shed Skin** | Restricted Python→C++ | 100–500 KB | ~30 stdlib modules only |
| **Codon** ([exaloop/codon](https://github.com/exaloop/codon)) | LLVM-based Python reimplementation | Small | ~27 modules; BSL license |

### pon — Watch List

A Rust-based AOT/JIT compiler targeting Python 3.14 via Cranelift. No CPython runtime at all — could potentially produce sub-1 MB binaries. Currently passes 209/244 corpus modules (JIT), 172 (AOT). Missing `_io`, `os`, `math`, `json`, `datetime`, `importlib`. Under heavy active development.

### Shed Skin — Supported Modules

Complete list from `shedskin/lib/` (v0.9.11): `array`, `base64` (partial), `binascii`, `bisect`, `collections` (deque only), `colorsys`, `configparser`, `copy`, `csv`, `datetime`, `fnmatch`, `functools`, `gc`, `getopt`, `glob`, `heapq`, `io` (partial), `itertools`, `math`, `mmap`, `os`+`os.path`, `random`, `re`, `select`, `signal`, `socket`, `stat`, `string`, `struct`, `sys`, `time`.

Missing for our projects: `json`, `hashlib`, `threading`, `subprocess`, `http`, `argparse`, `pathlib`, `urllib`, `asyncio`, `ssl`, `sqlite3`, `logging`, `dataclasses`, `gzip`, `zipfile`, `shutil`, `uuid`, `email`.

### Codon — Supported Modules

From `stdlib/` directory: `asyncio`, `bisect`, `bz2`, `cmath`, `collections`, `copy`, `datetime`, `functools`, `getopt`, `gzip`, `heapq`, `itertools`, `math`, `operator`, `os`+`os.path`, `pickle`, `random`, `re`, `statistics`, `string`, `sys`, `threading`, `time`, `typing`, `unicodedata`, `unittest`.

Same critical gaps as Shed Skin, plus BSL (Business Source License) — free for non-production, paid for commercial use.

## Tier 3: Not Standalone

| Tool | What It Produces |
|---|---|
| **mypyc** | C extension modules (`.so`/`.pyd`), not executables. Speeds up modules 1.5–10× but still needs Python installed. |
| **PEX / Shiv / zipapp** | Zip archives with bundled deps. Require Python installed on target. |

## Tier 4: Deprecated / Platform-Limited

| Tool | Status |
|---|---|
| **PyOxidizer** | Abandoned — project lead walked away ~2023 |
| **bbFreeze** | Dead, Python 2 only |
| **py2exe** | Windows only, barely maintained |
| **py2app** | macOS only |
