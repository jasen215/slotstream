---
type: claim
id: 01m3a7kywf81gbxetazsrfap77
created: 2026-09-24T17:32:39.183190+00:00
updated: 2026-09-24T17:32:39.183190+00:00
summary: The GPU keepalive and direct demand reads made decode 1.28x faster at a 10 GB target without the draft head
basis: measured
gate: none
needle: 1.28x faster at a 10 GB target
supported_by: '[[records/measurements/decode-perf-2026-09-24]]'
surfaces: docs/ENGINEERING.md, llms.txt, CHANGELOG.md
title: The GPU keepalive and direct demand reads made decode 1.28x faster at a 10 GB target without the draft head
status: current
---
Keepalive plus direct demand reads against neither, plain decode at a 10 GB target: 1.279 over six swap-free pairs of a rerun (1.257 over all eight) and 1.274 over five in the first run (1.298 over eight), four prompts of 192 greedy tokens on one 48 GB M5 Pro, identical output. Surfaces round it to 1.28x. The landed build's own on/off comparison measured 1.228 over eight pairs, all with swap-ins, so it confirms the direction only. Nothing gates the ratio; `decode-overlap-check` gates exactness. Adopted in [[records/decisions/gpu-keepalive-on-ac-power]] and [[records/decisions/direct-demand-reads-default]].
