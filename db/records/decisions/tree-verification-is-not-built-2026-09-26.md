---
type: decision
meta-type: conclusion
id: 01m3ewv8tdrx2jrg7gy2v20czp
created: 2026-09-26T13:00:36.557692+00:00
updated: 2026-09-26T13:00:36.591043+00:00
summary: 'Order 343 stops after its offline shape model: both tree shapes lose throughput at the adopted depth, with the token screen met only by tree-6 and the cost ladder against it'
decided_on: 2026-09-26
evidence: '[[records/measurements/tree-verification-does-not-pay-2026-09-26]]'
reversible_if: A tree whose extra rows cost materially less than 8 ms each, a tree at a longer chain depth, or a gain driven by sampling rather than greedy acceptance is measured under its own pre-registration
title: The verification tree is not built
status: standing
---
Carlos's call, 2026-09-26, after order 343's step 1 measurement: the verification tree is not
built. Order 343 stops after its offline shape model. Its steps 2 through 5 — the branch-local
recurrent verification, the ancestry mask, the budget work and the native screen — stay
unexecuted, and no tree code, ancestry fixture or default change is added.

**The evidence.** On the engine's own four probe prompts, 380 positions, using the draft head's
recorded ranks and the measured per-row pass cost: the shipped two-draft chain accepts 1.5474
tokens per verify pass at x1.33 of a one-token pass, a 4-new-row tree 1.6368 (+5.8%) at x1.65,
and a 6-new-row tree 1.7237 (+11.4%) at x1.99. Gain over cost is 0.752 for the shipped chain
against 0.641 and 0.559, so both shapes lose throughput, the larger one by about 26%. The
criterion behind that: every extra verify row costs about one sixth of a pass (about 8 ms on a
48.3 ms pass), so a tree pays only if each extra row buys more than 0.166 accepted tokens, and
these buy about 0.044 — roughly 3.8x below break-even, consistent across both shapes and all
four prompts.

**Against the letter of the gate.** The registered G1 reads a lower bound and says a bound more
than 10% above the shipped chain is a go; `tree-6`'s bound is 11.4% and `tree-4`'s is 5.8%, so
the gate did not fail. The reason to stop is the cost ladder registered beside it, not the
screen. That distinction is kept: this is a decision on cost evidence, and the plan record
states both readings rather than manufacturing a gate failure.

**What it is not based on.** No tree row has ever run on the model, so expert bytes per
committed token — the co-primary gate — is unmeasured. The 7-row cost is extrapolated from a
ladder measured to 5 rows. 29.5% of positions left the rank-0 chain, so the tree figures are
lower bounds. The prior art's +17.2% committed tokens per event is from another engine and is
not contradicted by this.

**What would reopen it.** A tree whose extra rows cost materially less than the ~8 ms that sets
the 0.166 break-even; a tree at a longer chain depth, where the baseline already pays for more
rows and the relative row overhead is smaller; or a gain driven by sampling rather than greedy
acceptance. Each is a different question and needs its own pre-registration.
