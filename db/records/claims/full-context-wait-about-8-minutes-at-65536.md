---
type: claim
id: 01m2dg6wnd3r4za58w2rp3mb89
created: 2026-09-13T13:44:49.581296+00:00
updated: 2026-09-24T19:17:34.434565+00:00
summary: M5 Pro-based prefill estimate is about 8 minutes near the larger window from a 32 GB simulation, about 9 at 24 GB
basis: estimated
gate: Tools/planner_gates.sh checks that doctor reports the wait, not its value
needle: about 8 minutes
supported_by: '[[records/measurements/decode-lookahead-default-2026-09-13]]'
surfaces: docs/HARDWARE.md
title: M5 Pro-based prefill estimate is about 8 minutes near the larger window from a 32 GB simulation, about 9 at 24 GB
status: current
---
Doctor's estimated full-window wait at 65,536 tokens: 7.8 minutes at 24 and 32 GB and 7.5 from 36 GB, from the prefill curve measured on the M5 Pro.

## Scope audit, 2026-09-13

The public rows now explicitly call this M5 Pro-based simulated prefill
time. It does not measure end-to-end wait across physical Macs and excludes
startup, queueing, image preparation and reasoning before visible answer text.
The configured window must reserve room for a nonempty reply.

## Streamed draft head, 2026-09-24

The 24 GB plan now runs the draft head with streamed experts ([[records/decisions/draft-head-streams-its-experts-below-76-per-layer]]), which leaves room for a 512-token prefill pass at 65,536 tokens instead of 1,024: doctor estimates 8.8 minutes there, 7.8 at 32 GB and 7.5 from 36 GB. HARDWARE.md now says about 9 minutes at 24 GB and about 8 from 32 GB.
