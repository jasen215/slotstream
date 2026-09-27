---
type: claim
id: 01m2dg6whed4acn5zk7gtr5tv1
created: 2026-09-13T13:44:49.454394+00:00
updated: 2026-09-24T19:15:12.968980+00:00
summary: The draft head keeps its experts resident from 76 experts per layer; below that they stream, and the automatic floor is 28
basis: derived
gate: slotstream-checks decode-lookahead-defaults and Tools/planner_gates.sh
needle: 76 experts per layer
supported_by: '[[records/measurements/mtp-depth-auto40-multitasking-2026-09-11]], [[records/measurements/decode-perf-2026-09-24]]'
surfaces: docs/CLI.md, docs/ENGINEERING.md, docs/HARDWARE.md, llms.txt
title: The draft head keeps its experts resident from 76 experts per layer
status: current
---
`Planner.mtpResidentFloorPerLayer` is 76: from 76 experts per layer after the head's full 1.6 GB charge the draft head keeps its 512 experts resident, and below it they stream through a 64-expert cache ([[records/decisions/draft-head-streams-its-experts-below-76-per-layer]]). Until September 24, 2026 the same number was the head's automatic floor ([[records/decisions/draft-head-auto-floor-76-per-layer]]). The check asserts plans on both sides of it; planner_gates.sh checks a 22 GB target with the resident head and a 16 GB target streaming. HARDWARE.md also uses the phrase for the 0.2.14 two-draft measurement at 76.4 per layer that set the former floor.

**Before September 24, 2026.** `Planner.mtpAutoFloorPerLayer` is 76 ([[records/decisions/draft-head-auto-floor-76-per-layer]]). The check asserts plans on both sides of it; planner_gates.sh checks a 24 GB Mac below it and a 32 GB Mac above it at the default context. HARDWARE.md also uses the phrase for the 0.2.14 two-draft measurement at 76.4 per layer that set the floor.
