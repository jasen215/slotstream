---
type: run
id: 01m3ez29wbdc7qgrfk50esynbz
created: 2026-09-26T13:39:24.171488+00:00
updated: 2026-09-26T13:39:40.091525+00:00
summary: The tier now reads a longer state only when it removes a pass of reading or saves rows that pay for its own restore; the equivalence gate, the T0 policy check and the corrected e2e suite all pass
binary: .build/out/Products/Release/slotstream sha256 1096156e50afd323a6de26b2b2904953e8260d2cdd91dc6747e3d7d00446281a
captured_at: 2026-09-26
command: slotstream-checks --tier t0 --filter persistent-prefix
discarded: 'false'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
title: 'Order 344 step 2: admission by saved pass or saved rows'
tool: slotstream-checks, slotstream optimization-state-check, Tools/persistent_prefix_e2e.py
---
# Order 344 step 2: admission by two measured wins

**What this is.** Order 344's step 2, rewritten after step 1's negative result: a candidate disk
state is read only when it removes a pass of reading, or when the rows it saves pay for its own
restore at the cheapest re-read cost ever measured. The rule, its two rejected earlier forms and
the reasons are frozen in the pre-registration's revision 3.

## Identity

- HEAD `21a948e751f671aecdc31dd9a732a67857daa6f2`, working tree dirty with another session's
  changes to `Generate`/`Plan`/`RequestControl`/`Server`/docs. None of them touch the policy,
  the tier or the diagnostics changed here.
- Changed here: `Sources/Slotstream/PersistentPrefixPolicy.swift` (the new pure
  `PersistentPrefixAdmission`: the schedule walk, the fitted restore cost, the cheapest measured
  re-read cost, and `takesDiskState`), `Sources/Slotstream/PersistentPrefixGenerator.swift`
  (`savedRows` and `skippedRestore` observations, the decision, and the skip's reason on the
  observation rather than a silent miss), `Sources/SlotstreamDiagnostics/Diagnostics+PersistentPrefixPolicy.swift`
  (nine assertions on the rule, inside the existing T0 check) and
  `Tools/persistent_prefix_e2e.py` (accounting corrected, see below).
- Binary `.build/out/Products/Release/slotstream`, sha256 `1096156e50afd323a6de26b2b2904953e8260d2cdd91dc6747e3d7d00446281a`; `make build` 121.93 s.
- `Tools/persistent_prefix_e2e.py` sha256 `b63eff9391540ddcc1902086bdc3b50f00a3567d1195677b9bec74914ada306b`.
- Machine [[records/machines/macbook-air-m5-32gb-local]], 13.9 GB reclaimable at launch, one
  model process at a time.

## The rule as implemented

```
takesDiskState  =  passes(from: diskHolds) < passes(from: memoryHeld)
                OR (diskHolds - memoryHeld) * 0.000418 > 0.0213 + 3.946e-06 * diskHolds
```

`passes` walks `PrefillSchedule.next(remaining:at:maxChunk:tailAware:)` under the request's own
chunk and the model's tail-aware setting. The second term's two constants are the fitted restore
cost (n=9, r2=0.954) and the cheapest re-read in the evidence (3921 rows in 1.64 s on a fully
resident pool), both from [[records/measurements/disk-tier-cost-arms-2026-09-26]]. No bespoke
length or cost threshold enters the engine.

## Gates

| gate | result |
| --- | --- |
| `slotstream-checks --tier t0 --filter persistent-prefix` | PASS, 132 assertions (nine new) |
| `slotstream optimization-state-check --memory-gb 10 --variant persistent-prefix --tokens 2051 --json` | `passed: true` |
| `Tools/persistent_prefix_e2e.py --memory-gb 10 --words 2400 --num-predict 48` | 12 of 12 checks pass, exit 0 |

The equivalence gate is the one that matters for safety: a restored state still matches a memory
hit bit for bit with the rule active, and a rule that had refused every restore would have failed
it.

## What the rule decided on a real conversation

| turn | memory offered | rows the disk would save | restored | residual re-read | evicted | restore s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 0 | 0 | 0 | 0 | 0 | - |
| 2, first server | 3840 | 0 | 0 | 0 | 0 | - |
| 3, first server | 3840 | 512 | 4352 | 927 | 2 | 0.0932 |
| 3, restarted server | 0 | 4352 | 4352 | 927 | 0 | 0.0500 |
| 3, regenerated | 0 | 5120 | 5120 | 159 | 0 | 0.0536 |

No restore was skipped in this run, and the two that saved fewer rows than a pass were kept
because they removed one. The co-primary is visible in the first row of turn 3: a 512-row saving
cost 0.0932 s against the fitted 0.0385 s for a state that size, and the difference is the two
conversations evicted to make room. A restore is cheap but it is not free, and the count of what
it displaces is now recorded next to it.

## The tool's stale accounting, corrected here

Five of the e2e's checks asserted the pre-shared-prefix accounting (exactly two heads after turn
2 and turn 3, and no reused bytes on turn 1). The engine writes a shared head and a state head per
conversation-starting turn, so turn 1 leaves two heads — the state descending from the shared head
written in the same turn, which is why it references 99 MB it did not write now — and later turns
leave three while replacing their own ancestor. Recorded actual values:
`after_turn_1 {heads 2, segments 2}`, `after_turn_2 {heads 3, segments 3}`,
`after_turn_3 {heads 3, segments 4}`, listing three states (5120 and 4352 continued, 3584
shared) with `in_use false`. The checks now assert that accounting and the property that still
matters — each turn's state is longer than the one before and reuses its rows — while the
id-equality checks, which never fail, remain the correctness guard.

## What is not here

- No paired A/B and no interleaved rounds: this step adds no read traffic and can only decline to
  read, so its gates are equivalence and accounting, not a speed claim.
- The admission rule's thresholds are not tuned: they follow the schedule and the two fitted
  constants. Step 4's paired A/B is where a throughput claim would come from.
- The eviction's cost to future requests is still unmeasured; only its count is recorded.

Raw output: `.build/disk-prefix-tier-20260926/{state-check-step2.json,e2e-step2.json,e2e-step2.log}`.
Pre-registration: [[sources/docs/2026/09/2026-09-26-disk-prefix-admission-step2-preregistration-rev3]].
