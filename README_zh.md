# Python 二进制编译实验

[English](README_en.md)

系统性参数扫描，比较 **Nuitka** 和 **Cython `--embed`** 将仅依赖标准库的 Python 项目编译为最小独立二进制文件的效果。

## 目标项目

| 项目 | 说明 | 仓库 |
|---|---|---|
| [llm-rosetta](https://github.com/oaklight/llm-rosetta) | LLM API 网关 | 标准库 + 动态 importlib 加载 |
| [tinyleaf](https://github.com/oaklight/tinyleaf) | 零依赖 LaTeX 在线编辑器 | 纯标准库 |

两个项目运行时**仅依赖 Python 标准库**，是二进制体积优化的理想对象。

## 方法论

我们对两种编译工具链的多个参数轴进行扫描，分别构建 **glibc** 和 **musl**（Alpine）两种 libc 变体：

### Nuitka 扫描

| 参数 | 取值 |
|---|---|
| 模式 | `onefile`、`standalone` |
| LTO | `yes`、`no` |
| Python 标志 | 最小化 (`-O`)、激进 (`-O,no_docstrings,no_warnings,no_annotations,no_asserts`) |
| 排除导入 | `standard`（测试/开发模块）、`maximal`（+ 未使用的标准库） |
| UPX 压缩 | `true`、`false` |

### Cython `--embed` 扫描

| 参数 | 取值 |
|---|---|
| CC 优化 | `-O2`、`-Os`、`-O3` |
| LTO | `yes`、`no` |
| Strip | `yes`、`no` |
| CPython 来源 | `system`（apt/apk）、`python-build-standalone`、`source`（源码编译） |
| 链接方式 | `dynamic`、`static` |
| UPX 压缩 | `true`、`false` |

## 结果

> 结果由 CI 自动生成。查看最新的工作流运行获取当前数据：
> - [Nuitka 扫描](../../actions/workflows/nuitka-sweep.yml)
> - [Cython 扫描](../../actions/workflows/cython-sweep.yml)

## 本地使用

```bash
# 使用 Nuitka 构建 llm-rosetta（默认参数）
make nuitka-build TARGET=llm-rosetta

# 使用 Cython --embed 构建 tinyleaf
make cython-build TARGET=tinyleaf

# 对收集的结果进行分析
make analyze
```

## 许可证

[MIT](LICENSE)
