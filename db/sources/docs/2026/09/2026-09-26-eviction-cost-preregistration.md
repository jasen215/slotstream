---
type: doc-snapshot
id: 01m3ge65zpp8dyfaz1dyev45kz
created: 2026-09-27T03:22:54.326602+00:00
updated: 2026-09-27T03:22:54.897969+00:00
summary: 'Pre-registration: what a restore-driven eviction costs a later sibling request'
captured_at: 2026-09-26
dirty: 'true'
git_head: b97be6648def58ddb38595f2bba5d5f24cc2e412
original_path: .build/disk-prefix-tier-20260926/eviction-cost-preregistration.md
sha256: caca8a0be67c0cfd7fa3ca3fa3b222a224ae061818c24a5d199d9481d42427e0
title: 'Pre-registration: what a restore-driven eviction costs a later sibling request'
---
# Pre-registration: what a restore-driven eviction costs a later sibling request

Frozen 2026-09-26 before any measurement of this question exists. Order 344's plan named the eviction
a restore causes as the co-primary beside the restore's own cost, and step 4 left it unmeasured
because nothing followed the eviction in that workload
([[sources/runs/2026/09/2026-09-26-disk-prefix-step4-paired-ab]]).

## Question

A restore makes room by evicting in-memory conversation states. What does the loss of those states
cost a later request that would have reused one, and does that cost offset the win the restore bought
in the same round?

## Why the sibling, and why now

The states a restore evicts are earlier states of the *same* growing conversation, which a later turn
of that conversation never needs. They matter only to a request that branches from an older state: a
sibling conversation sharing the same prefix, or a client that decorates a conversation (the title or
tag request the four-conversation cache exists for). This experiment therefore adds a sibling
conversation, asks it before the eviction, and asks it again after.

## Arms and battery

Arms are step 4's: **A** = disk tier on a fresh directory, **B** = no disk tier (memory cache in both).
Per battery, on a fresh server:

1. **T1 cold-long** — the 2400-word notes prompt plus the first question: conversation C1.
2. **T2 sibling** — the same notes plus a different first question: conversation C2, which shares the
   notes head and gets its own state.
3. **T3 trigger** — a long follow-up in C1, chosen so the disk holds a state longer than memory's for
   this request: the restore makes room and evicts.
4. **T4 sibling-after** — a new question in C2. Arm A has lost C2's state to the eviction; arm B has not.
5. **T5 control-after** — a new question in C1.

Same workload definition, parameters, tooling and guardrails as step 4
(`paired_ab.py`, `--memory-gb 10`, one model process, interleaved rounds, contamination rules,
reclaimable-memory preflight, fresh directory per round for arm A).

## Readings, not gates

1. `evictionsForRestore` on T3 in arm A, and the state listing after each turn, so the eviction is
   attributable to the named states.
2. The T4 ratio `B/A` and, for arm A, whether T4 reused a state (from memory or by restore) or rebuilt
   — a restore of C2's own disk state would offset the eviction, and that is part of the answer rather
   than a nuisance.
3. The paired per-round comparison `(B_T3/A_T3)` against `(B_T4/A_T4)`: whether the win the restore
   bought in a round exceeds what its eviction cost later in the same round. This is the co-primary.
4. Output ids where the prompts are identical across arms.
5. T3's own admission fields (`memoryOfferedTokens`, `savedRows`, `restoredTokens`,
   `residualPrefillTokens`) as the record of what the rule saw.

## Exits

Not a speed claim and not a gate on the engine: the deliverable is the measured cost, with the paired
rounds, the contamination notes, and an explicit statement of what was not measured. A reading in
which the eviction costs more than the restore buys is a legitimate and decision-relevant outcome.
The registration is frozen at this text; any change of arm, battery, metric or reading after the first
measurement is recorded as a new revision with its reason, not as an edit.
