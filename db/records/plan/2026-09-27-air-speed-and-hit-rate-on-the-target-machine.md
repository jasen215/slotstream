---
type: plan
id: 01m3gkvj5ng0kfanz45jydr5j7
created: 2026-09-27T05:01:57.813011+00:00
updated: 2026-09-27T06:32:21.117273+00:00
summary: Measure on the 32 GB M5 Air whether prefill reaches 100+ token/s at a 14 GB target, what decode is with MTP on, and where the agent-shaped hit rate lands; the gates are frozen in a pre-registration written before the numbers
date: 2026-09-27
doc: plan
kind: queue-item
level: '2'
note: 'Steps 1-2 are done and recorded in records/measurements/air-speed-and-hit-rate-2026-09-27: prefill is 94.88/63.80/73.90 token/s at forced passes 256/1024/2048 with the pool shrinking 1742 to 899 slots, the hit rate is 0.9850 at a ~19.5k prefix and 0.92 at ~10k, and decode is a cold-pool burst of 3.2-3.9 token/s against a 6.0 gate with the warm rate deliberately unmeasured. It stays open on purpose: publication was deferred (no user-facing surface carries these numbers), and a certified run of the 20.2x long-context restore comparison would be needed before any of them is published.'
order: '345'
title: 'What this machine can hold: prefill 100+, decode, and the hit rate'
status: open
---
# What this machine can hold: prefill 100+, decode, and the hit rate

**Question.** On the 32 GB M5 Air this engine is developed against, can prefill reach and *hold*
100+ token/s, can decode exceed 10 token/s, and can the conversation hit rate reach 98%? The
published evidence gives one answer per target and none of them together: a 32 GB Air in the field
reported 126.28 token/s prefill and 6.22 token/s decode at a 22 GB plan, the repo's 8k anchor is 184.1
token/s at a 16 GB target on the development Mac, this Air's own paired runs read 3,849 rows at about
53 token/s at a 10 GB target and a 256-row pass, and the 24-<48 GB band claims 6-14 token/s.

**Gates are frozen before the numbers**:
[[sources/docs/2026/09/2026-09-27-air-speed-hitrate-preregistration]] fixes G1 (pass 2048 reaches
>= 100 token/s at a 14 GB target), G2 (decode >= 6.0 with MTP on; > 10 is pre-registered as not
expected), G3 (hit rate >= 0.98 at a ~16k prefix and >= 0.95 at ~8k) and G4 (no swapping, aborting or
contended cell counts), with the decision each outcome forces.

## Steps

0. Pre-registration frozen 2026-09-27 with 19.7 GB reclaimable at freeze. **Done.**
1. Part 1, prefill and decode per compute pass: `Tools/prefill_bench.py`, the immutable ~8k
   `acceptance` fixture, passes 256 / 1024 / 2048 of the same binary at `--memory-gb 14`, MTP on,
   `--max-tokens 64`, three interleaved rounds, raw JSON under `.build/air-speed-20260927/`.
2. Part 2, agent-shaped hit rate: `Tools/persistent_prefix_e2e.py` at a ~8k and a ~16k prefix with
   ~50-token new turns and the disk tier enabled, per-turn `reusedPrefixTokens / promptTokens` plus
   each turn's first-token seconds and the tier's restore and save numbers.
3. Write the measurement record from the raw artifacts and move the surfaces the result touches: the
   24-<48 GB hardware band and the Air's row, any published statement about prefill 100+ or the 98%
   hit rate, as claims with needles on every surface they list; regenerate MEASUREMENTS.md, PLAN.md
   and `llms-full.txt`; run `Tools/brain_gates.sh` and `Tools/static_gates.sh`; commit locally.
4. Stop conditions: if 17 GB is not reclaimable before a launch, stop and report rather than start; if
   the planner clamps a requested pass so that no cell delivers it, that is the answer, not a reason
   to raise the target; if the machine swaps during a cell, the cell is excluded by the tool's own
   rule and the campaign continues.

## Why it is worth a machine slot

Every one of these three numbers is currently answered by an estimate, a different machine, or a
different memory plan. The engine's own documentation tells a 32 GB Mac owner what to expect from a
14 GB plan only by interpolating a band whose bottom is a field report from another person's Air.
