---
type: measurement
id: 01m3exsk4avrhne5mhr5w2k4k3
created: 2026-09-26T13:17:10.154855+00:00
updated: 2026-09-26T13:17:19.751328+00:00
summary: A restore costs 21.3 ms plus 3.95 ms per 1000 restored tokens (n=9, r2=0.954); the re-read arm does not fit token count (n=19, r2=0.012) - its unit of cost is one 256-row pass
date: 2026-09-26
doc: measurements
level: '3'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
note: Offline fit over the turns in the store; no model run. The disk arm's fit is tight and is a lower bound on its cost.
order: '344'
runs: '[[sources/runs/2026/09/2026-09-26-disk-prefix-step1-fit]]'
title: A restore is cheap and a re-read is priced by the pass
status: measured
---
The two arms of the disk prefix tier's break-even, measured from the turns already in the store:
what a restore costs, and what the re-read it replaces costs.

**The state the tier serves.** `--prefix-cache-dir` writes a committed text state to disk and
restores it into buffers of the saved shapes. Memory answers first; disk is consulted only for
a state longer than the one memory retains, and only at one of the request's own prefill pass
boundaries. So the tier's benefit is never the whole prompt — it is the tokens between what
memory offered and what the disk state holds.

**A restore costs 21 ms plus 3.95 ms per 1000 restored tokens.** Nine restored states of 3584
to 15632 tokens across the recorded runs, 0.0305 to 0.0908 s each:

```
seconds = 0.0213 + 3.946e-06 * restored tokens     n=9  r2=0.954
residual p50 +0.0004 s, p90 +0.0046 s
```

This is a lower bound. The timer starts inside the operations lock, after room has been made,
so it excludes the eviction a restore causes. Order 344's step-0 instrumentation measured that
eviction for the first time: one 4352-token restore on the first server evicted two
conversations.

**The re-read is not priced per token, and a per-token fit is a negative result.** Regressing
the recorded prefill times on the tokens each request read for itself gives

```
seconds = 19.429 + 0.00310 * tokens read            n=19  r2=0.012
residual p50 -17.718 s, p90 +21.130 s
```

with the same 25-token residual costing 1.50 to 1.79 s in warm turns and 42.23 s in a cold one
of the same run, and a 3921-token read costing 1.64 s where a 3663-token read cost 37.33 s in
another run. The reason is the pass, not the pool: `PrefillSchedule` keeps a 256-row floor, so
reading 18 tokens and reading 256 tokens are one pass, and any "milliseconds per token" figure
that divides by a small residual is an artifact of that floor. Across the recorded turns one
pass measured 1.5 to 1.7 s at a warm pool and 21 to 52 s cold or SSD-bound.

**What the comparison therefore is.** A restore costs at most 0.09 s. The smallest saving a
re-read can yield is one pass: 1.5 s warm, tens of seconds cold. So the disk arm wins by about
20x when it removes a pass and by three orders of magnitude when it removes a cold one, and the
decision turns on whether it removes a pass at all. A state that is longer than memory's offer
but leaves the residual in the same number of passes saves nothing and costs its restore plus
the evictions it causes. The threshold an admission rule would need is a **pass count**, not a
token count, and no such rule exists: `PersistentPrefixPolicy` compares lengths against
`minimumTokens`, which gates writes only.

**Limits.** One machine (32 GB MacBook Air, M5, macOS 27) and the engine's own four-prompt and
conversation fixtures; run records from 2026-09-14 and 2026-09-16 were collected on the same
class of target at 8.1 to 10 GB. The disk arm's nine observations span a single segment layout
and one filesystem, so the 3.95 ms per 1000 tokens is not a portable constant. The two arms were
never measured in the same request: every read figure comes from a turn that took no disk state
or from its own run's cold counterpart, which is why the comparison is stated as a ratio of
magnitudes and not as a paired difference. The eviction's cost to later requests is unmeasured;
only its count is now recorded.
