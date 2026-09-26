---
type: doc-snapshot
id: 01m3ey5f64k032xy2qcz6rxc7j
created: 2026-09-26T13:23:39.332133+00:00
updated: 2026-09-26T13:24:21.115913+00:00
summary: 'Pre-registration rev2: order 344 step 2, admission by a saved pass of rows'
captured_at: 2026-09-26
dirty: 'true'
git_head: 21a948e751f671aecdc31dd9a732a67857daa6f2
original_path: .build/disk-prefix-tier-20260926/admission-step2-preregistration-rev2.md
sha256: 99fd02a873bd1e9c7d5b7eeb6bca4504614d593426bf051610c06ccb7b6d6b51
title: 'Pre-registration rev2: order 344 step 2, admission by a saved pass of rows'
status: superseded
---
# Pre-registration: order 344 step 2, admission by pass count

Frozen 2026-09-26, before any line of this step's implementation exists; revised the same day,
still before any gate of this step ran (revision 2 below).

## What this replaces

The plan's step 2 as originally written chose the cheaper arm from step 1's *fitted
constants*: a per-token cost for the re-read against a per-token cost for the restore.
Step 1 answered that question negatively and the registration's own rule stopped the
record: the re-read arm does not fit token count (`n=19`, `r2=0.012`, residual -17.7 to
+21.1 s across runs), because the re-read's unit of cost is a **pass**, not a token.
`PrefillSchedule` keeps a 256-row floor, so reading 18 tokens and reading 256 tokens are
one pass; across the recorded turns one pass measured 1.5 to 1.7 s at a warm pool and 21
to 52 s cold, and the smallest residual read observed cost 1.07 to 1.79 s
([[records/measurements/disk-tier-cost-arms-2026-09-26]]).

## Revision 2, 2026-09-26, before any gate of this step ran

Revision 1 wrote the rule as a comparison of prefill **pass counts**:
`passes(from: L, to: P) < passes(from: K, to: P)`. Reading the schedule it walks
`PrefillSchedule.next(remaining:at:maxChunk:tailAware:)`, whose `tailAware` argument returns the
*entire remaining tail as one pass* whenever the query-by-key product fits. With
`SLOTSTREAM_OPT_TAIL_SCHEDULE=1` a follow-up turn's residual is therefore one pass from either
resume point, both counts read 1, and revision 1's rule would skip every disk state — including
the restores it is meant to keep. The option defaults off (`InferenceOptimizations.tailAwarePrefill`
is `false`; `Optimizations.swift` only turns it on through that variable), so the deployed
configuration is unaffected and revision 1 would have passed its gates. A rule whose correctness
depends on an environment variable being unset is not a rule.

Revision 2 keeps the unit — one pass of reading — and states it in rows against the schedule's own
pass size at the memory resume point rather than by counting passes:

```
diskHolds - memoryHeld >= PrefillSchedule.chunk(at: memoryHeld, maxChunk: chunk)
```

Under the uniform schedule this is the same decision as revision 1, because both lengths are pass
boundaries; under a tail-aware one-pass schedule it still requires a real pass worth of rows, which
is what the cost evidence supports: a restore costs 0.021 s plus 3.95 ms per 1000 restored tokens,
and the cheapest read measured was 0.42 ms per row (fully resident), so about 215 rows are needed
before a restore pays at the most favourable-to-reading cost ever observed. The scheduled pass size
is at least 256 while the measured product fits, and 64 only in very late context, where a restore
is by far the cheaper arm anyway. Nothing is hardcoded: the bound is the schedule's own chunk at
the position the request would otherwise resume from.

## What does not change

The aligned-resume rule and its boundaries; the four-conversation ceiling; the
shared-token ceiling; the miss-eviction order; `minimumTokens`, which still gates writes
only; the restore itself (same format, same buffers, same lineage); the requirement that
memory answers first; and the byte-identity of a restored state against a memory hit. No
new read traffic: this step can only decline to read.

## The co-primary: what the skip and the restore cost other conversations

Step 0 made the eviction a restore causes visible for the first time
([[sources/runs/2026/09/2026-09-26-disk-prefix-step0-scalars]]: one 4352-token restore
on the first server evicted two conversations). This step reports, for every request that
reaches the disk path: what memory offered, the pass count each way, whether the rule
skipped a longer state, and — when it did not skip — the evictions the restore caused.
A step whose restore evicts conversations to avoid a pass that would have been cheaper to
read is a regression even though it is fast on that request, and the counts must show it.

## Exits

1. `optimization-state-check --variant persistent-prefix --tokens 2051` still reports
   `passed: true`: a restored state still matches a memory hit bit for bit.
2. A pure gate, with no model loaded, asserts the decision is the schedule's: for a fixed
   prompt, a candidate that removes a pass is taken and an equal-pass-count candidate is
   skipped, and both counts are reported.
3. The turn-level behaviour is recorded on real restarts by
   `Tools/persistent_prefix_e2e.py`, whose bookkeeping checks are corrected first to the
   engine's actual accounting (a shared-prefix head plus a conversation state head per
   turn) — step 0 recorded why they fail and why they are not a regression. Its id-equality
   checks, which already pass, are the part that guards correctness.
4. No skip is silent: every request reports what memory offered, the two pass counts, and
   the skip when it happens.

## What would falsify this step

A recorded run in which a restore that removes a pass loses more to evictions than the
pass it saved, or a run in which the rule skips a state whose restore would have removed a
pass under the request's actual chunking. Both are visible in the reported counts, and
either one sends the rule back to the plan rather than to a constant.
