---
type: claim
id: 01m3adkkdxmpcpfktxsf5z3f06
created: 2026-09-24T19:17:18.909735+00:00
updated: 2026-09-24T19:17:18.909735+00:00
summary: Auto turns speculative decode on when the cache still reaches 28 experts per layer after the head, a 12 GB target
basis: derived
gate: Tools/planner_gates.sh
needle: 12 GB target
supported_by: '[[records/measurements/decode-perf-2026-09-24]]'
surfaces: docs/CLI.md, docs/ENGINEERING.md, llms.txt
title: Auto turns speculative decode on when the cache still reaches 28 experts per layer after the head, a 12 GB target
status: current
---
At the default context, doctor plans the head off at an 11.9 GB target and on at 12 GB, with its experts streamed, from the 28-per-layer floor of [[records/claims/draft-head-auto-floor-28-experts-per-layer]]. The floor rests on [[records/measurements/decode-perf-2026-09-24]]: at 12 GB the streamed head with the lookahead decoded 1.23x faster than plain decode with the lookahead. Decision [[records/decisions/draft-head-streams-its-experts-below-76-per-layer]]; replaces [[records/claims/mtp-auto-floor-76-per-layer-21-gb-target]]. As before, the floor is checked after the head and context charges and before the lookahead's own reservation, and physical availability, a larger window or a missing draft file can keep the head off on a larger Mac.
