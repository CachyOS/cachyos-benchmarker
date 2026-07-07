#!/bin/bash
# y-cruncher-only — standalone y-cruncher pi 1b benchmark
#
# Extracted from cachyos-benchmarker for isolated y-cruncher testing.
# Useful for demonstrating the Infinity Scheduler's effect on pure
# compute-bound synthetic workloads.

set -euo pipefail

VERSION="v1.0"
CDATE=$(date +%F-%H%M)
CPUCORES=$(nproc)

# Terminal effects
TB=$(tput bold)
TN=$(tput sgr0)
FARBE1=$(printf '\033[0;91m')
FARBE2=$(printf '\033[4;37m')
FARBE3=$(printf '\033[0;33m')

YCRUNCHER_VER="0.8.6.9545"
WORKDIR=""
CLEANUP=false

say()    { printf "${FARBE3}${TB}y-cruncher:${TN} %s\n" "$1"; }
ok()     { printf "  ${TB}[OK]${TN} %s\n" "$1"; }
err()    { printf "  ${FARBE1}${TB}[ERR]${TN} %s\n" "$1" >&2; }

usage() {
    cat <<EOF
Usage: ./y-cruncher-only.sh [options] <workdir>

Run y-cruncher pi 1b benchmark in isolation.

Options:
  -c, --cleanup   Delete downloaded archives on exit
  -h, --help      Show this help

Examples:
  ./y-cruncher-only.sh /tmp/yc-test
  ./y-cruncher-only.sh --cleanup /tmp/yc-test
EOF
}

ensure_archive() {
    local file="$1"
    local description="$2"
    local url="$3"
    shift 3

    if [[ -f "$file" ]] && ! "$@" "$file" &>/dev/null; then
        echo "--> Cached ${description} archive is invalid, re-downloading..."
        rm -f "$file"
    fi

    if [[ ! -f "$file" ]]; then
        echo "--> Downloading ${description} archive..."
        wget -c --show-progress -qO "$file" "$url"
    fi
}

run_ycruncher() {
    local LOGFILE="$WORKDIR/y-cruncher_${CDATE}.log"

    say "Running y-cruncher pi 1b..."

    cd "$WORKDIR/y-cruncher v$YCRUNCHER_VER-static" || exit 4
    rm -f "Pi*.txt"

    local RESFILE="$WORKDIR/runyc"
    /usr/bin/time -f%e -o "$RESFILE" ./y-cruncher bench 1b -od:0 \
      -o "$WORKDIR" &>/dev/null &
    local PID=$!

    # Animate spinner while waiting
    local s='-+'
    local i=0
    while kill -0 "$PID" &>/dev/null; do
        i=$(( (i+1) % 2 ))
        printf "\b${s:$i:1}"
        sleep 1
    done

    local result
    result=$(cat "$RESFILE")
    printf "\b "
    echo "$result"

    {
        echo "y-cruncher pi 1b: $result"
        echo "Date: ${CDATE}"
        echo "CPUs: ${CPUCORES}"
    } > "$LOGFILE"

    ok "Result written to $LOGFILE"
    ok "y-cruncher pi 1b completed in ${result} seconds"
}

# ── Argument parsing ──

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--cleanup) CLEANUP=true; shift ;;
        -h|--help) usage; exit 0 ;;
        -*)
            err "Unknown option: $1"
            usage >&2
            exit 1
            ;;
        *)
            if [[ -z "$WORKDIR" ]]; then
                WORKDIR="$1"
            else
                err "Too many arguments"
                usage >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$WORKDIR" ]]; then
    usage
    exit 1
fi

[[ "${WORKDIR:0:1}" != "/" ]] && WORKDIR="$PWD/$WORKDIR"
if [[ ! -d "$WORKDIR" ]]; then
    read -p "Directory $WORKDIR does not exist. Create it (y/N)? " DCHOICE
    [[ "$DCHOICE" == "y" || "$DCHOICE" == "Y" ]] && mkdir -p "$WORKDIR" || exit 4
fi

# ── Setup cleanup trap ──
cleanup() {
    echo -e "\n-> Removing temporary files..."
    rm -f "$WORKDIR/runyc" "$WORKDIR"/Pi*.txt
    if [[ "$CLEANUP" == "true" ]]; then
        echo "-> Cleaning up downloaded archives..."
        rm -f "$WORKDIR/y-cruncher.tar.xz"
        rm -rf "$WORKDIR/y-cruncher v$YCRUNCHER_VER-static"
    fi
    echo -e "${TB}Done${TN}\n"
}
trap cleanup EXIT

# ── Download y-cruncher ──
say "Preparing y-cruncher..."
mkdir -p "$WORKDIR"
if [[ ! -d "$WORKDIR/y-cruncher v$YCRUNCHER_VER-static" ]]; then
    ensure_archive "$WORKDIR/y-cruncher.tar.xz" "y-cruncher" \
      "https://github.com/Mysticial/y-cruncher/releases/download/v$YCRUNCHER_VER/y-cruncher.v$YCRUNCHER_VER-static.tar.xz" \
      tar -tf
    echo "--> Uncompressing y-cruncher..."
    cd "$WORKDIR"
    tar -xf y-cruncher.tar.xz
fi

# ── Run benchmark ──
echo ""
run_ycruncher
