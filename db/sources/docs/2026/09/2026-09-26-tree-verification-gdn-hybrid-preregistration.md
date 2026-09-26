---
type: doc-snapshot
id: 01m3esdk8kepggnyhs8a6ffqs6
created: 2026-09-26T12:00:42.771022+00:00
updated: 2026-09-26T12:00:46.795347+00:00
summary: 'Pre-registration for order 343: tree verification for the GDN hybrid, frozen 2026-09-26'
captured_at: 2026-09-26
dirty: 'true'
git_head: cebdd8e9e7424ece78bf447a0c41199e6fb6a236
original_path: .build/tree-verification-20260926/preregistration.md
sha256: 0489d3dddb7a7913bf36a20721a96c775669160529d0958bad5578a5370c10c7
title: 'Pre-registration for order 343: tree verification for the GDN hybrid, frozen 2026-09-26'
---
# Pre-registration: order 343, tree verification for the GDN hybrid

Frozen 2026-09-26 before any data for this question exists. The plan record is
`db/records/plan/2026-09-26-tree-verification-gdn-hybrid.md` (order 343, status open); its
step 1 requires this document first. Nothing here is a result; every gate below is stated
before the data it will be judged on.

## 0. Frozen identities

| Item | Value |
| --- | --- |
| git HEAD | `cebdd8e9e7424ece78bf447a0c41199e6fb6a236` |
| Working tree | dirty: `Sources/Slotstream/{Generate,Plan,RequestControl,Server}.swift`, `Sources/SlotstreamTestKit/T0Checks.swift`, `docs/{CLI,ENGINEERING}.md`, `llms-full.txt`, plus untracked `Sources/SlotstreamDiagnostics/Diagnostics+FailureReporting.swift`, `docs/MEASURE-MEMORY-HEADROOM-AB.md`, `docs/m5-32gb-ssd-streaming-ctx65536-2026-09-24.md` (8 tracked files, +41/-1 lines). **Checked:** no hunk touches `draft`, `specul`, `effectiveDraftDepth`, `rollback` or `mtp`, so the speculation baseline is the committed one. |
| Machine | [[records/machines/macbook-air-m5-32gb-local]] |
| Binary | `.build/out/Products/Release/slotstream`, sha256 `f449f0019cc2439a5436885a7c7d14dde033e57f71d7b790f64ef85d323f10b3` |
| Model | `~/.slotstream/models/qwen38-flash-next-mlx-4bit`, draft head `mtp.safetensors`; identity checked by `slotstream pull --verify` |
| `Tools/verify.sh` | sha256 `4b97bf005cbe1ca7` |
| `Sources/slotstream-cli/MTPCommands.swift` | sha256 `1a7e54381bccd0cd` |
| Corpus | `Tools/fixtures/expert-lookahead/corpus.json` sha256 `adac22f1b1439be4638dad1e05809162924f796e1c7fe7ad80f3348d97ea17d5`, version 1, seed 1729, 95 families, 307 requests |
| Adopted draft depth | 2 (`draft_depth: 2`, `mtp: on`), `Generator.defaultDraftDepth` |
| Speculation region | `Sources/Slotstream/Generate.swift:1255-1618`; the dirty hunk is at ~691, so this region is HEAD semantics |

## 1. Input availability, checked before writing this

The capture seam records ten shard record kinds. Verified by reading the parser
(`Tools/expert_lookahead.py`, `parse_record`): kind 1 pass begin (phase, tokens, nanos),
kind 2 token/position with context and embedding, kind 3 per-layer routing ids, kind 4 the
router input `x2`, kind 5 demand events with start/read/adopt/end and hit/miss/victim sets,
kind 6 experts, kind 7 residency snapshots, kind 8 the pass's `kept` accepted length,
kind 9 pass end with nanos, kind 10 forecasts as rows x per-row ids and margins.

**What this gives the tree question.** Kind 8 is the shipped chain's own acceptance, so
"committed tokens per verify pass" has a recorded baseline; kinds 1 and 9 give pass timing;
kind 5 gives the miss sets and read counts that the second gate needs.

**What does not exist.** No record kind carries the **draft head's candidate distribution**
at a verify position, and nothing records the draft head's input hidden state. A tree's
branching rule has nothing to branch on in the recorded data, so step 1 as written ("compute
the accepted chain length for candidate trees from the recorded per-position linear states
and the draft head's own logits") **cannot be computed from existing artifacts**.

**Second missing input.** Step 1 as written also names "the recorded per-position linear
states". Those do not exist on disk either: `LinearCache.record` (`Sources/Slotstream/Layers.swift:364-412`)
keeps the per-position state in memory for the duration of one verify pass and nothing
persists it to a fixture, and `MTPAccept.probeGreedy`
(`Sources/slotstream-cli/MTPCommands.swift:168-195`) records only the greedy `argMax`
continuation, not the ranks below it. So both of step 1's named inputs have to be produced
by step 0, and the plan record's step 1 wording is corrected accordingly.

**Decision.** Step 0 below extends the observation seam rather than changing the engine's
arithmetic: emit the draft head's top-k ids and margins per verify position using the
**existing kind 10 layout** with a new tap code, at no model-arithmetic change. Its gate is
self-referential and checkable: replaying the shipped draft chain from the recording must
reproduce kind 8's `kept` for every pass of the same capture, or the recording is rejected.

## 2. The question

At the adopted draft depth of two, does a tree with node budget 4 or 6 raise committed
tokens per verify forward pass by at least 10% over the shipped chain, **without** raising
expert bytes per committed token, on this engine and this SSD? The second half is the
engine-specific half: a wider tree activates the union of its branches' experts, and those
experts are streamed from disk.

## 3. Arms

| arm | what it is |
| --- | --- |
| `chain-2` | the shipped chain at draft depth 2, the reference |
| `tree-4` | node budget 4: two levels of branching factor 2 from the reference chain's first node |
| `tree-6` | node budget 6: branching factor 2 at the first node and 3 at the second, or 3 then 2, whichever the declared rule yields |
| `tree-off` | the shipped build with the tree path disabled, a bit-identity control |

The branching rule is the draft head's own top-k at each expanded node, k = 2 (and 3 only
for the budget-6 arm at one level), deterministic tie-break by higher margin then lower
expert id. No arm may substitute an expert, prune the model, or change what "accepted"
means: a node is accepted exactly when the target's own verification accepts it.

## 4. Declared shapes and the exact commands

Step 0, the capture extension, is the only engine change before step 1 and is arithmetic
inert (observation only). **`--draft-topk` does not exist yet**: it is the interface this
step adds, and the command below is therefore the shape of the step, not something that can
be run today.

```
# after the seam records the draft head's top-k with a new tap code, capture the frozen prompts
Tools/expert_lookahead.py capture --protocol .build/tree-verification-20260926/protocol.json \
  --out .build/tree-verification-20260926/capture \
  --requests .build/tree-verification-20260926/requests.jsonl \
  --features off --x2 on --capture on --forecast-taps attention \
  --forecast-inputs on --forecast-per-row 24 --draft-topk on
```

Step 1 replays the recording offline: for every verify pass, reconstruct the reference
chain's acceptance from the recorded draft top-k, then expand each declared tree, and
compare against kind 8's recorded `kept` on the same pass (the self-check of section 1).
It uses no new engine path, and the probe that produces the ranks is
`mtp-accept --depth 2` extended to record the draft logits' 2nd and 3rd places, on the
frozen prompts, with `mtp-passcost --positions 8 --max-batch 5` supplying the width cost.

Steps 2 to 5 use the existing gates as they are written: `mtp-check`
(whose output must contain `MTP CHECK PASS`, exactly one `MTP CHECK MEMORY` line and
`memory_validated is True`, per `Tools/verify.sh:202-211`), `mtp-parity --fixture`,
`mtp-rowcheck` (verify rows equal plain decode bit for bit), the `prefix-exact-check`
family, `Tools/verify.sh`'s `prefix-check`/`prefix-exact-check` entries, and
`optimization-state-check` with the frozen `mtp-*` variants. The screen and the held-out confirmation reuse the
forecast program's protocols: exploration prompts r0005, r0206, r0096, r0074 at 256 outputs
under the contention rule, then eight unused training-split families, three rounds at 512
outputs at 20 GB.

## 5. Metrics

- **Committed tokens per verify forward pass** = `GenStats.acceptedDrafts / verifyPasses`
  (`Sources/Slotstream/Generate.swift:232,233`, printed by `main.swift:545`); the recorded
  baseline is about 2.1. Kind 8's per-pass `kept` gives the same quantity per pass. Primary.
- **Expert bytes per committed token** = `GenStats.decodeReadBytes / decodeTokens`, where
  `decodeReadBytes = pool.recordsFetched * pool.recordBytes` (`Generate.swift:1333`,
  `Sources/Slotstream/ExpertStore.swift:178-186`). Co-primary; a tree that wins the first
  and loses this one has failed. `--stats-json` exports the whole `GenStats`
  (`main.swift:493-524`), so both are readable without a new counter.
- **The width cost is measured and linear.** `mtp-passcost`, every expert resident at
  57/layer: one token 48.3 ms; 2/3/4/5 rows 56.7/64.2/72.1/79.8 ms = x1.17/x1.33/x1.49/x1.65.
  The adopted depth-2 chain is a **three-row** pass, so its cost is **x1.33**; x1.65 is the
  five-row depth-4 pass. The fetch-free ceiling with the shipped accept curve is x1.48 at
  depth 2 and x1.38 at depth 4
  ([[records/measurements/the-plateau-its-ceiling-measured-then-the-a-b-itself-2026-09-02]]).
  Every gate below is judged against x1.33, and any earlier text in this program that
  attached 1.65 to the adopted depth is a misattribution.
- Per-request latency ratio, reported separately: the external result's own view is +4.0%
  per-request-equal while winning token-weighted throughput, and both readings must appear.
- Acceptance per verified position, so a tree that mostly wastes rows is visible.

## 6. Gates

- **G1, offline shape, before any engine change.** Predicted committed tokens per verify
  forward at least 10% above `chain-2` on the frozen prompts, with predicted expert bytes
  per committed token no worse than `chain-2`'s. A negative reading closes the shape
  question at the terminal and costs no model launch.
- **G2, correctness without timing.** With the tree forced on for fixed prompts: the
  accepted chain's prompt logits equal the shipped chain's for the same accepted ids within
  the band re-chunking already moves, `mtp-check`'s fused-versus-stepped identity still
  holds, the `prefix-exact-check` family is unchanged, and with the tree off the ordinary
  path is bit-identical to the shipped build.
- **G3, budget without timing.** Peak inside the request's target, requested context window
  unchanged, every extra row (attention KV, indexer, MoE workspace) charged to the plan, and
  a tree whose charge does not fit is refused rather than silently trimmed.
- **G4, memory floor.** The 8.1 GB profile still runs, the ordinary path is unchanged, and
  no tree is enabled by default.
- **G5, screen then held-out confirmation.** Under the forecast program's registered
  protocols with every gate stated twice: per accepted token and per expert byte read.
  Identical outputs are a precondition of every timing cell.

A failing gate closes its question instead of being tuned around. Changing the default, the
draft depth this interacts with, any doc text and any public number are a separate decision
after G5.

## 7. Resource and memory discipline

One model process at a time, checked with `pgrep -fl slotstream` before launch and killed
the moment a test ends; reclaimable memory checked before every heavy step (`slotstream
doctor` prints it), with the preflight margin the protocol driver enforces (target plus
5 GB); small explicit test sizes at the 8.1 GB floor and a 10 GB target unless the larger
configuration is itself the measurement; `.build/` is git-ignored scratch. Global paging
counters are diagnostics, never a gate. No arm may be enabled by default while it is being
measured.

## 8. Reporting, append-only

Raw output lands in `.build/tree-verification-20260926/` first, its sha256 and the machine
recorded in a `db/sources/runs/` record; the measurement record links it, and every number
that reaches a public surface needs a claim. A negative result is recorded as a result: this
file is never edited after the first data exists, only appended to through the record's log
with the reason and the timestamp.

## 9. Outcome states

- **positive**: G1 passes and G5's confirmation passes both readings; the tree becomes a
  candidate for a default change, which is its own decision.
- **negative at the terminal**: G1 fails; the shape question closes, no engine change is
  attempted, and the record states the measured predicted ceiling.
- **negative at correctness or budget**: G2 or G3 fails; the tree is kept out of the engine
  and the failing property is named.
- **negative at the screen**: identical outputs but no ratio above 1; recorded as such, and
  the default stays two.

## 10. Execution checklist

1. Confirm the working tree's dirty paths still do not touch speculation; record HEAD.
2. Extend the seam for the draft head's top-k; run its self-check against kind 8.
3. Capture the frozen prompts; validate the shards.
4. Step 1 offline; stop at a negative G1.
5. Steps 2 to 4 as separate correctness and budget gates, never merged behind a default.
6. G5's screen, then its held-out confirmation, under the contention rule.
7. Record, project (`Tools/projections.py`), gate (`Tools/brain_gates.sh`), commit.

## 11. Known gaps

- The draft head's own distribution is not recorded anywhere today; step 0 is the smallest
  seam that fixes it, and if the recording cannot reproduce kind 8's acceptance it is
  rejected rather than patched.
- Step 1 is a model of acceptance, not a speed. Breadth costs rows, so the planner's
  per-request ceilings are the binding constraint, not the GPU.
- The prior art's +27% is a different model, engine and batch-one gate, and its equivalence
  evidence is a probability-rescore closure rather than a distribution-distance proof; no
  number from it transfers.
- One machine, one checkpoint, one SSD: the break-even of breadth against streamed bytes is
  a property of this disk and planner and must be re-derived, not carried.
