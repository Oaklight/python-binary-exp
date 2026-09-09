# Cython `--embed` Results

[← Back to README](../README_en.md)

12 builds completed for tinyleaf (glibc + musl, various optimization levels).

## Results

| CC Opt | LTO | Strip | Link | Libc | Size (MB) | Smoke | Standalone? |
|--------|-----|-------|------|------|-----------|-------|-------------|
| -Os | yes | yes | dynamic | glibc | 0.02 | ✅ | ❌ |
| -Os | yes | yes | dynamic | musl | 0.02 | ✅ | ❌ |
| -O2 | yes | yes | dynamic | glibc | 0.02 | ✅ | ❌ |
| -O3 | yes | yes | dynamic | glibc | 0.02 | ✅ | ❌ |
| -O2 | no | no | dynamic | glibc | 10.00 | ✅ | ❌ |
| -O2 | no | no | dynamic | musl | 10.14 | ✅ | ❌ |

## Why Cython `--embed` Doesn't Work for Standalone

### The 20 KB illusion

The stripped dynamic-link binaries are ~20 KB. But they are **not standalone** — they require `libpython3.x.so` at runtime:

- **Linux**: only present if Python is installed, version must match exactly
- **macOS**: Apple deprecated system Python; not guaranteed on newer versions
- **Windows**: `python3x.dll` only present if Python is installed

### Static linking is theoretically possible but impractical

To produce a true standalone binary, you need to:

1. Obtain or build `libpython3.x.a` (static library) — **15 MB** on glibc, **~99 MB** on Alpine
2. Statically link every C extension module your code uses (`_json.a`, `_hashlib.a`, `_ssl.a`, etc.)
3. Do this per target platform

Our CI attempts at static linking mostly failed:
- **python-build-standalone**: download URL discovery issues, doesn't always include static libs
- **System Alpine**: `python3-libs-static` package doesn't exist for the Docker image's Python version
- **CPython from source**: works but adds 15+ minutes build time and requires platform-specific `Modules/Setup.local` configuration

### The math doesn't favor it

Even if static linking worked perfectly, the resulting binary would be ~2–4 MB. Nuitka musl onefile is ~7 MB. The 3 MB savings doesn't justify the engineering effort and CI fragility.

## Conclusion

Cython `--embed` is a dead end for standalone binary distribution. It's designed for creating Python extensions and embedding Python in C applications — not for producing deployable executables. Use Nuitka or PyInstaller instead.
