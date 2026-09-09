#!/usr/bin/env bash
set -euo pipefail

TARGET="${TARGET:?}"
MODE="${MODE:-onefile}"
LTO="${LTO:-yes}"
PYTHON_FLAGS="${PYTHON_FLAGS:-minimal}"
NOFOLLOW="${NOFOLLOW:-standard}"
UPX="${UPX:-false}"
LIBC="${LIBC:-glibc}"
OUTPUT_DIR="${OUTPUT_DIR:-build}"

NOFOLLOW_STANDARD="pytest setuptools pip _pytest tkinter unittest pydoc doctest test distutils ensurepip idlelib lib2to3 turtle turtledemo xmlrpc curses"
NOFOLLOW_MAXIMAL="$NOFOLLOW_STANDARD logging sqlite3 ssl xml ctypes multiprocessing concurrent email.mime importlib.metadata zipimport _strptime calendar pprint"

ENTRY_PACKAGE="$(cat /tmp/target_entry_package.txt)"
ENTRY_FILE="/tmp/target_entry.py"
SMOKE_CMD="$(cat /tmp/target_smoke_cmd.txt)"

NUITKA_JOBS="${NUITKA_JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)}"

mkdir -p "$OUTPUT_DIR"

FLAGS="--$MODE"
FLAGS="$FLAGS --output-dir=$OUTPUT_DIR"
FLAGS="$FLAGS --jobs=$NUITKA_JOBS"
FLAGS="$FLAGS --assume-yes-for-downloads"
FLAGS="$FLAGS --include-package=$ENTRY_PACKAGE"

if [ "$LTO" = "yes" ]; then
    FLAGS="$FLAGS --lto=yes"
fi

case "$PYTHON_FLAGS" in
    minimal)
        FLAGS="$FLAGS --python-flag=-O"
        ;;
    aggressive)
        FLAGS="$FLAGS --python-flag=-O --python-flag=no_docstrings --python-flag=no_warnings --python-flag=no_annotations --python-flag=no_asserts"
        ;;
esac

case "$NOFOLLOW" in
    standard)
        for mod in $NOFOLLOW_STANDARD; do
            FLAGS="$FLAGS --nofollow-import-to=$mod"
        done
        ;;
    maximal)
        for mod in $NOFOLLOW_MAXIMAL; do
            FLAGS="$FLAGS --nofollow-import-to=$mod"
        done
        ;;
esac

if [ "$TARGET" = "llm-rosetta" ]; then
    SITE_DIR="$(python -c "import llm_rosetta; import os; print(os.path.dirname(llm_rosetta.__file__))")"
    if [ -d "$SITE_DIR/shims/providers" ]; then
        FLAGS="$FLAGS --include-data-dir=$SITE_DIR/shims/providers=llm_rosetta/shims/providers"
    fi
    if [ -d "$SITE_DIR/gateway/admin" ]; then
        FLAGS="$FLAGS --include-data-dir=$SITE_DIR/gateway/admin=llm_rosetta/gateway/admin"
    fi
fi

BINARY_NAME="${TARGET}-$(python -c "import ${ENTRY_PACKAGE}; print(${ENTRY_PACKAGE}.__version__)" 2>/dev/null || echo "dev")"

echo "=== Nuitka build: $TARGET ==="
echo "Config: mode=$MODE lto=$LTO flags=$PYTHON_FLAGS nofollow=$NOFOLLOW upx=$UPX libc=$LIBC"
echo "Nuitka flags: $FLAGS"

START_TIME=$(date +%s)

python -m nuitka $FLAGS "$ENTRY_FILE"

END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))

BINARY=$(find "$OUTPUT_DIR" -maxdepth 2 -type f -executable ! -name "*.so" ! -name "*.py" ! -name "*.dist" | head -1)

if [ -z "$BINARY" ]; then
    BINARY=$(find "$OUTPUT_DIR" -maxdepth 2 -name "target_entry*" -type f | head -1)
fi

if [ -z "$BINARY" ]; then
    echo "ERROR: No binary found in $OUTPUT_DIR"
    find "$OUTPUT_DIR" -type f | head -20
    exit 1
fi

if [ "$UPX" = "true" ]; then
    echo "=== Applying UPX compression ==="
    PRE_SIZE=$(stat -c%s "$BINARY" 2>/dev/null || stat -f%z "$BINARY")
    upx --best "$BINARY" || echo "UPX compression failed (non-fatal)"
    POST_SIZE=$(stat -c%s "$BINARY" 2>/dev/null || stat -f%z "$BINARY")
    echo "UPX: $PRE_SIZE -> $POST_SIZE bytes"
fi

BINARY_SIZE=$(stat -c%s "$BINARY" 2>/dev/null || stat -f%z "$BINARY")

echo "=== Smoke test ==="
SMOKE_PASSED="false"
if chmod +x "$BINARY" 2>/dev/null; then true; fi
if timeout 10 "$BINARY" $SMOKE_CMD >/dev/null 2>&1; then
    SMOKE_PASSED="true"
    echo "Smoke test PASSED"
else
    echo "Smoke test FAILED (non-fatal for data collection)"
fi

NUITKA_VERSION="$(python -m nuitka --version 2>/dev/null | head -1 || echo unknown)"
PYTHON_VERSION="$(python --version 2>&1)"

RESULT_FILE="$OUTPUT_DIR/result-nuitka-${TARGET}-${MODE}-${LTO}-${PYTHON_FLAGS}-${NOFOLLOW}-${UPX}-${LIBC}.json"
cat > "$RESULT_FILE" <<EOJSON
{
  "target": "$TARGET",
  "compiler": "nuitka",
  "mode": "$MODE",
  "lto": "$LTO",
  "python_flags": "$PYTHON_FLAGS",
  "nofollow": "$NOFOLLOW",
  "upx": $UPX,
  "libc": "$LIBC",
  "binary_size_bytes": $BINARY_SIZE,
  "build_time_seconds": $BUILD_TIME,
  "smoke_test_passed": $SMOKE_PASSED,
  "python_version": "$PYTHON_VERSION",
  "compiler_version": "$NUITKA_VERSION",
  "binary_path": "$BINARY"
}
EOJSON

echo "=== Result ==="
cat "$RESULT_FILE"

FINAL_NAME="$OUTPUT_DIR/${BINARY_NAME}-${LIBC}"
if [ "$MODE" = "onefile" ]; then
    mv "$BINARY" "$FINAL_NAME"
    echo "Binary: $FINAL_NAME ($BINARY_SIZE bytes)"
fi
