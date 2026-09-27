---
type: source
id: 01m3gq71gz5xe1ddc0ym25q9z3
created: 2026-09-27T06:00:39.711061+00:00
updated: 2026-09-27T06:01:18.788421+00:00
summary: rev2's acceptance fixture answers with EOS in --raw mode, so all nine Part 1 cells decoded zero tokens and no decode rate exists; addendum A measures decode on fixtures that generate, with the gate fixed at 6.0 tok/s and the same swap rule
captured_at: 2026-09-27
doc: docs
source_url: ''
title: 'Frozen pre-registration addendum A: the decode rate rev2 could not measure'
---


## Paging eligibility, fixed before this run

The tool excluded all nine rev2 cells because a swap counter moved *at all*, while `swapouts` stayed
constant at 196401289 pages for the whole campaign and `swapins` rose 28 to 204 pages (0.07 to 0.8 MB)
per cell, on a machine reporting 19.5 to 25.1 GB reclaimable. A rule that treats 0.1 MB of another
application's paging the same as a swap storm cannot measure anything on a shared Mac, and it is
stricter than this project's own decision that **global paging is a diagnostic, never a gate on its
own**, which keeps clean benchmark eligibility separate from functional acceptance
([[records/decisions/global-paging-is-diagnostic]]).

`Tools/prefill_bench.py` now excludes a cell only when either counter moves by more than
`SWAP_EXCLUSION_PAGES` (4096 pages, 16 MiB, about 0.1% of a 14 GB target), and records the per-cell
deltas as `swap_pages` either way so both verdicts are visible. The threshold and the numbers it will
be judged by are fixed here, before any decode cell runs. **Rev2's nine excluded cells keep their
binary-rule verdict as recorded in RESULTS.md; nothing about rev2 is rewritten.**
