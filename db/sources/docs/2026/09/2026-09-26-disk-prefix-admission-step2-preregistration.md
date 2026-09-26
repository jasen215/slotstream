---
type: doc-snapshot
id: 01m3ey3vv28xty9n8eph7gm2fj
created: 2026-09-26T13:22:46.754175+00:00
updated: 2026-09-26T13:23:39.951848+00:00
summary: 'Pre-registration: order 344 step 2, admission by pass count'
captured_at: 2026-09-26
dirty: 'true'
git_head: 21a948e751f671aecdc31dd9a732a67857daa6f2
original_path: .build/disk-prefix-tier-20260926/admission-step2-preregistration.md
sha256: 98184907ceac057f178b7586d555398c32d13df90050941afa974266d73cf6ca
title: 'Pre-registration: order 344 step 2, admission by pass count'
status: superseded
---
# Pre-registration: order 344 step 2, admission by pass count

Frozen 2026-09-26, before any line of this step's implementation exists.

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

## The rule

A candidate disk state is taken only when restoring it removes at least one prefill pass
from what the request would otherwise read. In the code that is exactly:

```
passes(from: L, to: P) < passes(from: K, to: P)
```

where `P` is the prompt length, `K` the length of the longest state memory retains for
this request (its aligned resume point, `retainedMatchLength`), `L` the candidate's
length, and `passes(from:to:)` walks `PrefillSchedule.next(remaining:at:maxChunk:tailAware:)`
one pass at a time from the start position to `P` with the request's own `prefillChunk`
and the model's tail-aware setting. When the condition does not hold the disk tier is
skipped and the request takes the ordinary in-memory path.

**The rule uses the schedule, not a measured constant.** The measured constants justify
the shape — a restore costs 21 ms plus 3.95 ms per 1000 restored tokens, at most 0.09 s
over every state measured, while the smallest pass a skip could avoid costs about 1.1 s —
so a step that removes one pass is worth about 20x and a step that removes none is worth
0.09 s less than nothing. No threshold in seconds, no threshold in tokens and no fitted
slope enters the engine: if the schedule changes, the decision follows it.

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
