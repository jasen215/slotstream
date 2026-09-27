---
type: claim
id: 01m3adf73hrksgst1qmmsw7s6t
created: 2026-09-24T19:14:55.217041+00:00
updated: 2026-09-24T19:14:55.217041+00:00
summary: The decode lookahead made plain decode 1.11x faster at a 10 GB target
basis: measured
gate: none
needle: made plain decode 1.11x faster
supported_by: '[[records/measurements/decode-perf-2026-09-24]]'
surfaces: docs/CLI.md, docs/ENGINEERING.md, llms.txt, CHANGELOG.md
title: The decode lookahead made plain decode 1.11x faster at a 10 GB target
status: current
---
Plain decode with the decode lookahead against without it, both with the GPU keepalive and direct demand reads, at a 10 GB target where the draft head stays off: 1.112 over four swap-free pairs of the environment-guarded prototype (1.123 over all eight, eight of eight above 1), 20.0 experts per layer before the lookahead's charge and 17.1 after, identical output, four prompts on one 48 GB M5 Pro. Surfaces round it to 1.11x. The landed build measured 1.045 over seven pairs and 1.082 over eight in a later session that interleaved it with the prototype (1.064 there), and 1.050 at 22 GB with the head off, all with swap-ins in every pair, so they confirm the direction only. Nothing gates the ratio; `draft-stream-check` gates exactness. Adopted in [[records/decisions/decode-lookahead-in-plain-decode]].
