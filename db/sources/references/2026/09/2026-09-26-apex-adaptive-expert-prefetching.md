---
type: reference
id: 01m3ecmqr6ehm68cm8n52bm9y6
created: 2026-09-26T08:17:25.254867+00:00
updated: 2026-09-26T08:17:51.466722+00:00
summary: 'APEX: confidence-gated adaptive expert prefetching'
captured_at: 2026-09-26
title: 'APEX: confidence-gated adaptive expert prefetching'
url: https://arxiv.org/abs/2608.11688
---
Prior art for confidence-gated adaptive expert prefetching, retrieved 2026-09-26
from the arXiv API (`export.arxiv.org/api/query`, id_list 2608.11688). Not
reproduced here: the numbers are the authors' own, on their hardware.

## Mechanism

A lightweight prefetch router predicts candidate experts *before the attention
block* and a learned confidence model decides whether to fetch additional experts,
instead of a fixed top-k prefetch.

## Reported numbers

- Over 99% overlap accuracy, described as significantly better than fixed top-k.
- Correctness-preserving mode: up to 26% lower per-token latency and up to 41%
  better energy-delay product than the baselines.
- A second, stall-free mode operates on available experts with negligible
  application-accuracy impact; slotstream's exactness invariant excludes it.

## Relevance

Slotstream's issue decision is a fixed margin cutoff. Lowering it was measured and
closed: `t000` wasted 2.4 times the bytes because every top-10 read arrived late
([[records/plan/decode-forecast-taps-2026-09-14]], step 10). This is prior art for
replacing a fixed margin with a learned confidence model at the same lead time,
which is a different mechanism from the lever that closed.
