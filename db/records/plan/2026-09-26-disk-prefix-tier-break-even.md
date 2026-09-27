---
type: plan
id: 01m3ecpsw8ezyhykv7ts5qcq22
created: 2026-09-26T08:18:32.968493+00:00
updated: 2026-09-27T03:20:42.790394+00:00
summary: 'The disk prefix tier: a measured load-versus-recompute admission and a queued preload'
date: 2026-09-26
doc: plan
kind: queue-item
level: '2'
note: 'Steps 0, 1 and 2 done: the tier admits a longer state only when it removes a pass of reading or saves rows that pay for its own restore, evictions are recorded beside every restore, and steps 3 (queued preload) and 4 (paired A/B) remain.'
order: '344'
title: 'The disk prefix tier: a measured load-versus-recompute admission and a queued preload'
status: open
---
Opened on 2026-09-26 from the persistent prefix cache's own semantics
([[records/decisions/prefix-cache-holds-four-conversations-extend-only]],
[[records/plan/n1-conversation-prefix-cache-kv-gdn-state-reuse-across-requests]]) and from two pieces of
prior art recorded on the same day:
[[sources/references/2026/09/2026-09-26-py-kvcache-external-kv-break-even]] and
[[sources/references/2026/09/2026-09-26-kv-cache-placement-across-tiers]].

## Problem

The disk tier restores the saved representation and never rebuilds, memory answers first, and disk is
read only for a state longer than memory holds, after making room like a miss. What has never been
measured is whether that read is cheaper than not using the disk at all. Under the aligned-resume rule
a hit is worth the distance back to the request's own pass boundary, so for a short follow-up the
saving can be one partial pass – and for a short prefix that a partial pass would re-read in a few
hundred milliseconds, reading a persisted state from the SSD, restoring it into buffers of the saved
shapes, and evicting another conversation to make room can cost more than the work it saves.

The prior art makes this the whole question: external KV caching is a setup-specific admission
decision, recomputation can beat loading for short prefixes or a fast device, and much of that work's
win came from *when* the transfer enters the schedule rather than from device bandwidth (preloading
contributed 1.34x of a 2.0x result). The placement study is the counter-argument and belongs in this
record's limits: in its setting the gains came from tier capacities, not placement, and prefetching did
not justify its bandwidth cost.

## Steps, in dependency order

0. Observation, no engine arithmetic. Add `memoryOfferedTokens` and `residualPrefillTokens` to
   `PersistentPrefixObservation` and `evictionsForRestore` to `reserveForRestore`. Correction,
   2026-09-26: this record said both arms were already instrumented, and that holds for the disk arm
   only (`restoreSeconds`/`restoreBytes`/`restoredTokens` exist, though timed inside the operations
   lock and after the eviction they trigger). The recompute arm has no same-request counterfactual:
   `prefillTokens` merges the resumed and re-read tokens, and what memory offered never leaves a log
   line. Exit: with the tier off the ordinary statistics are byte-identical to the shipped build's, and
   where a value appears both in a log line and in a statistic the two agree.

   **Outcome, 2026-09-26: done.** `optimization-state-check --variant persistent-prefix --tokens 2051`
   reports `passed: true` with every item green, so a restored state still equals a memory hit bit for
   bit and the new fields changed no arithmetic. The scalars populate: over six turns of one
   conversation on a fresh tier, memory offered 3840 on turn 2 and the request took nothing from disk,
   while turn 3 restored 4352 tokens in 0.043 to 0.062 s, still had to read 927 tokens itself, and on
   the first server evicted two conversations to do it. `Tools/persistent_prefix_e2e.py` passes every
   id-equality check and fails five bookkeeping checks that assert one persisted head per turn: turn 1
   also writes a shared prefix head (`sharedSaveOutcome "saved"`, 3584 tokens), so two heads after turn
   1 is the engine's design, the tool's expectation predates shared prefixes and it is not a CI gate.
   Raw output: [[sources/runs/2026/09/2026-09-26-disk-prefix-step0-scalars]]. Step 1, the two-armed fit,
   is next and its input now exists.
1. Cost model from existing evidence, no engine change and no model launch. For the turns the store
   already records, resolve both arms per candidate state: (a) the disk read plus restore cost of the
   persisted state, and (b) the re-prefill cost from the request's last aligned pass boundary to the
   same length, whose token distance is deterministic from the prompt length and the chunk size
   (`PrefillSchedule.resumeBoundaries`), with `PrefillSchedule.estSeconds` available as a weights-free
   estimator. Exit: a fitted model of both arms over recorded turns, each with its residual and its
   fitted range, reported as a lower bound on the disk arm's true cost; a fit whose residual spans the
   whole decision range is a negative result and stops the record; and no hardcoded length threshold
   anywhere in the engine.

   **Outcome, 2026-09-26: the disk arm fits, the re-read arm is a negative result, and this step stops
   there.** Nine restored states of 3584 to 15632 tokens across the recorded turns give
   `restoreSeconds = 0.0213 + 3.946e-06 * restored tokens` (n=9, r2=0.954, residual p50 +0.0004 s,
   p90 +0.0046 s) — a lower bound, because the timer starts inside the operations lock and excludes the
   eviction a restore causes, which step 0 measured at two conversations for one 4352-token restore.
   The re-read arm does not fit the token count: `seconds = 19.429 + 0.00310 * tokens read`, n=19,
   **r2=0.012**, residual p50 -17.7 s and p90 +21.1 s, with the same 25-token residual costing 1.50 s
   in one warm turn and 42.23 s in a cold one of the same run. By this step's own rule that is a
   negative result and it stops here: no admission rule, no engine arithmetic, steps 2 to 5 not entered
   by it. Turns used were the registration's named 2026-09-14 trio, the two 2026-09-16 shared-prefix
   records its limits section admits, and step 0's own run.
   **The reason is the pass, not the pool**: `PrefillSchedule` keeps a 256-row floor, so reading 18
   tokens and reading 256 tokens are one pass, and one pass measured 1.5 to 1.7 s at a warm pool and 21
   to 52 s cold. A restore therefore wins by about 20x when it removes a pass and by three orders of
   magnitude when it removes a cold one, while a state whose residual stays inside the same pass count
   saves nothing and costs its restore plus the evictions it causes. **The threshold worth gating is a
   pass count, not a token count**, which makes step 2 below a different step than the one registered.
   For whenever it is rewritten: its exit names `Tools/persistent_prefix_e2e.py` passing, and that
   tool's five bookkeeping checks fail on an expectation that predates shared prefixes — step 0 records
   why — so the check set needs updating before it can serve as an exit.
   Raw output: [[sources/runs/2026/09/2026-09-26-disk-prefix-step1-fit]]; measurement
   [[records/measurements/disk-tier-cost-arms-2026-09-26]].
2. Admission in the cache. Per candidate state, choose the cheaper arm using step 1's measured
   constants, leaving the aligned-resume rule, the four-conversation ceiling, the shared-token ceiling
   and the miss-eviction order unchanged. Exit: `optimization-state-check --variant
   persistent-prefix[-mtp]` still bit-matches a memory hit, `Tools/persistent_prefix_e2e.py` still
   passes, and a gate asserts the decision is computed from the measured constants and flips when they
   flip.

   **Outcome, 2026-09-26: rewritten and done, with the rule the evidence supports rather than the
   one first written.** Step 1's negative result replaced "choose the cheaper arm from a fitted
   per-token read cost" with two wins that are real in the measured data: the restore removes a pass
   of reading (a removed pass is worth about a second, since 25 rows cost 1.07 to 1.79 s against 3.6k
   rows at 21 to 52 s), or the rows it saves pay for its own restore at the cheapest re-read ever
   measured (0.42 ms per row on a fully resident pool, against a fitted restore of
   `0.0213 + 3.946e-06 * rows`). `PersistentPrefixAdmission.takesDiskState` is a pure function of the
   schedule and those two constants; no bespoke threshold entered the engine. The registration was
   revised twice before any gate ran — pass counts alone collapse under a tail-aware schedule, rows
   alone give up a small saving that crosses a pass boundary — and revision 3 records both rejected
   forms and why. Exits: `slotstream-checks --tier t0 --filter persistent-prefix` PASS with 132
   assertions (nine on the rule), `optimization-state-check --variant persistent-prefix --tokens 2051`
   `passed: true`, and `Tools/persistent_prefix_e2e.py` 12 of 12 after its bookkeeping checks were
   corrected to the shared-prefix accounting they predated — the correction is part of this step
   because that tool is named as an exit. On a real conversation the rule kept every restore it met;
   turn 3 of the first server saved 512 rows, restored in 0.0932 s against the fitted 0.0385 s, and
   evicted two conversations to do it, which is the co-primary now recorded beside every restore.
   Raw output: [[sources/runs/2026/09/2026-09-26-disk-prefix-step2-admission]].

   **Revision 4, 2026-09-26, after step 4 measured what reading actually costs.** The second term's
   rate was 0.42 ms per row, measured on a pool holding the whole model, which is not this engine's
   target; at that rate a 4k-row restore needed about 90 saved rows, so the rule declined savings of 8
   to 90 rows that the target pays for several times over — 64 rows cost about 1.2 s there against a
   0.038 s restore. It now credits the cheapest re-read measured where the model did not fit, 5.80 ms
   per row, which puts a 4k-row state's break-even at about seven rows and leaves the rule declining
   only a state that is effectively the length memory already holds. Its gates were re-run and are
   green: T0 policy PASS with 132 assertions, the equivalence gate `passed: true`, and the e2e suite 12
   of 12. Raw output: [[sources/runs/2026/09/2026-09-26-disk-prefix-admission-recalibration]].
3. Queued preload, bounded. Start the disk read while an accepted request waits for its guards or is
   queued, inside the existing staging and reservation accounting, cancelled and drained on failure or
   cancellation, with no reader pinned past the request's ownership. Exit: process footprint at the
   target unchanged, no read issued for a request that never proceeds, cancellation drains workers, and
   a rejected or timed-out request leaves no partial state visible to the next request.
4. Paired A/B on the two workloads this store already uses: agent short turns (many short follow-ups)
   and a long first turn. Exit: identical outputs, aggregate at least 1.02 with the lower bootstrap
   bound above 1.00, no family median below 0.97 on the short-turn family, and no long-turn duration
   regression above 2%. A reading that favours recomputation everywhere is a legitimate outcome: this
   record then closes by recording that the disk tier is not the lever for short prefixes, and the tier
   keeps serving only the long states it serves today.

   **Outcome, 2026-09-26: met, and it measures the tier rather than the rule's refusal arm.** Paired
   A/B over three rounds and twenty-four turns — arm A with the disk tier on a fresh directory, arm B
   with no disk tier, the workload this store already uses. Aggregate geometric mean **1.5988** with a
   bootstrap 2.5th percentile **1.4865**; short-follow-up family 1.3949 with nothing below 1.0009;
   restart-long turns 3.44 to 3.72x; prompt and output ids identical in all twelve pairs. Every
   registered exit is met and the outcome that would have closed this plan — a reading favouring
   recomputation — did not occur.
   Two readings matter more than the aggregate. The campaign's own warm-up inflates round 1: its
   control reads 1.4364 where rounds 2 and 3 read 1.0012 and 0.9978 for the same turn, and arm A's own
   cold turn was 48.09 s against 72.63 s later, so the machine changed state and stayed there; the
   steady-state view of rounds 2 and 3 is 1.5006 with the control at 1.000, both are recorded, neither
   is discarded. And **the admission rule never refused a candidate**, so this validates the tier, not
   step 2's refusal: the refusal regime needs a saving that removes no pass and is negligible, which no
   turn here produced.
   What the tier buys, as a rate: arm A's post-restart turn restores 3584 rows in 0.035 to 0.037 s and
   then reads 265 rows for 20.5 s, against arm B's 70.7 to 73.1 s for the same 3849-row prompt read
   cold — about 77 ms per row on the first pass and 18.5 ms amortized, so the tier's value is skipping
   the cold start rather than removing an average pass. The follow-up family's mechanism is a boundary:
   memory holds 3840 rows and the disk state 4352, which straddles a prefill pass boundary.
   Co-primary: every round evicted two conversations to admit the 4352-row state, and **nothing
   followed those evictions**, so their cost to later requests is the one thing this step still owes.
   Raw output: [[sources/runs/2026/09/2026-09-26-disk-prefix-step4-paired-ab]]. This measurement also
   recalibrated the admission rule's second term — the rate it used was measured on a fully resident
   pool, which is not this engine's target — and that revision is recorded on its own.
5. Changing a default, the docs and any public number are a separate decision after step 4.

## Limits

One machine and one internal SSD: the break-even point is a property of this disk, this model's pass
structure and the current planner, and it must be re-derived, not carried, on any other machine. The
placement study's negative prefetch result is from PCIe-attached tiers with GPU HBM and a simulated
execution model, so it does not transfer to reading a local SSD into unified memory; its capacity-over-
placement finding is the reason step 1 measures admission rather than a new placement policy. Step 1's
negative result left this plan open and step 2 was rewritten and completed on 2026-09-26 on the two
wins the evidence supports; the eviction a restore causes — invisible until step 0 — is recorded
beside every restore as the co-primary, and step 3's queued preload is the one step the placement
study's negative prefetch result still argues against. Steps 1
and 2 add no read traffic; only step 3 does, and it is the step the placement study argues against, so
it runs last and on its own registration.

## Registration

Frozen 2026-09-26 before any measurement of this question exists:
`.build/disk-prefix-tier-20260926/preregistration.md`, sha256
`c020840abf4bf34194658f0b21b66943c9562272ec739a71a54f6fc65756c584`, committed into the store as
[[sources/docs/2026/09/2026-09-26-disk-prefix-tier-break-even-preregistration]] so the text outlives
the scratch directory. It names the recorded turns used for the fit
([[sources/runs/2026/09/2026-09-14-persistent-prefix-segments-exactness]] and its two companions,
with the discarded M5 Air live session excluded from timing), the two cost estimators, the residual
bound (a fit whose residual spans the decision range closes the record), the admission rule (a pure
function of the fitted constants, which a gate must be able to flip, with no length or cost threshold
hardcoded in the engine) and the warning that `optimization-state-check --help`'s variant list is
stale, so the dispatch in `OptimizationCommands.swift` is the authority.
