---
type: doc-snapshot
id: 01m3gbnq3v46xcvysevy79zcf4
created: 2026-09-27T02:38:57.659464+00:00
updated: 2026-09-27T02:38:58.223816+00:00
summary: 'Pre-registration rev4: the admission rule''s read rate recalibrated to the target configuration'
captured_at: 2026-09-26
dirty: 'true'
git_head: 32c77288c0157a3932d0b83c727e3cd5c680447e
original_path: .build/disk-prefix-tier-20260926/admission-step2-preregistration-rev4.md
sha256: 94dcf6fe27bf87868dc2707fd9be276271038b64c5f681870ef5b8beaaaaf65c
title: 'Pre-registration rev4: the admission rule''s read rate recalibrated to the target configuration'
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

## Revision 3, 2026-09-26, still before any gate of this step ran

Two forms were tried and both were wrong in a way the code shows, not the data.

**Revision 1** compared prefill pass counts. It is right whenever the schedule runs uniform
passes, including the case that matters most: a saving smaller than one pass still removes a whole
pass when it crosses a pass boundary, and the fixed cost of a pass is most of what a short read
costs (25 rows cost 1.07 to 1.79 s against 3.6k rows at 21 to 52 s). But
`PrefillSchedule.next(remaining:at:maxChunk:tailAware:)` returns the *entire remaining tail as one
pass* when `tailAware` is set and the product bound fits, so with `SLOTSTREAM_OPT_TAIL_SCHEDULE=1`
both arms are one pass and revision 1 would skip every disk state. That option defaults off, so
revision 1 would have passed its gates and hidden the defect.

**Revision 2** required the saving to reach one scheduled pass of rows. That is safe under both
schedules but gives up revision 1's best case: 96 saved rows that cross a boundary are worth about
a second of avoided pass and are skipped.

**Revision 3 takes the disk when either win is real:**

```
removes a scheduled pass            OR      saved rows pay for the restore at the
                                            cheapest re-read cost ever measured
```

The second term is the conservative half: 3921 rows in 1.64 s on a fully resident pool is
0.42 ms per row, the cheapest re-read in the evidence, so a saving is only credited when even the
best case for reading pays for the restore, whose fitted cost is `0.0213 + 3.946e-06 * rows`
([[records/measurements/disk-tier-cost-arms-2026-09-26]]). Every read cost measured in the
streaming target configuration is larger, so the rule errs toward taking the disk in exactly the
configuration this engine exists for, and never takes it on a saving that cannot pay for itself in
any configuration measured.

Both terms come from the schedule and the measured evidence; neither is a bespoke length or cost
threshold. The first is `passes(from: diskHolds) < passes(from: memoryHeld)` walked with
`PrefillSchedule.next(remaining:at:maxChunk:tailAware:)` under the request's own chunk and the
model's tail-aware setting, so it disappears on its own under a tail-aware schedule instead of
lying; the second is the two fitted constants above. A pure gate asserts both flips.

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

## Revision 4, 2026-09-26, after step 4's measurement

Step 4 measured what this engine actually pays to read
([[sources/runs/2026/09/2026-09-26-disk-prefix-step4-paired-ab]]): arm A's post-restart turn
restores 3584 rows in 0.035 to 0.037 s and then reads 265 rows for 20.5 s, while arm B reads the same
3849-row prompt cold in 70.7 to 73.1 s. That is about 77 ms per row on the first pass after a restart
and 18.5 ms amortized over the whole read.

The second term of revision 3 credited a saving at 0.42 ms per row — 3921 rows in 1.64 s on a *fully
resident* pool, which is the one configuration this engine does not target. It is an estimator
returning a value from outside the range it measured, in the direction that costs: at a 0.42 ms rate a
restore of a 4k-row state needs about 90 saved rows to pay, so revision 3 declines savings of 8 to 90
rows that the target configuration would pay for several times over (64 rows cost 1.2 s at the
measured 18.5 ms per row against a 0.038 s restore).

Revision 4 credits a saving at **5.80 ms per row** — 3660 rows in 21.22 s, the cheapest re-read
measured in a configuration where the model did not fit in memory
([[records/measurements/disk-tier-cost-arms-2026-09-26]]). The break-even for a 4k-row state becomes
about 7 rows, so the term now declines only a state that is effectively the length memory already
holds, which is the case it exists for, while still covering a tail-aware schedule where the pass term
collapses. The resting rule is unchanged: whatever the rate, the rule may only ever decline a restore,
and every decline is recorded with its reason.

