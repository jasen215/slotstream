---
type: reference
id: 01m3ecmqq71c206b3zb2z3377p
created: 2026-09-26T08:17:25.223762+00:00
updated: 2026-09-26T08:17:50.918033+00:00
summary: 'Pre-attention expert prediction: a lightweight same-layer predictor'
captured_at: 2026-09-26
title: 'Pre-attention expert prediction: a lightweight same-layer predictor'
url: https://arxiv.org/abs/2511.10676
---
Prior art for a lightweight same-layer expert predictor, retrieved 2026-09-26 from
the arXiv API (`export.arxiv.org/api/query`, id_list 2511.10676). Not reproduced
here: the accuracies below are the authors' own, on their models and hardware.

## Claim

Expert prediction that reads the previous layer's activations is inaccurate and
leaves the first MoE layer unoptimized, while complex or separately trained
predictors cost too much. Some functions in an LLM are ranking-preserving, so the
ranking of the selected experts can be matched with simple linear functions.

## Mechanism

Two linear functions applied to the activations *before the attention block of the
same layer*, trained with a ranking-aware loss. No standalone network and no
previous-layer dependency, so the first layer is covered too.

## Reported top-10 accuracy

- DeepSeek-V2-Lite 93.03%, Qwen3-30B 94.69%, Phi-mini-MoE 97.62%.
- About 15 points of absolute accuracy above the state of the art it compares to.

## Relevance

Slotstream's shipped forecast is a tap plus a learned rank-128 ridge correction
that lifts validation top-10 agreement from 0.7292 to 0.7980
([[records/plan/decode-forecast-taps-2026-09-14]]). This paper argues the predictor
*form* is the lever, not only the tap position: a same-layer pre-attention input
with a ranking-aware objective. Cross-model accuracy does not transfer; the
relevant question is predictor family at equal lead time, equal memory and equal
trained parameters.
