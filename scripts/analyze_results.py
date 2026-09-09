#!/usr/bin/env python3
"""Analyze binary compilation sweep results and generate comparison tables."""

import json
import os
import sys
from pathlib import Path


def load_results(results_dir: str) -> list[dict]:
    results = []
    for f in Path(results_dir).rglob("result-*.json"):
        try:
            with open(f) as fh:
                results.append(json.load(fh))
        except (json.JSONDecodeError, OSError) as e:
            print(f"WARN: skipping {f}: {e}", file=sys.stderr)
    return results


def format_size(size_bytes: int) -> str:
    if size_bytes >= 1_048_576:
        return f"{size_bytes / 1_048_576:.2f} MB"
    if size_bytes >= 1024:
        return f"{size_bytes / 1024:.1f} KB"
    return f"{size_bytes} B"


def format_time(seconds: int) -> str:
    if seconds >= 60:
        return f"{seconds // 60}m{seconds % 60:02d}s"
    return f"{seconds}s"


def config_summary(r: dict) -> str:
    if r["compiler"] == "nuitka":
        return (
            f"mode={r['mode']} lto={r['lto']} flags={r['python_flags']} "
            f"nofollow={r['nofollow']} upx={r['upx']}"
        )
    return (
        f"cc={r['cc_opt']} lto={r['lto']} strip={r['strip']} "
        f"cpython={r['cpython_source']} link={r['link']} upx={r['upx']}"
    )


def generate_table(results: list[dict], title: str) -> str:
    if not results:
        return f"## {title}\n\nNo results.\n"

    sorted_results = sorted(results, key=lambda r: r["binary_size_bytes"])

    lines = [
        f"## {title}",
        "",
        "| Rank | Target | Compiler | Config | Size | Build Time | Smoke |",
        "|------|--------|----------|--------|------|------------|-------|",
    ]

    for i, r in enumerate(sorted_results, 1):
        smoke = "✅" if r.get("smoke_test_passed") else "❌"
        lines.append(
            f"| {i} | {r['target']} | {r['compiler']} | "
            f"{config_summary(r)} | {format_size(r['binary_size_bytes'])} | "
            f"{format_time(r['build_time_seconds'])} | {smoke} |"
        )

    lines.append("")
    return "\n".join(lines)


def generate_best_per_category(results: list[dict]) -> str:
    if not results:
        return ""

    categories = {}
    for r in results:
        key = (r["target"], r["compiler"], r["libc"])
        if key not in categories or r["binary_size_bytes"] < categories[key]["binary_size_bytes"]:
            categories[key] = r

    lines = [
        "## Best Configuration Per Category",
        "",
        "| Target | Compiler | Libc | Best Config | Size | Smoke |",
        "|--------|----------|------|-------------|------|-------|",
    ]

    for (target, compiler, libc), r in sorted(categories.items()):
        smoke = "✅" if r.get("smoke_test_passed") else "❌"
        lines.append(
            f"| {target} | {compiler} | {libc} | "
            f"{config_summary(r)} | {format_size(r['binary_size_bytes'])} | {smoke} |"
        )

    lines.append("")
    return "\n".join(lines)


def generate_flag_impact(results: list[dict]) -> str:
    if len(results) < 2:
        return ""

    nuitka_results = [r for r in results if r["compiler"] == "nuitka"]
    if not nuitka_results:
        return ""

    lines = ["## Flag Impact Analysis (Nuitka)", ""]

    for target in sorted({r["target"] for r in nuitka_results}):
        for libc in ["glibc", "musl"]:
            target_results = [
                r for r in nuitka_results
                if r["target"] == target and r["libc"] == libc
            ]
            if len(target_results) < 2:
                continue

            baseline = None
            for r in target_results:
                if (r.get("mode") == "onefile" and r.get("lto") == "no"
                        and r.get("python_flags") == "minimal"
                        and r.get("nofollow") == "standard" and not r.get("upx")):
                    baseline = r
                    break

            if not baseline:
                baseline = max(target_results, key=lambda r: r["binary_size_bytes"])

            base_size = baseline["binary_size_bytes"]
            lines.append(f"### {target} ({libc}) — baseline: {format_size(base_size)}")
            lines.append("")
            lines.append("| Config Change | Size | Δ |")
            lines.append("|---------------|------|---|")

            for r in sorted(target_results, key=lambda r: r["binary_size_bytes"]):
                delta = r["binary_size_bytes"] - base_size
                pct = (delta / base_size * 100) if base_size else 0
                sign = "+" if delta > 0 else ""
                lines.append(
                    f"| {config_summary(r)} | {format_size(r['binary_size_bytes'])} | "
                    f"{sign}{pct:.1f}% |"
                )

            lines.append("")

    return "\n".join(lines)


def main():
    results_dir = sys.argv[1] if len(sys.argv) > 1 else "results"

    if not os.path.isdir(results_dir):
        print(f"ERROR: results directory '{results_dir}' not found", file=sys.stderr)
        sys.exit(1)

    results = load_results(results_dir)
    if not results:
        print("No result files found.", file=sys.stderr)
        sys.exit(1)

    print(f"Loaded {len(results)} results", file=sys.stderr)

    sections = ["# Python Binary Compilation — Sweep Results", ""]

    sections.append(generate_best_per_category(results))

    for libc in ["glibc", "musl"]:
        libc_results = [r for r in results if r["libc"] == libc]
        sections.append(generate_table(libc_results, f"All Results — {libc}"))

    sections.append(generate_flag_impact(results))

    smallest = min(results, key=lambda r: r["binary_size_bytes"])
    sections.extend([
        "## Recommendation",
        "",
        f"**Smallest binary overall:** {format_size(smallest['binary_size_bytes'])} "
        f"({smallest['target']}, {smallest['compiler']}, {smallest['libc']})",
        f"Config: {config_summary(smallest)}",
        "",
    ])

    output = "\n".join(sections)
    print(output)

    output_file = os.path.join(results_dir, "analysis.md")
    with open(output_file, "w") as f:
        f.write(output)
    print(f"\nAnalysis written to {output_file}", file=sys.stderr)


if __name__ == "__main__":
    main()
