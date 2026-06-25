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

## How It Works

*   **cachyos-benchmarker**: The core script. It prepares the environment, downloads necessary assets, and runs a suite of 14 synthetic and real-world benchmarks (such as `stress-ng`, Blender CPU render, FFmpeg/Kernel compilation, x265 encoding, schbench, and cyclictest). Results, along with detailed system and `sched-ext` information, are logged to a `.log` file.
*   **benchmark_scraper.py**: A visualization and data extraction tool. It parses the generated `.log` files to aggregate performance metrics, compare different kernel or scheduler configurations, and generate a categorized composite chart with two sections (Throughput & Compilation / Scheduler Latency), alongside a cross-kernel comparison chart and an HTML report. It also automatically exports the aggregated raw data to time-stamped `.csv` and `.json` files for further analysis.
*   **kernel-autofdo.sh**: A helper script for hardware profiling. It automatically configures kernel branch sampling and runs the benchmarker alongside additional workloads (like `sysbench` and base-kernel compilation) to generate a footprint for AutoFDO.


# Credits

- Torvic: Author of this script
- https://github.com/julmajustus for creating the scrapper
