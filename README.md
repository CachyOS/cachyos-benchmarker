#### This is a small script for Arch-compatible distros that runs simple benchmarks and stress tests.

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

## How It Works

*   **cachyos-benchmarker**: The core script. It prepares the environment, downloads necessary assets, and runs a suite of 12 synthetic and real-world benchmarks (such as `stress-ng`, Blender CPU render, FFmpeg/Kernel compilation, and x265 encoding). Results, along with detailed system and `sched-ext` information, are logged to a `.log` file.
*   **benchmark_scraper.py**: A visualization tool. It parses the generated `.log` files to aggregate performance metrics, compare different kernel or scheduler configurations, and generate visual bar charts alongside an HTML report.
*   **kernel-autofdo.sh**: A helper script for hardware profiling to generate a footprint for AutoFDO.

# ToDo

- Geekbench: Request in benchmark, if its wanted to run geekbench and then print the URL into Logfile
- schbench: Add schbench and parse the result into logfile for scheduler latency benchmarking


# Credits

- Torvic: Author of this script
- https://github.com/julmajustus for creating the scrapper
