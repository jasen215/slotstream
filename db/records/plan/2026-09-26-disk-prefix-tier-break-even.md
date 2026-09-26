---
type: plan
id: 01m3ecpsw8ezyhykv7ts5qcq22
created: 2026-09-26T08:18:32.968493+00:00
updated: 2026-09-26T12:02:30.054655+00:00
summary: 'The disk prefix tier: a measured load-versus-recompute admission and a queued preload'
date: 2026-09-26
doc: plan
kind: queue-item
level: '2'
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
1. Cost model from existing evidence, no engine change and no model launch. For the turns the store
   already records, resolve both arms per candidate state: (a) the disk read plus restore cost of the
   persisted state, and (b) the re-prefill cost from the request's last aligned pass boundary to the
   same length, whose token distance is deterministic from the prompt length and the chunk size
   (`PrefillSchedule.resumeBoundaries`), with `PrefillSchedule.estSeconds` available as a weights-free
   estimator. Exit: a fitted model of both arms over recorded turns, each with its residual and its
   fitted range, reported as a lower bound on the disk arm's true cost; a fit whose residual spans the
   whole decision range is a negative result and stops the record; and no hardcoded length threshold
   anywhere in the engine.
2. Admission in the cache. Per candidate state, choose the cheaper arm using step 1's measured
   constants, leaving the aligned-resume rule, the four-conversation ceiling, the shared-token ceiling
   and the miss-eviction order unchanged. Exit: `optimization-state-check --variant
   persistent-prefix[-mtp]` still bit-matches a memory hit, `Tools/persistent_prefix_e2e.py` still
   passes, and a gate asserts the decision is computed from the measured constants and flips when they
   flip.
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
5. Changing a default, the docs and any public number are a separate decision after step 4.

## Limits

One machine and one internal SSD: the break-even point is a property of this disk, this model's pass
structure and the current planner, and it must be re-derived, not carried, on any other machine. The
placement study's negative prefetch result is from PCIe-attached tiers with GPU HBM and a simulated
execution model, so it does not transfer to reading a local SSD into unified memory; its capacity-over-
placement finding is the reason step 1 measures admission rather than a new placement policy. Steps 1
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
