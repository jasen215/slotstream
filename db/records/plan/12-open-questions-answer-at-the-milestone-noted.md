---
type: plan
meta-type: operational
id: 01m1hhwp3605p6f1mjs77q43jy
created: 2026-09-02T17:15:28.230415+00:00
updated: 2026-09-26T03:28:41.931919+00:00
summary: 12. Open questions (answer at the milestone noted)
date: 2026-08-28
doc: plan
kind: questions
level: '2'
order: '410'
source: '[[sources/docs/2026/09/plan-md-2026-09-02]]'
title: 12. Open questions (answer at the milestone noted)
---

1. ✅**ANSWERED (M0).** N-gram indexing: `ngram_heads = (ngram_size−1) × heads_per_ngram
   = 16`; per head, id = XOR of `splitmix64`-derived multipliers over the token n-gram,
   mod that head's distinct prime near 20 M (`_nth_prime_after(19_999_999, g+1)`), plus
   the head's offset; the concatenation is split into 128 shards of 2,500,012 rows.
   Rows are 160-dim, 100 B packed, quant group 32. PLE sits at layer index 1.
2. ✅**ANSWERED (M0).** **16 rows per token = 1,600 B** of n-gram data (≈20× less than
   the 23 KB assumed). Unrepacked that is 48 scattered preads/token; repacked, 16.
3. ✅**ANSWERED (M0), and better than hoped.** `mlx-swift-lm` ships
   `Qwen3NextGatedDeltaNet` + `gatedDeltaUpdate` (with `conv1d`, `dt_bias`, `A_log`,
   a `decodeConv` fast path, and compiled-decode tests), plus `SwitchGLU` /
   `QuantizedSwitchLinear` over `MLX.gatherQuantizedMM`. Novel Swift work reduces to
   the QSA indexer, hyper-connections, and the PLE path.
4. MTP block internals (own experts?) and self-spec accept rates on this model (M9)
   — now the load-bearing unknown for §8.1's enable thresholds, together with
   whether draft-batched expert fetches help fetch-bound tiers at all.
5. h-curves per tier (M1) — **no longer the load-bearing unknown**: at 17.3 GB/s even
   h=0 sustains ~13 tok/s. It now sizes tiers rather than deciding viability.
6. Whether `mixed-4-8` measurably beats all-4-bit on agentic evals worth +disk (M8).
7. External-USB4-NVMe tier viability for 256 GB-disk Macs (M8, one bench row).
8. **NEW — the actual binding constraint.** How much of decode is kernel-launch
   overhead, and how far do MLX compiled graphs close it? Batch-1 matmul hits only
   20% of memory bandwidth. This displaced IO as the top performance risk (M4/M5).
9. ✅**ANSWERED (M7).** Metal shader build: **vendored metallib**. CI builds the
   release with Xcode on its runner and ships `mlx.metallib` beside the binary;
   a CLT-only machine builds and runs fine against it. Separately — and this was
   conflated for two releases — *writing a new kernel* needs neither, because
   `MLXFast.metalKernel` JIT-compiles at runtime, which is how the gated-DeltaNet
   kernel already ships.
10. **NEW (2026-08-29), and the reason N1 exists.** How much of real-world latency is
   re-prefill rather than prefill? Found by inspection, not measurement: state is rebuilt
   per request, so for a conversation it is *all* of it after turn 1. Open sub-question
   for N1: how often does a real client actually send an exactly-extending prefix
   (tool loops and edited history both break it), i.e. what is the true hit rate of an
   extend-only cache?

11. **NEW (2026-09-24, 32 GB MacBook Air).** Does auto's availability clamp leave an
   SSD-streaming engine enough room for the file cache its expert reads depend on?
   The clamp keeps `availabilitySlackGB = max(1.5, 0.05 × RAM)` — 1.7 GB on this
   machine — and that value is a "do not claim the whole machine" guard, not a
   performance margin. A live session that sized itself to 21.7 GB against 23.4 GB
   reclaimable then logged two governor pressure events and swapped
   ([[sources/runs/2026/09/2026-09-24-m5-air-live-agent-session]]; its timings are
   discarded, and nothing in this capture is a clean measurement). What answers it:
   an interleaved A/B of `--memory-limit-gb 16` against auto over the same real turn
   sequence — protocol in `docs/MEASURE-MEMORY-HEADROOM-AB.md`. **No default moves
   before that runs.**
12. **NEW (2026-09-24).** Why does the in-memory prefix tier stop serving a
   conversation once it is large? The same session took 3 of 23 reusable prefixes
   from memory and 18 from disk, and the switch begins with the request that
   follows one which failed during preparation — `takeForGeneration` hands a
   non-reusable entry out and a failed request has `mayRetainState == false`, so
   that state is consumed and never returned. Whether that is the whole story, or
   the retention ceiling and `reserveForRestore` keep the tier empty afterwards, is
   unresolved: the disk path now prints the memory tier's own
   `retainedMatchLength` as `memory offered N`. Same capture as item 11.

13. **NEW (2026-09-24).** The prefill ladder's rate is the acceptance prompt's, and
   ordinary prose is the honest number — recorded, not a defect
   ([[records/measurements/what-the-sweep-does-not-settle]], and the qualifier
   already rides the claim [[records/claims/prefill-220-tok-s-at-a-4096-pass]]:
   ~30% slower, 131 against 184 tok/s at 16 GB). What is *not* written down is
   why the measured ratio cannot simply be folded into `estPrefillTokS`, so it
   keeps getting rediscovered: the estimate feeds **three decision surfaces with
   three different behaviours under a constant factor**.
   - The automatic context window compares two estimates as a **ratio**, so a
     uniform factor cancels and the choice is unaffected
     (`ContextWindowPolicy.automaticWindowRefusal`).
   - The prefill pass size compares **absolute** seconds across candidate
     chunks, and only the prefill term moves, so a constant factor reweights
     prefill against decode and can change the chosen pass (`Plan.prefillChunkFor`).
   - The prefill wait guard refuses a request when `elapsed + estimate` exceeds
     `--max-prefill-wait`, so a slower factor makes it refuse **more**
     (`RequestControl.admit`, `prefillWaitExceeded`).
   Plus a public claim and the README banner rest on the same ladder. So a prose
   anchor is a policy change, not a one-line correction: it needs a prose-anchored
   ladder (or an explicit, documented prose factor) measured at the pass sizes
   the planner actually picks, recorded as a measurement, with the wait-guard
   consequence and the claim updated in the same change. Until then the banner
   says the rate is the acceptance prompt's, and no estimate silently carries a
   prose factor.
**Answer to item 12 (2026-09-26).** The tier does not stop because a failed request consumed the state. On [[sources/runs/2026/09/2026-09-26-m5-air-live-agent-session]] the three refusals precede a working memory hit by four minutes, and the switch to disk follows a request that succeeded. `memory offered 0` on all 24 disk reuses localises the cause instead: `GovernorPolicy.liveControls` derives the post-resize prefix ceiling from a pool-only share with no `retentionFloor` whenever the decided target is not exactly the desired plan slot count — the ordinary dead-band path, not only an OS pressure event — so a 9.3 to 8.2 GB shed cut the ceiling from 65,536 to 29,659 tokens, below the live conversation, and `PrefixCache.store` (which admits a state only while `t.count <= _maxTokens`) then refused every boundary snapshot. `PrefixCache.setBudgetLimit` clamped downward only, so the pool regrowing to 10.3 GB could not raise the ceiling again: one shed pinned the tier for the process lifetime. Both are fixed and gated by `governor-check`, which drives the captured machine ladder and asserts that a shed never lowers the ceiling below the planner own retention answer and that a later larger plan raises it back. Item 11 remains open.