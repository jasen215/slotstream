---
type: claim
id: 01m3adf743eq66fbj1qx38bmz1
created: 2026-09-24T19:14:55.235550+00:00
updated: 2026-09-24T19:14:55.235550+00:00
summary: The decode lookahead made plain decode 1.05x to 1.11x faster on the development Mac
basis: measured
gate: none
needle: plain decode 1.05x to 1.11x faster
supported_by: '[[records/measurements/decode-perf-2026-09-24]]'
surfaces: docs/HARDWARE.md
title: The decode lookahead made plain decode 1.05x to 1.11x faster on the development Mac
status: current
---
The plain-decode lookahead's measured range on the development Mac: 1.112 at a 10 GB target and 1.054 at 16 GB, each over four swap-free pairs of the environment-guarded prototype with identical output. HARDWARE.md quotes the range beside the planner's small-tier estimates, which leave the lookahead out. See [[records/claims/plain-decode-lookahead-1-11x-at-10-gb]] for the landed confirmations.
