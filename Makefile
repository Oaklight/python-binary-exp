.PHONY: all nuitka-build cython-build analyze clean help

TARGET ?= tinyleaf
OUTPUT_DIR ?= build

all: help

nuitka-build:
	@echo "=== Nuitka build: $(TARGET) ==="
	TARGET=$(TARGET) MODE=onefile LTO=yes PYTHON_FLAGS=aggressive NOFOLLOW=standard UPX=false LIBC=glibc OUTPUT_DIR=$(OUTPUT_DIR) bash scripts/build_nuitka.sh

cython-build:
	@echo "=== Cython build: $(TARGET) ==="
	TARGET=$(TARGET) CC_OPT=-Os LTO=yes STRIP=yes CPYTHON_SOURCE=system LINK=dynamic UPX=false LIBC=glibc OUTPUT_DIR=$(OUTPUT_DIR) bash scripts/build_cython.sh

analyze:
	python scripts/analyze_results.py $(OUTPUT_DIR)

clean:
	rm -rf $(OUTPUT_DIR) /tmp/cython_c /tmp/entry.c /tmp/target_*.txt /tmp/target_entry.py

help:
	@echo "Python Binary Compilation Experiments"
	@echo ""
	@echo "Targets:"
	@echo "  nuitka-build   - Build with Nuitka (default flags)"
	@echo "  cython-build   - Build with Cython --embed (default flags)"
	@echo "  analyze        - Analyze results in build/"
	@echo "  clean          - Remove build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  TARGET=<name>  - Target project (llm-rosetta or tinyleaf, default: tinyleaf)"
	@echo "  OUTPUT_DIR=<d> - Output directory (default: build)"
