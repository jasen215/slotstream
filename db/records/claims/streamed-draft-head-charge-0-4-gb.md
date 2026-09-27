---
type: claim
id: 01m3adf755ncn4q831hhhrjtsw
created: 2026-09-24T19:14:55.269843+00:00
updated: 2026-09-24T19:14:55.269843+00:00
summary: A draft head whose experts stream is charged 0.4 GB instead of 1.6 GB
basis: derived
gate: Tools/planner_gates.sh
needle: 0.4 GB
supported_by: '[[records/measurements/decode-perf-2026-09-24]]'
surfaces: docs/CLI.md, docs/ENGINEERING.md, llms.txt, CHANGELOG.md
title: A draft head whose experts stream is charged 0.4 GB instead of 1.6 GB
status: current
---
A streamed draft head is charged 389,017,600 bytes instead of the resident 1.6 GB: the resident charge minus its 512 routed experts of 2,764,800 bytes each, plus 64 cached and 10 scratch records (`PlannerCostModel.mtpStreamedBytes`). Surfaces round it to 0.4 GB. planner_gates.sh asserts the JSON ledger's `mtp_resident_bytes` at a 16 GB target; `MTPExpertStream` refuses a head whose geometry differs from the charged one. [[records/decisions/draft-head-streams-its-experts-below-76-per-layer]].
