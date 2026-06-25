import os
import re
import csv
import json
from datetime import datetime, timezone
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from collections import defaultdict

# ── Category definitions ──
# Category 1: Throughput & Compilation benchmarks (all lower-is-better, in seconds)
CATEGORY_1 = [
    "stress-ng cpu-cache-mem",
    "perf sched msg fork thread",
    "perf memcpy",
    "calculating prime numbers",
    "namd 92K atoms",
    "argon2 hashing",
    "ffmpeg compilation",
    "xz compression",
    "kernel defconfig",
    "blender render",
    "x265 encoding",
    "y-cruncher pi 1b",
]

# Category 2: Scheduler latency metrics (per-metric direction)
# Each entry: (test_name, direction, unit_label)
CATEGORY_2 = [
    ("schbench p99 latency (us)", "lower", "us"),
    ("schbench avg rps",         "higher", "rps"),
    ("cyclictest max latency (us)", "lower", "us"),
]

# Combined regex pattern for all parseable test names
ALL_TEST_NAMES = CATEGORY_1 + [c[0] for c in CATEGORY_2]

# Function to parse log files and extract test data, system information, and kernel versions
def parse_log_files():
    test_data = defaultdict(list)
    kernel_info = {}
    kernel_versions = defaultdict(dict)
    kernel_metadata = {}

    for file in os.listdir('.'):
        if file.endswith('.log') and file.startswith('benchie_'):
            with open(file, 'r') as f:
                data_text = f.read()

            kernel_version_match = re.search(r'Kernel: (\S+)', data_text)
            if kernel_version_match:
                kernel_version = kernel_version_match.group(1)
                kernel_label = kernel_version
                scx = "none"
                scx_version = "none"
            else:
                print(f"Warning: Could not extract kernel version from file: {file}")
                continue

            scx_match = re.search(r'SCX Scheduler: (\S+)', data_text)
            scx_version_match = re.search(r'SCX Version: (\S+)', data_text)
            if scx_match and scx_version_match:
                scx = scx_match.group(1)
                scx_version = scx_version_match.group(1)
                kernel_label = ''.join([kernel_version, '_', scx, '_', scx_version])

            kernel_metadata[kernel_label] = {
                "kernel": kernel_version,
                "scx_scheduler": scx,
                "scx_version": scx_version,
            }

            system_info_match = re.search(r'System:(.*?)$', data_text, re.DOTALL)
            if system_info_match:
                system_info = system_info_match.group(1).strip()
            else:
                print(f"Warning: Could not extract system information from file: {file}")
                continue

            # Build regex alternation from all test names
            escaped_names = [re.escape(n) for n in ALL_TEST_NAMES]
            pattern = r'(' + '|'.join(escaped_names) + r'|Total time \(s\)|Total score): (\d+\.?\d*)'
            for match in re.finditer(pattern, data_text):
                test_name = match.group(1)
                test_time = float(match.group(2))
                test_data[(kernel_label, test_name)].append(test_time)
                kernel_versions[kernel_label].setdefault(test_name, []).append(test_time)
                kernel_info[kernel_label] = system_info

    return test_data, kernel_info, kernel_versions, kernel_metadata

# Function to aggregate test results
def aggregate_test_results(data):
    aggregated_data = {}
    for key, values in data.items():
        aggregated_data[key] = np.mean(values)
    return aggregated_data

# Color palette
colors = list(mcolors.TABLEAU_COLORS.keys())

def get_category1_tests(average_times_for_kernel):
    """Return (test_names, values) for all category 1 tests present in the data."""
    names, values = [], []
    for t in CATEGORY_1:
        if t in average_times_for_kernel:
            names.append(t)
            values.append(average_times_for_kernel[t])
    return names, values

def get_category2_tests(average_times_for_kernel):
    """Return (test_names, values, directions, units) for all category 2 tests present."""
    names, values, directions, units = [], [], [], []
    for t, direction, unit in CATEGORY_2:
        if t in average_times_for_kernel:
            names.append(t)
            values.append(average_times_for_kernel[t])
            directions.append(direction)
            units.append(unit)
    return names, values, directions, units

# New categorized composite chart
def plot_categorized_comparison(average_times, mode, kernel_versions):
    """
    Generate a composite figure with two sections stacked vertically:

    Top   — Category 1: Throughput & Compilation (all lower is better)
    Bottom — Category 2: Scheduler Latency (per-metric direction labels)

    One sub-figure per kernel version, each with two subplots.
    """
    num_kernels = len(average_times)
    if num_kernels == 0:
        return

    # Determine how many category 2 tests exist across all kernels
    max_cat2 = 0
    for avg in average_times:
        cat2_names, _, _, _ = get_category2_tests(avg)
        max_cat2 = max(max_cat2, len(cat2_names))

    # Vertical layout: Category 1 (top), then Category 2 (bottom) for each kernel
    cat1_height = 4.0
    cat2_height = 2.8 if max_cat2 > 0 else 0
    total_height = num_kernels * (cat1_height + cat2_height)
    fig, axes = plt.subplots(num_kernels * 2, 1,
                             figsize=(15, total_height))

    reverse_order = list(range(num_kernels))[::-1]
    average_times_rev = [average_times[i] for i in reverse_order]
    kernel_versions_rev = [kernel_versions[i] for i in reverse_order]

    for row_idx, (avg, kv) in enumerate(zip(average_times_rev, kernel_versions_rev)):
        ax_top = axes[row_idx * 2]
        ax_bottom = axes[row_idx * 2 + 1]

        # ── Category 1: bar chart (top subplot) ──
        cat1_names, cat1_values = get_category1_tests(avg)
        if cat1_names:
            names_rev = cat1_names[::-1]
            values_rev = cat1_values[::-1]
            bars = ax_top.barh(names_rev, values_rev, color='skyblue', edgecolor='white')
            for bar, val in zip(bars, values_rev):
                ax_top.text(bar.get_width() + max(cat1_values) * 0.01,
                            bar.get_y() + bar.get_height() / 2,
                            f'{val:.2f}', va='center', fontsize=9)
            ax_top.set_xlabel('Time (s), lower is better', fontsize=10)

        ax_top.set_title(f'{kv} — Throughput & Compilation', fontsize=11, fontweight='bold')
        ax_top.grid(axis='x', linestyle='--', alpha=0.3)

        # ── Category 2: bar chart (bottom subplot) ──
        cat2_names, cat2_values, cat2_dirs, cat2_units = get_category2_tests(avg)
        if cat2_names:
            paired = list(zip(cat2_names, cat2_values, cat2_dirs, cat2_units))
            lower_first = sorted(paired, key=lambda x: (0 if x[2] == 'lower' else 1))
            names_rev2 = [p[0] for p in lower_first][::-1]
            values_rev2 = [p[1] for p in lower_first][::-1]
            dirs_rev2 = [p[2] for p in lower_first][::-1]
            units_rev2 = [p[3] for p in lower_first][::-1]

            bar_colors = []
            for d in dirs_rev2:
                bar_colors.append('#59a14f' if d == 'higher' else '#e15759')

            bars2 = ax_bottom.barh(names_rev2, values_rev2, color=bar_colors, edgecolor='white')
            for bar, val, d, unit in zip(bars2, values_rev2, dirs_rev2, units_rev2):
                label = f'{val:.2f} {unit}'
                direction_label = '↑' if d == 'higher' else '↓'
                ax_bottom.text(bar.get_width() + max(cat2_values) * 0.01,
                               bar.get_y() + bar.get_height() / 2,
                               f'{label} {direction_label}', va='center', fontsize=10)

            from matplotlib.patches import Patch
            legend_elements = [
                Patch(facecolor='#e15759', label='↓ lower is better'),
                Patch(facecolor='#59a14f', label='↑ higher is better'),
            ]
            ax_bottom.legend(handles=legend_elements, loc='lower right', fontsize=9)

        ax_bottom.set_title(f'{kv} — Scheduler Latency', fontsize=11, fontweight='bold')
        ax_bottom.grid(axis='x', linestyle='--', alpha=0.3)

    fig.suptitle(f'CachyOS Benchmarker — Categorized Results ({mode} mode)',
                 fontsize=14, fontweight='bold', y=0.98)
    plt.subplots_adjust(hspace=0.6, top=0.88)
    plt.savefig(f'categorized_comparison_{mode}.png', dpi=160, bbox_inches='tight')
    plt.close()

# Function to export aggregated data to CSV and JSON
def export_data(average_times, kernel_versions, csv_filename, json_filename, kernel_metadata=None):
    def split_kernel_string(kv):
        if kernel_metadata and kv in kernel_metadata:
            metadata = kernel_metadata[kv]
            return metadata["kernel"], metadata["scx_scheduler"], metadata["scx_version"]
        parts = kv.rsplit('_', 1)
        if len(parts) == 2 and '_' in parts[0]:
            kernel, scx = parts[0].split('_', 1)
            return kernel, scx, parts[1]
        return kv, "none", "none"

    # JSON export
    json_data = []
    for i, kernel_version in enumerate(kernel_versions):
        kernel, scx, scx_ver = split_kernel_string(kernel_version)
        entry = {
            "kernel": kernel,
            "scx_scheduler": scx,
            "scx_version": scx_ver,
            "metrics": {k: float(v) for k, v in average_times[i].items()}
        }
        json_data.append(entry)

    with open(json_filename, 'w') as f:
        json.dump(json_data, f, indent=4)

    # CSV export
    if not kernel_versions:
        return

    test_names = list(average_times[0].keys())

    with open(csv_filename, 'w', newline='') as f:
        writer = csv.writer(f)
        header = ['Kernel', 'SCX Scheduler', 'SCX Version'] + test_names
        writer.writerow(header)

        for i, kernel_version in enumerate(kernel_versions):
            kernel, scx, scx_ver = split_kernel_string(kernel_version)
            row = [kernel, scx, scx_ver]
            for test_name in test_names:
                row.append(average_times[i].get(test_name, ''))
            writer.writerow(row)

# Function to plot performance comparison between different kernel versions (keep existing)
def plot_kernel_version_comparison(average_times, mode, kernel_versions):
    all_test_names = list(average_times[0].keys())
    all_test_names.reverse()
    num_tests = len(all_test_names)
    num_kernel_versions = len(kernel_versions)

    base_height_per_test = 0.7
    additional_height_per_kernel = 1.8
    fig_height = base_height_per_test * num_tests + additional_height_per_kernel * num_kernel_versions
    fig_width = 12
    fig, ax = plt.subplots(figsize=(fig_width, fig_height))

    bar_height = 0.8 / num_kernel_versions
    font_size = max(6, 16 - num_kernel_versions * 0.5)

    for i, avg_times in enumerate(average_times):
        kernel_version = kernel_versions[i]
        values = list(avg_times.values())[::-1]
        color = colors[i % len(colors)]
        ax.barh(np.arange(num_tests) + i * bar_height, values, height=bar_height,
                label=kernel_version, color=color)
        for j, value in enumerate(values):
            ax.text(value, j + i * bar_height, f'{value:.2f}',
                    fontsize=font_size, ha='left', va='center', color='black')

    ax.set_yticks(np.arange(num_tests) + bar_height * (num_kernel_versions - 1) / 2)
    ax.set_yticklabels(all_test_names)
    ax.set_xlabel('Average Time (s). Less is better')
    ax.set_ylabel('Mini-Benchmarker')
    ax.set_title(f'Test Performance Comparison Between Different Kernel Versions ({mode} mode)')

    handles, labels = ax.get_legend_handles_labels()
    ax.legend(handles[::-1], labels[::-1], loc='lower right')
    ax.grid(axis='x')

    plt.tight_layout()
    plt.savefig(f'kernel_version_comparison_{mode}.png')
    plt.close()

# ── Main ──
test_data, kernel_info, kernel_versions, kernel_metadata = parse_log_files()

if test_data:
    sorted_kernel_versions = sorted(kernel_versions.keys())
    kernel_versions_list = list(sorted_kernel_versions)

    # Calculate average test times for each kernel version
    average_times = [aggregate_test_results(kernel_versions[kv]) for kv in sorted_kernel_versions]

    # Generate categorized composite chart (NEW — replaces the old horizontal chart)
    plot_categorized_comparison(average_times, 'All', kernel_versions_list)

    # Keep the cross-kernel comparison chart (existing)
    plot_kernel_version_comparison(average_times, 'All', kernel_versions_list)

    # Generate ISO 8601 timestamp for filenames
    timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%SZ')
    csv_filename = f"test_results_{timestamp}.csv"
    json_filename = f"test_results_{timestamp}.json"

    # Export data to CSV and JSON
    export_data(average_times, kernel_versions_list, csv_filename, json_filename, kernel_metadata)

    # Generate HTML page
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Performance</title>
</head>
<body>
    <h1>Test Performance</h1>

    <h2>Categorized Results</h2>
    <p>Category 1: Throughput & Compilation (lower is better).
       Category 2: Scheduler Latency (↓ lower is better, ↑ higher is better).</p>
    <img src="categorized_comparison_All.png" alt="Categorized Comparison - All Kernels"
         style="max-width: 100%; height: auto;">

    <h2>Performance Comparison Between Different Kernel Versions</h2>
    <img src="kernel_version_comparison_All.png" alt="Kernel Version Comparison - All Kernels"
         style="max-width: 100%; height: auto;">

    <h2>Raw Data Exports</h2>
    <p>
        <a href="{csv_filename}">Download Results (CSV)</a> |
        <a href="{json_filename}">Download Results (JSON)</a>
    </p>
</body>
</html>"""

    with open('test_performance.html', 'w') as html_file:
        html_file.write(html_content)

    print("HTML page generated successfully!")
else:
    print("No logs found. HTML page not generated.")
