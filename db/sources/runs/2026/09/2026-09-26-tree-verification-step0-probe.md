---
type: run
id: 01m3etw78m5md80er7v69ck7x6
created: 2026-09-26T12:26:10.580700+00:00
updated: 2026-09-26T12:26:17.783898+00:00
summary: Draft head top-k recorded at the probe's argmax line; the ranks do not perturb the chain, and the shape model shows both tree shapes lose throughput
binary: .build/out/Products/Release/slotstream sha256 27ab98f24122d1b0fbb5ccdda93ce1560e433fb96675a8c00064531f3e79d328
captured_at: 2026-09-26
command: slotstream mtp-accept --memory-gb 10 --mtp on --depth 2 --max-tokens 96 --top-k 4 --out .build/tree-verification-20260926/probe-depth2-topk4.json
discarded: 'false'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
title: 'Order 343 step 0: the draft-head rank probe and the lower-bound shape model'
tool: slotstream mtp-accept --top-k, .build/tree-verification-20260926/tree_shape_model.py
---
# Order 343 step 0: the draft-head rank probe, and the shape model it feeds

**What this is.** Order 343's step 0, the observation the pre-registration
(`sources/docs/2026/09/2026-09-26-tree-verification-gdn-hybrid-preregistration-rev3`)
requires before any tree work: the engine's own probe, extended to record the draft head's
top-k at the line where it currently throws everything but the argmax away, plus the offline
lower-bound shape model that recording feeds. No engine arithmetic changed, no tree verify
pass has ever run, and no tree code exists.

## Identity

- HEAD `cebdd8e9e7424ece78bf447a0c41199e6fb6a236`, working tree dirty (another session's
  `Generate`/`Plan`/`RequestControl`/`Server`/`T0Checks`/docs changes, none of which touch
  speculation or this file).
- `Sources/slotstream-cli/MTPCommands.swift` was clean and is the only source file this step
  changed: `GreedyTrace` gains `ranksAt`, plus `DraftRank`, `MTPAcceptDump`, `--top-k` and
  `--out`. The chain still takes rank 0; the ranks are recorded beside it.
- Binary `.build/out/Products/Release/slotstream`, sha256
  `27ab98f24122d1b0fbb5ccdda93ce1560e433fb96675a8c00064531f3e79d328`, built from this tree by
  `make build` (125.13 s, 120/120 targets).
- Machine [[records/machines/macbook-air-m5-32gb-local]]; reclaimable at launch about 14.4 GB
  (free 103,847 + inactive 767,687 + purgeable 31,152 pages of 16 KiB).
- Model `~/.slotstream/models/qwen38-flash-next-mlx-4bit` with `mtp.safetensors`.

## Commands

```
slotstream mtp-accept --memory-gb 10 --mtp on --depth 2 --max-tokens 96 --top-k 4 \
  --out .build/tree-verification-20260926/probe-depth2-topk4.json
slotstream mtp-accept --memory-gb 10 --mtp on --depth 2 --max-tokens 96 --top-k 0
python3 .build/tree-verification-20260926/tree_shape_model.py \
  .build/tree-verification-20260926/probe-depth2-topk4.json \
  --out .build/tree-verification-20260926/tree-shape-model.json
```

**Protocol deviation.** The pre-registration's step 0 command says `--memory-gb 12`. The
12 GB target plus the protocol's 5 GB preflight margin is 17 GB against 14.4 GB reclaimable,
so both runs used 10 GB instead, which is the repository's standard small test size and the
exact configuration the frozen `Tools/fixtures/optimization/qualification/mtp-resource.json`
qualifies. Pool size does not change the arithmetic; it changes expert residency, and this
step measures none of that.

## What happened

Both runs exited 0. They ran sequentially, one model process at a time, with no other
`slotstream` process alive.

**The gate the pre-registration set is met.** With the ranks recorded, the chain, the accept
curve and the ordinary statistics are identical to the run without them: the two reports
diff empty, and in the dump `ranksAt[i][j][0].id == draftsAt[i][j]` at every position. Rank
0 is what the chain takes, so recording the rest cannot move it.

```
draft accept curve (chain-prefix match over 380 positions):
  depth 1:  85.3%  (324/380)
  depth 2:  70.2%  (264/376)
```

Those reproduce the curve recorded when the depth default was adopted (85.8% / 71.0%,
[[records/measurements/the-accept-curve-measured-previously-unpublished-anywhere]]), within
0.5 and 0.8 points, on four prompts and a different build — the probe is measuring the same
thing it always did.

## The shape model, and where the tree loses

`tree_shape_model.py` reads the dump only. Under greedy decoding exactly one child per node
can be accepted, so the first level is exact; **29.5% of the 380 positions (112) went off the
rank-0 path, and there the children of that node were never recorded, so the tree figures are
lower bounds.**

| shape | accepted per pass | gain vs chain-2 | rows | cost x one token | gain / cost |
| --- | ---: | ---: | ---: | ---: | ---: |
| `chain-2` (shipped) | 1.5474 | 1.000x | 3 | 1.330 | 0.752 |
| `tree-4` | 1.6368 | 1.058x | 5 | 1.650 | 0.641 |
| `tree-6` | 1.7237 | 1.114x | 7 | 1.994 | 0.559 |

Cost comes from the measured ladder (verify 2/3/4/5 rows cost x1.17/1.33/1.49/1.65 of a
one-token pass, about 8 ms per extra row;
[[records/measurements/the-plateau-its-ceiling-measured-then-the-a-b-itself-2026-09-02]]).
The 7-row figure is **extrapolated** from that ladder, not measured.

The deciding quantity is not the token gain but what a row buys. Each extra row costs about
1/6 of a one-token pass, so a tree pays only if each extra row buys more than **0.166**
accepted tokens; here 2 extra rows buy 0.089 and 4 buy 0.176, i.e. about **0.044 per row,
roughly 3.8x below break-even.** The per-prompt gains are consistent rather than one outlier:
`tree-6` gains 1.18x, 1.09x, 1.13x and 1.07x on the four prompts, each against roughly twice
the pass cost.

## What is not here

- **No tree verify pass.** No row of any tree has run on the model, so expert bytes per
  committed token — the co-primary gate — is **not measured**; the pre-registration moved that
  half to the step that can measure it. Nothing here says what a tree's expert union costs.
- The 7-row cost is an extrapolation; `mtp-passcost --max-batch 7` would measure it, and that
  is the one number that would move `tree-6`'s reading.
- Four prompts, 380 positions, one machine, one checkpoint, greedy decoding only. The probe's
  own prompts are prose, code, list and reasoning; a tree's gain is a property of how often
  the true token sits below rank 1, which this sample measures but does not exhaust.
- Sampling is not modelled. Under the engine's actual sampler a non-greedy branch can be
  accepted, which would raise a tree's gain; the size of that effect is not measured here.

## Artifacts

| file | sha256 (first 16) |
| --- | --- |
| `probe-depth2-topk4.json` | `e56202d9858ab1b3` |
| `probe-topk4.log` | `bded11e3e8524099` |
| `probe-topk0.log` | `1043e0ccaa15ea74` |
| `tree-shape-model.json` | `d3dee0cd5701e00c` |
| `tree_shape_model.py` | `3b02ac197955e7e5` |

All in `.build/tree-verification-20260926/` (git-ignored scratch); the probe source change is
committed, and the shapes, the prompt set and the gates were frozen before any of this ran.
