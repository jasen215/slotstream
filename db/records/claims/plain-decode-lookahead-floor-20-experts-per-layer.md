---
type: claim
id: 01m3adf74mtkpabjsrrfmxpsa5
created: 2026-09-24T19:14:55.252390+00:00
updated: 2026-09-24T19:14:55.252390+00:00
summary: Without the draft head the decode lookahead runs from 20 experts per layer before its charge
basis: derived
gate: slotstream-checks decode-lookahead-defaults and Tools/planner_gates.sh
needle: 20 experts per layer
supported_by: '[[records/measurements/decode-perf-2026-09-24]]'
surfaces: docs/CLI.md, llms.txt, CHANGELOG.md
title: Without the draft head the decode lookahead runs from 20 experts per layer
status: current
---
`Planner.plainLookaheadFloorPerLayer` is 20: without the draft head, the decode lookahead runs when the cache before its charge still holds 20 experts per layer, the smallest cache it was measured faster at, a 10 GB target ([[records/decisions/decode-lookahead-in-plain-decode]]). The decode-lookahead-defaults check asserts plain plans at 10 GB with it and 9 GB without it; planner_gates.sh checks `--memory-gb 11` and `--mtp off`.
