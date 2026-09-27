---
type: run
id: 01m3ge1w9x8pxedj2m1d6f99fq
created: 2026-09-27T03:20:33.341575+00:00
updated: 2026-09-27T03:20:34.268780+00:00
summary: The rule now credits a saving at 5.80 ms per row, the cheapest re-read measured where the model did not fit, instead of 0.42 ms on a fully resident pool; all three gates pass
binary: .build/out/Products/Release/slotstream sha256 a8f65db31e4666db92714b89a760251011599bef10057501e14d068cfbf7b590
captured_at: 2026-09-26
command: slotstream-checks --tier t0 --filter persistent-prefix
discarded: 'false'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
title: 'Order 344 step 2 revision 4: the admission rule''s read rate recalibrated to the target configuration'
tool: slotstream-checks, slotstream optimization-state-check, Tools/persistent_prefix_e2e.py
---
# Order 344 step 2, revision 4: the admission rule's read rate recalibrated to the target

**What this is.** Step 4 measured what this engine actually pays to read, and the admission rule's
second term was crediting a saving at a rate from the one configuration this engine does not target.
The rule now credits the cheapest re-read measured *in* the target configuration. Revision 4 of the
pre-registration carries the reasoning; this record carries the change and its gates.

## Identity

- Binary `.build/out/Products/Release/slotstream`, sha256 `a8f65db31e4666db92714b89a760251011599bef10057501e14d068cfbf7b590`, `make build` 109.97 s.
- `PersistentPrefixPolicy.swift`: `cheapestReadSecondsPerRow` becomes `21.22 / 3660` (5.80 ms per
  row, 2026-09-16 shared-prefix run, a configuration where the model did not fit) from `1.64 / 3921`
  (0.42 ms per row, a fully resident pool). The first term is unchanged.
- `Diagnostics+PersistentPrefixPolicy.swift`: the refusal assertion moves to a saving of four rows,
  which is what the new rate declines; everything else is unchanged.
- Machine [[records/machines/macbook-air-m5-32gb-local]], 14.0 GB reclaimable at launch.

## Why

Step 4 read the same 3849-row prompt cold in 70.7 to 73.1 s and read a 265-row post-restart residual
in 20.5 s: 18.5 ms per row amortized and 77 ms per row on the first pass
([[sources/runs/2026/09/2026-09-26-disk-prefix-step4-paired-ab]]). At the old rate a 4k-row restore
needed about 90 saved rows to pay for itself, so the rule would have declined savings of 8 to 90 rows
that the target configuration pays for many times over — 64 rows cost about 1.2 s there against a
0.038 s restore. It is the "an estimator may not return a value outside the range it measured" mistake
in the direction that loses time: the 0.42 ms rate was measured on a pool holding the whole model.
The new rate puts the break-even for a 4k-row state at about seven rows, so the term now declines only
a state that is effectively the length memory already holds — the case it exists for — while still
covering a tail-aware schedule, where the pass-count term collapses and the row term has to decide.

## Gates

| gate | result |
| --- | --- |
| `slotstream-checks --tier t0 --filter persistent-prefix` | PASS, 132 assertions |
| `slotstream optimization-state-check --memory-gb 10 --variant persistent-prefix --tokens 2051 --json` | `passed: true` |
| `Tools/persistent_prefix_e2e.py --memory-gb 10 --words 2400 --num-predict 48` | 12 of 12, exit 0 |

The run's own decisions are unchanged where the rule was already taking the state: the first server's
turn 3 saved 512 rows and took the 4352-row restore (0.0572 s, two conversations evicted), and the
restarted server saved 4352 and took it (0.0429 s). No turn skipped a restore, which is the same
observation as step 4's: with the measured cost of reading, there is nearly nothing left to decline.

## Limits

The new rate is the cheapest of four streaming re-reads measured across two sessions of runs
(5.80 to 14.24 ms per row) plus step 4's 18.5 ms amortized; a faster target machine could read more
cheaply still, and the rule is only as good as that floor. One machine, one SSD, `--memory-gb 10`,
no images and no speculation interaction. The refusal regime remains unexercised by every workload
recorded so far.

Raw: `.build/disk-prefix-tier-20260926/{state-check-rev4.json,e2e-rev4.json,e2e-rev4.log}`.
Pre-registration: [[sources/docs/2026/09/2026-09-26-disk-prefix-admission-step2-preregistration-rev4]].
