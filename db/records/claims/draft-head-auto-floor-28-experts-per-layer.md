---
type: claim
id: 01m3adf72zy53mdzya8pj0z7z8
created: 2026-09-24T19:14:55.199752+00:00
updated: 2026-09-24T19:14:55.199752+00:00
summary: The draft head's automatic floor is 28 experts per layer, a 12 GB target
basis: derived
gate: slotstream-checks decode-lookahead-defaults and Tools/planner_gates.sh
needle: 28 experts per layer
supported_by: '[[records/measurements/decode-perf-2026-09-24]]'
surfaces: docs/CLI.md, docs/ENGINEERING.md, llms.txt, CHANGELOG.md
title: The draft head's automatic floor is 28 experts per layer
status: current
---
`Planner.mtpAutoFloorPerLayer` is 28: automatic mode enables the draft head when the cache still holds 28 experts per layer after the head's charge, streamed below 76 ([[records/decisions/draft-head-streams-its-experts-below-76-per-layer]]). A 12 GB target reaches it at the 32,768-token window and a 24 GB Mac's automatic plan runs the head. The decode-lookahead-defaults check asserts the 12 GB plan at or above the floor; planner_gates.sh checks `--memory-gb 12` with the streamed head, `--memory-gb 11` without it and a 24 GB Mac streaming.
