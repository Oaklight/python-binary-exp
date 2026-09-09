# PyInstaller Results

[← Back to README](../README_en.md)

12 parameter combinations across both targets, built for glibc and musl.

## All Results

Sorted by binary size ascending.

| Target | Mode | Strip | UPX | Libc | Size (MB) | Smoke |
|--------|------|-------|-----|------|-----------|-------|
| tinyleaf | onedir | true | no | glibc | 1.69 | ✅ |
| tinyleaf | onedir | true | no | musl | 1.70 | ✅ |
| llm-rosetta | onedir | true | no | glibc | 2.84 | ❌ |
| llm-rosetta | onedir | true | no | musl | 2.84 | ❌ |
| tinyleaf | onefile | true | yes | glibc | 7.88 | ✅ |
| tinyleaf | onefile | true | no | glibc | 7.88 | ✅ |
| tinyleaf | onefile | true | no | musl | 7.99 | ✅ |
| llm-rosetta | onefile | true | no | glibc | 10.15 | ❌ |
| llm-rosetta | onefile | true | yes | glibc | 10.15 | ❌ |
| llm-rosetta | onefile | true | no | musl | 10.42 | ❌ |
| tinyleaf | onefile | false | no | glibc | 19.83 | ✅ |
| llm-rosetta | onefile | false | no | glibc | 22.81 | ❌ |

## Key Findings

### 1. Strip is critical for PyInstaller

| Target | Stripped | Unstripped | Savings |
|--------|----------|------------|---------|
| tinyleaf | 7.88 MB | 19.83 MB | **60%** |
| llm-rosetta | 10.15 MB | 22.81 MB | **55%** |

Unlike Nuitka (where strip has minimal effect), PyInstaller binaries carry massive debug symbols by default. Always use `--strip`.

### 2. UPX has zero effect

PyInstaller's onefile mode already compresses the payload. UPX can't further compress it (7.88 MB with and without UPX).

### 3. llm-rosetta fails all PyInstaller builds

All llm-rosetta configs fail the smoke test. The cause: llm-rosetta uses `importlib.util.spec_from_file_location` to dynamically load provider `transforms.py` files at runtime. PyInstaller can't trace these — they're loaded by filesystem path, not `import` statements. While `--hidden-import` could help for static imports, the file-path-based loading pattern fundamentally doesn't work with PyInstaller's frozen import system.

This is a known PyInstaller limitation. Nuitka solves it with `--include-data-dir` to bundle the files alongside.

### 4. onedir is tiny but not single-file

The `onedir` binary is just 1.69 MB for tinyleaf — but it requires the entire directory (with `libpython`, stdlib `.so` files, etc.) to run. Not a standalone deployment option.

## Comparison with Nuitka

| Metric | PyInstaller (tinyleaf) | Nuitka musl (tinyleaf) |
|--------|----------------------|----------------------|
| onefile size (stripped) | 7.88 MB | 6.98 MB |
| Build time | ~30 sec | ~2 min |
| Dynamic import support | ❌ | ✅ |
| C compilation required | No | Yes (GCC/Clang) |

PyInstaller is a strong choice for simple projects — faster builds, comparable size. But Nuitka wins on dynamic import handling and produces slightly smaller musl binaries.
