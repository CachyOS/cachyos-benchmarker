#### This is a small script for Arch-compatible distros that runs simple benchmarks and stress tests.

Benchmarks are grouped into two categories in the generated charts:

**Category 1 — Throughput & Compilation** (all ↓ lower is better):
* perf sched & mem
* stress-ng cpu & mem
* xz compression
* ffmpeg compilation
* y-cruncher pi calculation
* argon2 hashing
* blender rendering
* primesieve
* kernel defconfig
* namd
* x265 encoding

**Category 2 — Scheduler Latency** (per-metric direction):
* schbench wakeup latency (us) — ↓ lower is better
* schbench throughput (rps) — ↑ higher is better
* cyclictest scheduling latency (us) — ↓ lower is better

## Quick Start

```bash
# Run the full benchmark suite in a working directory
sudo ./cachyos-benchmarker /path/to/workdir

# The script will:
#   1. Prompt you to drop the page cache
#   2. Ask for a run label (or press Enter for auto-generated name)
#   3. Download all required assets into the working directory
#   4. Run all 14 benchmarks (this takes 15–25 minutes)
#   5. Generate a .log file, charts, CSV, JSON, and HTML report

# After completion, the working directory contains:
#   benchie_<label>_<date>.log        — raw benchmark results
#   categorized_comparison_All.png    — stacked chart (Category 1 + 2)
#   kernel_version_comparison_All.png — cross-kernel grouped chart
#   test_performance.html             — interactive HTML report
#   test_results_*.csv / .json        — machine-readable exports

# Example: compare two different kernels by running in separate directories
sudo ./cachyos-benchmarker /tmp/bench-kernel-A
# reboot into kernel B
sudo ./cachyos-benchmarker /tmp/bench-kernel-B

# Then run the scraper against both logfiles to generate a combined comparison:
cd /tmp/bench-comparison && cp /tmp/bench-kernel-A/benchie_*.log . && cp /tmp/bench-kernel-B/benchie_*.log . && python3 /path/to/benchmark_scraper.py
```

## How It Works

*   **cachyos-benchmarker**: The core script. It prepares the environment, downloads necessary assets, and runs a suite of 14 synthetic and real-world benchmarks (such as `stress-ng`, Blender CPU render, FFmpeg/Kernel compilation, x265 encoding, schbench, and cyclictest). Results, along with detailed system and `sched-ext` information, are logged to a `.log` file.
*   **benchmark_scraper.py**: A visualization and data extraction tool. It parses the generated `.log` files to aggregate performance metrics, compare different kernel or scheduler configurations, and generate a categorized composite chart with two sections (Throughput & Compilation / Scheduler Latency), alongside a cross-kernel comparison chart and an HTML report. It also automatically exports the aggregated raw data to time-stamped `.csv` and `.json` files for further analysis.
*   **kernel-autofdo.sh**: A helper script for hardware profiling. It automatically configures kernel branch sampling and runs the benchmarker alongside additional workloads (like `sysbench` and base-kernel compilation) to generate a footprint for AutoFDO.


# Credits

- Torvic: Author of this script
- https://github.com/julmajustus for creating the scrapper
