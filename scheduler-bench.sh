#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# scheduler-bench.sh — standalone scheduler-focused benchmark suite
#
# Measures scheduler performance via schbench (wakeup latency + RPS)
# and cyclictest (scheduling latency), with optional hackbench and
# perf bench sched messaging. Each metric is reported independently
# with its own direction (lower/higher is better).
#
# This script is a focused alternative to the monolithic
# cachyos-benchmarker, designed for comparing CPU schedulers.
#
# Outputs:
#   --log-file      Human-readable structured log
#   --summary-file  Machine-parseable KEY=VALUE summary (env format)

set -euo pipefail

VERSION="v1.0"
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Terminal effects
TB=$(tput bold)
TN=$(tput sgr0)
FARBE1=$(printf '\033[0;91m')
FARBE2=$(printf '\033[4;37m')
FARBE3=$(printf '\033[0;33m')

# Defaults
LOG_FILE=""
SUMMARY_FILE=""
LABEL=""
EXPECTED_SCHEDULER=""
HARD_RT=0
VERBOSE=0

say()    { printf "${TB}scheduler-bench:${TN} %s\n" "$1"; }
ok()     { printf "  ${TB}[OK]${TN} %s\n" "$1"; }
warn()   { printf "  ${FARBE3}[WARN]${TN} %s\n" "$1" >&2; }
err()    { printf "  ${FARBE1}[ERR]${TN} %s\n" "$1" >&2; }

usage() {
    cat <<EOF
Usage: ./scheduler-bench.sh [options]

Run scheduler-focused benchmarks: schbench, cyclictest, hackbench,
and perf bench sched.

Options:
  --log-file FILE        Write structured log to FILE
  --summary-file FILE    Write KEY=VALUE summary to FILE
  --label NAME           Label for this run (default: hostname)
  --expected-scheduler   Verify this scheduler is active (e.g. scx_flow)
  --hard-rt             Hard real-time cyclictest mode (FIFO prio 99,
                         SMP, 200us interval, histogram 20us)
  -v, --verbose         Print detailed output
  -h, --help            Show this help

Exit codes:
  0  All benchmarks completed successfully
  1  Command-line error
  2  Missing dependencies
  3  Scheduler mismatch
  8  Benchmark execution failure

Examples:
  sudo ./scheduler-bench.sh --hard-rt
  sudo ./scheduler-bench.sh --expected-scheduler scx_flow
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --log-file) LOG_FILE="$2"; shift 2 ;;
        --summary-file) SUMMARY_FILE="$2"; shift 2 ;;
        --label) LABEL="$2"; shift 2 ;;
        --expected-scheduler) EXPECTED_SCHEDULER="$2"; shift 2 ;;
        --hard-rt) HARD_RT=1; shift ;;
        -v|--verbose) VERBOSE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) err "Unknown option: $1"; usage >&2; exit 1 ;;
    esac
done

if [[ -z "$LABEL" ]]; then
    LABEL="${USER:-unknown}@${HOSTNAME:-unknown}"
fi

check_scheduler() {
    if [[ -n "$EXPECTED_SCHEDULER" ]]; then
        local actual=""
        if [[ -f "/sys/kernel/sched_ext/root/ops" ]]; then
            actual=$(cat "/sys/kernel/sched_ext/root/ops" 2>/dev/null || true)
        fi
        if [[ "$EXPECTED_SCHEDULER" == "none" || "$EXPECTED_SCHEDULER" == "baseline" ]]; then
            if [[ -n "$actual" ]]; then
                err "Expected no sched-ext scheduler, but found: $actual"
                exit 3
            fi
        else
            if [[ -z "$actual" ]] || [[ "$actual" != *"$EXPECTED_SCHEDULER"* ]]; then
                err "Expected scheduler '$EXPECTED_SCHEDULER' but found: ${actual:-none}"
                exit 3
            fi
        fi
        ok "Scheduler match: ${EXPECTED_SCHEDULER}"
    fi
}

check_tool() {
    command -v "$1" >/dev/null 2>&1 || { warn "Missing: $1 (skipping related benchmarks)"; return 1; }
    return 0
}

CDATE=$(date +%F-%H%M)
HOST=$(uname -n)

# ---- Benchmark functions ----

run_schbench() {
    local label="schbench"
    local rawfile="$WORKDIR/schbench_raw"
    say "Running schbench (30s measurement)..."
    schbench -m 2 -r 30 2>&1 > "$rawfile" || {
        err "schbench failed"
        return 1
    }

    local p99 max rps
    p99=$(grep -oP '99\.0th:\s*\K\d+' "$rawfile" | head -1)
    max=$(grep -oP 'max=\K\d+' "$rawfile" | head -1)
    rps=$(grep -oP 'average rps: \K[\d.]+' "$rawfile" | head -1)

    SCHBENCH_P99="${p99:-0}"
    SCHBENCH_MAX="${max:-0}"
    SCHBENCH_RPS="${rps:-0}"

    ok "schbench p99 latency: ${SCHBENCH_P99} us"
    ok "schbench max latency:  ${SCHBENCH_MAX} us"
    ok "schbench avg rps:      ${SCHBENCH_RPS}"
}

run_cyclictest() {
    local label="cyclictest"
    local rawfile="$WORKDIR/cyclictest_raw"

    if [[ "$HARD_RT" -eq 1 ]]; then
        say "Running cyclictest (hard RT mode: FIFO prio 99, SMP, 200us interval)..."
        cyclictest -D 30 -S -p 99 -i 200 -h 20 -q -m 2>&1 > "$rawfile" || {
            err "cyclictest (hard RT) failed; trying non-RT fallback"
            cyclictest -D 30 -t -i 1000 -d 0 -q -m --policy=other 2>/dev/null > "$rawfile" || {
                err "cyclictest fallback also failed"
                return 1
            }
        }
    else
        say "Running cyclictest (30s, all CPUs)..."
        cyclictest -D 30 -t -i 1000 -d 0 -q -m --policy=other 2>/dev/null > "$rawfile" || {
            err "cyclictest failed"
            return 1
        }
    fi

    # Parse max latency across all threads
    local max_latency total_samples spikes
    max_latency=$(grep '^T:' "$rawfile" | sed 's/.*Max:[[:space:]]*//' | sort -n | tail -1)
    total_samples=$(grep '^T:' "$rawfile" | sed 's/.*C:[[:space:]]*//' | awk '{s+=$1} END {print s}')
    spikes=$(grep '^T:' "$rawfile" | sed 's/.*Max:[[:space:]]*//' | awk -v threshold=100 '$1 > threshold' | wc -l)

    CYCLICTEST_MAX="${max_latency:-0}"
    CYCLICTEST_TOTAL_SAMPLES="${total_samples:-0}"
    CYCLICTEST_SPIKES_OVER_100US="${spikes:-0}"

    # In hard RT mode, also capture overflows (>20us)
    if [[ "$HARD_RT" -eq 1 ]]; then
        local over_20us=0
        if grep -q 'Histogram' "$rawfile" 2>/dev/null; then
            over_20us=$(grep -oP '# Overflows: \K\d+' "$rawfile" | head -1 || echo "0")
        else
            over_20us=$(grep '^T:' "$rawfile" | grep -oP 'Max:[[:space:]]*\K\d+' | awk '$1 > 20' | wc -l)
        fi
        CYCLICTEST_OVER_20US="${over_20us:-0}"
    else
        CYCLICTEST_OVER_20US=""
    fi

    ok "cyclictest max latency: ${CYCLICTEST_MAX} us"
    ok "cyclictest total samples: ${CYCLICTEST_TOTAL_SAMPLES}"
    ok "cyclictest spikes >100us: ${CYCLICTEST_SPIKES_OVER_100US}"
    [[ -n "${CYCLICTEST_OVER_20US:-}" ]] && ok "cyclictest overflows >20us: ${CYCLICTEST_OVER_20US}"
}

run_hackbench() {
    check_tool hackbench || return 0

    local rawfile="$WORKDIR/hackbench_raw"
    say "Running hackbench..."
    hackbench -l 100000 -s 100 2>&1 > "$rawfile" || {
        warn "hackbench failed; skipping"
        return 0
    }

    # Parse "Time: X.XXX" from output
    local time_val
    time_val=$(grep -oP 'Time: \K[\d.]+' "$rawfile" | head -1)
    HACKBENCH_MEAN="${time_val:-0}"
    ok "hackbench mean time: ${HACKBENCH_MEAN} s"
}

run_perf_sched() {
    check_tool perf || return 0

    local rawfile="$WORKDIR/perf_sched_raw"
    say "Running perf bench sched messaging..."
    perf bench -f simple sched messaging -t -g 24 -l 6000 2>&1 > "$rawfile" || {
        warn "perf bench sched failed; skipping"
        return 0
    }

    local time_val
    time_val=$(grep -oP 'Total time: \K[\d.]+' "$rawfile" | head -1)
    PERF_SCHED_TIME="${time_val:-0}"
    ok "perf sched total time: ${PERF_SCHED_TIME} s"
}

run_stressng() {
    check_tool stress-ng || return 0

    local rawfile="$WORKDIR/stressng_raw"
    local cpus
    cpus=$(nproc)
    say "Running stress-ng (cpu+cache, ${cpus} workers, 15s)..."
    stress-ng -q --cpu "$cpus" --cache "$cpus" --timeout 15s \
        --metrics-brief 2>&1 > "$rawfile" || {
        warn "stress-ng failed; skipping"
        return 0
    }

    local bogo
    bogo=$(grep -oP 'total:\s+\K[\d.]+(?=\s+bogo)' "$rawfile" | awk '{s+=$1} END {print s}')
    STRESSNG_BOGO="${bogo:-0}"
    ok "stress-ng bogo ops/s: ${STRESSNG_BOGO}"
}

# ---- Write outputs ----

write_logfile() {
    if [[ -z "$LOG_FILE" ]]; then
        LOG_FILE="$WORKDIR/scheduler-bench_${LABEL}_${CDATE}.log"
    fi

    {
        echo "Kernel: $(uname -r)"
        echo "Sched-Ext: $(cat /sys/kernel/sched_ext/root/ops 2>/dev/null || echo 'none')"
        echo "Label: ${LABEL}"
        echo "Date: ${CDATE}"
        echo "Hard RT: ${HARD_RT}"
        echo ""
        echo "schbench p99 latency (us): ${SCHBENCH_P99}"
        echo "schbench max latency (us): ${SCHBENCH_MAX}"
        echo "schbench avg rps: ${SCHBENCH_RPS}"
        echo ""
        echo "cyclictest max latency (us): ${CYCLICTEST_MAX}"
        echo "cyclictest total samples: ${CYCLICTEST_TOTAL_SAMPLES}"
        echo "cyclictest spikes >100us: ${CYCLICTEST_SPIKES_OVER_100US}"
        if [[ -n "${CYCLICTEST_OVER_20US:-}" ]]; then
            echo "cyclictest overflows >20us: ${CYCLICTEST_OVER_20US}"
        fi
        echo ""
        if [[ -n "${HACKBENCH_MEAN:-}" ]]; then
            echo "hackbench mean (s): ${HACKBENCH_MEAN}"
        fi
        if [[ -n "${PERF_SCHED_TIME:-}" ]]; then
            echo "perf sched total time (s): ${PERF_SCHED_TIME}"
        fi
        if [[ -n "${STRESSNG_BOGO:-}" ]]; then
            echo "stress-ng bogo ops/s: ${STRESSNG_BOGO}"
        fi
        echo ""
        echo "Host: ${HOST}"
        echo "CPUs: $(nproc)"
    } > "$LOG_FILE"

    ok "Log written: $LOG_FILE"
}

write_summary() {
    if [[ -z "$SUMMARY_FILE" ]]; then
        return
    fi

    {
        echo "BENCHMARK_LABEL=${LABEL}"
        echo "EXPECTED_SCHEDULER=${EXPECTED_SCHEDULER:-none}"
        echo "KERNEL_RELEASE=$(uname -r)"
        echo "SCHED_EXT_STATE=$(cat /sys/kernel/sched_ext/state 2>/dev/null || echo 'unknown')"
        echo "CURRENT_SCHEDULER=$(cat /sys/kernel/sched_ext/root/ops 2>/dev/null || echo 'none')"
        echo ""
        echo "SCHBENCH_WAKEUP_P99=${SCHBENCH_P99}"
        echo "SCHBENCH_WAKEUP_MAX=${SCHBENCH_MAX}"
        echo "SCHBENCH_RPS=${SCHBENCH_RPS}"
        echo ""
        echo "LATENCY_MAX_US=${CYCLICTEST_MAX}"
        echo "LATENCY_TOTAL_SAMPLES=${CYCLICTEST_TOTAL_SAMPLES}"
        echo "LATENCY_SPIKES_OVER_100US=${CYCLICTEST_SPIKES_OVER_100US}"
        if [[ -n "${CYCLICTEST_OVER_20US:-}" ]]; then
            echo "LATENCY_OVER_20US=${CYCLICTEST_OVER_20US}"
        fi
        echo "LATENCY_HARD_RT=${HARD_RT}"
        echo ""
        if [[ -n "${HACKBENCH_MEAN:-}" ]]; then
            echo "HACKBENCH_MEAN_SECONDS=${HACKBENCH_MEAN}"
        fi
        if [[ -n "${PERF_SCHED_TIME:-}" ]]; then
            echo "PERF_SCHED_TOTAL_SECONDS=${PERF_SCHED_TIME}"
        fi
        if [[ -n "${STRESSNG_BOGO:-}" ]]; then
            echo "STRESSNG_BOGO_OPS_PER_SEC=${STRESSNG_BOGO}"
        fi
        echo ""
        echo "LOG_PATH=${LOG_FILE}"
        echo "DATE=${CDATE}"
        echo "HOST=${HOST}"
        echo "CPUS=$(nproc)"
    } > "$SUMMARY_FILE"

    ok "Summary written: $SUMMARY_FILE"
}

# ---- Main ----

WORKDIR=$(mktemp -d "/tmp/scheduler-bench.XXXXXX")
trap 'rm -rf "$WORKDIR"' EXIT

say "scheduler-bench ${VERSION}"
say "Label: ${LABEL}"
say ""

check_scheduler

# Initialize all outputs
SCHBENCH_P99=0
SCHBENCH_MAX=0
SCHBENCH_RPS=0
CYCLICTEST_MAX=0
CYCLICTEST_TOTAL_SAMPLES=0
CYCLICTEST_SPIKES_OVER_100US=0
CYCLICTEST_OVER_20US=""
HACKBENCH_MEAN=""
PERF_SCHED_TIME=""
STRESSNG_BOGO=""

run_schbench
echo ""
run_cyclictest
echo ""
run_hackbench
echo ""
run_perf_sched
echo ""
run_stressng
echo ""

write_logfile
write_summary

say "All benchmarks completed."
exit 0
