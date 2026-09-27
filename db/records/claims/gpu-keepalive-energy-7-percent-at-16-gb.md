---
type: claim
id: 01m3a7kyxnkrreqytr9h98b18v
created: 2026-09-24T17:32:39.221501+00:00
updated: 2026-09-24T17:32:39.221501+00:00
summary: The GPU keepalive raised energy per generated token 7% at 16 GB
basis: measured
gate: none
needle: rose 7% at 16 GB
supported_by: '[[records/measurements/decode-perf-2026-09-24]]'
surfaces: docs/ENGINEERING.md, llms.txt
title: The GPU keepalive raised energy per generated token 7% at 16 GB
status: current
---
IOReport SoC energy per generated token over the whole request at a 16 GB target, streamed draft head and lookahead on both arms: 1.071 with the keepalive over four swap-free pairs (1.067 over all eight), average power 26.7 to 32.5 W. Surfaces round it to 7%. This is why `--gpu-keepalive auto` stays off on battery ([[records/decisions/gpu-keepalive-on-ac-power]]). Nothing gates it.
