---
type: decision
id: 01m3a7k682zn0tddfbdcqz6b1m
created: 2026-09-24T17:32:13.954076+00:00
updated: 2026-09-24T17:32:26.722070+00:00
summary: 'Cache misses are read into host scratch and copied straight into their pool slots, without staging arrays or a GPU scatter: 1.16x alone at 10 GB, identical output'
decided_on: 2026-09-24
evidence: '[[records/measurements/decode-perf-2026-09-24]]'
reversible_if: A paired comparison shows slower decode or different output with it, or a failed read leaves a stale or partial slot
title: Cache misses are read straight into their slots by default
status: standing
---
Carlos approved landing the tested decode changes on September 24, 2026: "yes, land them in Slotstream". This records the direct demand read default among them.

**Decision.** Cache misses are read into per-lane host scratch buffers through the store's existing uncached descriptors and copied straight into their slots in the pool's nine piece buffers. The staged path read each batch into MLX staging arrays and scattered it into the pool on the GPU, one more dispatch and synchronization per layer. The direct path puts the same bytes in the same slots, so arithmetic is unchanged. It joins the deployment family (`InferenceOptimizations.directDemandReads`); `SLOTSTREAM_OPT_DIRECT_DEMAND=0` restores the staged path and `1` selects it outside the family. Saved statistics count `prefillSlotDirectBatches` and `decodeSlotDirectBatches`.

**Safety.** A victim slot is unmapped before its bytes change, so a failed read leaves it absent rather than stale. Pins keep every slot an unevaluated gather still reads out of the victim scan, the invariant the decode lookahead's slot adoption already relies on for its CPU writes. The path stays off where that does not hold or where another mechanism owns the write: the resident-overlap path, whose GPU readers may still be running, transfer profiling, packed record reads, and the explicit slot-write experiments. Pool base pointers are cached per write epoch and dropped on every resize or scatter. `decode-overlap-check` compares staged, direct and keepalive runs on a cold floor-sized pool, with and without the draft head, and repeats the pool-level and request-level read-failure recovery checks with direct reads; `runtime-check` covers the switch's parsing.

**Evidence.** [[records/measurements/decode-perf-2026-09-24]]: at a 10 GB target without the draft head, direct reads alone gave 1.16x over four swap-free pairs (1.14x over all eight), and with the keepalive 1.28x over six. At 22 GB with the draft head and lookahead they added 1.05x on top of the keepalive over six swap-free pairs. No pair changed output. Short prompts that prefill through the pool path read their misses directly too: at 10 GB on the landed build, with the keepalive also on, a 75-token prompt prefilled in 1.97 and 1.89 s against 2.27 and 2.35 s.

**Scope.** One M5 Pro 48 GB with its internal SSD. The gain is the removed scatter and synchronization, so it should grow with the miss rate: small caches gain most.
