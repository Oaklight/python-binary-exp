# Cosmofy (Cosmopolitan APE) Results

[← Back to README](../README_en.md)

4 builds (2 targets × with/without bytecode compilation).

## Results

| Target | Bytecode | Size (MB) | Build Time | Smoke | Platforms |
|--------|----------|-----------|------------|-------|-----------|
| tinyleaf | no | **38.80** | 3s | ✅ | Linux + macOS + Windows |
| llm-rosetta | no | **39.32** | 3s | ✅ | Linux + macOS + Windows |
| tinyleaf | yes | — | — | ❌ | (bytecode compilation needs APE loader) |
| llm-rosetta | yes | — | — | ❌ | (same) |

## How It Works

cosmofy downloads the Cosmopolitan Python binary (~39 MB) from [cosmo.zip](https://cosmo.zip/pub/cosmos/bin/python), then appends your `.py` files to its internal zip section. The Cosmopolitan Python runtime uses `zipimport` to load your code at startup.

The binary is an **Actually Portable Executable (APE)** — a file format that is simultaneously valid as a Linux ELF, Windows PE, and macOS Mach-O. One file, three operating systems, no recompilation.

## Key Observations

### 1. App size is negligible

The base runtime is ~39 MB. tinyleaf adds 0.0 MB, llm-rosetta adds 0.5 MB. The binary size is dominated by the CPython interpreter + stdlib, not your application code.

### 2. Build is near-instant

No compilation. cosmofy just copies the APE binary, runs `uv` to install deps into a temp venv, and zips everything together. ~3 seconds total.

### 3. Bytecode compilation fails in CI

The `--compile-bytecode` flag tries to run the APE binary to compile `.pyc` files, but GitHub Actions runners may lack the APE loader (`/usr/bin/ape`). This is a CI-specific issue — on a developer machine with the APE loader installed, it would work.

### 4. Pure Python only

cosmofy cannot bundle C extensions (`numpy`, `pandas`, etc.). For stdlib-only projects like ours, this is a non-issue. For projects with C deps, use Nuitka instead.

## Limitations

- **Size**: ~39 MB baseline vs Nuitka's 7 MB. The 5.5× penalty is the cost of universal portability.
- **Dynamic version**: projects using `dynamic = ["version"]` in `pyproject.toml` need patching to a static version before bundling (cosmofy calls `uv version` which can't resolve dynamic versions).
- **Startup**: first run on a new OS may be slower as the APE bootstrap detects the host platform.

## When to Use

cosmofy is the right choice when:
- You need **one binary that works on Linux, macOS, and Windows** without separate builds
- Binary size is not a primary constraint
- Your project is pure Python (no C extensions)
- You want the fastest possible build pipeline (~3 sec vs ~2 min for Nuitka)
