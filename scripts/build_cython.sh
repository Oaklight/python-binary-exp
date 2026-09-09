#!/usr/bin/env bash
set -euo pipefail

TARGET="${TARGET:?}"
CC_OPT="${CC_OPT:--O2}"
LTO="${LTO:-yes}"
STRIP="${STRIP:-yes}"
CPYTHON_SOURCE="${CPYTHON_SOURCE:-system}"
LINK="${LINK:-dynamic}"
UPX="${UPX:-false}"
LIBC="${LIBC:-glibc}"
OUTPUT_DIR="${OUTPUT_DIR:-build}"

ENTRY_PACKAGE="$(cat /tmp/target_entry_package.txt)"
ENTRY_FILE="/tmp/target_entry.py"
SMOKE_CMD="$(cat /tmp/target_smoke_cmd.txt)"

mkdir -p "$OUTPUT_DIR"

PYTHON_BIN="python3"
PYTHON_CONFIG="python3-config"
STATIC_LIBDIR=""

setup_python_build_standalone() {
    echo "=== Setting up python-build-standalone ==="
    local PBS_DIR="/tmp/pbs-python"
    if [ ! -d "$PBS_DIR" ]; then
        local ARCH
        ARCH="$(uname -m)"
        local PBS_URL="https://github.com/astral-sh/python-build-standalone/releases/latest/download/cpython-3.12.8+20250213-${ARCH}-unknown-linux-gnu-install_only_stripped.tar.gz"
        mkdir -p "$PBS_DIR"
        echo "Downloading python-build-standalone..."
        curl -sL "$PBS_URL" | tar xz -C "$PBS_DIR" --strip-components=1 || {
            echo "Failed to download PBS, trying alternate URL pattern..."
            local PBS_URL2="https://github.com/astral-sh/python-build-standalone/releases/latest/download/cpython-3.12.8+20250213-${ARCH}-unknown-linux-gnu-install_only.tar.gz"
            curl -sL "$PBS_URL2" | tar xz -C "$PBS_DIR" --strip-components=1
        }
    fi
    PYTHON_BIN="$PBS_DIR/bin/python3"
    PYTHON_CONFIG="$PBS_DIR/bin/python3-config"
    STATIC_LIBDIR="$PBS_DIR/lib"
    export PATH="$PBS_DIR/bin:$PATH"
}

setup_cpython_source() {
    echo "=== Building CPython from source (static) ==="
    local CPYTHON_DIR="/tmp/cpython-build"
    local INSTALL_DIR="/tmp/cpython-static"
    if [ ! -d "$INSTALL_DIR/bin" ]; then
        mkdir -p "$CPYTHON_DIR"
        curl -sL "https://www.python.org/ftp/python/3.12.8/Python-3.12.8.tgz" | tar xz -C "$CPYTHON_DIR" --strip-components=1
        cd "$CPYTHON_DIR"
        ./configure --prefix="$INSTALL_DIR" --disable-shared --enable-optimizations LDFLAGS="-static" 2>&1 | tail -5
        make -j"$(nproc)" 2>&1 | tail -5
        make install 2>&1 | tail -5
        cd -
    fi
    PYTHON_BIN="$INSTALL_DIR/bin/python3"
    PYTHON_CONFIG="$INSTALL_DIR/bin/python3-config"
    STATIC_LIBDIR="$INSTALL_DIR/lib"
    export PATH="$INSTALL_DIR/bin:$PATH"
}

case "$CPYTHON_SOURCE" in
    system)
        echo "Using system Python"
        ;;
    python-build-standalone|pbs)
        setup_python_build_standalone
        ;;
    source)
        setup_cpython_source
        ;;
esac

pip install --quiet cython 2>/dev/null || $PYTHON_BIN -m pip install --quiet cython

CYTHON_VERSION="$(cython --version 2>&1 || echo unknown)"

SITE_DIR="$($PYTHON_BIN -c "import ${ENTRY_PACKAGE}; import os; print(os.path.dirname(${ENTRY_PACKAGE}.__file__))")"
echo "Package at: $SITE_DIR"

echo "=== Cythonizing entry point ==="
cython --embed -3 -o /tmp/entry.c "$ENTRY_FILE"

PY_FILES=()
C_FILES=("/tmp/entry.c")

echo "=== Cythonizing package modules ==="
while IFS= read -r pyfile; do
    rel="${pyfile#$SITE_DIR/}"
    cfile="/tmp/cython_c/${rel%.py}.c"
    mkdir -p "$(dirname "$cfile")"
    if cython -3 -o "$cfile" "$pyfile" 2>/dev/null; then
        C_FILES+=("$cfile")
    else
        echo "WARN: Failed to cythonize $rel (skipping)"
    fi
done < <(find "$SITE_DIR" -name "*.py" -not -path "*/__pycache__/*" -not -name "setup.py")

echo "Cythonized ${#C_FILES[@]} files total"

CFLAGS="$CC_OPT"
LDFLAGS=""

if [ "$LTO" = "yes" ]; then
    CFLAGS="$CFLAGS -flto"
    LDFLAGS="$LDFLAGS -flto"
fi

PY_CFLAGS="$($PYTHON_CONFIG --cflags 2>/dev/null || $PYTHON_CONFIG --includes)"
PY_LDFLAGS="$($PYTHON_CONFIG --ldflags --embed 2>/dev/null || $PYTHON_CONFIG --ldflags)"

if [ "$LINK" = "static" ] && [ -n "$STATIC_LIBDIR" ]; then
    LDFLAGS="$LDFLAGS -L$STATIC_LIBDIR -static"
    PY_LDFLAGS="$(echo "$PY_LDFLAGS" | sed 's/-lpython[^ ]*//')"
    STATIC_LIB="$(find "$STATIC_LIBDIR" -name 'libpython3*.a' | head -1)"
    if [ -n "$STATIC_LIB" ]; then
        LDFLAGS="$LDFLAGS $STATIC_LIB"
    else
        echo "WARN: No static libpython found in $STATIC_LIBDIR"
        LDFLAGS="$LDFLAGS -lpython3.12"
    fi
    LDFLAGS="$LDFLAGS -lm -lz -lpthread -ldl -lutil"
fi

BINARY_NAME="${TARGET}-cython-${LIBC}"
BINARY_PATH="$OUTPUT_DIR/$BINARY_NAME"

echo "=== Compiling ==="
echo "CC flags: $CFLAGS $PY_CFLAGS"
echo "LD flags: $LDFLAGS $PY_LDFLAGS"
echo "C files: ${#C_FILES[@]}"

START_TIME=$(date +%s)

gcc $CFLAGS $PY_CFLAGS -o "$BINARY_PATH" "${C_FILES[@]}" $LDFLAGS $PY_LDFLAGS 2>&1 || {
    echo "Full compilation failed, trying entry-only build..."
    gcc $CFLAGS $PY_CFLAGS -o "$BINARY_PATH" /tmp/entry.c $LDFLAGS $PY_LDFLAGS 2>&1
}

END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))

if [ "$STRIP" = "yes" ]; then
    strip --strip-all "$BINARY_PATH" 2>/dev/null || strip "$BINARY_PATH" 2>/dev/null || echo "strip failed (non-fatal)"
fi

if [ "$UPX" = "true" ]; then
    echo "=== Applying UPX compression ==="
    upx --best "$BINARY_PATH" || echo "UPX failed (non-fatal)"
fi

BINARY_SIZE=$(stat -c%s "$BINARY_PATH" 2>/dev/null || stat -f%z "$BINARY_PATH")

echo "=== Smoke test ==="
SMOKE_PASSED="false"
chmod +x "$BINARY_PATH" 2>/dev/null || true
if timeout 10 "$BINARY_PATH" $SMOKE_CMD >/dev/null 2>&1; then
    SMOKE_PASSED="true"
    echo "Smoke test PASSED"
else
    echo "Smoke test FAILED"
fi

PYTHON_VERSION="$($PYTHON_BIN --version 2>&1)"

RESULT_FILE="$OUTPUT_DIR/result-cython-${TARGET}-${CC_OPT}-${LTO}-${STRIP}-${CPYTHON_SOURCE}-${LINK}-${UPX}-${LIBC}.json"
cat > "$RESULT_FILE" <<EOJSON
{
  "target": "$TARGET",
  "compiler": "cython-embed",
  "cc_opt": "$CC_OPT",
  "lto": "$LTO",
  "strip": "$STRIP",
  "cpython_source": "$CPYTHON_SOURCE",
  "link": "$LINK",
  "upx": $UPX,
  "libc": "$LIBC",
  "binary_size_bytes": $BINARY_SIZE,
  "build_time_seconds": $BUILD_TIME,
  "smoke_test_passed": $SMOKE_PASSED,
  "python_version": "$PYTHON_VERSION",
  "compiler_version": "$CYTHON_VERSION",
  "binary_path": "$BINARY_PATH",
  "c_files_count": ${#C_FILES[@]}
}
EOJSON

echo "=== Result ==="
cat "$RESULT_FILE"
echo "Binary: $BINARY_PATH ($BINARY_SIZE bytes)"
