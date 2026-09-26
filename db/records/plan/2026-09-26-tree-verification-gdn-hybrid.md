---
type: plan
id: 01m3ecpsva89kcy0xe2x445256
created: 2026-09-26T08:18:32.938619+00:00
updated: 2026-09-26T13:00:36.650880+00:00
summary: 'Tree verification for the GDN hybrid: accepted tokens per verify pass'
date: 2026-09-26
doc: plan
kind: queue-item
level: '2'
note: 'Closed 2026-09-26 by decision on the measured cost evidence (not by a gate failure): tree-6''s lower bound clears the +10% screen but costs about twice a chain pass. Steps 2 to 5 stay unexecuted.'
order: '343'
title: 'Tree verification for the GDN hybrid: accepted tokens per verify pass'
status: withdrawn
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

0. Observation, correctness without timing. Record the draft head's top-k at the probe's own
   `argMax` line in `MTPAccept.probeGreedy` (`Sources/slotstream-cli/MTPCommands.swift:140-195`), on
   the CLI's four frozen probe prompts. Exit: with the ranks recorded the chain, the accept curve and
   the ordinary statistics are identical to a run without them. Revised 2026-09-26: this was written as
   a capture-seam extension, and the probe needs no engine change and touches none of the files another
   session has open.
1. Offline shape and acceptance model, no engine change, acceptance side only: under greedy decoding
   exactly one child per node can be accepted, so the probe decides this half exactly. The expert-bytes
   half of the gate is not decidable offline (a branch away from the true continuation has no recorded
   routing) and is judged at step 3 with the bar unchanged.

   **Outcome, 2026-09-26: negative — the shape question is closed at the adopted depth.** The probe
   recorded the draft head's top-k on four prompts, 380 positions, with the chain and the accept curve
   byte-identical to a run without the ranks (85.3% at depth 1, 70.2% at depth 2, reproducing the
   recorded 85.8%/71.0% within 0.8 points). The offline lower-bound model then read: the shipped chain
   accepts 1.5474 tokens per verify pass at x1.33 of a one-token pass, `tree-4` 1.6368 (+5.8%) at
   x1.65, `tree-6` 1.7237 (+11.4%) at x1.99 — gain over cost 0.752 against 0.641 and 0.559. Only
   `tree-6` clears the +10% token bar and it costs about twice a chain pass, so both shapes lose
   throughput. The deciding number is what a row buys: each extra verify row costs about a sixth of a
   pass, so a tree pays only above 0.166 accepted tokens per extra row, and these buy about 0.044.
   Measurement: [[records/measurements/tree-verification-does-not-pay-2026-09-26]]; raw output:
   [[sources/runs/2026/09/2026-09-26-tree-verification-step0-probe]]. Steps 2 through 5 have not been started.

   **Disposition, stated against the registered gate rather than around it.** G1 as registered reads a
   bound and says a bound already 10% above `chain-2` is a go; `tree-6`'s lower bound is 11.4% and
   `tree-4`'s 5.8%, so by the letter of the gate **`tree-6` is a go for step 2** and `tree-4` simply
   fails the screen. The cost ladder registered beside it in §5 says the same shape costs about twice a
   chain pass, which is a ~26% throughput loss on the measured model — a strong prior against spending
   step 2's build, not a gate failure, and this record does not manufacture one. The call is a decision,
   not a measurement: build the branch-local recurrent verification for `tree-6` and let step 3 measure
   expert bytes, or stop here on the cost evidence. Until that call is made the record stays open and
   steps 2 to 5 stay unstarted. What is still open as a question, named in the measurement's last
   section: a tree at a longer chain depth, one whose rows cost less than about 8 ms, or one whose gain
   comes from sampling rather than greedy acceptance — each needs its own registration. From the recorded per-position linear states
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
`500bd3186ef809fa836c0810eccc1a29ce64948dd28dad2ea4c13c92fe07112f`, committed into the store as
[[sources/docs/2026/09/2026-09-26-tree-verification-gdn-hybrid-preregistration-rev3]] so the text
outlives the scratch directory (revisions 1 and 2 are superseded before any data). Revised before any data existed: step 0 is the probe rather than a capture-seam change, the
expert-bytes half of the gate is judged at step 3, the shapes are pinned (`tree-4` two level-1
nodes with one child each; `tree-6` two level-1 nodes with two children each), and G1 reads a
**lower bound** because the probe follows the draft head along the rank-0 chain only. It names the tree shapes (node budgets 4 and 6, plus the shipped chain and a
tree-off bit-identity control), the branching rule (the draft head's own top-k at each expanded node,
deterministic tie-break by higher margin then lower expert id), the prompt set (the frozen corpus: the
four exploration prompts for the screen, then eight unused training-split families for the confirmation)
and both gates: committed tokens per verify-forward at least 10% above the shipped chain, and expert
bytes per committed token no worse than the shipped chain's. Step 2 is the first engine change and must
not be merged behind a default.
