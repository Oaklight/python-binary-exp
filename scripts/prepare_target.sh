#!/usr/bin/env bash
set -euo pipefail

TARGET="${TARGET:?TARGET must be set (llm-rosetta or tinyleaf)}"
INSTALL_MODE="${INSTALL_MODE:-pip}"

case "$TARGET" in
    llm-rosetta)
        PKG_NAME="llm-rosetta"
        REPO_URL="https://github.com/oaklight/llm-rosetta.git"
        ENTRY_PACKAGE="llm_rosetta"
        ENTRY_STUB='from llm_rosetta.gateway import main\nmain()'
        SMOKE_CMD="--help"
        ;;
    tinyleaf)
        PKG_NAME="tinyleaf"
        REPO_URL="https://github.com/oaklight/tinyleaf.git"
        ENTRY_PACKAGE="tinyleaf"
        ENTRY_STUB='from tinyleaf.cli import main\nmain()'
        SMOKE_CMD="--help"
        ;;
    *)
        echo "ERROR: Unknown target '$TARGET'. Must be 'llm-rosetta' or 'tinyleaf'."
        exit 1
        ;;
esac

echo "=== Preparing target: $TARGET (mode: $INSTALL_MODE) ==="

if [ "$INSTALL_MODE" = "pip" ]; then
    pip install --quiet "$PKG_NAME"
elif [ "$INSTALL_MODE" = "source" ]; then
    CLONE_DIR="/tmp/target-src"
    rm -rf "$CLONE_DIR"
    git clone --depth=1 "$REPO_URL" "$CLONE_DIR"
    pip install --quiet -e "$CLONE_DIR"
else
    echo "ERROR: Unknown INSTALL_MODE '$INSTALL_MODE'. Must be 'pip' or 'source'."
    exit 1
fi

SITE_PACKAGES="$(python -c "import ${ENTRY_PACKAGE}; import os; print(os.path.dirname(${ENTRY_PACKAGE}.__file__))")"
echo "Package installed at: $SITE_PACKAGES"

echo "$ENTRY_PACKAGE" > /tmp/target_entry_package.txt
printf "$ENTRY_STUB" > /tmp/target_entry.py
echo "$SMOKE_CMD" > /tmp/target_smoke_cmd.txt
echo "$TARGET" > /tmp/target_name.txt

echo "=== Target $TARGET prepared ==="
