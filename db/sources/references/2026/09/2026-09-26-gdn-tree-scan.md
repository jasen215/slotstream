---
type: reference
id: 01m3ecmqp5s771w8x6xtdsk2bn
created: 2026-09-26T08:17:25.189872+00:00
updated: 2026-09-26T08:17:46.268069+00:00
summary: Tree verification for recurrent-hybrid models (GDN Tree-Scan)
captured_at: 2026-09-26
title: Tree verification for recurrent-hybrid models (GDN Tree-Scan)
url: https://arxiv.org/abs/2609.23900
---
Prior art for tree-structured verification of recurrent-hybrid models, retrieved
2026-09-26 from the arXiv API (`export.arxiv.org/api/query`, id_list 2609.23900).
Not reproduced here: every number below is the authors' own measurement on their
hardware, and no slotstream run has tested this mechanism.

## Claim

Tree speculative decoding normally needs only an ancestry mask because attention
state is a function of the mask. Recurrent-hybrid models break that assumption: a
candidate row must also carry the recurrent state that native sequential decode
would have produced along its root-to-node path, or the verifier conditions on an
impossible recurrent history.

## Mechanism

FlashAttention-2 tree-bias attention, branch-local GDN scan/replay, device-side
multidraft commitment, and accepted-chain-only state publication, integrated into
vLLM as `GDN Tree-Scan`.

## Reported numbers

- Qwen3.6-27B-FP8, clean batch-one SWE/Codex decode gate, temperature 0.6.
- A six-node root-branch tree raises committed tokens per event by 17.2% at
  near-native verify-forward time.
- 23.88 token-weighted decode tokens/s against 18.80 for native five-step MTP, a
  27.0% token-weighted decode-throughput gain.
- The per-request-equal latency view is +4.0%; end-to-end task wall time stays
  prefill-heavy.
- Equivalence evidence is scoped to recurrent-oracle probability-rescore closure
  within the observed native flip floor, not a full distribution-distance proof.

## Relevance

The model family is the same shape as the shipped checkpoint: Gated-DeltaNet
hybrid layers plus a draft head. It is the strongest external prior art for the
acceptance-per-pass lever that [[records/plan/decode-forecast-taps-2026-09-14]]
names as what the forecast program leaves open.
