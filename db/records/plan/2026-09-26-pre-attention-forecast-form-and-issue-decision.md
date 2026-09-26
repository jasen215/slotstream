---
type: plan
id: 01m3ecpstcm5j7raghq0st14gj
created: 2026-09-26T08:18:32.908050+00:00
updated: 2026-09-26T11:24:50.017688+00:00
summary: 'Forecast form and the issue decision: a ranking-aware predictor and a learned confidence gate'
date: 2026-09-26
doc: plan
kind: queue-item
level: '2'
order: '342'
title: 'Forecast form and the issue decision: a ranking-aware predictor and a learned confidence gate'
status: open
---
Opened on 2026-09-26 from the closing state of [[records/plan/decode-forecast-taps-2026-09-14]], which
names the forecast's own form and its issue decision as the parts the program never tested, and from
two external results recorded as prior art:
[[sources/references/2026/09/2026-09-26-pre-attention-expert-prediction]] and
[[sources/references/2026/09/2026-09-26-apex-adaptive-expert-prefetching]].

## Problem

The shipped forecast is a tap plus a learned rank-128 ridge correction: validation top-10 agreement
0.7980 against the plain attention tap's 0.7292, and the corrected tap decoded at 1.111x the qualified
configuration on held-out prompts ([[records/measurements/decode-forecast-taps-2026-09-15]]). The tap
position is settled. What has never been separated is the *form* of the predictor and the *issue
decision*:

- The learned part is a single ridge regression fitted on one recorded feature per target layer, and
  the half that would carry a ranking objective was never fitted.
- The issue decision is still a fixed 0.062 margin cutoff. The one registered attempt to lower it
  issued late reads and wasted 2.4 times the bytes (step 10 of the closed record), which is evidence
  against that *cutoff value*, not against a learned confidence model.

The two papers describe exactly these two mechanisms and report high accuracies, but on other models,
other engines and other hardware. Cross-model accuracy does not transfer, so the gates below are all
relative to this project's own measured tap and correction at equal lead time, equal staged memory and
equal trained-parameter count. A negative outcome is a useful result: it would say the predictor
family is closed and leave only the issue decision, or close both.

## Steps, in dependency order

1. Feature capture and predictor families, offline. Reuse the existing capture seam for the pilot's 56
   training and 13 validation requests and record, per target layer, the same-layer pre-attention
   streams the boundary tap already reads, the shipped tap's recorded candidates, and the true router
   input. Fit three families at equal memory and equal parameter count: (a) the shipped rank-128 ridge
   correction as the reference, (b) a two-linear-map form trained with a ranking-aware loss, (c) the
   ridge correction re-fitted with a ranking-aware objective. Exit: validation top-10 agreement at
   least 0.05 above the reference's re-derived value (0.7980 under the lost capture) and twin coverage
   at the shipped traffic at least 0.05 above the reference's (0.6209 under the lost capture) with no
   more wasted reads, within 64 MiB of FP16 weights, before any native code. The features come from this protocol's own
   observer-only capture, because the predecessor `xla3-learned-20260915` shards are no longer on
   disk; one capture therefore runs before the fit (about 56 minutes and 7.9 GB of shards for the
   pilot's 69 requests), while no training or evaluation step loads the model. Outcome, 2026-09-26:
   **negative, and the predictor-family question closes.** On 142,968 pooled validation rows over
   targets 2 to 47, the shipped rank-128 ridge correction re-derived at 0.8028, the rank-128 ranking
   arm read 0.7663 and the two-linear-layer ranking arm 0.7672 -- both about 3.6 points below the
   reference and 8.6 points below the gate. Their FP16 weights are 35.30 and 35.31 MiB against the
   shipped 35.25, and all forms were scored on identical rows and splits. Gate G1 failed, so the
   pre-registered negative rule applies and the shipped tap and its correction stay. The two
   ranking arms stopped early (best epoch 3 to 12) on 12,195 training rows per layer, so the deficit
   is measured at this data volume, not at the paper's 10M samples. Gate G2 also fails and G3 passes:
   on the twin's replay of this capture at its 10 GB pool, matched at the recorded tap's 564,959 issued
   tickets, the ridge correction covers 0.0430 more of the 1,114,258 decode misses where the two
   ranking arms cover 0.0178 and 0.0172, and every form wastes fewer reads than the tap. An earlier
   reading of this run called G2 and G3 unevaluable because the capture looked observer-only; that was
   wrong, the shards carry 5,321 passes, 248,160 demand events and 69 residency snapshots, and the
   cost model and matched-traffic rule were rebuilt from this capture. Evidence:
   [[records/measurements/expert-lookahead-ranking-forms-2026-09-26]] and
   [[sources/runs/2026/09/2026-09-26-xla4-form-capture-and-fits]].
2. Issue decision, offline. From the same capture, record per issued candidate its confidence feature,
   whether its read was adopted, and whether it arrived before use. Fit a calibrated confidence model
   to decide issue/adopt in place of the fixed margin. Exit: at the shipped read traffic, adopted and
   timely reads at least 0.03 above the fixed margin's with no more wasted read bytes; and at a matched
   adopted rate, at least 0.20 fewer wasted bytes. A positive reading here is not a speed claim.
3. Native correctness without timing. Apply the surviving predictor and/or issue model as a new tap
   (`attention-ranking`, plus a confidence field on the existing tap record), loaded at engine start
   and charged to the lookahead reserve. Capture the 13 validation requests. Exit, over targets 2 to 47:
   the native top-10 set equals the offline set in at least 99% of rows, native agreement within 0.005
   of the offline value, and the plain and corrected taps still read 0.7292 and 0.7980 within 0.002.
4. Screen: the qualified configuration against each surviving arm on the exploration prompts at 256
   outputs under the contention rule, adding rounds until 12 counted pairs per arm or six. Exit:
   identical outputs and a paired ratio of at least 1.01 with at least 8 of the first 12 counted pairs
   above 1, before confirmation.
5. Held-out confirmation: eight prompts from unused training-split families, three rounds at 512
   outputs at 20 GB. Exit: identical outputs, aggregate at least 1.02, lower bootstrap bound above
   1.00, no family median below 0.97, no family duration regression above 2%, at least two counted
   pairs per prompt.
6. Changing the default, the artifact's home, docs and any public number are a separate decision after
   step 5.

Steps 1 and 2 need no model launch and may run whenever no timed run is active; neither waits for the
other. Step 3 is the first step that touches engine source.

## Limits

One machine. The cited accuracies are the papers' own measurements on other models; nothing in this
record reproduces them, and the steeper of the two claims (over 99% overlap accuracy) comes from a
hardware design study whose execution model this engine does not share. The twin counts reads, not
in-flight joins, evictions by wasted reservations or GPU time, so a twin projection is not a claim.
Every arm here changes only which bytes are staged and when; the native router still chooses the
experts that execute, and no arm may change outputs.

## Registration

Frozen 2026-09-26T08:30Z and amended 2026-09-26T08:32Z and 09:15Z, all before any fit under it,
as
`.build/expert-lookahead/xla4-form-20260926/preregistration.md` (sha256
`faf0c98a1e2148b4ea61c3d4482338034425d9eb2a9896b9ade8e88b120a512f`): protocol `xla4-form-20260926`,
with the frozen identities, arms R/L2/LR plus the step-2 confidence arm, the declared hyperparameter
grids, gates G1 to G9 and the append-only reporting rules. It covers steps 1 and 2; steps 3 to 6 need
their own registration once a candidate exists. Step 4's contention rule and step 5's prompt draw are
the ones already registered for the forecast program; reuse them verbatim rather than restating them.
That scratchpad is git-ignored and a predecessor protocol's directory was already lost with its
`xla3` capture shards, so this record carries the registration's identity and gates: do not treat the
file as the only copy. Amendment 2 names the arms' implementation,
`Tools/expert_lookahead_ranking.py` (sha256 `f82ee69f`), fixes the intermediate size at 128 for
parameter parity with the rank-128 correction, and records an execution gap: this protocol's capture
is observer-only, so gate G2 (twin coverage) and G3 (wasted reads) cannot be evaluated from it and
wait on a residency capture; step 1's report will carry G1, G4 and G5 and mark G2 and G3 pending. The amendment corrected the seed command's `--features on` to
`--features off`, which §4 of the registration and the `xla3` precedent both require; the frozen
protocol file is `.build/expert-lookahead/xla4-form-20260926/protocol.json`.
