# Nuitka Results

[← Back to README](../README_en.md)

40 parameter combinations per target (pruned from 256), built for both glibc and musl.

## tinyleaf — 20 Builds, All Completed

Sorted by binary size. Only smoke-test-passing configs are viable.

| Mode | LTO | Python Flags | Nofollow | UPX | Libc | Size (MB) | Smoke |
|------|-----|-------------|----------|-----|------|-----------|-------|
| standalone | yes | aggressive | standard | no | musl | 6.29 | ✅ |
| standalone | yes | aggressive | standard | no | glibc | 6.31 | ✅ |
| onefile | yes | aggressive | standard | no | musl | **6.98** | ✅ |
| onefile | yes | aggressive | standard | yes | musl | 6.98 | ✅ |
| onefile | no | aggressive | standard | no | musl | 7.14 | ✅ |
| onefile | yes | minimal | standard | no | musl | 7.22 | ✅ |
| onefile | no | minimal | standard | no | musl | 7.38 | ✅ |
| onefile | yes | aggressive | maximal | yes | musl | 6.50 | ❌ |
| onefile | yes | aggressive | maximal | no | musl | 6.50 | ❌ |
| onefile | yes | aggressive | standard | yes | glibc | **14.87** | ✅ |
| onefile | yes | aggressive | standard | no | glibc | 14.87 | ✅ |
| onefile | no | aggressive | standard | no | glibc | 15.03 | ✅ |
| onefile | yes | minimal | standard | no | glibc | 15.11 | ✅ |
| onefile | no | minimal | standard | no | glibc | 15.26 | ✅ |
| onefile | yes | aggressive | maximal | yes | glibc | 14.37 | ❌ |
| onefile | yes | aggressive | maximal | no | glibc | 14.37 | ❌ |

## llm-rosetta — 20 Builds, All Completed

| Mode | LTO | Python Flags | Nofollow | UPX | Libc | Size (MB) | Smoke |
|------|-----|-------------|----------|-----|------|-----------|-------|
| onefile | yes | minimal | standard | no | musl | **11.62** | ✅ |
| onefile | no | minimal | standard | no | musl | 11.67 | ✅ |
| onefile | yes | minimal | standard | no | glibc | **19.95** | ✅ |
| onefile | no | minimal | standard | no | glibc | 19.96 | ✅ |
| onefile | yes | aggressive | standard | no | musl | 10.82 | ❌ |
| onefile | yes | aggressive | standard | no | glibc | 19.14 | ❌ |
| standalone | yes | aggressive | standard | no | musl | 17.13 | ❌ |
| standalone | yes | aggressive | standard | no | glibc | 17.35 | ❌ |

> **Only `minimal` + `standard` passed for llm-rosetta.** The `aggressive` flags break it — see Flag Impact Analysis below.

## Flag Impact Analysis

### musl onefile — size comparison

| Flag change | tinyleaf | llm-rosetta |
|-------------|----------|-------------|
| Baseline (no LTO, minimal, standard) | 7.38 MB | 11.67 MB |
| + LTO | 7.22 MB (−2.2%) | 11.62 MB (−0.4%) |
| + aggressive flags | 6.98 MB (−5.4%) | ❌ breaks |
| + maximal nofollow | 6.50 MB (−11.9%) | ❌ breaks |

### Key findings

1. **musl is ~2× smaller than glibc** — the single biggest factor (6.98 vs 14.87 MB for tinyleaf)
2. **LTO**: marginal but consistent (0.4–2.2% savings)
3. **Aggressive flags** (`no_annotations`, `no_asserts`): safe for tinyleaf (−5.4%), breaks llm-rosetta
4. **Maximal nofollow**: breaks both projects — removes modules actually used at runtime
5. **UPX**: zero effect on onefile (Nuitka already compresses internally at ~28.5% ratio)

### Flag safety matrix

| Flag | tinyleaf | llm-rosetta | Risk |
|------|----------|-------------|------|
| `no_docstrings` | ✅ | ✅ | Low — safe for most projects |
| `no_warnings` | ✅ | ✅ | Low |
| `no_annotations` | ✅ | ❌ | Medium — breaks runtime `typing.get_type_hints()` |
| `no_asserts` | ✅ | ❌ | Medium — breaks initialization assertions |

## Recommended Configuration

Both projects use the same flags for consistency and safety:

```bash
python -m nuitka --onefile --lto=yes \
  --python-flag=-O --python-flag=no_docstrings \
  --python-flag=no_warnings \
  --nofollow-import-to=pytest,setuptools,pip,_pytest,tkinter,unittest,pydoc,doctest,test,distutils,ensurepip,idlelib,lib2to3,turtle,turtledemo,xmlrpc,curses \
  --include-package=<your_package> entry.py
```

### Why `no_annotations` and `no_asserts` are excluded

Even though tinyleaf passes smoke tests with these flags (~5% savings), we deliberately exclude them for consistency with llm-rosetta. The flags break llm-rosetta because:

- **`no_annotations`**: llm-rosetta uses `typing.get_type_hints()` at runtime for type validation (`_vendor/validate.py`), and `@dataclass` classes that rely on `__annotations__` for field definitions. Stripping annotations silently breaks both systems.
- **`no_asserts`**: llm-rosetta uses `assert _config is not None` as startup initialization guards (`gateway/app.py`). Without assertions, the gateway proceeds with `None` config → crash.

Applying the same conservative flags across projects avoids maintenance landmines if tinyleaf later adds dataclasses, runtime type validation, or initialization guards.
