# cx_Freeze Results

[← Back to README](../README_en.md)

8 parameter combinations across both targets. cx_Freeze produces directories only — there is no single-file mode.

## All Results

| Target | Optimize | Libc | Binary (MB) | Dir Total (MB) | Smoke |
|--------|----------|------|-------------|----------------|-------|
| tinyleaf | 2 | musl | 7.55 | **18.67** | ✅ |
| tinyleaf | 0 | musl | 7.55 | 18.95 | ✅ |
| llm-rosetta | 2 | musl | 7.55 | 24.11 | ✅ |
| tinyleaf | 2 | glibc | 6.78 | 24.72 | ✅ |
| llm-rosetta | 0 | musl | 7.55 | 24.84 | ✅ |
| tinyleaf | 0 | glibc | 6.78 | 25.00 | ✅ |
| llm-rosetta | 2 | glibc | 6.78 | 39.32 | ✅ |
| llm-rosetta | 0 | glibc | 6.78 | 40.06 | ✅ |

## Key Findings

### 1. All smoke tests pass

cx_Freeze has the best compatibility of any tool tested — **100% pass rate** on both projects, including llm-rosetta which fails on PyInstaller. cx_Freeze includes the full stdlib and doesn't need to trace dynamic imports.

### 2. optimize=2 saves ~1–2%

The `optimize` flag (equivalent to Python's `-OO`) removes docstrings and asserts. Marginal savings.

### 3. No single-file mode

This is the main drawback. The directory includes the binary, `libpython`, stdlib `.so` extensions, and `.pyc` files. You'd need to ship the whole thing (or wrap it in a self-extracting archive).

### 4. musl directories are smaller

musl dirs are 19–24 MB vs glibc's 25–40 MB. Same pattern as Nuitka — musl libc is lighter.

## When to Use cx_Freeze

- You can deploy a directory (not just a single file)
- You need guaranteed compatibility with complex projects
- You want the simplest build process (Python-only, no C compiler needed)
