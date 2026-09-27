---
type: measurement
id: 01m3ge74rvycp69hmqbpgvj9nk
created: 2026-09-27T03:23:25.851219+00:00
updated: 2026-09-27T03:23:52.697946+00:00
summary: 'Both the disk candidate and memory''s offer must sit on the request''s own prefill pass boundaries, so K to L is whole passes and the pass-count term is always true: 30 recorded turns, zero refusals'
captured_at: 2026-09-26
date: 2026-09-26
doc: measurements
level: '3'
order: '345'
title: The disk tier's admission rule cannot refuse on the deployed path
status: measured
---
# The disk tier's admission rule cannot refuse on the deployed path

**What was asked.** Order 344 step 2 built an admission rule so the disk tier would not read a state
whose saving does not pay for its own restore, and after step 4 the open question was to force a
refusal and watch what the engine does. This record is the answer to the forcing half: on the deployed
configuration there is nothing to force. The rule cannot refuse, and not by luck — the states the disk
tier may offer are constrained to the request's own prefill pass boundaries, and that constraint makes
the rule's first term true for every candidate it can ever see.

## The constraint

`PersistentPrefixPolicy.bestMatch` accepts an entry only when

```
entry.tokens.count > retained                                   // longer than what memory offers
&& (boundaries?.contains(entry.tokens.count) ?? true)           // line 211
&& (boundaries == nil || (prefillChunk != nil && entry.prefillChunk == prefillChunk))   // line 212
&& prompt.starts(with: entry.tokens)
```

and `restorePersistentPrefix` passes `boundaries: resume?.boundaries`, the request's own prefill pass
ends under `alignedPrefixResume` (the deployed family), which also clamps what *memory* offers to one
of those same boundaries. So both the disk candidate's length `L` and memory's offered length `K` are
positions on one lattice: the pass ends of reading this prompt from zero.

## Why that decides it

Reading this prompt from `K` instead of from `L` re-reads exactly the tokens `[K, L)`. Because the
schedule's pass size is a function of the position (`PrefillSchedule.chunk(at:maxChunk:)`), the passes
that decompose `[K, L)` starting at `K` are the same passes the full decomposition uses, so `K` to `L`
is a whole number `n >= 1` of complete passes and

```
passes(from: K)  =  passes(from: L) + n,   n >= 1   =>   passes(from: L) < passes(from: K)
```

which is precisely `PersistentPrefixAdmission`'s first term. The second term is only consulted when
the first is false, so no candidate the deployed tier can produce is ever refused.

## What the recorded turns show

Every candidate in every recorded run, with the schedule's 256-row pass at these lengths:

| run | K memory offered | L disk held | prompt | passes(K) | passes(L) |
| --- | ---: | ---: | ---: | ---: | ---: |
| e2e turn 3, first server | 3840 | 4352 | 5279 | 6 | 4 |
| e2e turn 3, restarted server | 0 | 4352 | 5279 | 21 | 4 |
| e2e turn 3, regenerated | 0 | 5120 | 5279 | 21 | 1 |
| A/B short follow-up, all rounds | 3840 | 4352 | 5279 | 6 | 4 |
| A/B restart-long, all rounds | 0 | 3584 | 3849 | 16 | 2 |

All six `L` values are multiples of 256, i.e. lattice points, and no turn in any run — 6 e2e turns and
24 A/B turns, three of them admitting a restore — recorded `skippedRestore`.

## Where it *is* reachable

- `SLOTSTREAM_OPT_ALIGNED_RESUME=0`, the comparison-only configuration: memory may then offer a length
  that is not one of the request's boundaries, so `K` and `L` can sit on different lattices and the
  pass counts can tie.
- `SLOTSTREAM_OPT_TAIL_SCHEDULE=1`, the tail-aware schedule: its rule swallows the remaining tail in
  one pass, so a boundary gap inside that collapsed tail can leave both sides at one pass. The second
  term then decides, and it declines only a saving below about seven rows at a 4k state — reachable
  with a prompt ending within a few rows of a pass multiple. The T0 check's tail-aware assertion is
  that corner, and it is the only thing keeping the second term alive.

Neither is the deployed family; the first is explicitly for comparison work and the second is off
unless an environment variable asks for it.

## Consequence

On the deployed path the rule is behaviourally identical to the behaviour it replaced — take any longer
state. That is why step 4 measured no refusal and why its numbers are the always-take numbers: the
campaign's arms both contain the rule, and it never fired. What step 2 observably delivered is the
accounting (`memoryOfferedTokens`, `savedRows`, `residualPrefillTokens`, `evictionsForRestore`), which
is what made the eviction visible as the co-primary at all; the decision-side of the rule is
unexercised machinery on the deployed configuration, and whether to keep it as a guard for the
tail-aware schedule or remove it under YAGNI is a separate decision with its own record.

## Limits

The argument is about the schedule and the resume rule as implemented on 2026-09-26: a schedule that
collapses its tail, or a resume rule that permits off-lattice starts, makes the refusal arm reachable
again — which is exactly what the two configurations above are, and the reason the T0 check keeps the
flip assertions rather than the invariant alone. The empirical half is 30 turns on one machine, one
prompt shape and `--memory-gb 10`; it confirms the argument, and the argument is the code above, not
the sample. No engine behaviour was changed to produce this record: the refusal path is not exercised,
so nothing here is a measurement of what a refusal *does*.

Evidence: [[sources/runs/2026/09/2026-09-26-disk-prefix-step4-paired-ab]],
[[sources/runs/2026/09/2026-09-26-disk-prefix-step2-admission]],
[[sources/runs/2026/09/2026-09-26-disk-prefix-admission-recalibration]].
