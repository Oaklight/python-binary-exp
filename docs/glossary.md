# Glossary

[← Back to README](../README_en.md)

| Term | Definition |
|------|-----------|
| **AOT** | Ahead-of-Time compilation — compiling source code to machine code before execution, as opposed to JIT (Just-in-Time) compilation at runtime. |
| **APE** | Actually Portable Executable — a single binary file simultaneously valid as Linux ELF, Windows PE, and macOS Mach-O. Invented by Justine Tunney as part of Cosmopolitan Libc. |
| **Cosmopolitan Libc** | A C library that enables building APE binaries. Programs linked against it run natively on Linux, macOS, Windows, FreeBSD, OpenBSD, and NetBSD from one file. |
| **cosmofy** | A tool that bundles Python apps into APE binaries using Cosmopolitan Python. Pure-Python only. [GitHub](https://github.com/metaist/cosmofy). |
| **Cranelift** | A fast code generator (compiler backend) written in Rust, used by the `pon` project and Wasmtime. Alternative to LLVM, optimized for compilation speed over peak code quality. |
| **cx_Freeze** | A Python freezing tool that bundles bytecode + interpreter into a directory. No single-file mode. [GitHub](https://github.com/marcelotduarte/cx_Freeze). |
| **glibc** | GNU C Library — the standard libc on most Linux distributions (Ubuntu, Fedora, Debian, etc.). Larger than musl but has broader compatibility and more features. |
| **JIT** | Just-in-Time compilation — compiling code to machine code during execution. Allows runtime optimization based on actual usage patterns. |
| **LLVM** | A compiler infrastructure project providing reusable components for building compilers. Used by Clang, Codon, and many other projects as a code generation backend. |
| **LTO** | Link-Time Optimization — allows the compiler/linker to optimize across all translation units at link time, enabling dead code elimination and cross-module inlining. Typically saves 0.4–2.2% binary size. |
| **musl** | A lightweight C standard library implementation for Linux, designed for static linking and correctness. Produces smaller binaries than glibc. Used in Alpine Linux. |
| **Nuitka** | A Python compiler that transpiles Python source to C, compiles with GCC/Clang, and bundles CPython runtime for standalone distribution. [nuitka.net](https://nuitka.net). |
| **nofollow-import-to** | Nuitka flag that excludes specific modules from compilation. Reduces binary size but may cause runtime `ImportError` if excluded modules are actually needed. |
| **onefile** | A build mode (Nuitka, PyInstaller) that packs everything into a single self-extracting executable. Larger than standalone/onedir due to compression overhead, but simpler to deploy. |
| **onedir / standalone** | A build mode that produces a directory containing the binary, interpreter, and all dependencies. Smaller total footprint but requires shipping the entire directory. |
| **PyInstaller** | A tool that freezes Python bytecode and bundles it with the CPython interpreter. Supports `--onefile` mode. [pyinstaller.org](https://pyinstaller.org). |
| **python-build-standalone** | Pre-built, portable CPython distributions maintained by Astral (makers of uv/rye). Available for many platforms. [GitHub](https://github.com/astral-sh/python-build-standalone). |
| **stdlib** | Python Standard Library — the set of modules included with every Python installation (`json`, `os`, `sys`, `http`, etc.). No `pip install` needed. |
| **UPX** | Ultimate Packer for eXecutables — a binary compressor. Effective on uncompressed binaries but has zero effect on Nuitka/PyInstaller onefile (already internally compressed). |
