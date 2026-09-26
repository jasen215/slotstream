---
type: plan
id: 01m3ecpsva89kcy0xe2x445256
created: 2026-09-26T08:18:32.938619+00:00
updated: 2026-09-26T12:00:57.946010+00:00
summary: 'Tree verification for the GDN hybrid: accepted tokens per verify pass'
date: 2026-09-26
doc: plan
kind: queue-item
level: '2'
order: '343'
title: 'Tree verification for the GDN hybrid: accepted tokens per verify pass'
status: open
---
Opened on 2026-09-26 from the closing state of [[records/plan/decode-forecast-taps-2026-09-14]] – decode
is about 64% GPU compute of verify passes at about 2.1 accepted tokens per pass, and acceptance per pass
is named there as the next lever outside the forecast – and from
[[sources/references/2026/09/2026-09-26-gdn-tree-scan]], prior art for exactly this lever on the same
model family.

## Problem

Speculation here is a single chain at the adopted draft depth of two, verified in one target forward
pass: a **three-row** pass, measured at x1.33 of a one-token pass with every expert resident, against
x1.65 for the five-row depth-4 pass, each extra row costing about 8 ms linearly
([[records/measurements/the-plateau-its-ceiling-measured-then-the-a-b-itself-2026-09-02]]). Correction,
2026-09-26: an earlier version of this paragraph attached 1.65 to the adopted depth; that is the depth-4
number and the fetch-free ceiling with the shipped accept curve is x1.48 at depth 2 against x1.38 at
depth 4, so the cost side of the gate is x1.33. A tree verifies several candidate continuations in
the same forward pass, so it raises committed tokens per pass without changing what "accepted" means.

The difficulty is specific to this model's layers. For an attention-only transformer the verifier needs
an ancestry mask and nothing else; for a recurrent-hybrid model a candidate row must also carry the
recurrent state that native sequential decode would have produced along its root-to-node path, or the
verifier can use a correct mask and still condition on an impossible history. This engine's linear
layers are Gated-DeltaNet with per-position recording (`LinearCache.record`) and
`State.rollback(keeping:of:from:ngramWindow:)`, so the machinery for branch-local state exists, but it
has never been exercised by more than one chain.

There is a second, engine-specific cost the paper's setting does not share: widening verification
activates the union of the experts the tree routes to, and this engine streams experts from the SSD.
Accepted tokens per pass is therefore only half the gate; expert bytes per committed token is the other
half. The paper's +27% is on a different model, a different engine and a clean batch-one gate, and its
equivalence evidence is scoped to a probability-rescore closure rather than a distribution-distance
proof; none of it transfers as a number.

## Steps, in dependency order

0. Observation seam for the draft head, correctness without timing. Record the draft head's top-k
   ids and margins per verify position using the existing forecast record layout with a new tap code,
   and the per-position linear states the shape model needs. Exit: replaying the shipped draft chain
   from the recording reproduces the recorded accepted length for every pass of the same capture;
   a recording that cannot is rejected rather than patched. Note added 2026-09-26: neither input is
   on disk today, so this step precedes the one below rather than being implied by it.
1. Offline shape and acceptance model, no engine change. From the recorded per-position linear states
   and the frozen pilot prompts, compute for candidate trees (node budgets 4 and 6, branching from the
   draft head's own logits at the adopted depth) the accepted chain length and the routed-expert union
   per verify pass, against the shipped chain on the same prompts. Exit: predicted committed tokens per
   verify-forward at least 10% above the shipped chain, with predicted expert bytes per committed token
   no worse than the shipped chain's, before any engine work. A negative reading closes the shape
   question at the terminal and costs no model launch.
2. Branch-local recurrent verification, correctness without timing. Each candidate row carries its own
   linear state; verification publishes state only for the accepted chain; a rejected branch rolls back
   to a recorded state and never re-runs kept tokens. Exit, with the tree forced on for fixed prompts:
   the accepted chain's prompt logits equal the shipped chain's for the same accepted ids within the
   band the shipped re-chunking already moves, `mtp-check`'s fused-versus-stepped identity still holds,
   the `prefix-exact-check` family is unchanged, and with the tree off the ordinary path is
   bit-identical to the shipped build.
3. Attention and indexer composition, correctness without timing. The model's attention is sparse under
   an indexer budget; the tree's ancestry bias must compose with the existing selection without
   widening the attended set beyond the charged budget, and every extra row (attention KV, indexer and
   MoE workspace) must be charged to the request's plan. Exit: measured peak inside the request target
   with the tree on, the requested context window unchanged, and a tree whose charge does not fit is
   refused rather than silently trimmed.
4. Memory and refusal behavior at the floor. Exit: the 8.1 GB floor profile still runs, the ordinary
   path is unchanged, and no tree is enabled by default.
5. Screen and held-out confirmation under the protocols already registered for the forecast program
   (exploration prompts at 256 outputs under the contention rule; eight unused training-split families,
   three rounds at 512 outputs at 20 GB), with every gate stated twice: per accepted token and per
   expert byte read.
6. Changing the default, the draft depth this interacts with, docs and any public number are a separate
   decision after step 5.

## Limits

One machine, one model checkpoint, one SSD. Step 1 is a model of acceptance, not a speed. Tree
verification raises the number of rows per verify forward, so its memory charge grows with breadth and
the planner's existing per-request ceilings are the binding constraint, not the GPU. The external
result's +4.0% per-request-equal latency view means a tree can win token-weighted throughput while
losing per-request latency; both readings must be reported, and the shipped draft depth stays two until
a decision says otherwise.

## Registration

Frozen 2026-09-26 before any data for this question exists:
`.build/tree-verification-20260926/preregistration.md`, sha256
`0489d3dddb7a7913bf36a20721a96c775669160529d0958bad5578a5370c10c7`, committed into the store as
[[sources/docs/2026/09/2026-09-26-tree-verification-gdn-hybrid-preregistration]] so the text outlives
the scratch directory. It names the tree shapes (node budgets 4 and 6, plus the shipped chain and a
tree-off bit-identity control), the branching rule (the draft head's own top-k at each expanded node,
deterministic tie-break by higher margin then lower expert id), the prompt set (the frozen corpus: the
four exploration prompts for the screen, then eight unused training-split families for the confirmation)
and both gates: committed tokens per verify-forward at least 10% above the shipped chain, and expert
bytes per committed token no worse than the shipped chain's. Step 2 is the first engine change and must
not be merged behind a default.
