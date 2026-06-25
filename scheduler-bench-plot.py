#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0
#
# scheduler-bench-plot.py — multi-chart plotter for scheduler benchmarks
#
# Reads scheduler-bench.sh output (logfiles or summary env files) and
# generates a composite PNG with one subplot per metric, each annotated
# with its own direction label (lower/higher is better).

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

# ── Metric definitions: (env_key, title, direction) ──
# direction: "lower" = lower is better, "higher" = higher is better
METRICS = [
    ("SCHBENCH_WAKEUP_P99",    "Schbench Wakeup P99 (us)",     "lower"),
    ("SCHBENCH_WAKEUP_MAX",    "Schbench Wakeup Max (us)",     "lower"),
    ("SCHBENCH_RPS",           "Schbench Avg RPS",             "higher"),
    ("LATENCY_MAX_US",         "Cyclictest Max Latency (us)",  "lower"),
    ("LATENCY_SPIKES_OVER_100US", "Latency Spikes >100us",     "lower"),
    ("HACKBENCH_MEAN_SECONDS", "Hackbench Mean Time (s)",      "lower"),
    ("PERF_SCHED_TOTAL_SECONDS", "Perf Sched Total Time (s)",  "lower"),
    ("STRESSNG_BOGO_OPS_PER_SEC", "Stress-ng Bogo Ops/s",      "higher"),
]

# Optional hard-RT metrics shown when any file has LATENCY_HARD_RT=1
HARD_RT_METRICS = [
    ("LATENCY_OVER_20US",      "Cyclictest Overflows >20us",   "lower"),
]

COLORS = [
    "#4e79a7", "#f28e2b", "#59a14f", "#edc948", "#e15759",
    "#b07aa1", "#ff9da7", "#9c755f", "#bab0ac", "#6b6ecf",
]


def parse_env_file(path: Path) -> dict[str, str]:
    """Parse a KEY=VALUE summary file (env format)."""
    data: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        raw_line = raw_line.strip()
        if not raw_line or raw_line.startswith("#"):
            continue
        if "=" not in raw_line:
            continue
        key, _, value = raw_line.partition("=")
        data[key.strip()] = value.strip()
    return data


def parse_logfile(path: Path) -> dict[str, str]:
    """Parse a scheduler-bench logfile into key-value pairs.

    Lines are expected in the format:
        metric name: value
    """
    data: dict[str, str] = {}
    text = path.read_text(encoding="utf-8", errors="replace")

    # Map logfile keys to env keys
    key_map = {
        "schbench p99 latency (us)": "SCHBENCH_WAKEUP_P99",
        "schbench max latency (us)": "SCHBENCH_WAKEUP_MAX",
        "schbench avg rps": "SCHBENCH_RPS",
        "cyclictest max latency (us)": "LATENCY_MAX_US",
        "cyclictest total samples": "LATENCY_TOTAL_SAMPLES",
        "cyclictest spikes >100us": "LATENCY_SPIKES_OVER_100US",
        "cyclictest overflows >20us": "LATENCY_OVER_20US",
        "hackbench mean (s)": "HACKBENCH_MEAN_SECONDS",
        "perf sched total time (s)": "PERF_SCHED_TOTAL_SECONDS",
        "stress-ng bogo ops/s": "STRESSNG_BOGO_OPS_PER_SEC",
    }

    for line in text.splitlines():
        line = line.strip()
        if ":" not in line:
            continue
        key_raw, _, val_raw = line.partition(":")
        key_raw = key_raw.strip().lower()
        val_raw = val_raw.strip()

        for log_key, env_key in key_map.items():
            if key_raw == log_key.lower():
                data[env_key] = val_raw
                break

    # Extract label and scheduler info
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("Label:"):
            data["BENCHMARK_LABEL"] = line.split(":", 1)[1].strip()
        elif line.startswith("Sched-Ext:"):
            data["CURRENT_SCHEDULER"] = line.split(":", 1)[1].strip()
        elif line.startswith("Kernel:"):
            data["KERNEL_RELEASE"] = line.split(":", 1)[1].strip()
        elif line.startswith("Hard RT:"):
            data["LATENCY_HARD_RT"] = line.split(":", 1)[1].strip()

    return data


def as_float(value: str | None) -> float | None:
    if not value or value == "none" or value == "unknown":
        return None
    try:
        return float(value)
    except ValueError:
        return None


def load_data(input_dir: Path) -> list[dict[str, str]]:
    """Load all summary/log files from input_dir."""
    all_data: list[dict[str, str]] = []

    # Try *.env files first (summary format from benchmark.sh)
    env_files = sorted(input_dir.glob("*.env"))
    if env_files:
        for path in env_files:
            all_data.append(parse_env_file(path))
        return all_data

    # Fall back to logfiles
    log_files = sorted(input_dir.glob("scheduler-bench_*.log"))
    for path in log_files:
        all_data.append(parse_logfile(path))

    return all_data


def has_value(entry: dict[str, str], key: str) -> bool:
    return as_float(entry.get(key)) is not None


def build_aggregated(data: list[dict[str, str]]) -> list[dict]:
    """Group by label/scheduler and aggregate (max for lower, mean for higher)."""
    grouped: dict[str, list[dict[str, str]]] = defaultdict(list)

    for entry in data:
        label = entry.get("BENCHMARK_LABEL") or entry.get("CURRENT_SCHEDULER") or "unknown"
        grouped[label].append(entry)

    aggregated = []
    for label, items in grouped.items():
        row: dict = {
            "label": label,
            "runs": len(items),
            "current_scheduler": items[-1].get("CURRENT_SCHEDULER", ""),
            "kernel_release": items[-1].get("KERNEL_RELEASE", ""),
            "hard_rt": items[-1].get("LATENCY_HARD_RT") == "1",
        }

        all_metrics = METRICS + (HARD_RT_METRICS if any(
            e.get("LATENCY_HARD_RT") == "1" for e in items
        ) else [])

        for metric_key, _, direction in all_metrics:
            values = [
                v for v in (as_float(e.get(metric_key)) for e in items)
                if v is not None
            ]
            if not values:
                row[metric_key] = None
            elif direction == "lower":
                row[metric_key] = max(values)  # worst case
            else:
                row[metric_key] = float(np.mean(values))

        aggregated.append(row)

    # Sort: baseline first, then labeled runs
    def sort_key(r: dict) -> tuple:
        label = str(r["label"]).lower()
        if "baseline" in label:
            return (0, label)
        return (1, label)

    aggregated.sort(key=sort_key)
    return aggregated


def render_charts(
    aggregated: list[dict],
    output_dir: Path,
    fmt: str = "png",
) -> Path:
    """Generate composite multi-chart figure, one subplot per metric."""
    is_hard_rt = any(r.get("hard_rt") for r in aggregated)
    all_metrics = METRICS + (HARD_RT_METRICS if is_hard_rt else [])

    active_metrics = [
        metric for metric in all_metrics
        if any(r.get(metric[0]) is not None for r in aggregated)
    ]

    if not active_metrics:
        raise SystemExit("No numeric metrics were available to plot")

    n_metrics = len(active_metrics)
    fig, axes = plt.subplots(n_metrics, 1, figsize=(12, 3.6 * n_metrics))
    if n_metrics == 1:
        axes = [axes]

    for ax, (metric_key, title, direction) in zip(axes, active_metrics):
        present = [r for r in aggregated if r.get(metric_key) is not None]
        missing = [r for r in aggregated if r.get(metric_key) is None]

        reverse_sort = direction == "higher"
        present.sort(
            key=lambda r: float(r[metric_key]) if r[metric_key] is not None else 0,
            reverse=reverse_sort,
        )
        ranked = present + missing

        labels = [str(r["label"]) for r in ranked]
        values = [r.get(metric_key) for r in ranked]
        display_values = [0.0 if v is None else float(v) for v in values]

        # Color by scheduler
        bar_colors = []
        for r in ranked:
            sched = str(r.get("current_scheduler", ""))
            if "scx_flow" in sched:
                bar_colors.append("#e15759")
            elif "scx_cosmos" in sched:
                bar_colors.append("#f28e2b")
            elif "scx_bpfland" in sched:
                bar_colors.append("#59a14f")
            elif "scx_cake" in sched:
                bar_colors.append("#edc948")
            elif not sched or sched == "none":
                bar_colors.append("#4e79a7")
            else:
                bar_colors.append("#76b7b2")

        direction_label = "lower is better" if direction == "lower" else "higher is better"
        ax.set_title(f"{title} ({direction_label})", fontsize=11, fontweight="bold")

        bars = ax.barh(labels, display_values, color=bar_colors, edgecolor="white", linewidth=0.5)
        ax.grid(axis="x", linestyle="--", alpha=0.3)
        ax.invert_yaxis()

        # Annotate bar values
        pad = max(display_values) * 0.02 if display_values and max(display_values) > 0 else 0.5
        for bar, value in zip(bars, values):
            label = "n/a" if value is None else f"{float(value):.2f}"
            ax.text(
                bar.get_width() + pad,
                bar.get_y() + bar.get_height() / 2,
                label,
                va="center",
                fontsize=9,
            )

    is_hard_rt = any(r.get("hard_rt") for r in aggregated)
    subtitle = "Hard RT mode: FIFO prio 99, SMP, 200us interval" if is_hard_rt else ""
    if subtitle:
        fig.suptitle("Scheduler Benchmark Comparison\n" + subtitle,
                     fontsize=14, fontweight="bold")
    else:
        fig.suptitle("Scheduler Benchmark Comparison",
                     fontsize=14, fontweight="bold")

    output_path = output_dir / f"scheduler-bench-comparison.{fmt}"
    fig.savefig(output_path, dpi=160, bbox_inches="tight")
    plt.close(fig)

    return output_path


def write_csv(aggregated: list[dict], output_dir: Path) -> Path:
    """Write aggregated results to CSV."""
    is_hard_rt = any(r.get("hard_rt") for r in aggregated)
    all_metrics = METRICS + (HARD_RT_METRICS if is_hard_rt else [])
    csv_path = output_dir / "scheduler-bench-results.csv"

    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        header = ["label", "runs", "current_scheduler", "kernel_release", "hard_rt"]
        header += [key for key, _, _ in all_metrics]
        writer.writerow(header)

        for row in aggregated:
            vals = [
                row["label"],
                row["runs"],
                row["current_scheduler"],
                row["kernel_release"],
                "yes" if row.get("hard_rt") else "no",
            ]
            for metric_key, _, _ in all_metrics:
                v = row.get(metric_key)
                vals.append("" if v is None else f"{v:.2f}")
            writer.writerow(vals)

    return csv_path


def write_json(aggregated: list[dict], output_dir: Path) -> Path:
    """Write aggregated results to JSON."""
    is_hard_rt = any(r.get("hard_rt") for r in aggregated)
    all_metrics = METRICS + (HARD_RT_METRICS if is_hard_rt else [])

    json_data = []
    for row in aggregated:
        entry = {
            "label": row["label"],
            "runs": row["runs"],
            "current_scheduler": row["current_scheduler"],
            "kernel_release": row["kernel_release"],
            "hard_rt": row.get("hard_rt", False),
            "metrics": {},
        }
        for metric_key, title, direction in all_metrics:
            v = row.get(metric_key)
            entry["metrics"][metric_key] = {
                "title": title,
                "value": round(v, 2) if v is not None else None,
                "direction": direction,
            }
        json_data.append(entry)

    json_path = output_dir / "scheduler-bench-results.json"
    json_path.write_text(json.dumps(json_data, indent=2), encoding="utf-8")
    return json_path


def write_html(aggregated: list[dict], output_dir: Path) -> Path:
    """Write an HTML report."""
    is_hard_rt = any(r.get("hard_rt") for r in aggregated)
    all_metrics = METRICS + (HARD_RT_METRICS if is_hard_rt else [])

    rows_html = ""
    for row in aggregated:
        cells = f"<td>{row['label']}</td><td>{row['runs']}</td>"
        for metric_key, _, direction in all_metrics:
            v = row.get(metric_key)
            display = "n/a" if v is None else f"{v:.2f}"
            icon = "↓" if direction == "lower" else "↑"
            cells += f"<td>{display} {icon}</td>"
        rows_html += f"<tr>{cells}</tr>"

    header_cells = "<th>Label</th><th>Runs</th>"
    for _, title, direction in all_metrics:
        dir_label = "(↓ lower)" if direction == "lower" else "(↑ higher)"
        header_cells += f"<th>{title}<br><small>{dir_label}</small></th>"

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Scheduler Benchmark Results</title>
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 2em; }}
h1 {{ color: #333; }}
img {{ max-width: 100%; height: auto; border: 1px solid #ddd; border-radius: 4px; }}
table {{ border-collapse: collapse; margin: 1em 0; width: 100%; }}
th, td {{ border: 1px solid #ddd; padding: 8px; text-align: center; }}
th {{ background-color: #f5f5f5; font-weight: bold; }}
tr:nth-child(even) {{ background-color: #fafafa; }}
</style>
</head>
<body>
<h1>Scheduler Benchmark Results</h1>
<img src="scheduler-bench-comparison.png" alt="Comparison chart">
<h2>Results Table</h2>
<table>
<thead><tr>{header_cells}</tr></thead>
<tbody>{rows_html}</tbody>
</table>
</body>
</html>"""

    html_path = output_dir / "scheduler-bench-report.html"
    html_path.write_text(html, encoding="utf-8")
    return html_path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate multi-chart comparison from scheduler-bench.sh output"
    )
    parser.add_argument(
        "--input-dir", type=Path, required=True,
        help="Directory containing *.env summary files or scheduler-bench_*.log files"
    )
    parser.add_argument(
        "--output-dir", type=Path, default=None,
        help="Output directory (default: input-dir)"
    )
    parser.add_argument(
        "--no-chart", action="store_true",
        help="Skip chart generation, only produce CSV/JSON/HTML"
    )
    args = parser.parse_args()

    input_dir = args.input_dir.resolve()
    output_dir = (args.output_dir or input_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    data = load_data(input_dir)
    if not data:
        print(f"No summary or log files found in {input_dir}", file=sys.stderr)
        sys.exit(1)

    aggregated = build_aggregated(data)

    csv_path = write_csv(aggregated, output_dir)
    json_path = write_json(aggregated, output_dir)
    html_path = write_html(aggregated, output_dir)

    print(f"CSV : {csv_path}")
    print(f"JSON: {json_path}")
    print(f"HTML: {html_path}")

    if not args.no_chart:
        png_path = render_charts(aggregated, output_dir)
        print(f"PNG : {png_path}")

    # Print summary to stdout
    print()
    for row in aggregated:
        print(f"  {row['label']}:")
        is_hard_rt = any(r.get("hard_rt") for r in aggregated)
        all_metrics = METRICS + (HARD_RT_METRICS if is_hard_rt else [])
        for metric_key, title, direction in all_metrics:
            v = row.get(metric_key)
            if v is not None:
                dir_sym = "↓" if direction == "lower" else "↑"
                print(f"    {title}: {v:.2f} {dir_sym}")


if __name__ == "__main__":
    main()
