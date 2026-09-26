---
type: run
id: 01m3e2dmjaq4wh9zbnm9eb16gz
created: 2026-09-26T05:18:46.858062+00:00
updated: 2026-09-26T05:19:24.928201+00:00
summary: 'The elastic drill traced on the 34 GB Air: a 1576-slot arena shrinks to 941 and cannot grow back, because the 1.75 GB round trip is under the 2 GB grow dead-band'
binary: slotstream (working tree at c5e4431 plus the SLOTSTREAM_GOVERNOR_TRACE knob); release build of 2026-09-26 13:18
captured_at: 2026-09-26
command: slotstream elastic-drill --slots 1000 --max-memory-gb 13 --memory-limit-gb 13 --mtp off, run with SLOTSTREAM_GOVERNOR_TRACE=1; then the same with --slots 1800, and a pre-fix binary built from b45edd4
discarded: 'true'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
title: 'The elastic drill arena on the 34 GB Air: a 1576-slot round trip is under the grow dead-band'
tool: slotstream elastic-drill (release build carrying the governor decision trace)
---
## Why this was captured

`Tools/verify.sh` requires the live governor drill
(`elastic-drill --slots 1000 --max-memory-gb 13 --memory-limit-gb 13 --mtp off`)
to shrink a running cache under simulated pressure, honor the 60 s grow
cooldown, and grow back. It failed on this machine on 2026-09-26, repeatedly,
and the drill's own log cannot say why: a refusal moves nothing.

The same command passed on 2026-09-21 (see the adaptive-memory second review),
but that run is attributed to `macbook-pro-m5-pro-48gb`, not to this 32 GB Air,
so it is not evidence about this machine.

## What the trace printed

`SLOTSTREAM_GOVERNOR_TRACE=1` was added the same day and prints every poll's
decision with its inputs. The three decisions of the round trip, verbatim:

```text
elastic: governor trace: resize to 941 (availability dropped) — now 1576 slots (4.4 GB), planner wants 941 (2.6 GB), available 2.0 GB
elastic: governor trace: hold — now 941 slots (2.6 GB), planner wants 1576 (4.4 GB), available 6.1 GB
elastic: governor trace: hold — now 941 slots (2.6 GB), planner wants 1576 (4.4 GB), available 6.1 GB
```

The first is the squeeze. The second and third are the cooldown poll and the
post-cooldown poll. Both hold although the planner wants the arena back at
1576 slots: 1576 − 941 = 635 slots, about 1.75 GB, is under
`GovernorPolicy.growDeadbandGB = 2.0`, and the `restoring` escape in
`GovernorPolicy.decide` does not apply because the plan at the 6.1 GB recovery
stimulus is still clamped by availability. The drill then reports:

```text
ELASTIC DRILL FAIL
  - governor did not grow back: 941 -> 941
  - governor did not restore the complete starting cache: 941 instead of 1576
```

## What it is not

- Not this session's prefix-retention fix. A pre-fix binary built from
  `b45edd4`'s `Governor.swift` and `PrefixCache.swift` fails identically:
  941 → 941, the same 6.1 GB stimulus, `complete:false`, at the same
  ~18.3 GB reclaimable.
- Not `--slots`. The starting pool is the 13 GB adaptive plan's own pool, so
  `--slots 1800` also starts at 1576 slots and fails the same way.
- Not the memory guard in `MemoryGovernor.apply`: the growth never reaches it.
  `GovernorPolicy.decide` returns `.hold`, so `apply` is not called at all.
- Not swap alone. `swapouts` were unchanged across the run and the drill's
  process peak stayed at 7.9 GB, under its 13 GB ceiling.

## What it settles

On a 34 GB machine whose 13 GB plan leaves a 4.4 GB pool, this drill cannot
pass: the round trip its availability seam produces is about 1.75 GB, under the
grow dead-band the governor deliberately keeps. The governor is behaving as
designed — growing a cache by 1.75 GB is exactly what a 2 GB band is meant to
ignore — so this red is a property of the drill's arena on this machine, not a
governor regression and not a regression from the retention-ceiling fix.

`verify.sh` counts it as a FAIL rather than a SKIP, which is honest but, without
a trace, indistinguishable from a governor regression. Whether the drill should
price its arena so the round trip crosses its own grow band, or skip when it
cannot, is a decision for the maintainer; nothing here changes the governor.
