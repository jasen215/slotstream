---
type: source
id: 01m3gktvn9jfz5jckx92dg8nsv
created: 2026-09-27T05:01:34.761273+00:00
updated: 2026-09-27T05:16:05.375652+00:00
summary: 'Frozen 2026-09-27 before measurement: three pass sizes at a 14 GB target on the 32 GB M5 Air for prefill and decode, two prefix lengths for the hit rate, with the gates fixed in advance'
captured_at: 2026-09-27
doc: docs
source_url: ''
title: 'Frozen pre-registration: prefill 100+, decode 10+, and a 98% prefix hit on the target machine'
status: superseded
---
# Frozen pre-registration: prefill 100+, decode 10+, and a 98% prefix hit on the target machine

**Frozen 2026-09-27**, before any measurement, on the machine it will run on:
[[records/machines/macbook-air-m5-32gb-local]] (Apple M5, applegpu_g17g, macOS 27, 34 GB RAM).
At freeze: **19.7 GB reclaimable**, no other model process. `doctor` auto-sizes to an 18.0 GB
process budget and a 32,768-token window at that reclaimable figure.

## The question

Asked of this machine, not of the engine in general: can prefill reach and *hold* 100+ token/s,
decode exceed 10 token/s, and the conversation hit rate reach 98%? Existing evidence gives one
answer per target: a 32 GB Air in the field reported **126.28 token/s** prefill and **6.22 token/s**
decode at a 22 GB plan ([[sources/community/2026/09/2026-09-07-macbook-air-m5-32gb-arczhi]]), this
repo's own 8k anchor is **184.1 token/s** at a 16 GB target on the development Mac, this Air's own
paired runs read a 3,849-row prompt at about 53 token/s at a 10 GB target with a 256-row pass, and
the published band for 24-<48 GB installed RAM is 6-14 token/s. This run settles it here.

## Instruments (both already gated; no new driver)

- **Prefill and decode**: `Tools/prefill_bench.py`. It runs one fresh process per cell, asserts
  `sum(prefillPasses) == promptTokens`, `promptTokens == len(prompt_ids)` and
  `decodeTokens == len(output_ids)`, interleaves rounds, and preserves and excludes failed,
  incomplete or swapping runs. Metrics come from `stats`: prefill token/s is
  `prefillTokens / prefillSeconds`, decode token/s is `decodeTokens / decodeSeconds`.
- **Hit rate**: `Tools/persistent_prefix_e2e.py`. It serves a three-turn conversation from separate
  servers at an explicit target, one model process at a time, and records `reusedPrefixTokens` and
  the disk tier's `restoredTokens`/`savedTokens` per turn. Hit rate is
  `reusedPrefixTokens / promptTokens` per turn.

## Frozen configuration

| part | setting |
| --- | --- |
| target | `--memory-gb 14` for both parts (14 + 3 GB margin = 17 GB <= 19.7 GB reclaimable) |
| Part 1 prompt | `--prompts acceptance` (the immutable ~8k-token fixture, 7,019 words) |
| Part 1 arms | three cells of the *same* binary differing only in compute pass: `--arm-chunk` 256, 1024, 2048 |
| Part 1 rounds | `--rounds 3`, same-cell rounds interleaved, order rotated |
| Part 1 decode | `--mtp on` (the adopted two-draft default), `--max-tokens 64` so the decode rate is not read off 16 tokens |
| Part 2 prefixes | `--words 6000` (~8k tokens) and `--words 12000` (~16k tokens) |
| Part 2 turns | `--turn-words 40` (~50-token new content), `--num-predict 48` |

The executor uses these tools as they are. If `SLOTSTREAM_PREFILL_CHUNK` is not the effective pass for
a cell, the effective pass must be read from `stats.prefillPasses` and the cell reported as not
delivered rather than silently counted.

## Gates, fixed before the numbers

- **G1 (prefill).** Median prefill token/s over three interleaved rounds on the 8k fixture:
  **pass 2048 must reach >= 100 token/s**, and pass 256 is expected to reproduce the 50-80 token/s
  range measured at a 10 GB target. If 2048 is under 100, prefill 100+ is *not* reachable at a 14 GB
  target on this machine and the remaining lever is the serial read path (cross-layer read-ahead),
  not the pass size.
- **G2 (decode).** Median decode token/s with MTP on at a 14 GB target: **>= 6.0** clears the
  published 32 GB Air figure (6.22, MTP off, 22 GB plan). **> 10 is pre-registered as not expected**;
  if a cell exceeds 10 the hardware table's Air row needs its own revisiting decision, and that is a
  finding to record, never a silent table edit.
- **G3 (hit rate).** `reusedPrefixTokens / promptTokens` on the longest prefix tested:
  **>= 0.98 at the ~16k-token prefix** and **>= 0.95 at the ~8k prefix**, each on the turn after the
  first, with the disk tier enabled. The predicted residual is the new turn's tokens plus at most one
  255-row partial pass, so the 16k prefix is the one that can reach 98%.
- **G4 (validity).** No cell counts if it swapped, aborted, timed out, or ran while a foreign model
  process or a compiler ran; every included cell must pass the tool's own identity assertions; the
  report gives per-round values and the spread, not only a median.

## What each outcome decides

| outcome | decision |
| --- | --- |
| G1 passes | the target machine's guidance becomes "raise the memory target to get a bigger pass", with the measured token/s per pass recorded as a claim |
| G1 fails | the honest answer to "prefill 100+" on this machine is *not at 14 GB*, and the read-path lever needs a plan of its own |
| G2 passes / fails | the 24-<48 GB hardware band keeps or loses its 6-token/s floor for this machine, with the evidence cited |
| G3 passes | "98% hit" is answerable as a workload property (long prefix, short turns), documented with the prefix length that reaches it |
| G3 fails | the residual model is wrong and the aligned-resume gap needs re-deriving from the raw per-turn stats |

## Limits, stated in advance

One machine, one SSD, one chip; the OS file cache is explicitly uncontrolled by the bench tool, so
"stable" can only be reported as the spread of interleaved rounds on this machine, never as a
guarantee; MTP on; no images; no concurrent requests; the weights are the local 4-bit conversion. A
14 GB target is chosen for safety on a machine whose reclaimable memory is 19.7 GB at freeze, so no
result here describes a 22 GB or larger plan on the same machine.
