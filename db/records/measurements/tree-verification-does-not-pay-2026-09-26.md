---
type: measurement
id: 01m3etw7ayth9m64hcx80v3ghm
created: 2026-09-26T12:26:10.654748+00:00
updated: 2026-09-26T12:26:10.686647+00:00
summary: Chain accepts 1.5474 tokens per verify pass at x1.33; a 4-row tree 1.6368 at x1.65 and a 6-row tree 1.7237 at x1.99, so gain over cost falls from 0.752 to 0.641 and 0.559
date: 2026-09-26
doc: measurements
level: '3'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
note: Lower-bound acceptance from the draft head's recorded ranks; no tree row has ever run, so expert bytes per committed token is not measured, and the 7-row cost is extrapolated.
order: '1671'
runs: '[[sources/runs/2026/09/2026-09-26-tree-verification-step0-probe]]'
title: A verification tree does not pay at the adopted draft depth on this engine
status: measured
---
# A verification tree does not pay at the adopted draft depth on this engine

**Result.** At the adopted draft depth of two, a two-level tree buys too little acceptance
for the rows it costs. Measured over the engine's own four probe prompts, 380 positions,
using the draft head's recorded ranks and the measured per-row pass cost: the shipped
two-draft chain accepts **1.5474** tokens per verify pass at **x1.33** of a one-token pass;
a 4-new-row tree accepts 1.6368 (**+5.8%**) at x1.65; a 6-new-row tree accepts 1.7237
(**+11.4%**) at x1.99. Gain divided by cost is **0.752** for the shipped chain against
**0.641** and **0.559** for the trees, so both shapes lose throughput, the larger one by
about 26%. Order 343's step 1 gate asked for at least +10% committed tokens per verify
forward; only `tree-6` clears the token bar, and it does so at roughly twice the pass cost.

**The criterion, which outlives these two shapes.** Every extra verify row costs about one
sixth of a one-token pass (about 8 ms on a 48.3 ms pass; verify 2/3/4/5 rows measured at
x1.17/1.33/1.49/1.65), so a tree pays only if each extra row buys more than **0.166**
accepted tokens. Measured, each extra row buys about **0.044** — roughly 3.8x below
break-even, and consistent across the two shapes and across all four prompts (tree-6 gains
1.18x, 1.09x, 1.13x, 1.07x per prompt, each against about double the pass cost). Any future
tree proposal on this engine has to move that number, not the acceptance percentage.

**Why the gain is small.** The chain already accepts 70.2% of its depth-2 chains, so the
cases a tree can rescue are the ones where the true continuation sits at rank 2 or below at
the first node. A wider level 1 converts those into one accepted token; it does not convert
them into a longer chain, because under greedy decoding the second level only continues
through the true token's own child.

**Method.** The engine's own probe (`slotstream mtp-accept`, extended to record the draft
head's top-k at the point where it previously kept only the argmax; rank 0 remains what the
chain takes, and with ranks on the report is byte-identical to a run with them off) at
`--depth 2 --max-tokens 96` on the four frozen probe prompts, at a 10 GB target on
[[records/machines/macbook-air-m5-32gb-local]], binary sha256
`27ab98f24122d1b0fbb5ccdda93ce1560e433fb96675a8c00064531f3e79d328`. The offline model
(`.build/tree-verification-20260926/tree_shape_model.py`) reads that recording only; it never
runs the model and assumes greedy decoding, under which exactly one child per node can be
accepted. The accept curve it reproduces, 85.3% at depth 1 and 70.2% at depth 2, matches the
curve recorded when the depth default was adopted (85.8% / 71.0%) within 0.8 points.

**Limits.** The tree figures are **lower bounds**: 29.5% of positions went off the rank-0
path, and the probe follows the draft head along that path only, so a non-rank-0 node's
children were never recorded. Expert bytes per committed token — the co-primary gate — is
**not measured at all**: no tree row has ever run on the model. The 7-row cost is
extrapolated from a ladder measured to 5 rows. Four prompts, one machine, one checkpoint,
greedy only; under the real sampler a non-greedy branch can be accepted, which would raise a
tree's gain by an unmeasured amount. The prior art's +17.2% committed tokens per event is not
contradicted by this: its engine is not this one, and this result is a statement about rows
costing about a sixth of a pass each here.

**What this closes, and what it does not.** It closes the shape question at the adopted depth
with the evidence available, which is why order 343's steps 2 through 5 — the branch-local
recurrent verification, the ancestry mask, the budget work and the native screen — were not
executed; the plan record is withdrawn with that reason and the tree shape is not built. It
does not close: a tree at a longer chain depth, where the baseline already pays for more rows
and the relative row overhead is smaller; a tree whose rows are cheaper than 8 ms each; or the
sampling case above. Each of those is a different question and needs its own registration.

Raw output: [[sources/runs/2026/09/2026-09-26-tree-verification-step0-probe]].
Pre-registration frozen before the data:
`500bd3186ef809fa836c0810eccc1a29ce64948dd28dad2ea4c13c92fe07112f`
([[sources/docs/2026/09/2026-09-26-tree-verification-gdn-hybrid-preregistration-rev3]]).
