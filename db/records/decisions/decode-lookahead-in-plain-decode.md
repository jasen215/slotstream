---
type: decision
id: 01m3adgvehb8mj9nkvqa3szryx
created: 2026-09-24T19:15:48.817298+00:00
updated: 2026-09-24T19:15:48.817298+00:00
summary: 'Without the draft head the qualified decode lookahead runs in plain decode from 20 experts per layer before its charge: 1.11x at 10 GB and 1.05x at 16 GB, landed 1.05x to 1.08x under paging'
decided_on: 2026-09-24
evidence: '[[records/measurements/decode-perf-2026-09-24]]'
reversible_if: A clean paired comparison shows plain decode slower with it at some cache size, a slower SSD measures a loss, or its output differs from plain decode without it
title: The decode lookahead runs in plain decode from 20 experts per layer
status: standing
---
Carlos approved landing the tested decode changes on September 24, 2026: "yes, land them in Slotstream". This records the plain-decode lookahead among them.

**Decision.** Without the draft head, because automatic mode left it off below its floor, `--mtp off` was given or the checkpoint has no head file, the qualified decode lookahead now runs in plain decode where the cache before its charge reaches 20 experts per layer (`Planner.plainLookaheadFloorPerLayer`). It is the configuration and charge that ride the head ([[records/decisions/decode-lookahead-default-with-the-draft-head]]): router-reuse prefetch with the corrected attention forecast, FP32 router weights, a GPU drain every four layers, 373 MiB, or 409 MiB with the correction file. Plain passes forecast from each pass's own layers; there are no draft-head start features. `SLOTSTREAM_OPT_EXPERT_PREFETCH=0` turns it off as before. With the head loaded, plain passes stay as they were. There is no upper cache bound, as with the head.

**Evidence.** [[records/measurements/decode-perf-2026-09-24]], environment-guarded prototype with the keepalive and direct demand reads on both arms: 1.11x at a 10 GB target over four swap-free pairs (1.12x over eight, eight of eight above 1), with 20.0 experts per layer before its charge and 17.1 after; 1.05x at 16 GB over four swap-free pairs (1.07x over seven). Output was identical in every pair. At 22 GB, running it in place of the head was 0.74x, so it never replaces a head that qualifies. The landed build ([[sources/runs/2026/09/2026-09-24-draft-stream-landed]]), with swap-ins in every pair, so confirming direction only: 1.045x at 10 GB over seven pairs (six above 1), 1.050x at 22 GB with the head off and 75 experts per layer over eight (seven above 1), and, in a later session that interleaved it with the prototype at 10 GB, 1.082x over eight (all above 1) against the prototype's 1.064x; the two builds were within 1.3% of each other with the lookahead and 0.4% without it. Output was identical in every pair.

**Side effect.** The reservation, about three experts per layer, moves a 48 GB Mac without the head from 152 to 149 experts per layer at the 32,768-token window, inside the planner's measured decode range of 150. The automatic context window then prices the 131,072-token window at 130 experts per layer, +5.9% to its typical request, instead of declining it as an unmeasured cache reduction, so that Mac's automatic window becomes 131,072 tokens. The frozen default plans move by the same reservation at their 24, 32 and 48 GB tiers; `Tools/fixtures/context-default-v3.json` and `context-automatic-v2.json` record the new values and keep the older versions.

**Scope.** One M5 Pro 48 GB, four prompts of 192 tokens. Caches above about 78 experts per layer in plain decode were not timed; the lookahead with the head also runs above its measured range. The planner's decode estimate leaves the lookahead's gain out while charging its memory, so its plain-decode estimates at 16 and 18 GB fell to about 3.5 and 5 tok/s.
