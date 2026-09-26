---
type: run
id: 01m3exs67wjcqa7chwg0a8txgs
created: 2026-09-26T13:16:56.956889+00:00
updated: 2026-09-26T13:17:19.823049+00:00
summary: restoreSeconds = 21.3 ms + 3.95 ms per 1000 restored tokens (n=9, r2=0.954); the re-read arm's per-token fit fails (n=19, r2=0.012) because its cost unit is one 256-row pass
binary: python3, .build/disk-prefix-tier-20260926/fit_two_arms.py sha256 effea1732ef859899b3c58414640e5ccdcbfc9b25dfe88224ab1a41a864c0bef (offline; reads db/sources/runs)
captured_at: 2026-09-26
command: python3 .build/disk-prefix-tier-20260926/fit_two_arms.py --runs 'db/sources/runs/2026/09/2026-09-1[456]-persistent-prefix-segments-*.md' ...
discarded: 'false'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
title: 'Order 344 step 1: the disk arm fits tightly and the re-read arm''s fit is a negative result'
tool: fit_two_arms.py (offline, reads db/sources/runs)
---
# Order 344 step 1: fitting the two cost arms from the recorded turns

**What this is.** Order 344's step 1, run against the turns already in the store. Nothing here
ran the model. Script: `.build/disk-prefix-tier-20260926/fit_two_arms.py`; the two JSON
artifacts it wrote are summarized in full below because `.build/` is not tracked.

**Turns used.** The three `2026-09-14-persistent-prefix-segments-*` records, the two
`2026-09-16-shared-prefix-*` records, and this session's step-0 run. The records embed an
abridged pretty-printed JSON dump, so whole-blob parsing fails; `fit_two_arms.py` anchors on
each `"prefill_seconds"` line and reads to the next anchor, which is one turn.

**Extracted table** (tokens the request read for itself, and what the disk arm did):

```
run                                          read    prefill  restored  restore
2026-09-14-persistent-prefix-segments-e2e      25    42.23s        0     0.0000s
                                               25     1.69s        0     0.0000s
                                               25     1.79s        0     0.0000s
                                               25     1.74s     3968     0.0373s
                                             3921     1.64s     3968     0.0390s
                                              n/a    55.38s        0     0.0000s
2026-09-14-...-long-conversation-e2e           24   204.85s        0     0.0000s
                                               25     1.53s    15561     0.0797s
                                               25     1.72s    15632     0.0736s
                                               25     1.50s    15632     0.0874s
                                              n/a     1.53s    15632     0.0908s
2026-09-16-shared-prefix-e2e                 3663    37.33s        0     0.0000s
                                               23     1.39s        0     0.0000s
                                               76     3.05s        0     0.0000s
                                             3660    21.22s     3584     0.0337s
                                               76     4.35s        0     0.0000s
                                             3660    45.47s     3683     0.0305s
                                               18     1.07s        0     0.0000s
                                               21     1.19s        0     0.0000s
                                             3640    51.85s     3584     0.0400s
                                               56     2.54s        0     0.0000s
```

## Arm A, the disk restore: fitted, tight

Nine observations, restored states of 3584 to 15632 tokens, restore times 0.0305 to 0.0908 s.

```
seconds = 0.0213 + 3.946e-06 * restored tokens     n=9  r2=0.954
residual p50 +0.0004 s, p90 +0.0046 s
3.95 ms per 1000 restored tokens, plus about 21 ms fixed
```

This is a lower bound on the arm's true cost, as the pre-registration says: the timer starts
inside the operations lock and excludes the eviction the restore triggers, which step 0
measured at two conversations for one 4352-token restore.

## Arm B, the re-read: the registered estimator is a negative result

```
seconds = 19.429 + 0.00310 * tokens read            n=19  r2=0.012
residual p50 -17.718 s, p90 +21.130 s
```

A residual spanning 39 s against a disk arm that costs at most 0.09 s cannot resolve the
decision, and the pre-registration's step-1 rule speaks to exactly this: *a fit whose residual
spans the whole decision range is a negative result and stops the record there*. It stops
here. No admission rule was added and steps 2 through 5 are not entered by this step.

**Why it failed, which is the useful part.** The re-read cost is not a function of the token
count. Reading 25 residual tokens cost 1.69, 1.79, 1.74, 1.53, 1.72, 1.50, 1.39 and 1.07 s in
the warm turns, and the same 25 cost 42.23 s in the same run's first (cold) turn; a 3921-token
read cost 1.64 s while a 3663-token read cost 37.33 s in another run. The unit of cost is one
**pass**, not one token: `PrefillSchedule` keeps a 256-row floor, so reading 18 tokens and
reading 256 tokens are the same pass. Per-run, one pass measured 1.5 to 1.7 s at a warm pool
and 21 to 52 s cold or streaming, and every "ms per token" figure that divides by a small
residual is an artifact of that floor.

**What that makes the break-even.** A restore costs 0.03 to 0.09 s. The smallest thing a
re-read can save is one pass, 1.5 s warm at worst. So the disk pays about 20x **when the
restore removes a pass**, and by a thousandfold when it removes a cold one. The case that
matters is the other one: a state that is longer than what memory holds but whose residual
still fits in the same number of passes saves nothing and is a pure cost of 0.03 to 0.09 s
plus the evictions it causes. The threshold is a **pass count**, not a token count, and it is
what an admission rule would have to compare.

Raw: `.build/disk-prefix-tier-20260926/{fit-two-arms.json,per-run-read-costs.json,fit_two_arms.py}`.
Pre-registration: [[sources/docs/2026/09/2026-09-26-disk-prefix-tier-break-even-preregistration]].
