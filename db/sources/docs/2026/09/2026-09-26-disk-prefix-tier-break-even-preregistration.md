---
type: doc-snapshot
id: 01m3esgvebbzrc7bzyy1dajc0m
created: 2026-09-26T12:02:29.451755+00:00
updated: 2026-09-26T12:02:30.025402+00:00
summary: 'Pre-registration for order 344: the disk prefix tier break-even, frozen 2026-09-26'
captured_at: 2026-09-26
dirty: 'true'
git_head: cebdd8e9e7424ece78bf447a0c41199e6fb6a236
original_path: .build/disk-prefix-tier-20260926/preregistration.md
sha256: c020840abf4bf34194658f0b21b66943c9562272ec739a71a54f6fc65756c584
title: 'Pre-registration for order 344: the disk prefix tier break-even, frozen 2026-09-26'
---
# Pre-registration: order 344, the disk prefix tier break-even

Frozen 2026-09-26 before any measurement of this question exists. The plan record is
`db/records/plan/2026-09-26-disk-prefix-tier-break-even.md` (order 344, status open); its
step 1 requires this document first. Nothing here is a result.

## 0. Frozen identities

| Item | Value |
| --- | --- |
| git HEAD | `cebdd8e9e7424ece78bf447a0c41199e6fb6a236` |
| Working tree | dirty: `Sources/Slotstream/{Generate,Plan,RequestControl,Server}.swift`, `Sources/SlotstreamTestKit/T0Checks.swift`, `docs/{CLI,ENGINEERING}.md`, `llms-full.txt`, plus three untracked files. **Unlike order 343, the dirty hunks DO reach this record's code**: `Generate.swift` shifts by 8 lines from line ~700, and the disk-tier decision path sits at ~648 to ~703, so every line anchor below is the working tree's and any patch must re-anchor after that session commits. |
| Machine | [[records/machines/macbook-air-m5-32gb-local]] |
| Binary | `.build/out/Products/Release/slotstream`, sha256 `f449f0019cc2439a5436885a7c7d14dde033e57f71d7b790f64ef85d323f10b3` |
| Model | `~/.slotstream/models/qwen38-flash-next-mlx-4bit`; identity checked by `slotstream pull --verify` |
| `Sources/Slotstream/PersistentPrefixGenerator.swift` | sha256 `cda64da4acc47c29` |
| `Sources/Slotstream/PersistentPrefixCache.swift` | sha256 `0f9896af4d6bdce3` |
| `Sources/Slotstream/PersistentPrefixPolicy.swift` | sha256 `9d325b33f1c6fde6` |
| `Sources/Slotstream/PersistentPrefixRestore.swift` | sha256 `1ac45c830b9d3ee1` |
| `Sources/Slotstream/PersistentPrefixSave.swift` | sha256 `1bd42c3dd2085777` |
| `Tools/persistent_prefix_e2e.py` | sha256 `2ca2279bfc2e36dd` |
| `Tools/verify.sh` | sha256 `4b97bf005cbe1ca7` |

## 1. Input availability, checked before writing this

**The disk arm is instrumented.** `PersistentPrefixObservation`
(`Sources/Slotstream/PersistentPrefixGenerator.swift:9-28`) records `restoredTokens`,
`restoreSeconds` and `restoreBytes` per request, filled at `:107-109`, logged as
`restored N tokens (X MB) in Y s` (`PersistentPrefixRestore.swift:26`) and printed by
`main.swift:696`. Two boundaries must be stated in any use of it: the timer starts *inside*
the operations lock (`PersistentPrefixRestore.swift:14-15`), so it excludes time waiting for
the lock, and it starts *after* `reserveForRestore` has already evicted to make room
(`PersistentPrefixGenerator.swift:96` is before `:104`). The tier's own `json()` carries no
duration field at all.

**The recompute arm has no same-request counterfactual.** `GenStats.prefillTokens` merges
the resumed and the residual re-read tokens into one number
(`Generate.swift:1201`), `memoryOffered` exists only inside a log string
(`Generate.swift:695-697`, from `retainedMatchLength`) and never enters `GenStats`, there is
no field for the distance back to the request's own aligned boundary, and an eviction caused
by a restore is not attributed (`PrefixCache.swift:474` to `:503` to `:796` increments one
global counter).

**The existing harness does not judge cost.** `Tools/persistent_prefix_e2e.py` starts a real
`serve --prefix-cache-dir` and gates correctness and id equality across first/restart/
regenerate/cold; it collects prefill and restore timings but makes no decision from them, so
citing it as break-even evidence would be a misuse. `optimization-state-check --help`'s
`--variant` list is **stale**: it does not name `persistent-prefix[-mtp]`, yet
`OptimizationCommands.swift:155-158` dispatches them (and `-mtp` is a value suffix, not a
flag). Trust the dispatch, not the help text.

**What can be derived without new data.** The recompute arm's token distance is
deterministic: given the prompt length and the chunk size, the request's own resume
boundaries decide how far back a re-read goes (`PrefillSchedule.resumeBoundaries`,
`Sources/Slotstream/Context.swift:225`), and a weights-free estimator already exists
(`PrefillSchedule.estSeconds(tokens:from:maxChunk:)`, `Context.swift:288`). The disk arm's
cost is recorded. So a two-arm cost model can be fitted from recorded turns; what cannot be
recovered from history is the *paired* comparison for one and the same turn, which is why
the gate that decides is G4's paired A/B and not the fit.

**Decision, step 0.** Add exactly three scalars so the fit is not blind and the admission is
checkable: `memoryOfferedTokens` and `residualPrefillTokens` on
`PersistentPrefixObservation`, filled in the disk-decision path, and `evictionsForRestore`
on `reserveForRestore`. No arithmetic changes. Exit: with the tier off the ordinary
statistics are byte-identical to the shipped build's, and where a value appears both in a log
line and in a statistic the two agree.

**Correction to the plan record.** Step 1 says both arms "are already instrumented in the
prefix and disk receipts". That holds for the disk arm only; the record now says so.

## 2. The question

For a candidate conversation state, is reading it from the SSD and restoring it cheaper than
recomputing the same length from the request's own last aligned pass boundary — and if the
answer depends on length, where is the break-even, measured rather than assumed? Under the
aligned-resume rule a memory hit is worth only the distance back to that boundary, so the
comparison is between a restore plus a short residual re-read and a longer re-read.

## 3. Arms

| arm | what it is |
| --- | --- |
| `memory-hit` | a state served from the retained in-memory set; the reference, unchanged |
| `disk-restore` | the same state served from `--prefix-cache-dir`: read, CRC, restore into buffers of the saved shape |
| `recompute` | no state taken: re-read from the request's own last aligned boundary to the same length |
| `policy` | per candidate state, take whichever of `disk-restore` and `recompute` the fitted cost model says is cheaper |

The policy is a pure function of the fitted constants, which is what makes G2 checkable: flip
the constants in a test and the decision must flip with them. **No length or cost threshold
may be hardcoded in the engine** — verified today: `PersistentPrefixPolicy.bestMatch`
(`PersistentPrefixPolicy.swift:145`) selects a candidate and applies no cost comparison, and
`minimumTokens` gates only what gets written.

## 4. Declared commands and the recorded turns

```
# the correctness gates that must stay green through every step
slotstream optimization-state-check --variant persistent-prefix --tokens 2051 --json
slotstream optimization-state-check --variant persistent-prefix-mtp --tokens 2051 --json
python3 Tools/persistent_prefix_e2e.py --memory-gb 10 --words 2400 --num-predict 48
slotstream prefix-check
slotstream prefix-exact-check
.build/release/slotstream-checks --tier t1 --filter persistent-prefix-round-trip

# the fit (step 1) reads recorded turns only; the A/B (step 4) is the new measurement
```

Turns used for the fit, all already in the store:
[[sources/runs/2026/09/2026-09-14-persistent-prefix-segments-exactness]],
[[sources/runs/2026/09/2026-09-14-persistent-prefix-segments-e2e]] and
[[sources/runs/2026/09/2026-09-14-persistent-prefix-segments-long-conversation-e2e]]. The
2026-09-16 shared-prefix runs may inform the shared-prefix boundary only, not the
break-even. [[sources/runs/2026/09/2026-09-26-m5-air-live-agent-session]] is **excluded from
the fit**: it is marked discarded, it has no timing, and its value is qualitative — on this
32 GB machine 24 disk reuses were offered zero memory tokens and only one request hit
memory at all, which is the observation that makes the disk tier worth measuring here.

## 5. Metrics

- `restoreSeconds`, `restoreBytes`, `restoredTokens` per restore, and the same for the save
  side. Disk arm.
- `prefillSeconds` per request with the residual token count from the new
  `residualPrefillTokens`, so the recompute arm's cost per token is separable from the
  resumed prefix. Recompute arm.
- `prefillTokens` before and after step 0, to prove the split changed no arithmetic.
- `evictionsForRestore`, so a restore that buys time by evicting another conversation cannot
  look free.
- Process footprint and the planner's target, and the requested context window: a policy
  that wins time by holding more state has to show what it paid.

## 6. Gates

- **G1, the two cost models, before any engine change.** Fitted over the recorded turns,
  each arm separately, with its residual and the range it was fitted over reported, and with
  no length threshold written anywhere in the engine. A fit whose residual spans the whole
  decision range is a negative result and stops the record there.
- **G2, admission in the cache.** The decision is computed from the fitted constants and
  flips when they flip; `optimization-state-check --variant persistent-prefix` and
  `persistent-prefix-mtp` still bit-match a memory hit; `Tools/persistent_prefix_e2e.py`
  still passes; the aligned-resume rule, the four-conversation ceiling, the shared-token
  ceiling and the miss-eviction order are unchanged.
- **G3, queued preload, bounded.** Starts a read only for a request that already owns its
  guards or is queued, inside the existing staging and reservation accounting; footprint at
  the target; no read for a request that never proceeds; cancellation drains workers; a
  rejected request leaves no partial state visible to the next one.
- **G4, paired A/B, interleaved.** Identical outputs; aggregate at least 1.02 with the lower
  bootstrap bound above 1.00; no family median below 0.97 on the short-turn family; no
  long-turn duration regression above 2%. A reading that favours recomputation everywhere is
  a legitimate outcome and closes the record by recording that the disk tier is not the
  lever for short prefixes.
- **G5.** Changing a default, docs or any public number is a separate decision after G4.

## 7. Reporting, append-only

Raw output lands in `.build/disk-prefix-tier-20260926/` first with its sha256, then a
`db/sources/runs/` record; the measurement record links it; public numbers need claims. This
file is never edited after the first data exists — only appended to through the record's log
with the reason and the time.

## 8. Resource and memory discipline

One model process at a time; `Tools/persistent_prefix_e2e.py` already refuses a second
process and runs a reclaimable preflight, and its `--memory-gb` is hard-limited to 8.1
through 10, which this work keeps. Reclaimable memory checked before every heavy step;
`.build/` is git-ignored scratch. Global paging counters stay diagnostics. No policy is
enabled by default while it is being measured.

## 9. Outcome states

- **positive**: G1 fits with a usable residual, G2 and G3 pass, and G4's aggregate clears
  1.02 with its lower bound above 1.00; then a default change is its own decision.
- **negative at the fit**: the residuals span the decision range; the record closes with the
  measured statement that the break-even cannot be resolved at this scale.
- **negative at the A/B**: the policy does not clear 1.02, or a family regresses; the disk
  tier keeps serving only the long states it serves today, recorded as a result.
- **negative at correctness**: G2 fails; no admission change ships.

## 10. Execution checklist

1. Re-check the working tree; re-anchor every line in section 0 if that session has
   committed.
2. Step 0's three scalars; ordinary statistics unchanged with the tier off; log and
   statistic agree.
3. Fit both arms from the recorded turns; report residuals and fitted ranges; stop on a
   negative G1.
4. Implement admission; run the correctness gates; check the decision flips with the
   constants.
5. Bounded queued preload, then the paired interleaved A/B on the short-turn and long-turn
   workloads.
6. Record, project (`Tools/projections.py`), gate (`Tools/brain_gates.sh`), commit.

## 11. Known gaps

- `restoreSeconds` excludes lock waiting and the eviction it triggers, so the fitted disk
  curve is a **lower bound** on the true cost of choosing the disk. G4's paired A/B is the
  instrument that can settle that; the fit cannot.
- The counterfactual link between the two fitted models is a model. Its residual is the
  honest uncertainty of the admission, and G4 is what tests it on real turns.
- One machine and one internal SSD: the break-even is a property of this disk, this model's
  pass structure and the current planner, and must be re-derived, not carried, elsewhere.
- The prior art's negative prefetch result is from PCIe-attached tiers with GPU HBM and a
  simulated execution model, so it does not transfer to reading a local SSD into unified
  memory; its capacity-over-placement finding is why this record measures admission instead
  of a new placement policy.
- The 2048-token write minimum, the 512-token shared minimum, the 20 GB quota and the
  30-day age are interim values, not measured optima
  ([[records/design/measured-operating-policies]]); this record does not change them.
