# Python Binary Compilation Experiments

[中文](README_zh.md)

Systematic parameter sweep comparing **Nuitka** and **Cython `--embed`** for compiling stdlib-only Python projects into minimal standalone binaries.

## Targets

| Project | Description | Repo |
|---|---|---|
| [llm-rosetta](https://github.com/oaklight/llm-rosetta) | LLM API gateway | stdlib + dynamic importlib shims |
| [tinyleaf](https://github.com/oaklight/tinyleaf) | Zero-dependency LaTeX web editor | pure stdlib |

Both projects depend **only on the Python standard library** at runtime, making them ideal candidates for aggressive binary size optimization.

## Methodology

We sweep two compilation toolchains across multiple parameter axes, building each target project for both **glibc** and **musl** (Alpine) libc variants:

### Nuitka Sweep

| Parameter | Values |
|---|---|
| Mode | `onefile`, `standalone` |
| LTO | `yes`, `no` |
| Python flags | minimal (`-O`), aggressive (`-O,no_docstrings,no_warnings,no_annotations,no_asserts`) |
| Nofollow imports | `standard` (test/dev modules), `maximal` (+ unused stdlib) |
| UPX compression | `true`, `false` |

### Cython `--embed` Sweep

| Parameter | Values |
|---|---|
| CC optimization | `-O2`, `-Os`, `-O3` |
| LTO | `yes`, `no` |
| Strip | `yes`, `no` |
| CPython source | `system` (apt/apk), `python-build-standalone`, `source` (compiled) |
| Linking | `dynamic`, `static` |
| UPX compression | `true`, `false` |

## Results

> Results are generated automatically by CI. See the latest workflow runs for current data:
> - [Nuitka Sweep](../../actions/workflows/nuitka-sweep.yml)
> - [Cython Sweep](../../actions/workflows/cython-sweep.yml)

## Local Usage

```bash
# Build llm-rosetta with Nuitka (default flags)
make nuitka-build TARGET=llm-rosetta

# Build tinyleaf with Cython --embed
make cython-build TARGET=tinyleaf

# Run analysis on collected results
make analyze
```

## License

[MIT](LICENSE)
