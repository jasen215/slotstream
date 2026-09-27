---
type: source
id: 01m3gmnd99nw3w541x6243xstc
created: 2026-09-27T05:16:04.777196+00:00
updated: 2026-09-27T05:16:13.649097+00:00
summary: Rev2 keeps gates G1-G4 and resolves rev1's instrument contradiction with an explicit --allow-large-target flag on the two drivers; rev1 halted before a model started, so no number exists
captured_at: 2026-09-27
doc: docs
source_url: ''
title: 'Frozen pre-registration rev2: prefill 100+, decode 10+, and a 98% prefix hit on the target machine'
---
# Frozen pre-registration rev2: prefill 100+, decode 10+, and a 98% prefix hit on the target machine

**Rev2, frozen 2026-09-27, still before any measurement.** Supersedes
[[sources/docs/2026/09/2026-09-27-air-speed-hitrate-preregistration]], whose campaign was **halted
before a model ever started**: rev1 set `--memory-gb 14` for both parts, and both named instruments
refuse a target above 10 GB at argument-parse time (`Tools/prefill_bench.py:221`,
`Tools/persistent_prefix_e2e.py:256`). No cell ran, no number exists, nothing was swapped. The raw
rejection evidence is in `.build/air-speed-20260927/probe-rejections.txt`
(sha256 cfeb80bc282887b744fa4dee0decbe860e824da893219da0aa51f6278a33496e). **The gates were not
touched by this revision and could not have been, since no measurement had been taken.**

## What changed, and why this way

The two instruments were given an explicit `--allow-large-target` flag that lifts their ceiling from
10 GB to 18 GB. The default guard is unchanged, and a target above 10 GB without the flag is still
refused. This follows the project's own memory-safety policy — tests use 8.1 to 10 GB *"unless the
large configuration is itself the measurement, and then nothing else heavy may be running"* — which
the drivers could not previously express. The alternative, re-freezing at 10 GB, would have measured a
configuration nobody runs: the engine's own `doctor` sizes this machine to an 18.0 GB plan and the
field report for this hardware used 22 GB, so a 10 GB cap answers a different question than the one
asked. Drivers as committed, with their own tests passing inside `Tools/static_gates.sh`:

| file | sha256 |
| --- | --- |
| `Tools/prefill_bench.py` | 2e6a5ea03c122162f00233f3a1761b7a906683ce63edbe7b2917eb6ef12d5e41 |
| `Tools/persistent_prefix_e2e.py` | 127610ecfc12681c3381b0af0b3822758ad0a5dbe45c2bf054d2349aaf4764d1 |

**Arithmetic correction to rev1.** `persistent_prefix_e2e.py`'s own `--headroom-gb` default is
**4.0**, not 3.0: at a 14 GB target it requires 18 GB reclaimable, not 17. That is still satisfied
(19.9 GB reported by the executor's preflight) and is the number the frozen config now states.

## Frozen configuration, rev2

| part | setting |
| --- | --- |
| target | `--memory-gb 14 --allow-large-target` for both parts (14 + 4 GB headroom = 18 GB <= 19.9 GB reclaimable at freeze) |
| Part 1 prompt | `--prompts acceptance` (the immutable ~8k-token fixture, 7,019 words) |
| Part 1 arms | three cells of the *same* binary differing only in compute pass: 256, 1024, 2048 via `--arm-chunk` |
| Part 1 rounds | `--rounds 3`, rounds interleaved, order rotated |
| Part 1 decode | `--mtp on`, `--max-tokens 64` |
| Part 2 prefixes | `--words 6000` (~8k tokens) and `--words 12000` (~16k tokens) |
| Part 2 turns | `--turn-words 40` (~50-token new content), `--num-predict 48` |

Everything else — the metrics, gates G1 to G4, the decision each outcome forces, the validity rules
and the limits — stands exactly as frozen in rev1 and is not restated here to avoid two versions
drifting. A cell whose requested pass is not the effective pass is still reported as not delivered.

## Added stop condition for rev2

If the engine refuses or clamps the 14 GB target at runtime (rather than at argument parse), that is
the answer for this machine and is reported as such; the target is not raised to force a number.
