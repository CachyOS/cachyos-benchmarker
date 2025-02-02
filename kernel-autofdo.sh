#!/usr/bin/env bash
set -euo pipefail

#-------------------------------------------------------------------------------
# CachyOS Benchmarker & Profiling Setup
#-------------------------------------------------------------------------------

# Allow to profile with branch sampling
sudo sh -c "echo 0 > /proc/sys/kernel/kptr_restrict"
sudo sh -c "echo 0 > /proc/sys/kernel/perf_event_paranoid"

# Variables
WORKDIR="${HOME}/profiling"
NPROC="$(nproc)"

echo "CachyOS Benchmarker"

# Create and enter the working directory
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

# Run the CachyOS benchmarker
cachyos-benchmarker "${WORKDIR}"

#-------------------------------------------------------------------------------
# Sysbench Tests
#-------------------------------------------------------------------------------

echo "Running Sysbench tests..."

# CPU Test
echo "CPU Test:"
sysbench --time=30 cpu --cpu-max-prime=50000 --threads="${NPROC}" run

# Memory Tests
echo "Memory Test:"
sysbench memory --memory-block-size=1M --memory-total-size=16G run
sysbench memory --memory-block-size=1M --memory-total-size=16G --memory-oper=read --num-threads=16 run

# I/O Tests
echo "I/O Test:"
sysbench fileio --file-total-size=5G --file-num=5 prepare
sysbench fileio --file-total-size=5G --file-num=5 \
    --file-fsync-freq=0 --file-test-mode=rndrd --file-block-size=4K run
sysbench fileio --file-total-size=5G --file-num=5 \
     --file-fsync-freq=0 --file-test-mode=seqwr --file-block-size=1M run
sysbench fileio --file-total-size=5G --file-num=5 cleanup

#-------------------------------------------------------------------------------
# Git and Kernel Compilation
#-------------------------------------------------------------------------------

echo "Cloning and compiling kernel..."

# Adjust the repository URL and branch as necessary
git clone --depth=1 -b 6.12/base git@github.com:CachyOS/linux.git linux
cd linux
git pull
zcat /proc/config.gz > .config
make prepare
make defconfig
make -j"${NPROC}"
cd .. && rm -rf linux

#-------------------------------------------------------------------------------
# Miscellaneous Tests
#-------------------------------------------------------------------------------

echo "Running miscellaneous tests..."

# Find all .conf files on the system (silenced output, may take a while)
find / -type f -name "*.conf" > /dev/null 2>&1 || true

# Using ripgrep (rg) to search for various terms
rg test || true
rg KERNEL || true
rg sched || true
rg fair || true

echo "All tests completed."
