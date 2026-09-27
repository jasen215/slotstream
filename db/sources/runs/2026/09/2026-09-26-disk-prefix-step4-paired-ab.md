---
type: run
id: 01m3gbmw1k5mc4b0ynw6jet01k
created: 2026-09-27T02:38:29.939735+00:00
updated: 2026-09-27T02:38:30.843960+00:00
summary: 'Paired A/B over 3 rounds and 24 turns: aggregate 1.5988 (steady state 1.5006) with a bootstrap 2.5th percentile of 1.4865, restart turns 3.44-3.72x, identical ids, and every registered exit met'
binary: .build/out/Products/Release/slotstream sha256 1096156e50afd323a6de26b2b2904953e8260d2cdd91dc6747e3d7d00446281a
captured_at: 2026-09-26
command: python3 .build/disk-prefix-tier-20260926/paired_ab.py --rounds 3
discarded: 'false'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
title: 'Order 344 step 4: the disk tier against recomputation, paired'
tool: paired_ab.py (imports Tools/persistent_prefix_e2e.py)
---
# Order 344 step 4: the disk tier against pure recomputation, paired

**What this is.** The plan's step 4: a paired A/B of the disk prefix tier against recomputation on
the two workloads this store already uses, run by a separate measurement task against the step-2
binary. Twenty-four turns, three rounds, 1,828 s of wall time on
[[records/machines/macbook-air-m5-32gb-local]].

## Identity

- Binary `.build/out/Products/Release/slotstream`, sha256
  `1096156e50afd323a6de26b2b2904953e8260d2cdd91dc6747e3d7d00446281a`, identical before and after
  the campaign, so no rebuild moved under it. It carries `PersistentPrefixAdmission`.
- Driver `.build/disk-prefix-tier-20260926/paired_ab.py`, sha256 `ba881bb83b792558c43cb357c5fee71f627240595787f46ce298cac3f6f48124`, importing
  `Tools/persistent_prefix_e2e.py` for the workload so its text is byte-identical to the recorded
  one. Raw output `paired-ab.json`, per-round notes `paired-ab-per-round.log`.
- Arms: A = `--prefix-cache-dir` on a fresh directory per round; B = no disk tier at all. The
  in-memory conversation cache works in both, which is the point of the comparison.
- Workload per battery: a 2400-word notes prompt, two 400-word follow-ups of 48 predicted tokens,
  server restart, the same 3849-token prompt again.

## Result

`ratio = B_first_token_seconds / A_first_token_seconds`, per matched turn:

| family | round 1 | round 2 | round 3 | median | min |
| --- | ---: | ---: | ---: | ---: | ---: |
| cold-long (control) | 1.4364 | 1.0012 | 0.9978 | 1.0012 | 0.9978 |
| short follow-ups | 1.4190, 1.4310 | 1.0009, 1.4184 | 1.0797, 1.3714 | 1.3949 | 1.0009 |
| restart-long | 3.7209 | 3.4352 | 3.5639 | 3.5639 | 3.4352 |

Aggregate geometric mean over the twelve matched turns **1.5988** (prefill metric 1.6009); bootstrap
2.5th percentile **1.4865** over 2,000 resamples of the three rounds. Prompt ids and output ids are
identical in all twelve pairs.

| registered exit | verdict |
| --- | --- |
| aggregate >= 1.02 and bootstrap lower bound > 1.00 | **met**: 1.5988, 1.4865 |
| no short-turn family median below 0.97 | **met**: 1.4250 / 1.2097 / 1.2255 by round, 1.3949 overall |
| no long-turn regression worse than 2% | **met**: long family 2.4358, worst single long turn 0.9978 |
| outputs identical | **met**: 12 of 12 pairs, digests repeat across rounds |

**The round-1 control is the campaign's own warm-up, not a foreign load.** Round 1's control reads
1.4364 where rounds 2 and 3 read 1.0012 and 0.9978 for the same 3849-token turn, and arm A's own
cold turn was 48.09 s in round 1 against 72.63 s in round 2 — the machine got *slower* after round 1
and stayed there. The load average rose 2.25 to 8.51 during the campaign and fell to 2.03 within four
minutes of the last server stopping, so the sustain came from this campaign's streaming inference
itself (cold boost, then a hot steady state). No foreign model process or compiler was visible at any
of the six round gates, and reclaimable memory never fell below 16.98 GB. Nothing is discarded, but
the steady-state view is the honest one: rounds 2 and 3 give aggregate **1.5006** with the control at
1.000 and restart-long **3.4995**, and every exit holds under it too.

## What the tier actually buys, turned into a rate

Arm A's post-restart turn restores 3584 rows in 0.035 to 0.037 s and then reads 265 rows, costing
20.5 s. Arm B reads the same 3849-row prompt from cold in 70.7 to 73.1 s. So the first pass after a
restart costs about 77 ms per row while arm B's 3849 rows average 18.5 ms, and the tier's value is
that it **skips the cold start altogether** rather than that it removes an average pass. That is also
why step 1's per-token read fit failed (n=19, r2=0.012): the cost is in the first cold pass, not in
the token count. On the follow-up family the mechanism is a boundary: memory holds 3840 rows and the
disk state holds 4352, which straddles a prefill pass boundary, so the recompute arm's 1439-row
residual costs two passes where the disk arm's 927-row residual costs one.

## The co-primary, and what this did not exercise

Every round's second follow-up evicted two in-memory conversations to admit the 4352-row state
(`evictionsForRestore = 2`), in 0.107 to 0.127 s of restore against the fitted 0.0385 s for a state
that size — the difference is the eviction's own work. **Nothing followed those evictions in this
workload, so their cost to later requests is still unmeasured**, and that is the one co-primary the
plan still owes.

**The admission rule never refused a candidate**: no turn in any arm recorded `skippedRestore`, so
this campaign measures the *tier*, not the rule's refusal arm. Its one enabled decision — taking the
3840-to-4352 state whose 512 saved rows cross a pass boundary — is the behaviour it was built for,
and the refusal regime needs its own workload to appear at all.

## Limits

One machine, one internal SSD, `--memory-gb 10`, one prompt shape, `num_predict 48`, no images and
no speculation interaction. R=3 is a coarse bootstrap (ten distinct multisets; the lower bound is a
statement about these three rounds, not a population). `ps` is denied in this session, so foreign CPU
consumers could not be enumerated beyond the process checks above. Wall-clock and request totals are
in the raw JSON but are not the primary metric. A reading that favours recomputation was a legitimate
outcome of this step; it did not occur.

Raw: `.build/disk-prefix-tier-20260926/{paired-ab.json,paired-ab-per-round.log,paired_ab.py,bias-analysis.json}`.
