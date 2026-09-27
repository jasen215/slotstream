---
type: decision
id: 01m3ghw0kzgvc8g0vwh0nkcfth
created: 2026-09-27T04:27:15.455896+00:00
updated: 2026-09-27T04:27:23.700285+00:00
summary: 'Order 344 changed no default: serve keeps the tier off unless asked, launch keeps starting its server with it, and the measured 1.5x-1.6x value justifies that split rather than a new default'
captured_at: 2026-09-26
decided_on: 2026-09-26
reversible_if: a target-range Mac's no-restore overhead grows enough to matter, or the invalidation key or disk quota changes behaviour for launch users
title: The disk prefix tier stays opt-in for serve and on for launch
status: standing
---
# The disk prefix tier stays opt-in for `serve` and on for `launch`

**Decision.** `slotstream serve` keeps `--prefix-cache-dir` off unless the user sets it.
`slotstream launch` keeps starting its server with `~/.slotstream/prefix-cache` and the 20 GB default
quota. Order 344 changed no default.

## Why

The measured value is real: on a paired A/B over three rounds and twelve matched turns the tier is
**1.60x** on first-token seconds against a no-disk arm — **1.50x** on the steady-state subset, since the
first round carries the machine's own warm-up — **3.44x to 3.72x** on the turn after a restart, and it
recovers a state its own restore evicted in 0.11 s where a rebuild reads the whole prompt
([[records/measurements/disk-prefix-tier-value-2026-09-26]]). That justifies keeping it on where the
product already chose a directory for it.

It does not justify turning it on for every `serve`. The tier writes model state to a directory the
user did not name, its files are keyed to the executable image, weight content, geometry and
optimization settings so a rebuild invalidates them, and it holds a disk quota. Enabling that silently
would trade someone's disk for speed they did not ask for; the flag is one word long and the docs now
say what it buys. `launch` is the case where the directory is the product's own choice and the win is
its purpose: an agent's instructions and long conversation are read once, and a restarted server should
not read them again.

## Revision criterion

Re-measure on another machine before carrying these numbers: the cold-start rate and the restore cost
are properties of this SSD, this model's pass structure and the current planner. Revisit the default if
a target-range Mac shows the tier's presence overhead (0.970 on the no-restore control turn, n=3,
suggestive only) growing enough to matter, or if the invalidation key or the disk quota changes
behaviour for `launch` users.

## Limits

One machine, one internal SSD, one prompt shape, `--memory-gb 10`, no images and no speculation
interaction; R=3 is a coarse bootstrap. The target range is Macs that cannot hold the model. The
eviction's isolated marginal cost was not isolable in the follow-up workload, so the tier's eviction
behaviour is measured as a net ([[sources/runs/2026/09/2026-09-26-disk-prefix-eviction-cost]]).
