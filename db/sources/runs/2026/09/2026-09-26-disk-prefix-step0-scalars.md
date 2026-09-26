---
type: run
id: 01m3exmbxbs0ftk9434t9rwc7y
created: 2026-09-26T13:14:18.923737+00:00
updated: 2026-09-26T13:14:25.063813+00:00
summary: memoryOfferedTokens, residualPrefillTokens and evictionsForRestore recorded per request; the equivalence gate passes and a 4352-token restore cost 0.043-0.062 s while still leaving 927 tokens to read
binary: .build/out/Products/Release/slotstream sha256 3c00f6b8ddf895d74e76d71a21ad8e2487cdccba754b69e14db064b5759f17dd
captured_at: 2026-09-26
command: slotstream optimization-state-check --memory-gb 10 --variant persistent-prefix --tokens 2051 --json
discarded: 'false'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
title: 'Order 344 step 0: the three disk-tier scalars and their first numbers'
tool: slotstream optimization-state-check, Tools/persistent_prefix_e2e.py
---
# Order 344 step 0: the three disk-tier scalars, and the first numbers they carry

**What this is.** Order 344's step 0, the observation the plan record and its
pre-registration require before the break-even fit: the three quantities that decide the
comparison, recorded per request. No arithmetic changed and no admission rule exists yet.

## Identity

- HEAD `cebdd8e9e7424ece78bf447a0c41199e6fb6a236`, working tree dirty with another session's
  changes to `Generate`/`Plan`/`RequestControl`/`Server`/`T0Checks`/docs. Those changes do
  not touch the save, parent or lineage paths.
- Changed here: `Sources/Slotstream/PersistentPrefixGenerator.swift` only.
  `PersistentPrefixObservation` gains `memoryOfferedTokens`, `residualPrefillTokens` and
  `evictionsForRestore`, all three are decoded with defaults so older statistics still read,
  and they are filled in `restorePersistentPrefix`. The observation is now created before the
  candidate is chosen, so a request the disk tier refuses still records what memory offered it.
  **No change to `PrefixCache.swift`**: evictions caused by a restore are the difference of
  the existing `evictions` counter around `reserveForRestore`.
- Binary `.build/out/Products/Release/slotstream`, sha256
  `3c00f6b8ddf895d74e76d71a21ad8e2487cdccba754b69e14db064b5759f17dd`, built by `make build` (112.85 s).
- Machine [[records/machines/macbook-air-m5-32gb-local]], about 15.0 GB reclaimable at launch.

## Commands

```
slotstream optimization-state-check --memory-gb 10 --variant persistent-prefix --tokens 2051 --json
python3 Tools/persistent_prefix_e2e.py --memory-gb 10 --words 2400 --num-predict 48 \
  --out .build/disk-prefix-tier-20260926/e2e-step0.json
```

## Results

**The equivalence gate passes.** `optimization-state-check --variant persistent-prefix
--tokens 2051` reports `passed: true` with every item green, and its own measurements include
`continued_restore_seconds 0.0324` and `disk_hit_restore_seconds 0.0342`. A restored state
still equals a memory hit bit for bit, so recording the new fields changed no arithmetic.

**`persistent_prefix_e2e.py`: every id-equality check passes, five bookkeeping checks fail, and
the failure is a stale expectation in the instrument.** Restart, regenerate and cold-identity
checks all pass. The five that fail assert one persisted head per turn
(`after_turn_2 heads == 2`). The engine writes **two** after turn 1 because turn 1 also writes
a shared prefix: that turn's own statistics say `sharedSaveOutcome "saved"`,
`sharedSavedTokens 3584`, and `files after_turn_1 heads 2, segments 2`, then three after turn
2. The tool's expectations predate the shared-prefix feature — this run's sibling record is
from 2026-09-14 and shared prefixes landed 2026-09-16 — and the counts it reads come from the
tier's file listing, which nothing in this change touches. The tool is **not** a CI gate: no
reference to it exists in `Tools/verify.sh`, `Tools/static_gates.sh`, the `Makefile` or the
workflows. Left unchanged here; the check set needs updating.

**The three scalars populate, and they already show the shape of the question.** Six turns of
one conversation on a fresh tier at a 10 GB target:

| turn | memory offered | restored from disk | residual re-read | evicted for the restore | restore s |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 0 | 0 | 0 | 0 | - |
| 2, first server | 3840 | 0 | 0 | 0 | - |
| 3, first server | 3840 | 4352 | 927 | 2 | 0.0616 |
| 3, restarted server | 0 | 4352 | 927 | 0 | 0.0429 |
| 3, regenerated | 0 | 5120 | 0 | 0 | - |
| 2, cold server | 0 | 0 | 0 | 0 | - |

Memory answers first (turn 2 was offered 3840 and took nothing from disk), a restore of 4352
tokens cost 0.043 to 0.062 s and still left 927 tokens to read, and on the first server that
restore evicted two conversations. Those are the two arms of the comparison in one table for
the first time: before this step the second column and the third existed only inside log
strings.

## What is not here

- No fit and no admission rule: this is step 1's input, not its result.
- No paired A/B, no interleaved rounds, and no timing gate is claimed. The restore seconds
  above are single observations beside a partially warm machine; the tool that collected them
  does not judge timings and this record does not either.
- Reclaimable was checked before the run; one model process ran at a time and the e2e tool
  ran its own preflight.

## Findings handed back

- `Tools/persistent_prefix_e2e.py`'s head-count expectations predate shared prefixes and
  should be updated to the engine's actual accounting (a shared head plus a state head).
- The other session's uncommitted `Generate.swift` change adds the same quantity to a log
  line (`memory offered N`), recomputed from `retainedMatchLength`. The statistic above is
  the structured home for it; the log line should read the field rather than recompute it, so
  there is one source rather than two.

Raw output: `.build/disk-prefix-tier-20260926/{state-check-step0.json,e2e-step0.json,e2e-step0.log}`.
Pre-registration: [[sources/docs/2026/09/2026-09-26-disk-prefix-tier-break-even-preregistration]].
