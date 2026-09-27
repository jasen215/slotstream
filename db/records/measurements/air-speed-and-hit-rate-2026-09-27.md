---
type: measurement
id: 01m3gr0xz1gty86gzqj14rxsk2
created: 2026-09-27T06:14:48.033341+00:00
updated: 2026-09-27T06:29:27.432893+00:00
summary: At a 14 GB target on the 32 GB M5 Air prefill is 94.88/63.80/73.90 token/s at forced passes 256/1024/2048 as the pool shrinks; the hit rate is 0.9850 at ~19.5k and 0.92 at ~10k; decode is a cold-pool burst of 3.2-3.9 token/s with the warm rate unmeasured
captured_at: 2026-09-27
date: 2026-09-27
doc: measurements
level: '3'
order: '347'
title: What the target machine reaches at a 14 GB target
status: measured
---
# What the target machine reaches at a 14 GB target

**The question**, from [[records/plan/2026-09-27-air-speed-and-hit-rate-on-the-target-machine]]: on the
32 GB M5 Air this engine is developed against, can prefill reach and hold 100+ token/s, can decode
exceed 10 token/s, and can the conversation hit rate reach 98%?

## Method

Two existing gated instruments, `Tools/prefill_bench.py` and `Tools/persistent_prefix_e2e.py`, at
`--memory-gb 14 --allow-large-target`, one model process at a time, `pgrep` empty before and after every
part, 19.5 to 25.1 GB reclaimable at the four checkpoints. Raw artifacts in
`.build/air-speed-20260927/` (RESULTS.md f5146d4f, results.jsonl 10c93b71, hit-rate-6000.json 30c347e5,
hit-rate-12000.json 701d4c50, RESULTS-ADDENDUM-A.md 837f223b, addendum results.jsonl f1ed4ebc). The campaign's first revision **halted before a model started**, because
both drivers refused the frozen 14 GB target at argument parse; that is recorded in
[[sources/docs/2026/09/2026-09-27-air-speed-hitrate-preregistration-rev2]] and the drivers now express
the large-target case explicitly.

**Eligibility, stated plainly.** All nine prefill cells were excluded by the tool's then-binary rule
that any swap-counter movement disqualifies a cell. The movement was 28 to 204 pages (0.07 to 0.8 MB)
per cell with `swapouts` constant for the whole campaign, so the table below is **diagnostic, not
certified**, and its verdicts are not claimed. The rule has since been bounded (4096 pages) for later
runs; rev2's verdict stands as recorded and is not rewritten. The hit-rate numbers come from a driver
whose own acceptance returned `passed:false` (its state accounting expects the 400-word turns in its own
comment, not the 40-word turns this workload used); every identity assertion it makes passed.

## Result 1: at a 14 GB target a bigger pass is worse on this machine

| pass | prefill token/s median | rounds | effective pool slots | engine footprint peak |
| --- | --- | --- | --- | --- |
| 256 | 94.88 | 101.93 / 85.91 / 94.88 | 1742 | 11.84 GB |
| 1024 | 63.80 | 60.02 / 64.30 / 63.80 | 1381 | 11.59 GB |
| 2048 | 73.90 | 67.31 / 73.90 / 77.48 | 899 | 10.95 GB |

Prompt was the immutable ~8k `acceptance` fixture (7,961 tokens), MTP on. The pass is charged against
the same budget as the expert pool, so a larger pass shrinks the pool 1742 → 899 slots and the extra
misses per pass outweigh the larger pass's better arithmetic. **The development Mac's ladder (88 → 222
token/s from 256 → 4096) was measured at a matched pool of 60 experts/layer and does not transfer to a
14 GB target on this machine.** Gate G1 read at face value: one round crossed 100 (101.93), the medians
did not, so prefill 100+ is not reachable at a 14 GB target here, and the remaining lever is the serial
read path rather than the pass size.

## Result 2: the hit rate is alignment-dependent, and its residual is one pass

| prefix | turn | prompt | reused | hit | first token | restored | saved |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ~10k | 2 | 9837 | 9216 | 0.9369 | 23.08 s | 0 | 0 |
| ~10k | 3 | 10009 | 9216 | 0.9208 | 25.17 s | 9216 | 0 |
| ~10k | 3, restart | 10009 | 9216 | 0.9208 | 38.45 s | 9216 | 0 |
| ~10k | 2, cold server | 9837 | 0 | 0.0000 | 155.32 s | 0 | 9216 |
| ~19.5k | 1 | 19413 | 0 | 0.0000 | 365.51 s | 0 | 18432 |
| ~19.5k | 2 | 19580 | 18432 | 0.9414 | 35.24 s | 18432 | 19456 |
| ~19.5k | 3 | 19752 | 19456 | **0.9850** | 18.55 s | 19456 | 0 |
| ~19.5k | 3, restart | 19752 | 19456 | 0.9850 | 27.81 s | 19456 | 0 |
| ~19.5k | 2, cold server | 19580 | 0 | 0.0000 | 374.08 s | 0 | 18432 |

The residual is the new turn's tokens plus the previous prompt's partial-pass tail, and a turn can
resume only at a boundary of *its own* passes: 19752 − 19456 = 296 tokens, against 50 tokens of new
content and 19580 mod 1024 = 124; 10009 − 9216 = 793 against 9837 mod 1024 = 565. **So 98% needs a long
prefix *and* a favourable boundary, and the pass size sets the worst case**, since the tail can never
exceed one pass. A smaller pass therefore raises the hit rate — and on this machine it also reads the
prompt faster, so the two goals point the same way here. Gate G3: the long sub-condition was met
(0.9850 at ~19.5k tokens, not the ~16k the protocol labelled) and the short one was not (0.9369 and
0.9208 at ~10k, against a 0.95 bar).

**The tier, on a real conversation.** The ~19.5k prefix's second turn read 19,580 tokens cold in 374.08
s (52 token/s) and its third turn reached the first token of a 19,752-token prompt in **18.55 s after
restoring 19,456** — 20.2x, which is what the disk tier is for. The same comparison at ~10k: 155.32 s
cold against 23.08 s, 6.7x.

## Result 3: decode is 3.2 to 3.9 token/s cold, and warm decode is unmeasured

Addendum A measured it on fixtures that generate (`code`, 3,719 tokens; `prose`, 440), MTP on, at the
same 14 GB target. Nine of twelve cells are valid; three were refused by the engine's own allocation
guard (`insufficient_memory ... with safety headroom`) before any prefill, with identical before and
after swap counters, so those are headroom refusals and not paging.

| prompt | pass | decode token/s median | rounds | pool slots |
| --- | --- | --- | --- | --- |
| code | 256 | 3.695 | 3.88, 3.51 | 1742 |
| code | 1024 | 3.18 | 3.37, 2.91, 3.18 | 1381 |
| prose | 256 | 3.425 | 3.45, 3.40 | 1742 |
| prose | 1024 | 3.215 | 3.29, 3.14 | 1381 |

**G5 is not met**: the bar was 6.0 token/s and no cell exceeded 10, the maximum being 3.88 across all
nine valid cells. What this measures is a burst immediately after a cold prefill in a fresh process,
with the expert pool still filling, because that is what the command frozen in advance runs. **Warm
decode on this machine at a 14 GB target is therefore not measured, and this record does not claim it.**

What bounds decode 10+ from the other direction is memory, and that needs no warm measurement: a 14 GB
target holds 1,742 slots, about 54 experts per layer, and this repository's warm anchors are 6.0 / 8.2 /
11.2 / 11.6 token/s at 30 / 60 / 120 / 150 experts per layer. Ten or more needs roughly 120 experts per
layer resident, which this machine cannot hold at this target; the field report of the same machine
reached 6.22 token/s at a 22 GB plan with 75 experts per layer and MTP off.

One gap is recorded rather than resolved: `doctor` estimates about 8 token/s at this target's 54 experts
per layer while the measured cold burst is 3.18 to 3.88. The difference is the cold pool and the burst
rather than something these data can settle, so the estimate is left standing and the measurement is
left labelled.

## Limits

One machine, its internal SSD, MTP on, no images, no concurrency, R=3 and single runs here vary. The
prefill table is diagnostic only, as stated above: the cells were excluded, and the forces pass
(`SLOTSTREAM_PREFILL_CHUNK`) brackets what each pass does at a 14 GB target rather than reporting what
the planner chooses. The hit-rate numbers are observations from a driver that returned `passed:false`.
The decode figure is a cold-pool burst, not a warm rate, and long-context decode is unmeasured; the
repository already records that decode after a long prefill is slower than the short-prompt anchors. **No number here has been published on a user-facing surface**:
the hardware band and the Air's row keep their existing evidence until the decode rate exists.

## What it decides

- **prefill 100+**: not at a 14 GB target, and not by enlarging the pass — that makes it worse here.
  The read-path lever is what is left.
- **decode 10+**: measured cold at 3.2 to 3.9 token/s at a 14 GB target, and not reachable there by
  the memory bound; the warm rate is unmeasured and is not claimed.
- **hit rate 98%**: reachable at a ~19.5k-token prefix with a favourable boundary, and it is a property
  of prefix length, pass size and where the turn's boundary falls, not of short turns alone.
