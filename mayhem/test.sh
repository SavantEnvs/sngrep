#!/usr/bin/env bash
#
# mayhem/test.sh — RUN mayhem/kat_sip_probe (already built by mayhem/build.sh). exit 0 = pass.
#
# sngrep ships NO test suite that can serve as a sabotage-proof oracle here:
#   - tests/test_00{1,2,3,4,5,6,8,9,11,13}.c fork+exec the REAL `sngrep` ncurses binary,
#     feed it simulated keystrokes over a pipe, and assert only the CHILD PROCESS'S EXIT
#     CODE (tests/test_input.c: `return ret` from `wait(&ret)`). That is exactly the
#     "exit-code-only test RUNNER" trap this fleet's field notes warn about (see
#     docs/netnew-worker-prompt.md §4): under verify-repo's sabotage shim, the exec'd
#     `sngrep` child gets `_exit(0)`'d by the shim's LD_PRELOAD constructor before it reads
#     a single byte, `wait()` sees a clean exit, and the test "passes" having tested nothing.
#     They also need a real ncurses TTY, which a headless container build doesn't have.
#   - tests/test_007.c / test_010.c are pure `assert()`-based unit tests with NO stdout on
#     success — same trap: a sabotaged binary that never reaches main() also never trips an
#     assert(), so it "passes" via a silent, empty exit(0) either way.
#
# So the REQUIRED behavioral oracle here is mayhem/kat_sip_probe (see its own header comment):
# a plain, dynamically linked, run-once binary that feeds sip_check_packet() (src/sip.c) two
# fixed SIP messages and asserts 14 EXACT parsed values (Call-ID, From, To, Contact, CSeq,
# method, SDP media type + rtpmap, response code/text). It prints "KAT_TOTAL: <p>/<n> PASS"
# ONLY after genuinely running every assertion — a sabotaged binary's stdout is empty (the
# shim's constructor _exit(0)s it before main() runs), so grepping for that exact line, with
# the exact expected count, is what makes this oracle fail under sabotage instead of passing
# via exit code alone.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "${SRC:-/mayhem}"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

BIN="/mayhem/kat_sip_probe"
EXPECTED_TOTAL=14   # keep in sync with mayhem/kat_sip_probe.c's CHECK_* call count

if [ ! -x "$BIN" ]; then
  echo "test.sh: $BIN missing or not executable (build.sh should have produced it)" >&2
  emit_ctrf "sngrep-kat" 0 1
  exit 1
fi

OUT="$("$BIN" 2>&1)"
RC=$?
echo "$OUT"

# Pull "<passed>/<total>" out of the mandatory marker line. An empty/sabotaged run (no
# stdout) or a mismatched total both count as a hard failure — never a skip.
LINE="$(printf '%s\n' "$OUT" | grep -E '^KAT_TOTAL: [0-9]+/[0-9]+ PASS$' || true)"
if [ -z "$LINE" ]; then
  echo "test.sh: no KAT_TOTAL marker in output (rc=$RC) — probe did not run to completion" >&2
  emit_ctrf "sngrep-kat" 0 "$EXPECTED_TOTAL"
  exit 1
fi

PASSED="$(printf '%s\n' "$LINE" | sed -E 's/^KAT_TOTAL: ([0-9]+)\/([0-9]+) PASS$/\1/')"
TOTAL="$(printf '%s\n' "$LINE" | sed -E 's/^KAT_TOTAL: ([0-9]+)\/([0-9]+) PASS$/\2/')"

if [ "$TOTAL" != "$EXPECTED_TOTAL" ]; then
  echo "test.sh: probe ran $TOTAL checks, expected $EXPECTED_TOTAL — test.sh/probe drifted out of sync" >&2
  emit_ctrf "sngrep-kat" 0 "$EXPECTED_TOTAL"
  exit 1
fi

FAILED=$(( TOTAL - PASSED ))
emit_ctrf "sngrep-kat" "$PASSED" "$FAILED"
