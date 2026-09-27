---
type: claim
id: 01m3a6dnc5fqcw0prdk0te9t12
created: 2026-09-24T17:11:44.261506+00:00
updated: 2026-09-24T17:11:44.261506+00:00
summary: 'M4 Max 64 GB community report: 15.93 tok/s'
basis: measured
gate: none
needle: 15.93 tok/s
supported_by: '[[records/measurements/c5-macbook-pro-m4-max-64gb-community]]'
surfaces: docs/HARDWARE.md
title: 'M4 Max 64 GB community report: 15.93 tok/s'
status: current
---
The third identical request on 0.2.22 with the auto plan (a 48.1 GB target
with about 119 experts per layer) and the model on the internal SSD. The run
used the pre-0.2.19 decode forecast because the correction file was absent.
The linked measurement also supports the row's 270 tok/s for 8,192 prompt
tokens and its 30.1 GB process peak. No gate: nothing in CI reproduces a
community machine.
