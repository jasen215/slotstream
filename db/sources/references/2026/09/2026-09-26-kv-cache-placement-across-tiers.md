---
type: reference
id: 01m3ecp6r5jee8aadyy2mmty34
created: 2026-09-26T08:18:13.381561+00:00
updated: 2026-09-26T08:18:13.885202+00:00
summary: 'Where should a long-lived KV cache live: tiers, placement and prefetch'
captured_at: 2026-09-26
title: 'Where should a long-lived KV cache live: tiers, placement and prefetch'
url: https://arxiv.org/abs/2609.16215
---
Prior art on where a long-lived KV cache should live, retrieved 2026-09-26 from the
arXiv API (`export.arxiv.org/api/query`, id_list 2609.16215). Not reproduced here:
the factors below are the authors' simulation study on their own tiers.

## Claim

Extending GPU memory with CPU DRAM and SSD supports far more concurrent sessions
and lowers cost per session, but in their study those gains come from tier
*capacities*, not from placement policy. At batch size one decode is compute
bound, so placement barely affects throughput: it mainly changes PCIe migration
traffic and time to first token. Their predicted-reuse policy is byte-identical to
recency, and prefetching never beats no-prefetch on migration traffic even for an
oracle with knowledge of future requests.

## Reported numbers

- 73.02x more concurrent sessions per GPU and 62.04x lower cost per session, from
  tier capacities of 1 + 8 + 64.
- Recency produces 2.30x less migration traffic than reuse frequency for chat;
  reuse frequency performs best for agents and document question answering.
- Prefetching does not justify its bandwidth cost across the policy and cache size
  grid.

## Relevance

This is the counter-argument to record for any disk-tier prefetch work: it says
the win is capacity and admission, not placement or readahead, and that a
predicted-reuse policy can collapse into recency. Its settings are PCIe-attached
tiers with GPU HBM and a simulated execution model, so neither the negative
prefetch result nor the compute-bound batch-one finding transfers unchanged to
reading a local SSD into unified memory; the admission framing does.
