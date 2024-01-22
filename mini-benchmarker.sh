#!/bin/bash
# mini-benchmarker
# by torvic9
# contributors and testers:
# Richard Gladman, William Pursell, SGS, mbb, mbod, Manjaro Forum, StackOverflow
# and everyone else I forgot
#
# In Memoriam Jonathon Fernyhough

TNAMES=('stress-ng cpu-cache-mem' 'ffmpeg compilation' 'zstd compression'
	'x265 encoding' 'argon2 hashing' 'perf sched msg fork thread'
	'perf sched msg pipe proc' 'perf memcpy' 'calculating prime numbers'
	'c-ray render' 'namd 92K atoms' 'blender render'
	'xz compression' 'kernel defconfig' 'y-cruncher pi 500m')

# tests definitions for mini run

runstress() {
	local RESFILE="$WORKDIR/runstress"
	/usr/bin/time -f %e -o $RESFILE $STRESS -q --job $WORKDIR/stressC &>/dev/null &
	local PID=$!
	echo -n -e "* ${TNAMES[0]}:\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat $RESFILE
	echo "${TNAMES[0]}: $(cat $RESFILE)" >> $LOGFILE
	return 0
}

runffm() {
	cd $WORKDIR/ffmpeg-6.1
	local RESFILE="$WORKDIR/runffm"
	/usr/bin/time -f %e -o $RESFILE make -s -j${CPUCORES} &>/dev/null &
	local PID=$!
	echo -n -e "* ${TNAMES[1]}:\t\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat $RESFILE
	echo "${TNAMES[1]}: $(cat $RESFILE)" >> $LOGFILE
	return 0
}

runzstd() {
	local RESFILE="$WORKDIR/runzstd"
 	/usr/bin/time -f %e -o $RESFILE zstd -z -k -T${CPUCORES} -16 -q -f $WORKDIR/firefox91.tar &
	local PID=$!
	echo -n -e "* ${TNAMES[2]}:\t\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat $RESFILE
	echo "${TNAMES[2]}: $(cat $RESFILE)" >> $LOGFILE
	return 0
}

runx265() {
	local RESFILE="$WORKDIR/runx265"
	/usr/bin/time -f %e -o $RESFILE x265 -p medium -b 5 -m 5 --pme -o /dev/null --no-progress \
	  --log-level none $WORKDIR/bosphorus_hd.y4m &
	local PID=$!
	echo -n -e "* ${TNAMES[3]}:\t\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat $RESFILE
	echo "${TNAMES[3]}: $(cat $RESFILE)" >> $LOGFILE
	return 0
}

runargon() {
	local RESFILE="$WORKDIR/runargon"
	/usr/bin/time -f %e -o $RESFILE argon2 BenchieSalt -id -t 16 -m 21 \
	  -p $CPUCORES &>/dev/null <<< $(dd if=/dev/urandom bs=64 count=1 status=none) &
	local PID=$!
	echo -n -e "* ${TNAMES[4]}:\t\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat $RESFILE
	echo "${TNAMES[4]}: $(cat $RESFILE)" >> $LOGFILE
	return 0
}

runperf_sch1() {
	local RESFILE="$WORKDIR/runperf"
	perf bench -f simple sched messaging -t -g 24 -l 4000 1> $RESFILE &
	local PID=$!
	echo -n -e "* ${TNAMES[5]}:\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat $RESFILE
	echo "${TNAMES[5]}: $(cat $RESFILE)" >> $LOGFILE
	return 0
}

runperf_sch2() {
	local RESFILE="$WORKDIR/runperf"
	perf bench -f simple sched messaging -p -g 24 -l 4000 1> $RESFILE &
	local PID=$!
	echo -n -e "* ${TNAMES[6]}:\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat $RESFILE
	echo "${TNAMES[6]}: $(cat $RESFILE)" >> $LOGFILE
	return 0
}

runperf_mem() {
	local RESFILE="$WORKDIR/runperf"
	/usr/bin/time -f %e -o $RESFILE perf bench -f simple mem memcpy --nr_loops 100 \
	  --size 2GB -f default &>/dev/null &
	local PID=$!
	echo -n -e "* ${TNAMES[7]}:\t\t\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat $RESFILE
	echo "${TNAMES[7]}: $(cat $RESFILE)" >> $LOGFILE
	return 0
}

runprime() {
	local RESFILE="$WORKDIR/runprime"
	/usr/bin/time -f%e -o $RESFILE primesieve 500000000000 --no-status | awk -F ': ' '/Seconds/{print $2}' 1> $RESFILE &
	local PID=$!
	echo -n -e "* ${TNAMES[8]}:\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat $RESFILE
	echo "${TNAMES[8]}: $(cat $RESFILE)" >> $LOGFILE
	return 0
}

runcray() {
	local RESFILE="$WORKDIR/runcray"
	/usr/bin/time -f%e -o $RESFILE $WORKDIR/c-ray-1.1/c-ray-mt -t $(( $CPUCORES * 16 )) \
	  -s 3200x1800 -r 8 -i $WORKDIR/c-ray-1.1/sphfract -o $WORKDIR/output.ppm 2>/dev/null &
	local PID=$!
	echo -n -e "* ${TNAMES[9]}:\t\t\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat $RESFILE
	echo "${TNAMES[9]}: $(cat $RESFILE)" >> $LOGFILE
	return 0
}

runnamd() {
	cd $WORKDIR/namd/NAMD_2.14_Linux-x86_64-multicore
	local RESFILE="$WORKDIR/runnamd"
	rm -f ../apoa1/FFTW*.txt
	/usr/bin/time -f%e -o $RESFILE ./namd2 +p${CPUCORES} +setcpuaffinity ../apoa1/apoa1.namd &>/dev/null &
	local PID=$!
	echo -n -e "* ${TNAMES[10]}:\t\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat $RESFILE
	echo "${TNAMES[10]}: $(cat $RESFILE)" >> $LOGFILE
	return 0
}

# test definitions for nano run

runblend() {
	local RESFILE="$WORKDIR/runblend"
	local BLENDER_USER_CONFIG="$WORKDIR"
	/usr/bin/time -f %e -o "$RESFILE" blender -b "$WORKDIR/blender/bmw27_cpu.blend" \
		-o "$WORKDIR/blenderbmw.png" -f 1 --verbose 0 -t 0 &>/dev/null &
	local PID=$!
	echo -n -e "* ${TNAMES[11]}:\t\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat "$RESFILE"
	echo "${TNAMES[11]}: $(cat "$RESFILE")" >> "$LOGFILE"
	return 0
}

runxz() {
	local RESFILE="$WORKDIR/runxz"
 	/usr/bin/time -f %e -o "$RESFILE" xz -z -k -T${CPUCORES} -Qqq -f "$WORKDIR/firefox78.tar" &
	local PID=$!
	echo -n -e "* ${TNAMES[12]}:\t\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat "$RESFILE"
	echo "${TNAMES[12]}: $(cat "$RESFILE")" >> "$LOGFILE"
	return 0
}

runkern() {
	cd "$WORKDIR/linux-$KERNVER" || exit 4
	local RESFILE="$WORKDIR/runkern"
	/usr/bin/time -f %e -o "$RESFILE" make -sj$CPUCORES vmlinux &>/dev/null &
	local PID=$!
	echo -n -e "* ${TNAMES[13]}:\t\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat "$RESFILE"
	echo "${TNAMES[13]}: $(cat "$RESFILE")" >> "$LOGFILE"
	return 0
}

runyc() {
	cd "$WORKDIR/y-cruncher v0.8.3.9532-static" || exit 4
	local RESFILE="$WORKDIR/runyc"
	/usr/bin/time -f%e -o "$RESFILE" ./y-cruncher bench 500m -od:0 -o $WORKDIR &>/dev/null &
	local PID=$!
	echo -n -e "* ${TNAMES[14]}:\t\t\t"
	local s='-+'; local i=0
	while kill -0 $PID &>/dev/null ; do i=$(( (i+1) %2 )); printf "\b${s:$i:1}"; sleep 1; done
	printf "\b " ; cat "$RESFILE"
	echo "${TNAMES[14]}: $(cat "$RESFILE")" >> "$LOGFILE"
	return 0
}

# intro text and explanation
intro() {
    echo -e "\n${FARBE1}${TB}MINI-BENCHMARKER: This script can take more than 30m on slow computers!${TN}\n"
    echo -e "${FARBE3}${TB}Usage: ${TN}\$ mini-benchmarker.sh /path/to/workdir [--mini | --nano]${TN}\n"
    echo -e "${FARBE2}${TB}Explanation notes${TN}:\n"

    echo -e "By default or by specifying the '--mini' parameter, this script runs"
    echo -e "in ${TB}mini${TN} mode, running the following tests:\n"

    echo -e "${FARBE3}${TB}stress-ng cpu-cache-mem${TN} tests sort&search, integer and floating"
    echo -e "point arithmetics, memory and cache operations.\n"
    echo -e "The ${FARBE3}${TB}C-Ray${TN} is a simple CPU-based rendering engine.\n"
    echo -e "The ${FARBE3}${TB}perf sched${TN} benchmarks concentrate on interprocess communication"
    echo -e "and pipelining, whereas the ${FARBE3}${TB}perf mem${TN} benchmark tries to measure raw"
    echo -e "RAM throughput speed with the libc memcpy function.\n"
    echo -e "The ${FARBE3}${TB}primesieve${TN} multithreaded benchmark searches for primes within the"
    echo -e "first 5*10^11 natural numbers.\n"
    echo -e "${FARBE3}${TB}NAMD${TN} is a multi-thread molecular dynamics simulation.\n"
    echo -e "${FARBE3}${TB}argon2${TN} is a prized hashing algorithm. It uses 16 iterations with"
    echo -e "2G of memory, with a fixed salt and a random password.\n"
    echo -e "What follows are three 'real world' benchmarks, measuring ${FARBE3}${TB}compilation"
    echo -e "of ffmpeg${TN}, ${FARBE3}${TB}zstd compression${TN} level 16 on a source code tarball,"
    echo -e "and ${FARBE3}${TB}x265 encoding${TN} of a short 1080p video clip.\n"

    echo -e "By using the '--nano' parameter, it runs in ${TB}nano${TN} mode, running fewer"
    echo -e "but heavier benchmarks, measuring ${FARBE3}${TB}kernel defconfig${TN} compilation time,"
    echo -e "${FARBE3}${TB}xz compression${TN} level 6 of a large source code tarball,"
    echo -e "the famous ${FARBE3}${TB}Blender${TN} BMW rendering (CPU only), and"
    echo -e "the ${FARBE3}${TB}y-cruncher${TN} highly optimised pi calculator."
    echo -e "The ${TB}nano${TN} mode does not apply weighting.\n"

    echo -e "The ${FARBE3}${TB}score${TN} is not really relevant. It tries to compress the pure"
    echo -e "time results using geometric mean. What counts is the ${FARBE3}${TB}total time${TN}.\n"
    echo -e "You should ${FARBE3}${TB}run this script in runlevel 3${TN}. On Linux with systemd,"
    echo -e "either append a '3' to the boot command line, or issue"
    echo -e "'systemctl isolate multi-user.target'.\n"
}

# traps (ctrl-c)
killproc() {
	echo -e "\n**** Received SIGINT, aborting! ****\n"
	kill -- -$$ && exit 2
}

exitproc() {
	echo -e "\n-> Removing temporary files..."
	for i in $WORKDIR/{"run*",stressC,"*.txt",firefox78.tar.xz,"*.zst","*.7z","*.png","*.ppm"}
		do rm -f $i
	done
	rm $(echo $LOCKFILE) && echo -e "${TB}Bye!${TN}\n"
}

# vars
export LANG=C
CURRDIR=$(pwd)
TMP="/tmp"
VER="v2.0"
CDATE=$(date +%F-%H%M)
RAMSIZE=$(awk '/MemTotal/{print int($2 / 1000)}' /proc/meminfo)
CPUCORES=$(nproc)
CPUGOV=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor)
CPUFREQ=$(awk '{print $1 / 1000000}' /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq)
COEFF="$(python -c "print(round((($CPUCORES+1)/2 + $CPUFREQ) ** (1/3),4))")"
KERNVER="6.1.65"
STRESSVER="0.17.04"
# system info will be logged
SYSINFO=$(inxi -CmSz -c0 -y-1 | sed -e "s/RAM Report:.*//;/^\s*$/d")
# allow more open files, needed by perf bench msg
ulimit -n 4096
# check system memory
[[ $RAMSIZE -lt 3500 ]] && echo "Your computer must have at least 4 GB of RAM! Aborting." && exit 2

# I leave this for reference
#CPUFREQ=$(cpupower frequency-info -l | grep -v "analyzing" | awk '{print $2 / 1000000}')
#CPUGOV=$(cpupower frequency-info -o | grep -m1 "^CPU" | awk -F' -  ' '{ print $3 }')
#CPUMHZ=$(lscpu -e=maxmhz | tail -n1)
#CPUGHZ=$(echo "scale=1; ${CPUMHZ%%,*} / 1000" | bc)
#CPUL3C=$(lscpu -C=name,all-size | awk '/L3/{print $2}')

# terminal effects
TB=$(tput bold)
TN=$(tput sgr0)
FARBE1="`printf '\033[0;91m'`"
FARBE2="`printf '\033[4;37m'`"
FARBE3="`printf '\033[0;33m'`"

# when called without parameters, print help text and exit
[[ $# == 0 ]] && intro && exit 0
WORKDIR="$1"

[[ "${WORKDIR:0:1}" != "/" ]] && WORKDIR="$PWD/$WORKDIR"
if [[ ! -d "$WORKDIR" ]] ; then
	read -p "The specified directory ${TB}$WORKDIR${TN} does not exist. Create it (y/N)? " DCHOICE
	[[ $DCHOICE = "y" || $DCHOICE = "Y" ]] && mkdir -p $WORKDIR || exit 4
fi

[[ -z $2 ]] && CMDOPT="--mini" || CMDOPT="$2"

# check files function
checkfiles() {
	echo -e "\n${TB}Checking, downloading and preparing test files...${TN}"

	# stress-ng jobfile
	cat > $WORKDIR/stressC <<- EOF
	run sequential 0
	no-rand-seed
	temp-path /tmp
	timeout 0
	matrix CPUCORES
	matrix-method prod
	matrix-size 256
	EOF
	echo "matrix-ops $((2400 / ${CPUCORES}))" >> $WORKDIR/stressC
	cat >> $WORKDIR/stressC <<- EOF
	sparsematrix CPUCORES
	sparsematrix-method hash
	sparsematrix-items 12000
	EOF
	echo "sparsematrix-ops $((2400 / ${CPUCORES}))" >> $WORKDIR/stressC
	cat >> $WORKDIR/stressC <<- EOF
	shm CPUCORES
	shm-bytes 16m
	EOF
	echo "shm-ops $((2400 / ${CPUCORES}))" >> $WORKDIR/stressC
	cat >> $WORKDIR/stressC <<- EOF
	fork CPUCORES
	fork-max 8
	EOF
	echo "fork-ops $((24000 / ${CPUCORES}))" >> $WORKDIR/stressC
	cat >> $WORKDIR/stressC <<- EOF
	cpu CPUCORES
	cpu-method cdouble
	EOF
	echo "cpu-ops $((4800 / ${CPUCORES}))" >> $WORKDIR/stressC
	cat >> $WORKDIR/stressC <<- EOF
	bsearch CPUCORES
	EOF
	echo "bsearch-ops $((2400 / ${CPUCORES}))" >> $WORKDIR/stressC
	cat >> $WORKDIR/stressC <<-EOF
	stream CPUCORES
	EOF
	echo "stream-ops $((4800 / ${CPUCORES}))" >> $WORKDIR/stressC
	cat >> $WORKDIR/stressC <<- EOF
	list CPUCORES
	EOF
	echo "list-ops $((2400 / ${CPUCORES}))" >> $WORKDIR/stressC
	cat >> $WORKDIR/stressC <<- EOF
	qsort CPUCORES
	qsort-size 65536
	EOF
	echo "qsort-ops $((2400 / ${CPUCORES}))" >> $WORKDIR/stressC
	cat >> $WORKDIR/stressC <<- EOF
	memfd CPUCORES
	memfd-bytes 64m
	memfd-fds 128
	EOF
	echo "memfd-ops $((2400 / ${CPUCORES}))" >> $WORKDIR/stressC

	sed -i "s/CPUCORES/$CPUCORES/g" $WORKDIR/stressC

	if [[ ! -x $WORKDIR/c-ray-1.1/c-ray-mt ]] ; then
		wget --show-progress -N -qO $WORKDIR/c-ray.tar.gz \
		  https://www.phoronix-test-suite.com/benchmark-files/c-ray-1.1.tar.gz
		echo "--> Compiling C-Ray..."
		cd $WORKDIR
		tar xf c-ray.tar.gz
		cd c-ray-1.1
		make -s clean
		gcc -O3 -march=native -ffast-math -lm -lpthread -o c-ray-mt c-ray-mt.c
	fi

	if [[ ! -f $WORKDIR/bosphorus_hd.y4m ]] ; then
		wget --show-progress -N -qO $WORKDIR/bosphorus_hd.7z \
		  http://ultravideo.cs.tut.fi/video/Bosphorus_1920x1080_120fps_420_8bit_YUV_Y4M.7z
		echo "--> Unzipping video..."
		cd $WORKDIR
		7z e bosphorus_hd.7z -o./ &>/dev/null
		mv Bosphorus_1920x1080_120fps_420_8bit_YUV.y4m bosphorus_hd.y4m
	fi

	# first, check for installed stress-ng binary
	if [[ -x $(which stress-ng) ]] ; then
		STRESS=$(which stress-ng)
	else
		if [[ ! -d $WORKDIR/stress-ng ]]; then
			wget --show-progress -N -qO $WORKDIR/stress-ng.tar.gz \
			  https://github.com/ColinIanKing/stress-ng/archive/refs/tags/V$STRESSVER.tar.gz
			echo "--> Preparing stress-ng..."
			cd $WORKDIR
			tar xf stress-ng.tar.gz
			cd stress-ng-$STRESSVER
			make -s -j${CPUCORES} &>/dev/null
			make -s DESTDIR=$WORKDIR/stress-ng install &>/dev/null
			rm -rf ../stress-ng-$STRESSVER
		fi
		STRESS=${WORKDIR}/stress-ng/usr/bin/stress-ng
	fi

	if [[ ! -d $WORKDIR/ffmpeg-6.1 ]]; then
		wget --show-progress -N -qO $WORKDIR/ffmpeg.tar.xz \
		  https://ffmpeg.org/releases/ffmpeg-6.1.tar.xz
		echo "--> Preparing ffmpeg..."
		cd $WORKDIR
		tar xf ffmpeg.tar.xz
	fi

	if [[ ! -d $WORKDIR/namd ]]; then
		wget --show-progress -N -qO $WORKDIR/namd.tar.gz \
		  http://www.ks.uiuc.edu/Research/namd/2.14/download/946183/NAMD_2.14_Linux-x86_64-multicore.tar.gz
		wget --show-progress -N -qO $WORKDIR/namd-example.tar.gz \
		  https://www.ks.uiuc.edu/Research/namd/utilities/apoa1.tar.gz
		echo "--> Preparing NAMD..."
		cd $WORKDIR
		mkdir namd
		tar -C namd -xf namd.tar.gz
		tar -C namd -xf namd-example.tar.gz
		sed -i 's/\/usr//;s/500/300/' namd/apoa1/apoa1.namd
	fi

	if [[ ! -d "$WORKDIR/blender" ]]; then
		wget --show-progress -N -qO "$WORKDIR/blender.zip" \
		  https://download.blender.org/demo/test/BMW27_2.blend.zip
		echo "--> Unzipping Blender demo file..."
		unzip -qqj "$WORKDIR/blender.zip" -d "$WORKDIR/blender"
	fi

	if [[ ! -f $WORKDIR/firefox91.tar ]]; then
		wget --show-progress -N -qO $WORKDIR/firefox91.tar.xz \
		  http://ftp.mozilla.org/pub/firefox/releases/91.13.0esr/source/firefox-91.13.0esr.source.tar.xz
		echo "--> Unzipping Firefox tarball..."
		xz -d -q $WORKDIR/firefox91.tar.xz
	fi

	if [[ ! -d "$WORKDIR/linux-$KERNVER" ]]; then
		wget --show-progress -N -qO "$WORKDIR/linux-$KERNVER.tar.xz" \
		  https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNVER.tar.xz
		echo "--> Uncompressing kernel source..."
		cd "$WORKDIR"
		tar -xf linux-$KERNVER.tar.xz
	fi

	if [[ ! -d "$WORKDIR/y-cruncher v0.8.3.9532-static" ]]; then
		wget --show-progress -N -qO "$WORKDIR/y-cruncher.tar.xz" \
		  http://numberworld.org/y-cruncher/"y-cruncher%20v0.8.3.9532-static.tar.xz"
		echo "--> Uncompressing y-cruncher..."
		cd "$WORKDIR"
		tar -xf y-cruncher.tar.xz
	fi

	# prepare kernel in nano mode
	if [[ "$CMDOPT" == "--nano" ]] ; then
		echo -e "\n${TB}Preparing kernel source...${TN}"
		cd "$WORKDIR/linux-$KERNVER" || exit 4
		make -s mrproper && make -s defconfig
	fi

	# prepare ffmpeg in mini mode
	if [[ "$CMDOPT" != "--nano" ]] ; then
		echo -e "\n${TB}Preparing ffmpeg source...${TN}"
		cd "$WORKDIR/ffmpeg-6.1" || exit 4
		make -s distclean &>/dev/null
		./configure --prefix=$TMP --disable-debug --enable-static \
		    --enable-gpl --enable-version3 --disable-ffplay --disable-ffprobe \
		    --disable-doc --disable-network --disable-protocols \
		    --enable-zlib --enable-libdrm --enable-alsa \
		    --disable-stripping --disable-autodetect --cpu=native &>/dev/null
	fi
}

checksys() {
	# ask user for dropping page cache
	echo -e "\n"
	read -p "Do you want to drop page cache now? Root priviledges needed! (y/N) " DCHOICE
	[[ $DCHOICE = "y" || $DCHOICE = "Y" ]] && su -c "echo 1 > /proc/sys/vm/drop_caches"

	# ask user for permission to choose performance gov
	if [[ $CPUGOV != "performance" ]] ; then
		read -p "You should use the ${TB}performance${TN} cpufreq governor, enable now? (y/N) " DCHOICE
		[[ $DCHOICE = "y" || $DCHOICE = "Y" ]] && su -c "cpupower frequency-set -g performance &>/dev/null"
	fi

	# traps (ctrl-c)
	trap killproc INT
	trap exitproc EXIT
}

logging() {
	# results will be written to this file
	LOGFILE="$WORKDIR/benchie_${CDATE}.log"
	# lockfile has no real purpose here but it's cool
	LOCKFILE=$(mktemp $WORKDIR/benchie.XXXX)
}

# print header
header() {
	echo -e "\n${TB}Starting in ${CMDOPT/--/} mode...${TN}\n" ; sync ; sleep 2

	echo -e "__________________________________________________"
	echo -e "=====${TB}__${TN}==${TB}__${TN} ===========================${TB}_____${TN} ====="
	echo -e "====${TB}|  \/  |${TN}==== MINI BENCHMARKER ====${TB}| ___ ))${TN}===="
	echo -e "====${TB}| |\/| |${TN}======= by torvic9 =======${TB}| ___ \\${TN}====="
	echo -e "====${TB}|_|${TN}==${TB}|_|${TN}=========  $VER  =========${TB}|_____//${TN}===="
	echo -e "==================================================\n"
}

# run
case $CMDOPT in
	'--mini')
	    NRTESTS=11
	    declare -a WEIGHTS=(0.9 0.8 0.9 0.95 0.85 0.9 0.85 0.8 1 1 1)
	    checkfiles ; checksys ; logging ; header
	    runstress ; sleep 2
	    runcray ; sleep 2
	    runperf_sch1 ; sleep 2
	    runperf_sch2 ; sleep 2
	    runperf_mem ; sleep 2
	    runnamd ; sleep 2
	    runprime ; sleep 2
	    runargon ; sleep 2
	    runffm ; sleep 2
	    runzstd ; sleep 2
	    runx265 ; sleep 2 ;;
	'--nano')
	    NRTESTS=4 ;
	    declare -a WEIGHTS=(1 1 1 1)
	    checkfiles ; checksys ; logging ; header
	    runyc ; sleep 2
	    runkern ; sleep 2
	    runxz ; sleep 2
	    runblend ; sleep 2 ;;
	*)
	    intro && exit 0 ;;
esac

# time and score calculations, print and log final results
unset ARRAYTIME ; unset ARRAY
ARRAYTIME=($(awk -F': ' '{print $2}' $LOGFILE))

# using geometric mean for now
for ((i=0; i<${NRTESTS}; i++)) ; do
	ARRAY[$i]="$(python -c "print(round(( ${ARRAYTIME[$i]} * $COEFF * ${WEIGHTS[$i]}),4))")"
done

TOTTIME="$(IFS="+" ; python -c "print(round((${ARRAYTIME[*]}),2))")"
INTSCORE="$(IFS="*" ; python -c "print(round((${ARRAY[*]}),4))")"
SCORE="$(python -c "print(round(($INTSCORE ** (1 / $NRTESTS)),2))")"

echo "--------------------------------------------------"
echo "Total time in seconds:"
echo "--------------------------------------------------"
echo "  ${TB}$TOTTIME${TN}" ; echo -e "\nTotal time (s): $TOTTIME" >> $LOGFILE
echo "--------------------------------------------------"
echo -n "Total score, lower is better" ; echo " [multi = $COEFF]:"
echo "--------------------------------------------------"
echo "  ${TB}$SCORE${TN}" ; echo "Total score: $SCORE" >> $LOGFILE
echo "=================================================="
echo -e "\nMode: ${CMDOPT/--/}" >> $LOGFILE
echo -e "\nDate: ${CDATE}" >> $LOGFILE
echo -e "\n$SYSINFO" >> $LOGFILE

exit 0

