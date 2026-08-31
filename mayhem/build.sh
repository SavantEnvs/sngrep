#!/usr/bin/env bash
#
# mayhem/build.sh — build sngrep's SIP-parsing fuzz harness + a standalone reproducer,
# plus a clean (unsanitized) build used by mayhem/test.sh's behavioral oracle (a KAT probe;
# sngrep ships no automated test suite that can run headless — see test.sh for why).
#
# sngrep has no upstream fuzz harness and is not an OSS-Fuzz project (checked via
# scripts/integration/ossfuzz-list.py --upstream https://github.com/irontec/sngrep.git
# -> NOTAPROJECT). The harness below (mayhem/fuzz_sip_check_packet.c) drives
# sip_check_packet() in src/sip.c — the exact function src/capture.c calls for every
# captured packet — via the real packet_t/packet_set_payload() API, so it exercises
# sngrep's actual SIP header + SDP parsing surface with no file I/O.
#
# sngrep has no separate library: everything (SIP/SDP parsing, RTP tracking, capture,
# ncurses UI) is one source list compiled straight into the `sngrep` binary (see
# CMakeLists.txt's target_sources()). This build compiles just the non-UI subset the
# parser needs (SIP/SDP/RTP/call state + option/setting/util/vector/hash/address/group/
# filter/keybinding), skipping curses/*.c, capture.c, capture_esp/gnutls/openssl/eep.c,
# and main.c — none of which sip_check_packet()'s call graph reaches. Two of those skipped
# files' symbols (ui_find_by_type, call_list_line_text) are still referenced (by address)
# from filter.c, so mayhem/harness_link_stubs.c supplies dead-code-only stand-ins — see
# that file's header comment for why they're safe.
#
#   /mayhem/fuzz_sip_check_packet             sanitized + libFuzzer -> Mayhem target
#   /mayhem/fuzz_sip_check_packet-standalone  sanitized, run-once   -> crash reproducer
#   /mayhem/kat_sip_probe                     clean, no sanitizer   -> test.sh's oracle
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
# SanitizerCoverage for the WHOLE parsing library, not just the harness TU — without this,
# libFuzzer/Mayhem get zero coverage feedback from sip.c/sip_call.c/media.c/rtp.c (0 edges).
# Unconditional (also applied when SANITIZER_FLAGS is empty, i.e. the no-sanitizer build).
FUZZ_COV="-fsanitize=fuzzer-no-link"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS FUZZ_COV

cd "${SRC:-/mayhem}"

# The parser's non-UI source set (see header comment above for what's excluded and why).
LIB_SRCS=(
  src/address.c src/packet.c src/sip.c src/sip_call.c src/sip_msg.c src/sip_attr.c
  src/option.c src/group.c src/filter.c src/keybinding.c src/media.c src/setting.c
  src/rtp.c src/util.c src/hash.c src/vector.c
)

# ── 0) Generate src/config.h from CMake's own template (config.h.cmake) ──
# Configure-only (no `cmake --build`): this is the project's own mechanism for turning
# `#cmakedefine WITH_GNUTLS` etc. into real C, and also proves libpcap + ncurses/panel/
# form/menu (the project's REQUIRED deps, needed because address.c calls pcap_findalldevs()
# and the harness includes the same headers as the real build) are actually resolvable.
# All optional features (GnuTLS/OpenSSL/PCRE/PCRE2/zlib/Unicode/IPv6/EEP) stay at their
# CMakeLists.txt defaults (off) — the harness never calls sip_set_match_expression() so the
# PCRE-vs-POSIX branch in sip_check_match_expression() is never reached either way.
cmake -S . -B build-cfg -G Ninja >/dev/null
CFG_INC="-Ibuild-cfg"
CURSES_INC="$(pkg-config --cflags ncurses panel form menu)"
CURSES_LIBS="$(pkg-config --libs ncurses panel form menu)"
INCS=(-Isrc "$CFG_INC" $CURSES_INC)

# ── 1) Sanitized build: the parser library + harness + standalone driver (DWARF < 4) ──
mkdir -p mayhem-build/sanitized
SAN_OBJS=()
for f in "${LIB_SRCS[@]}"; do
  o="mayhem-build/sanitized/$(basename "$f").o"
  $CC "${INCS[@]}" $SANITIZER_FLAGS $FUZZ_COV $DEBUG_FLAGS -c "$f" -o "$o"
  SAN_OBJS+=("$o")
done
$CC "${INCS[@]}" $SANITIZER_FLAGS $FUZZ_COV $DEBUG_FLAGS -c mayhem/harness_link_stubs.c -o mayhem-build/sanitized/harness_link_stubs.c.o
SAN_OBJS+=(mayhem-build/sanitized/harness_link_stubs.c.o)

# Fleet policy: disable LeakSanitizer (ASan's own memory-corruption checks + UBSan stay
# active) — compiled once, linked into both the fuzz binary and its standalone twin below
# via SAN_OBJS.
$CC $SANITIZER_FLAGS -c mayhem/lsan_off.c -o mayhem-build/sanitized/lsan_off.c.o
SAN_OBJS+=(mayhem-build/sanitized/lsan_off.c.o)

$CC "${INCS[@]}" $SANITIZER_FLAGS $FUZZ_COV $DEBUG_FLAGS -c mayhem/fuzz_sip_check_packet.c -o mayhem-build/sanitized/fuzz_sip_check_packet.c.o
$CC "${INCS[@]}" $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
  mayhem-build/sanitized/fuzz_sip_check_packet.c.o "${SAN_OBJS[@]}" \
  -o /mayhem/fuzz_sip_check_packet -lpthread -lm $CURSES_LIBS -lpcap

$CC "${INCS[@]}" $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o mayhem-build/sanitized/standalone_main.o
$CC "${INCS[@]}" $SANITIZER_FLAGS $FUZZ_COV $DEBUG_FLAGS \
  mayhem-build/sanitized/standalone_main.o mayhem-build/sanitized/fuzz_sip_check_packet.c.o "${SAN_OBJS[@]}" \
  -o /mayhem/fuzz_sip_check_packet-standalone -lpthread -lm $CURSES_LIBS -lpcap

# ── 2) Clean (unsanitized) build: same library, NORMAL flags, for the KAT probe oracle ──
# Independent object dir/build (no upstream build artifacts to collide with — sngrep's own
# CMake build writes to its own build/ dir, untouched here), so this "comes free" alongside
# step 1 with no clean/stash dance. $COVERAGE_FLAGS is empty by default (no effect); a
# coverage build passes it in to instrument this oracle build's source-coverage measurement.
mkdir -p mayhem-build/plain
PLAIN_OBJS=()
for f in "${LIB_SRCS[@]}"; do
  o="mayhem-build/plain/$(basename "$f").o"
  $CC "${INCS[@]}" $COVERAGE_FLAGS -g -c "$f" -o "$o"
  PLAIN_OBJS+=("$o")
done
$CC "${INCS[@]}" $COVERAGE_FLAGS -g -c mayhem/harness_link_stubs.c -o mayhem-build/plain/harness_link_stubs.c.o
PLAIN_OBJS+=(mayhem-build/plain/harness_link_stubs.c.o)

$CC "${INCS[@]}" $COVERAGE_FLAGS -g -c mayhem/kat_sip_probe.c -o mayhem-build/plain/kat_sip_probe.c.o
$CC "${INCS[@]}" $COVERAGE_FLAGS -g \
  mayhem-build/plain/kat_sip_probe.c.o "${PLAIN_OBJS[@]}" \
  -o /mayhem/kat_sip_probe -lpthread -lm $CURSES_LIBS -lpcap

# Regression guard: the KAT probe must be dynamically linked (LD_PRELOAD-based sabotage in
# verify-repo's anti-reward-hack check can only neuter a dynamically linked executable).
file /mayhem/kat_sip_probe | grep -q 'dynamically linked' \
  || { echo "build.sh: /mayhem/kat_sip_probe is NOT dynamically linked" >&2; exit 1; }

echo "build.sh: built /mayhem/fuzz_sip_check_packet(-standalone) and /mayhem/kat_sip_probe"
