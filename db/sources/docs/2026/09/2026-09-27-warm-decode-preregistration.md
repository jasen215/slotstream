---
type: source
id: 01m3gsndh13g73b9b5n3xjs4mh
created: 2026-09-27T06:43:27.905189+00:00
updated: 2026-09-27T06:43:28.512798+00:00
summary: 'Frozen before the run: the warm decode rate at a 14 GB target on the 32 GB Air, measured with several requests against one server, with gate G6 at 6.0 token/s and an estimator check that is 20% either way'
captured_at: 2026-09-27
doc: docs
source_url: ''
title: 'Frozen pre-registration: the warm decode rate'
---
# Frozen pre-registration: the warm decode rate

**Frozen 2026-09-27, before the run.** Addendum A measured decode at 3.18 to 3.88 token/s, but that is a
burst immediately after a cold prefill in a fresh process, with the pool still filling
([[records/measurements/air-speed-and-hit-rate-2026-09-27]]). `doctor` estimates about 8 token/s at that
target's 54 experts per layer, and this machine's published figure is 6.22 token/s at a 22 GB plan with
MTP off. Which of those the warm rate actually is decides whether the estimator is sound on this
machine or optimistic by more than a factor of two, which is the kind of error this project treats as a
defect rather than a rounding difference.

## Frozen configuration

| part | setting |
| --- | --- |
| instrument | `Tools/persistent_prefix_e2e.py` (sha256 pinned at dispatch), which issues several requests against **one** server, so the pool admitted by the last prefill pass is warm for the following turns |
| new field | the driver now records the engine's own `decodeSeconds` beside `decodeTokens` per turn (`tools: record the decode phase on each e2e turn`) |
| target | `--memory-gb 14 --allow-large-target`, the same target as addendum A, so the cold and warm numbers are directly comparable |
| workload | `--words 12000` (about a 19.5k-token prefix), `--turn-words 400`, `--num-predict 64`, default `--headroom-gb` |
| why 400 | the driver's own comment says 400 is what crosses a pass boundary; the 40-word turns of rev2 saved nothing and failed its state accounting, so this is also the口径 that lets its identity checks pass |
| second target | attempted only if reclaimable memory is at least 18 GB: `--memory-gb 20 --allow-large-target`, the effective target of a 22 GB adaptive ceiling, since that is the configuration a user actually runs |

## Metrics reported per turn

`decodeTokens`, `decodeSeconds`, decode token/s, `firstTokenSeconds`, `reusedPrefixTokens`,
`restoredTokens`, effective pool slots, lifetime RSS peak, engine footprint peak, and the swap counters
before and after. Turn 1 is labelled cold (the pool is being filled by its own final pass); turns 2 and
3 are the warm measurements.

## Gates, fixed before the numbers

- **G6.** Warm decode (turn 3) reaches **6.0 token/s**, this machine's published figure. Met: the
  24-<48 GB band's floor holds here and MTP's contribution keeps its evidence. Missed: the Air row and
  the MTP contribution must be restated with this measurement cited, never edited silently.
- **G7 (estimator check).** Compare the warm rate with `doctor`'s warm estimate at the same pool size.
  Within **20%** of the estimate: the estimator is sound on this machine and the cold burst is a
  methodology artifact to document as such. Below **80%** of it: the estimator is optimistic here and
  needs its own correction plan, quoting this measurement, before any planner number is trusted.
- **Validity.** The tool's swap rule and identity assertions stand. An excluded turn is reported with its
  swap magnitudes and its face-value number and is **never waived to make a gate pass**.

## Limits, stated in advance

One machine, one conversation shape, a long prefix and short turns, MTP depth 2 as adopted, no images,
no concurrency, one round per target, and the second target only if memory allows. Warm here means
"several requests into one server", not a steady state after minutes of traffic. Nothing measured here
is a claim about a different memory tier, and no user-facing number moves without its own decision.
