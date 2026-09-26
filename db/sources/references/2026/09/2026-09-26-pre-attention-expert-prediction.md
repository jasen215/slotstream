---
type: reference
id: 01m3ecmqq71c206b3zb2z3377p
created: 2026-09-26T08:17:25.223762+00:00
updated: 2026-09-26T08:57:12.776360+00:00
summary: 'Pre-attention expert prediction: a lightweight same-layer predictor'
captured_at: 2026-09-26
title: 'Pre-attention expert prediction: a lightweight same-layer predictor'
url: https://arxiv.org/abs/2511.10676
---
Prior art for a lightweight same-layer expert predictor, retrieved 2026-09-26 from
the arXiv API (`export.arxiv.org/api/query`, id_list 2511.10676) and read in full the
same day from the v1 source package (`arXiv-2511.10676v1.tar.gz`, fetched through the
local proxy at 127.0.0.1:54110: direct egress to arxiv.org fails DNS resolution in
this sandbox, the proxy path returns 200). Not reproduced here: every number below is
the authors' own, on their models and hardware.

## Claim

Expert prediction that reads the previous layer's activations is inaccurate and
leaves the first MoE layer unoptimized, while complex or separately trained
predictors cost too much. Some functions in an LLM are ranking-preserving, so the
ranking of the selected experts can be matched with simple linear functions.

## Mechanism (precise, from the v1 source, sections 4.2 and 4.3)

Prediction is trained as multi-label classification over the expert axis, and at
inference the predicted scores are ranked and the top-k taken, as the original
router does. Input `X` is the activations *before the attention block of the same
layer*.

- **Architecture 1**: `Linear(d to 2048)` then `BatchNorm1d`, `GELU`, dropout
  (p = 0.1), then `Linear(2048 to E)` emitting one logit per expert.
- **Architecture 2** (the streamlined one): two linear layers with a `SiLU`
  between them, intermediate size 2048.
- **Loss**, ranking-aware weighted BCE: weighted binary cross-entropy with
  `w = 3.0` for experts in the real top-10, `1.5` for ranks 11 to 30 and `0.5`
  otherwise, normalized by `N * E`; plus `lambda` times a pairwise hinge ranking
  term over pairs inside the top-10, `ReLU(m - (s_raw_ij - s_raw_ik))`, with
  margin `m = 0.1` and `lambda = 0.3`.
- **Training**: 10M MMLU-derived samples, 30 epochs, on one TITAN RTX 24 GB. The
  authors state inference needs no GPU.

## Reported accuracy (the authors')

Single-epoch loss comparison: MSE regression 86.61%, weighted BCE 90.19% (their best
for architecture 2), focal loss 86.40 to 87.64%, ranking-aware BCE 89.19%
(architecture 1) and 89.95% (architecture 2). Top-10 accuracy at full training:
DeepSeek-V2-Lite 93.03%, Qwen3-30B 94.69%, Phi-mini-MoE 97.62%, about 15 points of
absolute accuracy above the FATE state of the art they compare to.

## Relevance

Slotstream's shipped forecast is a tap plus a learned rank-128 ridge correction
that lifts validation top-10 agreement from 0.7292 to 0.7980
([[records/plan/decode-forecast-taps-2026-09-14]]). This paper argues the predictor
*form* is the lever, not only the tap position, and it separates the two choices the
closed record could not: a classification objective over the expert axis, and a
ranking-aware term on top of it, against the regression the shipped correction in
fact is. Their own ablation is the direct precedent (86.61% regression against
90.19% weighted BCE). Cross-model accuracy does not transfer; the relevant question
is predictor family at equal lead time, equal memory and equal trained parameters.

Parameter budget, since their headline hidden size does not fit ours: at `d = 2560`
and `E = 512`, their intermediate size 2048 costs 6.29M parameters per layer, while
the shipped 35.2 MiB FP16 correction budget allows about 384k per layer (rank-128
ridge is exactly 393,216). A same-budget instance of architecture 2 uses an
intermediate size of 128, which is also 393,216 parameters, so the form comparison
can be parameter-matched exactly.
