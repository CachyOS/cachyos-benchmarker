import os
import re
import csv
import json
from datetime import datetime, timezone
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from collections import defaultdict

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

            for match in re.finditer(r'(stress-ng cpu-cache-mem|y-cruncher pi 1b|perf sched msg fork thread|perf memcpy|namd 92K atoms|calculating prime numbers|argon2 hashing|ffmpeg compilation|xz compression|kernel defconfig|blender render|x265 encoding|schbench p99 latency|cyclictest max latency|Total time \(s\)|Total score): (\d+\.?\d*)', data_text):
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

# Function to plot horizontal bar chart with annotations
def plot_horizontal_bar_chart_with_annotations(average_times, mode, kernel_versions):
    test_names = list(average_times[0].keys())
    test_names.reverse()
    num_kernel_versions = len(average_times)

    fig, axes = plt.subplots(num_kernel_versions, 1, figsize=(12, num_kernel_versions * 4))

    # Reverse the order of average_times and kernel_versions
    average_times = average_times[::-1]
    kernel_versions = kernel_versions[::-1]

    for i, avg_times in enumerate(average_times):
        kernel_version = kernel_versions[i]
        ax = axes[i] if num_kernel_versions > 1 else axes
        values = list(avg_times.values())[::-1]
        ax.barh(test_names, values, color='skyblue')
        for j, value in enumerate(values):
            ax.text(value, j, f'{value:.2f}', ha='left', va='center')
        ax.set_xlabel('Average Time (s), Less is better')
        ax.set_ylabel('Mini-Benchmarker')
        ax.set_title(f'Test Performance - Kernel Version: {kernel_version} ({mode} mode)')
        ax.grid(axis='x')

    plt.tight_layout()
    plt.savefig(f'average_performance_comparison_horizontal_{mode}.png')
    plt.close()

# Define a color palette
colors = list(mcolors.TABLEAU_COLORS.keys())

# Function to export aggregated data to CSV and JSON
def export_data(average_times, kernel_versions, csv_filename, json_filename, kernel_metadata=None):
    # Helper to split the concatenated kernel version string. Prefer parser metadata
    # so scheduler names containing underscores (for example scx_lavd) are preserved.
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

# Function to plot performance comparison between different kernel versions
def plot_kernel_version_comparison(average_times, mode, kernel_versions):
    test_names = list(average_times[0].keys())
    test_names.reverse()
    num_tests = len(test_names)
    num_kernel_versions = len(kernel_versions)

    # Dynamically adjust the figure height based on the number of tests and kernel versions
    base_height_per_test = 0.7  # Base height per test
    additional_height_per_kernel = 1.8  # Additional height per kernel version
    fig_height = base_height_per_test * num_tests + additional_height_per_kernel * num_kernel_versions

    fig_width = 12  # Keep the width fixed
    fig, ax = plt.subplots(figsize=(fig_width, fig_height))

    # Calculate the height of each bar
    bar_height = 0.8 / num_kernel_versions  # Ensure the bars fit within the allocated space for each test

    # Adjust font size based on the number of kernel versions
    font_size = max(6, 16 - num_kernel_versions * 0.5)  # Minimum font size of 6

    for i, avg_times in enumerate(average_times):
        kernel_version = kernel_versions[i]
        values = list(avg_times.values())[::-1]
        color = colors[i % len(colors)]  # Use modulo to loop through the color palette
        ax.barh(np.arange(num_tests) + i * bar_height, values, height=bar_height, label=kernel_version, color=color)
        for j, value in enumerate(values):
            ax.text(value, j + i * bar_height, f'{value:.2f}', fontsize=font_size, ha='left', va='center', color='black')

    ax.set_yticks(np.arange(num_tests) + bar_height * (num_kernel_versions - 1) / 2)
    ax.set_yticklabels(test_names)
    ax.set_xlabel('Average Time (s). Less is better')
    ax.set_ylabel('Mini-Benchmarker')
    ax.set_title(f'Test Performance Comparison Between Different Kernel Versions ({mode} mode)')

    # Reverse the order of the legend entries
    handles, labels = ax.get_legend_handles_labels()
    ax.legend(handles[::-1], labels[::-1], loc='lower right')
    ax.grid(axis='x')

    plt.tight_layout()
    plt.savefig(f'kernel_version_comparison_{mode}.png')
    plt.close()

# Extract test data, system information, and kernel versions from .log files
test_data, kernel_info, kernel_versions, kernel_metadata = parse_log_files()

# Check if logs were found
if test_data:
    # Get sorted kernel versions
    sorted_kernel_versions = sorted(kernel_versions.keys())

    # Get kernel versions list
    kernel_versions_list = [kernel_version for kernel_version in sorted_kernel_versions]

    # Calculate average test times for each kernel version
    average_times = [aggregate_test_results(kernel_versions[kernel_version]) for kernel_version in sorted_kernel_versions]

    # Plot horizontal bar chart with annotations
    plot_horizontal_bar_chart_with_annotations(average_times, 'All', kernel_versions_list)

    # Plot performance comparison between different kernel versions
    plot_kernel_version_comparison(average_times, 'All', kernel_versions_list)

    # Generate ISO 8601 timestamp for filenames
    # E.g., 2026-05-15T21-26-12Z
    timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H-%M-%SZ')
    csv_filename = f"test_results_{timestamp}.csv"
    json_filename = f"test_results_{timestamp}.json"

    # Export data to CSV and JSON
    export_data(average_times, kernel_versions_list, csv_filename, json_filename, kernel_metadata)

    # Generate HTML page
    html_content = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Test Performance</title>
    </head>
    <body>
        <h1>Test Performance</h1>
    """

    # Include charts for comparison of different kernel version performance based on average calculations
    html_content += f"""
    <h2>Average Test Performance Comparison</h2>
    <img src="average_performance_comparison_horizontal_All.png" alt="Average Test Performance Comparison - All Kernels" style="max-width: 100%; height: auto;">
    """

    # Include charts for comparison of performance between different kernel versions
    html_content += f"""
    <h2>Performance Comparison Between Different Kernel Versions</h2>
    <img src="kernel_version_comparison_All.png" alt="Performance Comparison Between Different Kernel Versions - All Kernels" style="max-width: 100%; height: auto;">
    """

    # Add links to raw data exports
    html_content += f"""
    <h2>Raw Data Exports</h2>
    <p>
        <a href="{csv_filename}">Download Results (CSV)</a> | 
        <a href="{json_filename}">Download Results (JSON)</a>
    </p>
    """

    html_content += """
    </body>
    </html>
    """

    # Write HTML content to a file
    with open('test_performance.html', 'w') as html_file:
        html_file.write(html_content)

    print("HTML page generated successfully!")
else:
    print("No logs found. HTML page not generated.")

