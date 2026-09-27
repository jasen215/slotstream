# Measuring a memory-limited session against auto (protocol)

**Status: protocol, not results.** No run of this has been recorded yet. Every
number below is a precondition or a thing to record, never a measurement this
document is asserting.

## What it answers

Two open questions from the captured 2026-09-24 `serve.log` session on the 32 GB
M5 Air (Mac17,3) — raw transcript in the brain at
`sources/runs/2026/09/2026-09-24-m5-air-live-agent-session`, marked discarded
because the machine was in use and swapped. Both need a real session, not a
synthetic bench:

1. **Does auto's availability clamp leave an SSD-streaming engine enough room?**
   Auto sized that run to a target of 21.7 GB against 23.4 GB reclaimable. The
   only thing standing between the plan and the whole machine is
   `availabilitySlackGB = max(1.5, 0.05 x RAM)` — 1.7 GB here — which
   `Plan.swift` documents as a "doesn't leave the machine at zero" guard, not a
   performance margin. The run then logged two `memory pressure (warning)`
   governor events, degraded prefill as the context grew, and ended two requests
   in `insufficient_memory`.
2. **Why does the in-memory prefix tier stop serving a growing conversation?**
   That run served 3 prefixes from memory and 18 from disk; the switchover
   followed a request that failed during preparation after a memory hit.
   `Generate.swift` now prints `(memory offered N)` on every disk hit, which is
   the quantity that chose disk (`PersistentPrefixGenerator.candidate(longerThan:)`).

## Why the existing bench cannot run question 1

`Tools/prefill_bench.py` enforces `8.1 <= --memory-gb <= 10`
(`Tools/prefill_bench.py:221`) and appends that one value to every arm
(`:288`). It is the equality-test harness by design and cannot express an
auto-vs-limited comparison. Do not widen it for this: the 8.1-10 GB band is
what keeps the acceptance gates cheap and safe. This protocol therefore
measures **the real workload**, twice, on the same machine — the same thing the
captured log already is, but with a controlled difference.

## Preconditions (all of them, every round)

- **One model process.** The binary itself takes a per-user file lock before
  model allocation, so a second server refuses rather than stacking; that is a
  backstop, not a licence to stop looking. `pgrep -fl slotstream` must be empty
  before starting each arm, and heavy work that is not a model process (a
  build, a second client) still has to be kept off the machine.
- **Quiet machine, and a real reading of it.** `slotstream doctor` prints
  reclaimable memory. The arm that claims the most memory needs it to be
  reclaimable *now*; a session started on a busy machine measures the busy
  machine.
- **Nothing else heavy.** No second server, no build, no browser pane doing
  work. This is the rule that exists because stacking processes crashed this
  Mac once.
- **A seed and a prompt you can repeat.** The comparison is only paired if both
  arms see the same turns in the same order.
- **One build, carrying the instrument, used by both arms.** The failure detail
  and the `memory offered N` reading this protocol exists to collect are not in
  the installed release — `strings ~/.slotstream/bin/slotstream | grep -c 'memory
  offered'` returns 0, and so does an older `.build/release` from before the
  change. Build once from the tree that has them, confirm the string is present
  in the binary you are about to run, and use that one binary for both arms:
  comparing two builds would confound the arms with the build. Record the build
  identity beside the capture and check its `Generate.swift` hash against the
  tree you built — a stale release binary is otherwise indistinguishable from a
  session that simply never needed the instrument.
- **Each arm's own limit must be what bound it.** Auto picks a target, then
  clamps it to `reclaimable − availabilitySlackGB`; when availability is the
  binding term the plan silently becomes "whatever is free minus the slack",
  and both arms collapse onto the same target — an A/B that measures nothing.
  Read the arm's own plan (`limit:` versus `target:`, and the `note:` line that
  says it was sized down) and confirm the arm's limit chose the target. If
  availability clamped it, that round is void, not evidence: this is a
  comparison of two limits, so both have to be the operative one.

## Procedure

Two arms, interleaved A/B/A/B so drift cannot be mistaken for the effect:

| arm | how it is started |
| --- | --- |
| `auto` | `.build/release/slotstream serve` with no memory flag |
| `limited` | `.build/release/slotstream serve --memory-limit-gb 16` |

Use the same client, the same conversation, and the same turn sequence for
both. `--memory-limit-gb` is the right knob: it is an adaptive ceiling, so the
cache still shrinks and recovers inside it, unlike `--memory-gb` which pins a
fixed cache.

```sh
# once, before either arm: build, and prove the instrument is in the binary
make build                       # swift build -c release + the metallib + the identity receipt
strings .build/release/slotstream | grep -c 'memory offered'   # must not be 0: 0 means this binary predates the instrument
```

`make build` wraps the compile in `Tools/build_identity.py before|after`, which is
what writes the receipt the next paragraph asks you to record. Inside a
filesystem-sandboxed harness plain `swift build` also fails on SwiftPM's own
sandbox, so that environment runs the same steps by hand —
`python3 Tools/build_identity.py before "$(swift build -c release --show-bin-path)"`,
`swift build -c release --disable-sandbox`, the `mlx.metallib` copy, then
`build_identity.py after` — and must not drop the receipt to make the build go.

```sh

# before each arm
pgrep -fl slotstream                  # must print nothing
.build/release/slotstream doctor | head -12   # record reclaimable + the plan it picks

# arm (run serve in a subshell so TaskStop kills the group)
(nohup .build/release/slotstream serve [--memory-limit-gb 16] > /tmp/serve-$ARM.log 2>&1 &)
# ... drive the identical turn sequence ...
# then stop it, and confirm it is gone before the next arm
pkill -f 'slotstream serve' ; sleep 2 ; pgrep -fl slotstream
```

## What to record, per arm

- `~/.slotstream/serve.log` verbatim (raw first — never transcribe before the
  raw output is captured).
- `.build/release/build-identity.json`, with its `Generate.swift` hash checked
  against the tree that was built. Without it a capture cannot be told apart
  from one taken on an older binary that had no instrument.
- `.build/release/slotstream doctor` before the session.
- From the log: every `prefill: done, N tokens in X` line, every
  `elastic: memory pressure` / `memory freed` line, every request that ends with
  a failure, and — for question 2 — every
  `reusing N/M tokens from disk (memory offered X)` line.

## Stop conditions

- **Any swapping observed during an arm invalidates that arm.** Global paging
  is a diagnostic, not a correctness gate, but it is exactly the confound here:
  record it and treat the pair as unusable rather than reporting a median over
  it.
- If the machine cannot give the `auto` arm its target, the answer is "not
  measured", not "auto is worse". Refusing to start is the correct outcome.
- Kill every process the moment an arm ends, and confirm.

## After the numbers exist

Capturing raw output is not transcribing it. Once both arms are captured,
the findings need the usual records before any of it reaches a public surface:
a measurement record per arm, claims records for any number that lands on
README/`docs/`/`llms.txt`, and the decision record if the default changes.
`Tools/dbmd_install.sh` pins the `dbmd` version CI uses; `Tools/brain_gates.sh`
runs the checks. **No default is changed by this protocol by itself** — a
tuning default moves only on this evidence.
