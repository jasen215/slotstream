---
type: reference
id: 01m3ecmqs50a5ytdjpqcyrsss3
created: 2026-09-26T08:17:25.285797+00:00
updated: 2026-09-26T08:17:52.008285+00:00
summary: 'py-kvcache: external KV caching as a measured break-even decision'
captured_at: 2026-09-26
title: 'py-kvcache: external KV caching as a measured break-even decision'
url: https://arxiv.org/abs/2609.11744
---
Prior art for admitting an external KV cache on a measured break-even, retrieved
2026-09-26 from the arXiv API (`export.arxiv.org/api/query`, id_list 2609.11744).
Not reproduced here: the ratios are the authors' own, on GPU/NVMe tiers.

## Claim

Reusing a previously computed KV state lowers time to first token, but for short
prefixes or a fast GPU, recomputation can be faster than loading from an external
tier. Performance depends on transfer granularity, intermediate memory use and
when transfers enter the request schedule, not only on device bandwidth. External
KV caching should be a setup-specific admission decision.

## Mechanism

`py-kvcache`, a vLLM KV-offload connector with asynchronous direct I/O, bounded
shared staging and scheduler-aware preloading that starts disk reads while
requests are still waiting, overlapping them with compute.

## Reported numbers

- At 80k tokens, loading from disk is 2.0x faster than LMCache; preloading
  contributes 1.34x of that.
- With GPU, CPU and disk caching enabled it is 1.23x faster than LMCache and
  within about 4% of the native vLLM KV-offload implementation.
- On an H100 the average request falls below the break-even point: GPU memory
  alone already retains enough prefixes.

## Relevance

The persistent prefix cache reads the disk tier only for a state longer than
memory holds, after making room like a miss
([[records/decisions/prefix-cache-holds-four-conversations-extend-only]]), and a
hit under the aligned-resume rule can save at most the distance back to the
request's own pass boundary. There is no measured load-versus-recompute
comparison today.
