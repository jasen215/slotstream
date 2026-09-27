---
type: claim
id: 01m3a6dn9smwkrpj69mx70dw6g
created: 2026-09-24T17:11:44.184741+00:00
updated: 2026-09-24T17:11:44.184741+00:00
summary: 'M2 mini 0.2.3 re-run: 1.48 tok/s'
basis: measured
gate: none
needle: 1.48 tok/s
supported_by: '[[records/measurements/c1-mac-mini-m2-16gb-base-storage-community-2026-09-02]]'
surfaces: docs/HARDWARE.md
title: 'M2 mini 0.2.3 re-run: 1.48 tok/s'
status: current
---
The third identical request of `@flol`'s 0.2.3 re-run on the 16 GB Mac mini
M2, at a 10.7 GB auto target with about 25 experts per layer. The linked
measurement also supports the rest of that row: 8,192 prompt tokens in
12.1 min (11 tok/s) with an 8.1 GB RSS peak. The 0.2.2 row's 1.41 tok/s stays
beside it; the difference is inside the run-to-run spread and is not a
speedup claim. No gate: nothing in CI reproduces a community machine.
