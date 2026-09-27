---
type: claim
id: 01m2dg6wgw8asdg6zw1n2ag5vn
created: 2026-09-13T13:44:49.436975+00:00
updated: 2026-09-24T19:17:18.891280+00:00
summary: Auto turns speculative decode on when the cache still reaches 76 experts per layer after the head, a 21 GB target
basis: derived
gate: Tools/planner_gates.sh
needle: 21 GB target
supported_by: '[[records/measurements/decode-lookahead-default-2026-09-13]]'
surfaces: docs/CLI.md, docs/ENGINEERING.md, llms.txt
title: Auto turns speculative decode on when the cache still reaches 76 experts per layer after the head, a 21 GB target
status: withdrawn
---
At the default context, doctor plans the head off at a 20.5 GB target and on at 21 GB. The floor rests on [[records/measurements/mtp-depth-auto40-multitasking-2026-09-11]]: two drafts 31.7% faster than plain decode on the same memory at 76.4 per layer. Decision [[records/decisions/draft-head-auto-floor-76-per-layer]]; replaces [[records/claims/mtp-auto-floor-120-per-layer-28-gb-target]].

## Scope audit, 2026-09-13

The activation threshold is checked after head and context charges but
before the separate decode-lookahead reservation. The final printed cache can
be smaller than the threshold. Physical availability, a different context or
missing draft weights can disable auto MTP even on a larger-memory Mac.

## Withdrawn (2026-09-24)

The draft head can now stream its experts, and automatic mode turns it on from 28 experts per layer after that smaller charge, a 12 GB target ([[records/decisions/draft-head-streams-its-experts-below-76-per-layer]]). The guides now name the 12 GB target; [[records/claims/mtp-auto-floor-28-per-layer-12-gb-target]] replaces this claim.
