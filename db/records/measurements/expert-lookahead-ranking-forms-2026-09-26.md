---
type: measurement
id: 01m3epv9hr66qvbpcygyqbshk6
created: 2026-09-26T11:15:45.848419+00:00
updated: 2026-09-26T11:16:06.540711+00:00
summary: Two ranking-aware pre-attention predictor forms, at the shipped lead time and parameter count, score 0.7663 and 0.7672 against the shipped rank-128 ridge correction's re-derived 0.8028
date: 2026-09-26
doc: measurements
level: '3'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
note: 'Offline fit over one observer-only capture: no native run, no timing evidence, and gates G2 and G3 unevaluated because no residency capture exists.'
order: '1670'
runs: '[[sources/runs/2026/09/2026-09-26-xla4-form-capture-and-fits]]'
title: Ranking-aware predictor forms lose to the shipped ridge correction at equal lead time, parameters and memory
status: measured
---
# Ranking-aware predictor forms lose to the shipped ridge correction at equal lead time, parameters and memory

**Result.** At the shipped lead time, at an equal trained-parameter count of about
393,700 per target layer and at an equal FP16 weight size of about 35.3 MiB over
47 targets, the pre-attention paper's own reader — multi-label classification over the
expert axis with a ranking-aware loss — scores **0.7663** (a rank-128 linear form) and
**0.7672** (two linear layers with SiLU between them) on validation top-10 agreement.
The shipped rank-128 ridge correction, re-derived from this capture by the frozen tool,
scores **0.8028**. Both ranking arms lose by about 3.6 points, and the registered gate
(0.05 above the re-derived reference, so 0.8528) was missed by about 8.6 points. The
predictor-family question is closed for this setting: the shipped tap and its ridge
correction stay.

## Why this was measured

[[records/plan/2026-09-26-pre-attention-forecast-form-and-issue-decision]], step 1, on
the prior art in
[[sources/references/2026/09/2026-09-26-pre-attention-expert-prediction]]. That paper
reports that its classification objective beats score regression 90.19% to 86.61% and
that a ranking-aware objective beats plain weighted BCE on one of its two
architectures. Slotstream's shipped correction *is* a regression — of the residual
between the true router logits and the tap's own score — so the prior art raised a real
question about the objective, not only about the tap position.

## Method

Protocol `xla4-form-20260926`, registration frozen at
`.build/expert-lookahead/xla4-form-20260926/preregistration.md` (sha256
`faf0c98a1e2148b4ea61c3d4482338034425d9eb2a9896b9ade8e88b120a512f`) before any fit, with
the arms' implementation named in its amendment 2. Run evidence and artifact hashes:
[[sources/runs/2026/09/2026-09-26-xla4-form-capture-and-fits]].

One observer-only capture on [[records/machines/macbook-air-m5-32gb-local]] recorded, for
each of 69 pilot requests (56 train, 13 validation) and every target layer, the tap's
input `u`, the true router input `x2`, the true routes and the recorded tap candidates,
at a 10 GB target. 12,195 training rows and 142,968 pooled validation rows per target
over 47 targets. The capture needed two attempts: the first exited 1 with 11 requests
cancelled by the engine's memory-pressure guard, and the same command with `--resume`
finished them.

Four forms were fitted and scored on identical rows and splits, and every one of them
predicts a correction to the tap's score (`s = p + f(u)`), so the tap term, the lead time
and the parameter count are held fixed:

- **tap**: the shipped forecast with no correction, 0.7340.
- **ridge rank-128**: the frozen tool (`Tools/expert_lookahead_learned.py fit`), a ridge
  regression of `z - p` truncated to rank 128, 0.8028; its dense form reaches 0.8073 but
  needs 117.5 MiB.
- **LR**: the same rank-128 linear form, trained instead with the paper's objective,
  0.7663.
- **L2**: two linear layers with SiLU between them at intermediate size 128, trained with
  the paper's objective, 0.7672.

The objective is the paper's own: weighted binary cross-entropy over the expert axis
(weight 3.0 for the real top-10, 1.5 for ranks 11 to 30, 0.5 otherwise, normalized by
`N * E`) plus `lambda = 0.3` times a pairwise hinge ranking term over the pairs inside the
top-10 at margin `m = 0.1`. Two declared departures: the ranking term is normalized by
its pair count where the paper writes a raw sum, and the intermediate size is 128 rather
than the paper's 2048, because 2048 costs 6.29M parameters per layer against the adopted
budget's ~384k; at 128 both forms carry exactly 393,216 parameters, matching the shipped
rank-128 correction. The declared grid was learning rate `{1e-4, 3e-4, 1e-3}` times
weight decay `{0, 1e-2}`, at most 20 epochs with early stopping on validation agreement,
searched on targets 2, 16, 32 and 46 and then applied to all 47; both arms chose the
most conservative cell (1e-4, 0.01).

## The numbers

Validation pooled over targets 2 to 47, 142,968 rows:

| form | top-10 agreement | exact top-10 | recall@16 | recall@24 | FP16 weights |
| --- | --- | --- | --- | --- | --- |
| attention tap | 0.7340 | 0.0555 | 0.8606 | 0.9192 | — |
| **ridge rank-128 (shipped)** | **0.8028** | 0.1072 | 0.9204 | 0.9610 | 35.25 MiB |
| ridge dense | 0.8073 | 0.1129 | 0.9235 | 0.9628 | 117.5 MiB |
| LR, ranking objective | 0.7663 | 0.0741 | 0.8924 | 0.9441 | 35.30 MiB |
| L2, ranking objective | 0.7672 | 0.0750 | 0.8936 | 0.9449 | 35.31 MiB |

## Gates

- **G1, agreement (0.05 above the re-derived reference, 0.8528): failed** by both arms,
  0.7663 and 0.7672. The pre-registered negative rule applies: the predictor-family
  question closes on this evidence and the shipped tap and correction stay.
- **G4, budget: met in substance.** Both arms are 35.30 and 35.31 MiB of FP16 weights over
  47 target layers against the shipped form's 35.25 MiB — a 0.05 MiB difference from the
  bias terms — and far inside the 64 MiB absolute bound. The registration's G4 wording
  (at most 35.2 MiB) was written from the shipped figure's rounded form and is 0.1 MiB
  stricter than that form's own 35.25 MiB; the comparison above is the honest one.
- **G5, one table: met.** Every form above was fitted and scored on the same rows, the
  same folds and the same splits.
- **G2 and G3: not evaluated.** They need a residency capture and this protocol's
  capture is observer-only; the registration records that as an execution gap rather than
  a pass.
- The re-derivation reproduces the published reference: the frozen tool's rank-128 form
  reads 0.8028 here against the 0.7980 in
  [[records/plan/decode-forecast-taps-2026-09-14]], inside the 0.005 agreement tolerance
  that record's native step used.

## Limits

- One machine, one 10 GB target, a 838-slot pool, 69 pilot requests and 12,195 training
  rows per layer. The paper trained on 10M samples across three models; at this data
  volume both arms stopped early, at best epoch 3 to 12, and the most conservative
  hyperparameters won, so the comparison says what it says *at this scale*. A
  substantially larger capture is the obvious way to test whether the deficit is data.
- The arms correct the tap's score rather than replacing it, because that holds the tap
  information and the parameter count fixed. The paper's predictors produce the ranking
  from the pre-attention activation alone, so this is the paper's objective and form in
  the shipped design, not a replication of the paper's own comparison.
- Agreement only. No coverage, no wasted reads, no timing, and no claim about what these
  forms would do to throughput.
- The sealed test split was not read, and no default, document or public number changed.
