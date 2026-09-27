---
type: claim
id: 01m3adf725v4skvdrywjc46cbx
created: 2026-09-24T19:14:55.172709+00:00
updated: 2026-09-24T19:14:55.172709+00:00
summary: The draft head with streamed experts decoded 1.23x faster than plain decode with the lookahead at a 12 GB target
basis: measured
gate: none
needle: 1.23x faster than plain decode
supported_by: '[[records/measurements/decode-perf-2026-09-24]]'
surfaces: docs/CLI.md, docs/ENGINEERING.md, llms.txt, CHANGELOG.md
title: The draft head with streamed experts decoded 1.23x faster than plain decode with the lookahead at a 12 GB target
status: current
---
The draft head with streamed experts and the lookahead against plain decode with the lookahead, both with the GPU keepalive and direct demand reads, at a 12 GB target: 1.230 over three swap-free pairs of the environment-guarded prototype (1.207 over all eight, eight of eight above 1), four prompts of 192 greedy tokens on one 48 GB M5 Pro. Surfaces round it to 1.23x. The landed build's own comparison, automatic mode against `--mtp off`, measured 1.205 over eight pairs, all with swap-ins, so it confirms the direction only. Nothing gates the ratio; `draft-stream-check` gates exactness. Adopted in [[records/decisions/draft-head-streams-its-experts-below-76-per-layer]].
