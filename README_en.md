# Python Binary Compilation Experiments

[中文](README_zh.md)

Systematic parameter sweep comparing compilation toolchains for producing **minimal standalone binaries** from stdlib-only Python projects. This repository serves as both an experimental harness and a reference for selecting optimal compilation strategies.

## Target Projects

| Project | Description | Stdlib Modules Used | Repo |
|---|---|---|---|
| [llm-rosetta](https://github.com/oaklight/llm-rosetta) | LLM API gateway | ~50 modules incl. asyncio, http, ssl, sqlite3, importlib (dynamic) | [GitHub](https://github.com/oaklight/llm-rosetta) |
| [tinyleaf](https://github.com/oaklight/tinyleaf) | Zero-dependency LaTeX web editor | ~22 modules incl. http.server, json, hashlib, subprocess, threading | [GitHub](https://github.com/oaklight/tinyleaf) |

Both projects depend **only on the Python standard library** at runtime, making them ideal candidates for binary size optimization.

## Tooling Landscape

We evaluated every known Python-to-binary toolchain as of September 2025. The table below summarizes viability for stdlib-only projects seeking the smallest standalone single-file binary.

### Tier 1: Production-Ready Standalone Binary Tools

| Tool | Approach | Binary Size | Stdlib Coverage | Status |
|---|---|---|---|---|
| **Nuitka** | Transpile Python→C, bundle CPython runtime | 7–20 MB | 100% | Active, production-ready |
| **PyInstaller** | Freeze bytecode + bundle interpreter | 15–30 MB | 100% | Active, widely used |
| **cx_Freeze** | Freeze bytecode + bundle interpreter | 15–25 MB | 100% | Active |
| **cosmofy** (Cosmopolitan) | Bundle app into Actually Portable Executable | ~20–40 MB | 100% (pure-Python only) | Active, cross-platform (Linux+macOS+Windows in one file) |

### Tier 2: Experimental / Not Yet Production-Ready

| Tool | Approach | Potential Size | Limitation |
|---|---|---|---|
| **pon** ([can1357/pon](https://github.com/can1357/pon)) | Rust-based AOT/JIT, Python 3.14→Cranelift→native | Sub-1 MB (no CPython) | Very early; stdlib build-out incomplete (missing `_io`, `os`, `json`, `datetime`, `importlib`) |
| **Cython `--embed`** | Transpile to C + static link against libpython | 2–4 MB | Requires manual static CPython builds per platform; fragile CI plumbing |
| **Shed Skin** | Transpile restricted Python→C++ | 100–500 KB | Only ~30 stdlib modules; missing `json`, `hashlib`, `threading`, `http`, `argparse`, `subprocess` |
| **Codon** ([exaloop/codon](https://github.com/exaloop/codon)) | LLVM-based Python reimplementation | Small | ~27 native modules; BSL license; missing `json`, `hashlib`, `http`, `argparse`, `subprocess` |

### Tier 3: Not Standalone (Require Python on Target)

| Tool | What It Produces |
|---|---|
| **mypyc** | C extension modules (`.so`/`.pyd`), not executables |
| **PEX / Shiv / zipapp** | Zip archives; require Python installed on target |

### Tier 4: Deprecated / Platform-Limited

| Tool | Status |
|---|---|
| **PyOxidizer** | Abandoned (project lead stepped away ~2023) |
| **bbFreeze** | Dead, Python 2 only |
| **py2exe** | Windows only, barely maintained |
| **py2app** | macOS only |

## Methodology

### Nuitka Parameter Sweep

We swept the following axes across both target projects, building for both **glibc** (native Ubuntu) and **musl** (Alpine Docker):

| Parameter | Values Tested |
|---|---|
| Mode | `onefile`, `standalone` (directory) |
| LTO (Link-Time Optimization) | `yes`, `no` |
| Python flags | `minimal` (`-O`), `aggressive` (`-O`, `no_docstrings`, `no_warnings`, `no_annotations`, `no_asserts`) |
| Nofollow imports | `standard` (test/dev modules), `maximal` (+ unused stdlib) |
| UPX compression | `true`, `false` |

**Total: 40 combinations per target** (pruned from 256 full cartesian).

### Cython `--embed` Parameter Sweep

| Parameter | Values Tested |
|---|---|
| CC optimization | `-O2`, `-Os`, `-O3` |
| LTO | `yes`, `no` |
| Strip symbols | `yes`, `no` |
| CPython source | `system` (apt/apk), `python-build-standalone` (astral-sh), `source` (compiled from CPython tarball) |
| Linking | `dynamic`, `static` |
| UPX compression | `true`, `false` |

**Total: 32 combinations per target** (pruned from 576 full cartesian).

### Cosmopolitan / cosmofy Sweep

| Parameter | Values Tested |
|---|---|
| Bytecode compilation | `yes`, `no` |
| Target | both projects |

## Results

### Nuitka — tinyleaf (20 builds, all completed)

Sorted by binary size ascending. Only configurations passing the smoke test (`--help`) are considered viable.

| Rank | Mode | LTO | Python Flags | Nofollow | UPX | Libc | Size (MB) | Smoke |
|------|------|-----|-------------|----------|-----|------|-----------|-------|
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

> All `nofollow=maximal` configs failed smoke tests — maximal exclusion removes modules tinyleaf actually uses.

### Nuitka — llm-rosetta (20 builds, all completed)

| Rank | Mode | LTO | Python Flags | Nofollow | UPX | Libc | Size (MB) | Smoke |
|------|------|-----|-------------|----------|-----|------|-----------|-------|
| 1 | onefile | yes | minimal | standard | no | musl | **11.62** | ✅ |
| 2 | onefile | no | minimal | standard | no | musl | 11.67 | ✅ |
| 3 | onefile | yes | minimal | standard | no | glibc | **19.95** | ✅ |
| 4 | onefile | no | minimal | standard | no | glibc | 19.96 | ✅ |

> **Only `minimal` + `standard` passed smoke tests for llm-rosetta.** The `aggressive` flags (`no_annotations`, `no_asserts`) break llm-rosetta, likely because it uses runtime type annotations (e.g., `typing.get_type_hints()`) or initialization-critical assertions.

### Cython `--embed` — tinyleaf (12 builds completed)

| Config | Size | Smoke | Libc | Notes |
|--------|------|-------|------|-------|
| `-Os`, lto=yes, strip=yes, dynamic | 0.02 MB | ✅ | glibc | **Not standalone** — requires `libpython3.12.so` |
| `-Os`, lto=yes, strip=yes, dynamic | 0.02 MB | ✅ | musl | **Not standalone** — requires `libpython3.12.so` |
| `-O2`, lto=no, strip=no, dynamic | 10.0 MB | ✅ | glibc | Includes debug symbols; still not standalone |

> **Key finding:** Cython `--embed` with dynamic linking produces a tiny binary (~20 KB) but it is **not standalone** — it depends on `libpython3.x.so` at runtime, which is not universally available on target systems. Static linking attempts largely failed due to the complexity of obtaining and linking static CPython builds in CI. Cython `--embed` is not a practical path for standalone distribution without significant manual plumbing.

### Cosmofy (Cosmopolitan APE) — Both Targets (4 builds, 2 passed)

Single Actually Portable Executable — one binary runs on Linux, macOS, and Windows natively.

| Target | Bytecode Compiled | Size (MB) | Build Time | Smoke | Notes |
|--------|-------------------|-----------|------------|-------|-------|
| tinyleaf | no | **38.80** | 3s | ✅ | Cross-platform single file |
| llm-rosetta | no | **39.32** | 3s | ✅ | Cross-platform single file |
| tinyleaf | yes | — | — | ❌ | Bytecode compilation requires APE loader on CI |
| llm-rosetta | yes | — | — | ❌ | Same issue |

> The base Cosmopolitan Python runtime is ~39 MB. App size adds negligibly — tinyleaf and llm-rosetta differ by only 0.5 MB. Build time is near-instant since cosmofy just bundles `.py` files into the APE zip section rather than compiling.

### Cross-Toolchain Summary (single-file, smoke-test passing)

| Toolchain | tinyleaf | llm-rosetta | Platforms | Trade-off |
|---|---|---|---|---|
| **Nuitka onefile, musl** | **6.98 MB** | **11.62 MB** | Linux (musl only) | Smallest binary, musl-only |
| **Nuitka onefile, glibc** | 14.87 MB | 19.95 MB | Linux (glibc) | Broadest Linux compat |
| **cosmofy APE** | 38.80 MB | 39.32 MB | Linux + macOS + Windows | One binary, all platforms |

## Verdict: Single-File Binary Ranking

For stdlib-only Python projects that need a **single portable file**, here are the three viable options, ranked by binary size:

### 🥇 Nuitka `--onefile` with musl — 7–12 MB

The smallest standalone single file. Transpiles Python to C, bundles a minimal CPython runtime, compresses everything with zlib. musl libc cuts size roughly in half compared to glibc.

- tinyleaf: **6.98 MB** / llm-rosetta: **11.62 MB**
- Platform: Linux only (musl-linked, runs on Alpine and most modern Linux)
- Build time: ~2 minutes
- Use when: deploying to Linux containers or servers where size matters

### 🥈 PyInstaller `--onefile` — 8–10 MB (stripped)

Freezes bytecode + bundles CPython interpreter. Comparable size to Nuitka when stripped. No C compilation step — faster builds.

- tinyleaf: **7.88 MB** (glibc) / **7.99 MB** (musl) — smoke ✅
- llm-rosetta: **10.15 MB** (glibc) / **10.42 MB** (musl) — smoke ❌ (hidden import issues with dynamic `importlib` loading)
- Build time: ~30 seconds
- Use when: standard projects without complex dynamic imports; fastest build pipeline
- Caveat: projects with dynamic `importlib` patterns may need extensive `--hidden-import` tuning

### 🥉 Nuitka `--onefile` with glibc — 15–20 MB

Same as 🥇 but linked against glibc. Larger because glibc is heavier, but compatible with virtually all Linux distributions. Better than PyInstaller for projects with dynamic imports (Nuitka's `--include-package` handles them).

- tinyleaf: **14.87 MB** / llm-rosetta: **19.95 MB**
- Platform: Linux only (glibc, broadest compatibility)
- Build time: ~2 minutes
- Use when: targeting diverse Linux environments, or when PyInstaller can't handle dynamic imports

### Honorable mention: cosmofy (Cosmopolitan APE) — ~39 MB

Bundles the Cosmopolitan Python runtime (~39 MB baseline) with your `.py` files into a single Actually Portable Executable. No compilation — just packaging. One file runs natively on Linux, macOS, and Windows.

- tinyleaf: **38.80 MB** / llm-rosetta: **39.32 MB**
- Platform: Linux + macOS + Windows (one binary)
- Build time: ~3 seconds
- Use when: you need one file that works everywhere, and size is secondary

### Directory-only (not single-file)

| Tool | Binary | Total Dir | Smoke | Notes |
|------|--------|-----------|-------|-------|
| **cx_Freeze** (tinyleaf, musl, opt=2) | 7.55 MB | **18.67 MB** | ✅ | No onefile mode; must ship entire directory |
| **cx_Freeze** (llm-rosetta, glibc, opt=2) | 6.78 MB | **39.32 MB** | ✅ | All smoke tests pass (better compat than PyInstaller) |
| **Nuitka `--standalone`** (tinyleaf, musl) | — | **6.29 MB** | ✅ | Smallest directory output |

### Not viable for standalone

| Tool | Why not |
|------|---------|
| **Cython `--embed`** | Produces a 20 KB binary but requires `libpython.so` on the target — not standalone. Static linking is theoretically possible (~3 MB) but requires manually building static CPython per platform; too fragile for CI. |
| **Shed Skin** | Missing critical stdlib modules (`json`, `hashlib`, `http`, `threading`, etc.) |
| **Codon** | Same stdlib gaps + BSL commercial license |
| **mypyc** | Produces `.so` extensions, not executables |
| **PyOxidizer** | Abandoned project |

## Key Findings

### 1. musl binaries are ~2× smaller than glibc for Nuitka onefile

| Target | glibc onefile | musl onefile | Reduction |
|--------|--------------|-------------|-----------|
| tinyleaf | 14.87 MB | 6.98 MB | **53%** |
| llm-rosetta | 19.95 MB | 11.62 MB | **42%** |

musl libc is much smaller than glibc, and Nuitka's internal zlib compression achieves a better ratio on the smaller payload.

### 2. `aggressive` Python flags are project-dependent

| Flag | tinyleaf | llm-rosetta |
|------|----------|-------------|
| `no_docstrings` | ✅ Safe | ✅ Safe (already used) |
| `no_warnings` | ✅ Safe | ✅ Safe (already used) |
| `no_annotations` | ✅ Safe | ❌ **Breaks runtime** |
| `no_asserts` | ✅ Safe | ❌ **Breaks runtime** |

> **Always test** after adding `no_annotations` or `no_asserts`. Projects using Pydantic, `typing.get_type_hints()`, or initialization assertions will break.

### 3. UPX has zero effect on Nuitka onefile binaries

Nuitka's onefile mode already compresses the payload with zlib (~28.5% compression ratio observed). UPX cannot further compress pre-compressed data. UPX remains useful for `standalone` mode binaries.

### 4. LTO provides marginal but consistent savings

| Target | Libc | Without LTO | With LTO | Saving |
|--------|------|-------------|----------|--------|
| tinyleaf | musl | 7.38 MB | 7.22 MB | 2.2% |
| tinyleaf | glibc | 15.26 MB | 15.11 MB | 1.0% |
| llm-rosetta | musl | 11.67 MB | 11.62 MB | 0.4% |
| llm-rosetta | glibc | 19.96 MB | 19.95 MB | 0.05% |

### 5. `nofollow=maximal` is unsafe

Aggressively excluding stdlib modules (`logging`, `ssl`, `sqlite3`, `xml`, `ctypes`, `multiprocessing`, etc.) broke smoke tests on both projects. The `standard` nofollow list (test/dev tools: `pytest`, `setuptools`, `tkinter`, `unittest`, `pydoc`, etc.) is the safe maximum.

### 7. cosmofy (Cosmopolitan APE) trades size for universal portability

cosmofy bundles the entire Cosmopolitan Python runtime (~39 MB baseline) plus your app's `.py` files into a single APE binary. The result runs on Linux, macOS, and Windows from one file — no recompilation needed. Build time is near-instant (~3 seconds) since there's no compilation step; it just zips your code into the APE.

The trade-off: **5.5× larger than Nuitka musl onefile** (39 MB vs 7 MB). Choose cosmofy when cross-platform distribution matters more than binary size.

### 6. Cython `--embed` is not practical for standalone binaries

Without static linking, Cython binaries require `libpython` on the target. Static linking requires platform-specific static CPython builds, is fragile in CI, and the resulting binary (~2–4 MB) is not dramatically smaller than Nuitka musl onefile (~7 MB) to justify the complexity.

## Recommended Configurations

### For tinyleaf (or similar simple stdlib-only projects)

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

Expected sizes: **6.98 MB** (musl), **14.87 MB** (glibc).

### For llm-rosetta (or projects using runtime annotations/assertions)

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

Expected sizes: **11.62 MB** (musl), **19.95 MB** (glibc).

> **Do NOT add** `--python-flag=no_annotations` or `--python-flag=no_asserts` without verifying the binary passes smoke tests.

## Glossary

| Term | Definition |
|------|-----------|
| **APE** | Actually Portable Executable — a single binary file valid as Linux ELF, Windows PE, and macOS Mach-O simultaneously. Invented by Justine Tunney. |
| **Cosmopolitan Libc** | A C library that enables building APE binaries. Programs linked against it run natively on Linux, macOS, Windows, FreeBSD, OpenBSD, and NetBSD from one file. |
| **cosmofy** | A tool that bundles Python apps into APE binaries using Cosmopolitan Python. Pure-Python only. |
| **Cranelift** | A fast code generator (compiler backend) written in Rust, used by the `pon` project. An alternative to LLVM optimized for compilation speed. |
| **LTO** | Link-Time Optimization — allows the compiler/linker to optimize across translation units, enabling dead code elimination and inlining across module boundaries. |
| **musl** | A lightweight C standard library implementation for Linux, designed for static linking. Produces smaller binaries than glibc. |
| **glibc** | The GNU C Library — the standard libc on most Linux distributions. Larger than musl but has broader compatibility. |
| **Nuitka** | A Python compiler that transpiles Python source to C, then compiles with GCC/Clang. Bundles CPython runtime for standalone distribution. |
| **UPX** | Ultimate Packer for eXecutables — a binary compressor. Ineffective on Nuitka onefile (already compressed) but useful on standalone mode. |
| **nofollow-import-to** | Nuitka flag that excludes specific modules from the compilation, reducing binary size at the risk of runtime ImportErrors. |

## Repository Structure

```
.github/workflows/
  nuitka-sweep.yml          # Nuitka parameter sweep CI
  cython-sweep.yml          # Cython --embed parameter sweep CI
  cosmofy-sweep.yml         # Cosmopolitan/cosmofy sweep CI (planned)
configs/
  nuitka_matrix.json        # Nuitka sweep matrix (40 combinations)
  cython_matrix.json        # Cython sweep matrix (32 combinations)
scripts/
  prepare_target.sh         # Clone/install target project
  build_nuitka.sh           # Parameterized Nuitka build
  build_cython.sh           # Parameterized Cython --embed build
  analyze_results.py        # Generate ranked comparison tables
Makefile                    # Local build convenience targets
```

## Reproducing Locally

```bash
# Build tinyleaf with Nuitka (default optimal flags)
make nuitka-build TARGET=tinyleaf

# Build llm-rosetta with Nuitka
make nuitka-build TARGET=llm-rosetta

# Run analysis on collected results
make analyze
```

## CI Workflow Runs

- [Nuitka Sweep](../../actions/workflows/nuitka-sweep.yml)
- [Cython Sweep](../../actions/workflows/cython-sweep.yml)

## License

[MIT](LICENSE)
