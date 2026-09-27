---
type: measurement
id: 01m3ghvc9brvmcky6rqstkpeqq
created: 2026-09-27T04:26:54.635903+00:00
updated: 2026-09-27T04:27:15.349311+00:00
summary: 'Paired A/B, three rounds, twelve matched turns: the tier is 1.60x on first-token seconds (1.50x without the first round''s warm-up) and 3.44x to 3.72x after a restart, with identical output ids'
captured_at: 2026-09-26
date: 2026-09-26
doc: measurements
level: '3'
order: '346'
title: The disk prefix tier against recomputation, paired
status: measured
---
# The disk prefix tier against recomputation, paired

**The question.** `serve --prefix-cache-dir` writes a committed conversation state after each reply and
restores it instead of re-reading the prompt — after a restart, or when a conversation is longer than
memory retains. `slotstream launch` already starts its server with that directory. What is it worth?

## Method

A paired A/B on [[records/machines/macbook-air-m5-32gb-local]]: arm A with the tier on a fresh
directory, arm B with no disk tier at all, the in-memory conversation cache present in both. Three
interleaved rounds of a battery the store already uses (a 2400-word notes prompt, two 400-word
follow-ups of 48 predicted tokens, a server restart, then the same prompt again), 12 matched turns per
arm, `--memory-gb 10`, one model process at a time, no foreign model process or compiler at any round
gate. Raw: [[sources/runs/2026/09/2026-09-26-disk-prefix-step4-paired-ab]].

Metric: `first_token_seconds`, ratio `B/A`, aggregated as a geometric mean over matched turns and
bootstrapped over the three rounds.

## Result

| reading | value |
| --- | --- |
| aggregate over 12 matched turns | **1.60x** (prefill metric 1.60x) |
| bootstrap 2.5th percentile | 1.49x |
| steady-state subset (rounds 2 and 3, machine warm-up excluded) | **1.50x**, control family 1.00x |
| cold-long control (no reuse available) | 1.00x, so the harness is not biased |
| after a restart | **3.44x to 3.72x** per round |
| short follow-ups whose saving crosses a pass boundary | 1.37x to 1.44x |

Prompt ids and output ids are identical between arms in all twelve pairs, and in the follow-up
experiment for all five turns of its battery, so the tier is a speed change and not an output change.

Round 1 is inflated by the machine's own warm-up: its control reads 1.44x against 0.998x and 1.001x in
rounds 2 and 3, and arm A's own cold turn took 48.09 s against 72.63 s later. Both views are reported;
the steady-state subset is the honest one for a warm machine.

## Mechanism

- **The tier's value is skipping the cold start.** Arm A's post-restart turn restores 3584 rows in
  0.035 to 0.037 s and then reads 265 rows for 20.5 s; arm B reads the same 3849-row prompt cold in
  70.7 to 73.1 s. That is about 77 ms per row on the first pass against 18.5 ms amortized — which is
  also why a per-token cost model of reading does not fit (n=19, r2=0.012).
- **The follow-up win is a pass boundary.** Memory held 3840 rows and the disk 4352, so the recompute
  arm's 1439-row residual cost two prefill passes where the tier's 927-row residual cost one.
- **A restore is cheap and flat**: `0.0213 + 3.946e-06 x rows` seconds (n=9, r2=0.954, 3584 to 15632
  rows). A restore makes room by evicting in-memory states, and the number of them is reported beside
  every restore (`evictionsForRestore`).
- **A restore is not free for what follows it, but the tier can undo that too.** In the follow-up
  experiment a restore evicted two conversations; when the evicted sibling was asked again, the tier
  restored its own state in 0.11 s where a rebuild took a whole prompt read, a 5.2x turn. The
  per-round net of the restore's win against that turn is +202 s in the tier's favour, 3 of 3 rounds
  ([[sources/runs/2026/09/2026-09-26-disk-prefix-eviction-cost]]). The *isolated* marginal cost of a
  restore-driven eviction was **not isolable** in that workload: the sibling's state left both arms at
  the trigger, arm B through the four-state ceiling.
- **A small presence cost exists.** On a control turn where the tier neither restores nor is offered
  anything longer it read 0.970 (0.950 to 0.997, n=3): the tier's mere presence costs a few percent.
  Suggestive only, no mechanism identified.

## Limits

One machine, one internal SSD, one prompt shape, `--memory-gb 10`, no images and no speculation
interaction; R=3 is a coarse bootstrap (ten distinct multisets), so the lower bound is a statement
about these three rounds rather than a population. The cold-start rate and the fitted restore cost are
properties of this disk, this model's pass structure and the current planner, and must be re-derived on
another machine rather than carried. The target range is Macs that cannot hold the model; larger Macs
gain from a larger cache and are not the optimization target. Nothing here measures a Mac that keeps
the model resident, a network or external tier, or concurrent requests.

Related: [[records/measurements/disk-tier-cost-arms-2026-09-26]] (the two cost arms),
[[records/measurements/disk-prefix-admission-is-unreachable-2026-09-26]] (why the tier reads every
longer state its boundary rules allow, with no admission threshold).
