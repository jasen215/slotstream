---
type: run
id: 01m3ght6r562q6qy006cym4jww
created: 2026-09-27T04:26:16.197185+00:00
updated: 2026-09-27T04:26:24.097129+00:00
summary: The rule that could never refuse on the deployed path is gone, replaced by one property assertion on the engine's pass boundaries; the e2e's restore decisions are field-for-field unchanged
binary: .build/out/Products/Release/slotstream sha256 a271a193e872107edf4add94bf3558de2b130c719a34e7ce75d3db67c5b19bc3
captured_at: 2026-09-26
command: slotstream-checks --tier t0 --filter persistent-prefix
discarded: 'false'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
title: 'Order 344: the admission rule removed, its invariant kept as a gate'
tool: slotstream-checks, slotstream optimization-state-check, Tools/persistent_prefix_e2e.py
---
# Order 344: the admission rule removed, its invariant kept as a gate

**What this is.** The decision that followed
[[records/measurements/disk-prefix-admission-is-unreachable-2026-09-26]]: the rule cannot refuse on the
deployed path, so it was removed and the property that made it unnecessary was pinned in the gate
instead. Kept: the accounting that made the eviction visible (`memoryOfferedTokens`, `savedRows`,
`residualPrefillTokens`, `evictionsForRestore`).

## Identity

- Binary `.build/out/Products/Release/slotstream`, sha256 `a271a193e872107edf4add94bf3558de2b130c719a34e7ce75d3db67c5b19bc3`, `make build` 112.58 s.
- Removed from `Sources/Slotstream/PersistentPrefixPolicy.swift`: `PersistentPrefixAdmission` in full
  (58 lines: the two fitted constants, the schedule walk, `takesDiskState`).
- Removed from `Sources/Slotstream/PersistentPrefixGenerator.swift`: the admission guard, the
  `skippedRestore` observation and its decoder entry. The tier reads every longer state its boundary
  and resume rules allow, as it did before order 344.
- `Sources/SlotstreamDiagnostics/Diagnostics+PersistentPrefixPolicy.swift`: the nine rule assertions
  are replaced by one property assertion. It asks the engine's own boundary producer
  (`PrefillSchedule.resumeBoundaries`) for the pass ends of six prompt lengths, walks
  `PrefillSchedule.next` between every pair, and requires that reading from the later boundary always
  costs strictly fewer passes — and that the enumeration is non-empty, so it cannot pass vacuously.
  If a schedule or resume-rule change ever makes a refusal reachable again, this fails first.

## Gates

| gate | result |
| --- | --- |
| `slotstream-checks --tier t0 --filter persistent-prefix` | PASS, 125 assertions (was 132) |
| `slotstream optimization-state-check --memory-gb 10 --variant persistent-prefix --tokens 2051 --json` | `passed: true` |
| `Tools/persistent_prefix_e2e.py --memory-gb 10 --words 2400 --num-predict 48` | 12 of 12, exit 0 |

**Behaviour preserved where it was measured.** The e2e's restore decisions after the removal are
field-for-field the ones revision 4 produced with the rule in place: turn 3 on the first server
offered 3840, saved 512, restored 4352, evicted 2; the restarted server restored 4352; the regenerated
one 5120. That is the same statement as the measurement above, made on the engine rather than on the
argument.

## What is deliberately given up

Under `SLOTSTREAM_OPT_ALIGNED_RESUME=0` and under the tail-aware schedule
(`SLOTSTREAM_OPT_TAIL_SCHEDULE=1`) a longer state may now be read for a saving of a few rows, paying a
restore of a few hundredths of a second for it. Both configurations are non-default, neither is the
target, and neither is measured; a guard for either needs its own registration and its own evidence,
which is exactly the standard the removed rule failed to meet on the deployed path.

Raw output: `.build/disk-prefix-tier-20260926/{e2e-norule.json,e2e-norule.log,state-check-norule.json}`.
