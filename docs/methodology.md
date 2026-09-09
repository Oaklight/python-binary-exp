# Methodology

[← Back to README](../README_en.md)

## Sweep Design

Each toolchain is tested across multiple parameter axes in a combinatorial matrix. The full cartesian product is pruned to the most informative combinations to keep CI time manageable.

### Nuitka Matrix (40 jobs per target)

| Axis | Values |
|------|--------|
| Mode | `onefile`, `standalone` |
| LTO | `yes`, `no` |
| Python flags | `minimal` (`-O`), `aggressive` (`-O,no_docstrings,no_warnings,no_annotations,no_asserts`) |
| Nofollow imports | `standard`, `maximal` |
| UPX | `true`, `false` |
| Libc | `glibc` (native Ubuntu), `musl` (Alpine Docker) |

### PyInstaller Matrix (12 jobs per target)

| Axis | Values |
|------|--------|
| Mode | `onefile`, `onedir` |
| Strip | `true`, `false` |
| UPX | `true`, `false` |
| Libc | `glibc`, `musl` |

### cx_Freeze Matrix (8 jobs per target)

| Axis | Values |
|------|--------|
| Optimize | `0`, `2` |
| Libc | `glibc`, `musl` |

### Cython `--embed` Matrix (32 jobs per target)

| Axis | Values |
|------|--------|
| CC optimization | `-O2`, `-Os`, `-O3` |
| LTO | `yes`, `no` |
| Strip | `yes`, `no` |
| CPython source | `system`, `python-build-standalone`, `source` |
| Link | `dynamic`, `static` |
| UPX | `true`, `false` |
| Libc | `glibc`, `musl` |

### cosmofy Matrix (4 jobs)

| Axis | Values |
|------|--------|
| Bytecode compilation | `true`, `false` |
| Target | `tinyleaf`, `llm-rosetta` |

## Build Environments

- **glibc builds**: GitHub Actions `ubuntu-latest` runner with `actions/setup-python@v5` (Python 3.12)
- **musl builds**: `python:3.12-alpine` Docker container running on the same Ubuntu runner
- **cosmofy builds**: GitHub Actions `ubuntu-latest` with `uv` and `cosmofy` installed via `uv tool install`

## Smoke Testing

Every build is smoke-tested with `./binary --help`. The binary must:
1. Exit with code 0
2. Complete within 10 seconds (timeout)

For musl onefile builds, smoke tests run inside a fresh `alpine` Docker container to verify true musl compatibility.

## Result Collection

Each build produces a JSON result file with:
- `target`, `compiler`, all config parameters
- `binary_size_bytes`, `build_time_seconds`
- `smoke_test_passed` (boolean)
- `python_version`, `compiler_version`

Results are uploaded as GitHub Actions artifacts and collected by the analysis job.

## Nofollow Import Levels

### Standard (safe)

```
pytest setuptools pip _pytest tkinter unittest pydoc doctest test
distutils ensurepip idlelib lib2to3 turtle turtledemo xmlrpc curses
```

### Maximal (unsafe — broke both projects)

Standard plus: `logging sqlite3 ssl xml ctypes multiprocessing concurrent email.mime importlib.metadata zipimport _strptime calendar pprint`

## Reproducing Locally

```bash
git clone https://github.com/oaklight/python-binary-exp
cd python-binary-exp

# Install target
pip install tinyleaf  # or llm-rosetta

# Run Nuitka build with default optimal flags
make nuitka-build TARGET=tinyleaf

# Or trigger CI sweeps
gh workflow run nuitka-sweep.yml -f targets=tinyleaf
gh workflow run pyinstaller-sweep.yml -f targets=tinyleaf
gh workflow run cxfreeze-sweep.yml -f targets=tinyleaf
gh workflow run cosmofy-sweep.yml
```
