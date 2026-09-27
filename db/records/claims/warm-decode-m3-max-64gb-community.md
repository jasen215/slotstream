---
type: claim
id: 01m3a6dnb4vbm1fcm4c05ahcmw
created: 2026-09-24T17:11:44.228269+00:00
updated: 2026-09-24T17:32:26.893733+00:00
summary: 'M3 Max 64 GB community report: 12.38 tok/s'
basis: measured
gate: none
needle: 12.38 tok/s
supported_by: '[[records/measurements/c4-macbook-pro-m3-max-64gb-community]]'
surfaces: docs/HARDWARE.md
title: 'M3 Max 64 GB community report: 12.38 tok/s'
status: current
---
The third identical request to the reporter's running server on 0.2.18 with
the auto plan: a 48.1 GB target with about 119 experts per layer. The linked
measurement also supports the rest of the row: 213 tok/s for 8,192 prompt
tokens at context-check's 34.6 GB target and a 30.1 GB process peak. It is
below the ~15 tok/s floor of the 48–<96 GB estimate, which stays until this
Mac is rerun on the current release. Keep the release and community
attribution visible.
No gate: nothing in CI reproduces a community machine.
