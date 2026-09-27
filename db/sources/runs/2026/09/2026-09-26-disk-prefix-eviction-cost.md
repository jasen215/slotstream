---
type: run
id: 01m3ggwy7305hv5xwn07btncyw
created: 2026-09-27T04:10:17.186867+00:00
updated: 2026-09-27T04:10:36.497980+00:00
summary: Both arms lost the sibling's state at the trigger, so T5 measures the tier's recovery of an evicted sibling (5.19x), not the eviction's marginal cost; the net is +202 s per round for the tier, 3 of 3
binary: .build/out/Products/Release/slotstream sha256 a8f65db31e4666db92714b89a760251011599bef10057501e14d068cfbf7b590
captured_at: 2026-09-26
command: python3 .build/disk-prefix-tier-20260926/eviction_cost.py --rounds 3
discarded: 'false'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
title: 'Order 344 co-primary: what a restore-driven eviction costs a later sibling request'
tool: eviction_cost.py (imports paired_ab.py and Tools/persistent_prefix_e2e.py)
---
# Order 344 co-primary: what a restore-driven eviction costs a later sibling request

**What this is.** The experiment the step-4 A/B left open: a restore makes room by evicting in-memory
states, and nothing followed the eviction there. The pre-registration is frozen at
`.build/disk-prefix-tier-20260926/eviction-cost-preregistration.md`, sha256
`caca8a0be67c0cfd7fa3ca3fa3b222a224ae061818c24a5d199d9481d42427e0`, committed as
[[sources/docs/2026/09/2026-09-26-eviction-cost-preregistration]].

## Identity

- Binary \`.build/out/Products/Release/slotstream\`, sha256
  \`a8f65db31e4666db92714b89a760251011599bef10057501e14d068cfbf7b590\`, identical at campaign start,
  during and after. **It is not step 4's binary**: commit \`b97be66\` landed four minutes before the
  preflight and changed exactly the admission rule's cost rate. The T4 trigger reproduces
  field-for-field, so the comparison is intact, but these numbers belong to admission revision 4.
- Driver \`.build/disk-prefix-tier-20260926/eviction_cost.py\`, sha256
  \`e76832a8aa06ebdb43d7d0f1b06d94bcd80a4228402797a5ba6ac57e0ab06c15\`, importing the step-4 driver and
  the workload module; an offline self-test shows T1, T3 and T4 byte-identical to step 4's turns.
- Three interleaved rounds, two arms, five turns, 2,492 s. Arm A = disk tier on a fresh directory,
  arm B = no disk tier. Machine [[records/machines/macbook-air-m5-32gb-local]], reclaimable 16.98 to
  17.29 GB, no foreign model process or compiler at any gate.

## Battery, and one deviation

T1 C1 first turn (cold-long) | T2 C2 first turn (sibling, sharing the notes head) | T3 C1 follow1 |
T4 trigger (C1's second follow-up, the step-4 restore) | T5 C2 follow-up (sibling-after).

The frozen pre-registration compressed the battery into five bullets and labelled the fifth a
control-after turn in C1, without listing the earlier C1 follow-up the disk state needs. The run used
the five turns the task enumerated and did **not** run the frozen control-after; the mapping is
recorded in the raw JSON's \`preregistration_mapping\`. The pre-registration was not edited.

## Result

\`ratio = B_first_token_seconds / A_first_token_seconds\`, medians over three rounds:

| turn | median | reading |
| --- | ---: | --- |
| T1 cold-long | 1.013 | control: no reuse available in either arm |
| T2 sibling | 1.022 | control: both arms reuse the 3584-row shared head |
| T3 C1 follow1 | 0.970 | control: both reuse the 3840-row state and read the same 731 rows |
| T4 trigger | 1.466 | the restore: arm A returns 28.47 s sooner |
| T5 sibling-after | 5.188 | arm A restores C2's state in 0.11 s; arm B rebuilds 4556 rows |

T4's admission fields are identical in all three rounds — memory offered 3840, saved 512, restored
4352, residual 927, two evictions, restore 0.116 to 0.132 s — and T5 in arm A is a disk restore of
exactly 3840 rows in all three rounds. Prompt ids and output ids are identical between arms for **all
five turns** in all three rounds, including T5.

## The confound, which is the honest answer

The pre-registration expected arm B to keep C2's state, because arm B performs no restore. It did not:
arm B's T5 reused zero tokens and rebuilt the whole conversation. A round ends with more states than
the four-state ceiling allows, and T4's own save (C1 at 5120 rows) is enough to evict the LRU
conversation, which is C2. **The sibling's state left both arms at T4** — in A through the restore's
two evictions, in B through the ordinary ceiling — and only A could get it back. So T5 measures the
disk tier's *recovery value* for an evicted sibling, not the marginal cost of the restore-driven
eviction, and that marginal cost was **not measurable in this workload**. This is a limitation of the
design, not of the engine: isolating it needs a workload in which the no-disk arm retains the sibling,
which means either a different conversation mix or a per-arm view of the in-memory cache that the
engine does not expose today.

## Buy against cost, per round, in the same round

| round | T4 win (B-A) | T5 difference (A-B) | net |
| --- | ---: | ---: | ---: |
| 1 | +28.47 s | +167.51 s | **+195.98 s** |
| 2 | +29.04 s | +173.03 s | **+202.06 s** |
| 3 | +26.16 s | +177.64 s | **+203.81 s** |

The restore's eviction is not an offsetting cost in any round: the win and the recovery both favour
the disk tier, a median **+202.06 s** net, 3 of 3 rounds.

## Secondary observation, suggestive only

T3 is a control — arm A neither restores nor is offered anything longer — and it reads 0.970, 0.997,
0.950 (median 0.970): the disk tier's mere presence costs about 3% on such a turn. n=3, no mechanism
identified, recorded as an observation and not as a claim.

## Disposition

With [[records/measurements/disk-prefix-admission-is-unreachable-2026-09-26]] in hand there is no
policy lever left to set from this number: the tier takes every longer state on the deployed path. The
isolated marginal cost of a restore-driven eviction is therefore recorded as **not isolable in this
workload and no longer decision-relevant**, and what replaces it is the measured recovery value
(5.19x on the sibling's turn) and the per-round net. Round 1's T1 control reads 1.546 against 0.991 and
1.013 in rounds 2 and 3 — the same warm-up drift step 4 saw, a bias rather than contamination; rounds 2
and 3 are the unbiased subset and every conclusion above holds in them.

## Not measured

Which named in-memory states were evicted (the cache exposes counts, not a listing; attribution here is
by offered-token counts against the disk listing); arm B's own eviction counts, since a process without
a persistent tier has no such counter; a workload in which the no-disk arm keeps the sibling; the
frozen control-after turn; anything beyond \`--memory-gb 10\`, one machine, one prompt shape, no images
and no speculation interaction. \`ps\` is denied in this session, so foreign CPU consumers could not be
enumerated beyond the process checks.

Raw: \`.build/disk-prefix-tier-20260926/{eviction-cost.json,eviction-cost-per-round.log,eviction_cost.py,eviction-bias.json}\`.
