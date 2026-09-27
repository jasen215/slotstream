---
type: measurement
id: 01m3gv2wzenzzsrypgbjc1pqp9
created: 2026-09-27T07:08:18.286493+00:00
updated: 2026-09-27T07:08:18.324204+00:00
summary: At a 14 GB target on the 32 GB Air, a 19.5k-token context decodes at 2.4 to 3.3 token/s warm or cold, so a cold pool does not explain addendum A's gap; doctor estimates about 7 at 40 of 512 experts per layer, 0.40 of the measurement
captured_at: 2026-09-27
date: 2026-09-27
doc: measurements
level: '3'
order: '348'
title: The warm decode rate on the target machine
status: measured
---
# The warm decode rate on the target machine

**Why.** Addendum A measured 3.18 to 3.88 token/s but only as a burst right after a cold prefill, and
`doctor` estimates about 7 token/s at this target, so the open question was whether the pool being cold
explained the gap. The frozen protocol is
[[sources/docs/2026/09/2026-09-27-warm-decode-preregistration]]; the run used
`Tools/persistent_prefix_e2e.py` sha256 b1c93f2d at HEAD 0c0390f, `--memory-gb 14 --allow-large-target
--words 12000 --turn-words 400 --num-predict 64`, one model process, raw artifacts in
`.build/air-speed-20260927/` (RESULTS-WARM-DECODE.md ae3689ec, warm-decode-14.json 5b38cdf3,
doctor-plan-14.txt c0d8ed06).

| request | context | decode token/s | decode s | first token s |
| --- | --- | --- | --- | --- |
| turn 1, cold | 19413 | 2.59 | 24.664 | 466.99 |
| turn 2, warm | 20151 | 2.86 | 22.369 | 64.64 |
| turn 3, warm | 20875 | 2.82 | 16.318 | 52.79 |
| turn 3, restart | 20875 | 2.63 | 17.523 | 65.67 |
| turn 3, regenerate | 20875 | 2.42 | 19.009 | 33.02 |
| turn 2, cold server | 20151 | 3.34 | 19.183 | 481.51 |

**G6 is not met**: turn 3 reads 2.82 token/s against the 6.0 bar, and the rate is flat from 2.42 to 3.34
across all six requests, cold and warm alike. **The pool being cold does not explain the gap**; the same
engine at the same 14 GB target, asked a 19.4k to 20.9k token question, decodes at about a third of the
published 6.22 for this machine.

**G7 reads as an optimistic estimator**: `doctor --memory-gb 14` prints about 7 token/s at 40 of 512
experts per layer (1902 planned slots), and 2.82 against 7 is 0.40, below the 80% that the protocol
fixes as a defect rather than a rounding difference.

**The confound is stated, not hidden.** Addendum A's burst used 3.7k and 440-token prompts while these
turns carry 19.4k to 20.9k tokens of context, so this run does **not** isolate pool warmth, and it does
not claim to. What it does show is that warm and cold requests at the *same* context differ by little
(2.42 to 3.34 over both), which points at context length rather than pool temperature — consistent with
this repository's own record that decode after a long prefill runs slower than the short-prompt anchors
(3.5 against about 7 at 41 experts per layer). The actionable number is therefore: **on this machine at a
19.5k-token context, decode is 2.4 to 3.3 token/s**, warm or cold.

**A 20 GB target is not deliverable with the pinned driver.** `--allow-large-target` lifts the ceiling to
18 GB, so 20 GB is refused at argument parse with no server started, and `doctor --memory-gb 20` refuses
separately at 19.0 GB reclaimable (maximum feasible window 0 tokens). An adaptive ceiling of 22 GB does
plan a 20.0 GB target; a fixed 20 GB cache does not. Recorded as not delivered, not worked around.

## Protocol errors in the frozen text, owned here

1. G7 quoted `doctor`'s 16 GB row (~8 at 54 of 512 experts per layer). At 14 GB it prints about 7 at 40
   of 512, and 7 is the number used; against 8 the ratio would be 0.35.
2. The protocol said the tool's swap rule stood. `Tools/persistent_prefix_e2e.py` samples no swap
   counters at all — that rule lives in `Tools/prefill_bench.py`. The campaign-level `vm_stat` moved
   +5168 swapins (~85 MB) and +804 swapouts (~13 MB) across the run and the idle around it,
   unattributable per turn, and `swapouts` moved for the first time in this campaign.
3. It asked for effective pool slots and lifetime RSS, which this driver does not copy out of the reply
   and whose work directory is removed without `--keep`. For the same 14 GB target addendum A realized
   1742 slots at pass 256 and 1381 at pass 1024 against doctor's planned 1902 here.

**The driver's own acceptance is still `passed:false`**, on one check: after turn 2 it expects the shared
head and both conversation states, finds 2 where it wants 3 (progression 1 to 2 to 3). All eleven
identity and behaviour checks pass, including that the restart and regenerate turns reproduce the first
server's prompt and output ids exactly. Whether that expectation predates the rule that a deeper
snapshot replaces the one it supersedes is unresolved and is not claimed either way.

## Limits

One machine, one conversation shape, one round, MTP depth 2 as adopted, no images, no concurrency, no
context sweep — so this does not separate context length from pool warmth quantitatively, and the second
target is absent. Warm here means the third request into one server, not a steady state after minutes of
traffic.

## What it decides

- **decode 10+**: further out than the cold burst suggested, and not reachable on this machine at a 14 GB
  target and a long context, where about 3 token/s is what it does.
- **The planner's decode estimate over-promises by roughly 2.5x for a long-context session on this
  machine.** G7's frozen rule requires its own correction plan, quoting this measurement, before any
  planner number is trusted; the estimator carries a pool-size ladder and no context-length term.
- **The earlier reading of about 6 to 8 token/s at this target is withdrawn** in favour of 2.4 to 3.3 at a
  19.5k-token context. No user-facing surface carries any of these numbers.
