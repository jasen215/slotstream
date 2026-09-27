---
type: measurement
id: 01m3a7jnqqry3n066smc20n496
created: 2026-09-24T17:31:57.047252+00:00
updated: 2026-09-24T19:16:08.887278+00:00
summary: 'Decode speed search: a GPU keepalive and direct demand reads 1.28x at 10 GB and 1.22x at 22 GB, a streamed draft head 1.23x at 12 GB, plain-decode lookahead 1.11x at 10 GB; keepalive energy +7%'
date: 2026-09-24
doc: measurements
level: '2'
machines: '[[records/machines/macbook-pro-m5-pro-48gb]]'
note: One development Mac with a live desktop and swap in use; claims use only comparisons with three or more pairs free of swap activity.
order: '1670'
runs: '[[sources/runs/2026/09/2026-09-24-decode-perf-experiments]], [[sources/runs/2026/09/2026-09-24-decode-overlap-landed]], [[sources/runs/2026/09/2026-09-24-draft-stream-landed]]'
title: 'Decode speed: GPU keepalive, direct demand reads, a streamed draft head and plain-decode lookahead'
status: measured
---
**Outcome: four decode changes won on the development Mac with unchanged output, and the other ideas tried did not.** A GPU keepalive and direct demand reads together made decode 1.28x faster at a 10 GB target without the draft head and 1.22x at 22 GB with the head and lookahead, over the pairs with no swap activity. Streaming the draft head's routed experts through a 64-expert cache freed 1.2 GB for the main cache, which made the head worth running at 12 GB: 1.23x over plain decode with the lookahead at 28.4 experts per layer, over three swap-free pairs (1.21x over all eight). Letting the decode lookahead run in plain decode added 1.11x at 10 GB. Together, at a 16 GB target, the four decoded 1.79x faster than the shipped default of that commit. The keepalive raised energy per generated token by 7%. The measured configurations were environment-guarded prototypes on an export of commit 37fcb8e; the landed implementations have their own confirmation below.

**Method.** One model process at a time on the 48 GB M5 Pro, a live desktop and 4.6 to 6.7 GB of swap in use. Every arm ran every prompt each round in rotated order, after a wait for reclaimable memory above the target plus 6 GB. Four public corpus prompts (r0005, r0206, r0096, r0074, `Tools/expert_lookahead_corpus.py`), greedy, 192 output tokens, two rounds: 8 pairs per comparison. The primary screen keeps completed runs with no global swap-out and no thermal warning; every run had none of the latter. The strict screen also requires no global swap-in, which removes most pairs on this machine; a timing claim needs three strict pairs. Ratios are geometric means of paired decode tok/s. Arms: `kadd` is keepalive plus direct reads, `la` the qualified lookahead configuration (`la_env.json`, the 22 GB plan's), `hs` the head's experts streamed through 64 slots.

**Why decode waits.** Streamed decode is stop-and-go. At each layer the host reads the routing back and reads the experts the cache lacks before it submits the next burst. With MLX timing instrumentation, a one-token pass with every expert resident was 337 command buffers with the GPU busy 58% of 55.2 ms, 68.3 µs idle per buffer. An idle Apple GPU clocks down and starts the next buffer late. A one-thread kernel spinning on its own command queue kept it busy: 65% of 47.4 ms, 49.5 µs idle per buffer (single instrumented runs, `gpu_windows.py`). Five paired rounds of the fetch-free pass cost, whose runs recorded swap-outs only, put the one-token pass at 55.8 against 48.5 ms (medians). A Metal microbenchmark re-run on a quiet GPU shows why: a small kernel that runs in 49 µs back to back took 230 µs after any idle gap of 200 µs or more, and the next buffer started 0.12 ms after commit after a 200 µs gap and 0.62 ms after a 5 ms gap; with the spin kernel resident on a second queue, 52 µs and 0.07 ms. Demand misses were read into staging arrays and scattered on the GPU, one more dispatch and synchronization per layer; the direct path reads into host scratch and copies each record into its slot.

**Decode, paired ratios.** All pairs, then pairs with no swap activity (n):

| comparison | target | all pairs | swap-free |
|---|---|---|---|
| keepalive + direct reads vs base, no head | 10 GB | 1.298, 1.257 in a rerun | 1.274 (5), 1.279 (6) |
| direct reads alone | 10 GB | 1.141 | 1.164 (4) |
| keepalive alone | 10 GB | 1.069 | 1.067 (4) |
| keepalive + direct, head and lookahead | 22 GB | 1.191 | 1.215 (5) |
| keepalive alone, head and lookahead | 22 GB | 1.127 | 1.110 (5) |
| direct reads over keepalive | 22 GB | 1.057 | 1.051 (6) |
| plain lookahead over keepalive + direct | 10 GB | 1.123 | 1.112 (4) |
| plain lookahead over keepalive + direct | 16 GB | 1.071 | 1.054 (4) |
| streamed head + la over plain la, all kadd | 12 GB | 1.207 | 1.230 (3) |
| streamed head + la over plain la, all kadd | 10 GB | 0.988 | 1.051 (3) |
| resident head over plain la, all kadd | 12 GB | 1.010 | 1.018 (2) |
| resident head + la over plain la, all kadd | 16 GB | 1.323 | 1.323 (5) |
| streamed over resident head, kadd | 22 GB | 1.008 | 0.990 (4) |
| streamed over resident head, kadd | 12 GB | 1.136 | 1.134 (2) |
| streamed over resident head, kadd | 10 GB | 1.005 | 1.005 (3) |
| streamed head + la + kadd vs shipped | 16 GB | 1.785 | 1.794 (4) |
| streamed head + kadd vs shipped | 22 GB | 1.166 | 1.178 (3) |

Every same-mode comparison kept identical output ids. Streamed and resident heads differed on 2 of 8 at 12 GB because the streamed plan's larger budget chose a longer prefill pass, which moves prompt logits within the known re-chunking envelope; with the pass pinned, the streamed head's ids equal the resident head's. Head against plain comparisons differ at near ties, as speculative and plain decode always have. The draft head's cache hit rate was 0.47 at depth 2, and its reads took 0.24 to 0.34 s per 192-token request.

**Caches measured, experts per layer.** 10 GB: 20.0 plain, 17.1 with the lookahead, 17.4 with the streamed head, 13.3 with the resident head (the floor pool). 12 GB: 31.1, 28.2, 28.4, 22.7. 16 GB: 53.7 plain, 47.6 with the streamed head and lookahead, 39.4 with the resident head and lookahead. 22 GB: 73.6 with the resident head and lookahead, 82.7 streamed. Peak memory with the streamed head stayed at or below the resident head's at every target.

**Energy.** IOReport SoC energy over the whole request at 16 GB, streamed head and lookahead on both arms: the keepalive raised energy per generated token 7.1% over four swap-free pairs (6.7% over eight), average power 26.7 to 32.5 W, for 1.17x decode (1.19x over eight). Against the shipped default the full configuration used 11.0% less energy per token (12.7% over eight), because it finished sooner.

**Did not help.** A duty-cycled keepalive with 200 µs or 1 ms gaps (1.033 and 1.019, wide spread: the clock falls in the gaps). MLX's host spin-wait instead of blocking waits (0.711). Committing every 10 operations, with or without a buffer size limit (0.968, 0.995). A compiled one-row GDN step (0.978). User-interactive QoS for the generating thread (1.007). Layer-local eviction at the floor pool (0.906 plain). Overlapping the shared expert (0.986 at 16 GB, 0.967 at 22 GB). Draft depth 1 (0.979 at 12 GB) and 3 (0.701), and an adaptive depth up to 3 (0.801). The plain lookahead in place of the head at 22 GB (0.744).

**Landed code.** The keepalive (`--gpu-keepalive`, `auto` on AC power) and direct demand reads (`SLOTSTREAM_OPT_DIRECT_DEMAND`) were confirmed on the landed build under heavier paging: every run saw swap-ins, so no pair is swap-free and these confirm direction, not a timing claim. Same binary, both switches on against both off, 8 pairs each: 1.228 at 10 GB (8 of 8 above 1, 1.111 to 1.307) and 1.116 at 22 GB (8 of 8 above 1, 1.006 to 1.223), identical ids. Against the installed 0.2.24 release: 1.150 at 10 GB (6 pairs without swap-outs) and 1.092 at 22 GB (8 pairs), identical ids and draft acceptance; the release differs by other commits and its build too. `decode-overlap-check` passed 1,672 assertions on the pre-release build.

**Landed streamed head and plain-decode lookahead.** The streamed head, its floor of 28 and the plain lookahead were confirmed on their own landed build ([[sources/runs/2026/09/2026-09-24-draft-stream-landed]]), again with swap-ins in every pair, so these confirm direction, not a timing claim. At 12 GB, automatic mode, the streamed head with the lookahead at 25.5 experts per layer, against `--mtp off`, plain decode with the lookahead at 28.2: 1.205 over eight pairs, eight of eight above 1 (1.093 to 1.329). Plain decode with the lookahead against without it: 1.045 at 10 GB over seven pairs without swap-outs (six above 1, 0.965 to 1.136) and 1.050 at 22 GB with `--mtp off`, 75 against 78 experts per layer at a 65,536-token automatic window, over eight (seven above 1). Because the 10 GB ratio fell short of the prototype's, a later session interleaved the landed build and the prototype, each with and without its lookahead, at 10 GB: 1.082 landed and 1.064 prototype, eight of eight above 1 each, and the two builds within 1.3% of each other with the lookahead and 0.4% without, so the shortfall came from the machine's state that hour. Plain-decode and lookahead pairs kept identical ids; head against plain pairs differ at near ties as always. `draft-stream-check` passed 23 assertions, and `decode-overlap-check` passed again on the combined build.

**Limits.** One Mac, one SSD and four prompts of 192 tokens; larger caches than 22 GB were not timed. Most comparisons keep fewer than three swap-free pairs; the claims use only those that keep three or more. The fetch-free pass-cost rounds recorded swap-outs but not swap-ins. The GPU span figures are single instrumented runs.
