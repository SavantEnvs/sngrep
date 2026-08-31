# AddressSanitizer stack-buffer-overflow (found during integration, not yet root-caused)

**Status:** real finding, confirmed under libFuzzer `-fork` mode; NOT independently
reproducible via a clean single-process replay of the saved artifact alone. Recorded here
per this fleet's "record every finding, don't file the serial numbers off" policy rather
than discarded.

## How it was found

```
mayhem/fuzz_sip_check_packet -fork=4 -ignore_crashes=1 -ignore_ooms=1 -ignore_timeouts=1 \
  -timeout=15 -rss_limit_mb=2560 -max_total_time=150 -artifact_prefix=<dir>/ \
  <corpus seeded from mayhem/fuzz_sip_check_packet/testsuite>
```

~150s in, one of the 4 fork workers hit:

```
==<pid>==ERROR: AddressSanitizer: stack-buffer-overflow on address 0x7fc1a9fc5a32
    at pc 0x557dfe13f812 bp 0x7ffd1ae772d0 sp 0x7ffd1ae76a78
```

Coverage kept climbing after the hit (271/733 -> 271/734 features by the end of the run),
so this is the healthy "found a bug and kept exploring" case (see
`docs/netnew-worker-prompt.md` §6c), not a rediscover-forever pattern — it was not disabled.

## Why it's not reproducible standalone

`reproducer.bin` (the exact artifact libFuzzer saved) replayed alone — `-runs=1`, 10
repeated attempts, and `-runs=3` (replaying it 3x in one process) — never crashes; it does
not even reach `sip_parse_msg_media()` in isolation, because the input has no `Call-ID:`
header, so `sip_check_packet()` returns `NULL` at the `sip_get_callid()` check before any
further parsing happens (see `src/sip.c`). ASan's classification (stack-buffer-overflow,
not stack-use-after-return) means the fault is a genuine in-bounds-frame overflow, not a
dangling-pointer bug — so it is almost certainly state-dependent: it needs the harness
process's accumulated `calls` table (built from many prior, DIFFERENT fuzzer inputs in the
same run) to be in a specific shape — e.g. a Call-ID collision/hash-bucket state from an
earlier input — before this exact byte sequence reaches the vulnerable code path. Replaying
the final 706-file merged corpus (in file order, single process) also did not reproduce it,
which is consistent with each of the 4 fork workers holding its own private, non-merged
corpus/history.

The input itself is a heavily libFuzzer-mutated ~1.7KB blob containing dozens of repeated
`m=audio 49170 RTP/AVP 0` / `a=rtpmap:...` SDP lines — i.e. it stresses
`sip_parse_msg_media()`'s per-"m=" line loop (`src/sip.c`, the `ADD_STREAM` macro +
`media_type`/`media_format`/`address` stack buffers), which is the most plausible site for
a genuine stack overflow given the crash class, even though a root cause was not pinned
down with a bisected repro.

## Not a harness artifact

`mayhem/fuzz_sip_check_packet.c` does no file I/O and takes an unbounded byte buffer
straight from libFuzzer into `sip_check_packet()` via the same `packet_t`/
`packet_set_payload()` API `src/capture.c` uses for every real captured packet — so this is
sngrep's own parser being exercised through its real entry point, not a harness-invented
code path.

## What the next person to look at this should try

- Re-run `-fork` mode for longer (this run was a 150s smoke check, not a full campaign) and
  capture ASan's full report (not just the truncated summary line) from the worker's own
  log directory (`-fork` mode logs each child to a temp `.log` file that gets cleaned up on
  success — set `-artifact_prefix` to something durable and inspect `fuzz-N.log` files while
  the run is still active, or increase libFuzzer's crash log retention).
- Feed a two-step reproduction: first a "victim" input establishing a specific `calls` table
  state (e.g. two messages sharing a Call-ID, or a Call-ID that collides in the hash table),
  then this artifact — via `-runs=2` with both files as separate arguments in a fixed order.
- If reproduced, symbolize with `addr2line`/`llvm-symbolizer` against the sanitized
  `mayhem/fuzz_sip_check_packet` binary to name the exact overflowing stack variable.
