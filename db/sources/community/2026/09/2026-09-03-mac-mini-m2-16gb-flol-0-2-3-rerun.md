---
type: community-report
id: 01m3a69ysygj02f1cygps4rvqv
created: 2026-09-24T17:09:42.846753+00:00
updated: 2026-09-24T17:09:43.847162+00:00
summary: 'Measured: Mac14,3, 16GB (0.2.3 re-run)'
captured_at: 2026-09-24
machines: '[[records/machines/mac-mini-m2-16gb]]'
reporter: flol
title: 'Measured: Mac14,3, 16GB (0.2.3 re-run)'
url: https://github.com/carloslfu/slotstream/issues/5#issuecomment-5525389653
---
Comment posted 2026-09-03T11:59:40Z on issue #5; captured 2026-09-24.

`@flol` re-ran the measurement procedure on slotstream 0.2.3, built from
source, and posted the results as a comment on the original report. The
comment is preserved verbatim from the GitHub response. The original 0.2.2
report is [[sources/community/2026/09/2026-09-02-mac-mini-m2-16gb-flol]].
One redaction: the weights path printed a macOS home directory containing a
personal name, replaced with `/Users/<user>/`. Nothing else is changed.

## Comment by @flol

2026-09-03T11:59:40Z · https://github.com/carloslfu/slotstream/issues/5#issuecomment-5525389653

Update with 0.2.3, self-compiled from 5bf0e67

### Mac

Mac Mini M2, 2023

### Unified memory

16 GB

### SSD

internal, 256 GB

### macOS version

26.6.2

### slotstream --version

0.2.3

### Memory plan

```text
device: applegpu_g14g  |  17 GB RAM (12.9 GB reclaimable now), 12.7 GB Metal working set
model:  48 layers x 512 experts x 2.76 MB (24576 records = 67.9 GB streamed from SSD)
weights: present by size, 105.3 GB at /Users/<user>/.slotstream/models/qwen38-flash-next-mlx-4bit (run pull --verify for hashes)

slotstream memory plan (auto)
  device: 17 GB RAM (12.9 GB reclaimable now), 12.7 GB Metal working set
  target: 10.7 GB total for this process   (override: --memory-gb N | --max-ram-percent P)
  cache:  ~25 of 512 experts per layer  (1193 global slots = 3.3 GB pool)
  expect: ~9.7 GB peak, ~5 tok/s warm decode (est. from M5 Pro anchors)
  prefill: 256 tokens per pass (~85 tok/s here; costs ~0.3 GB of the target)
  context: up to 32768 tokens per request (prompt + reply); a full-length prompt takes ~6.4 min before its first token here, follow-up turns read only what is new
  reuse:  up to 15961 tokens across 4 conversations (~0.8 GB), so a follow-up turn re-prefills only what is new

knobs (first one given wins; with none, auto is the default):
  --memory-gb G           easiest: total memory the process may use
  --experts-per-layer N   precise: cache N of 512 per layer (pool = N x 0.133 GB)
  --pool-gb G             raw pool size (1 GB = 7.5 experts/layer)
min ~13/layer = 8.1 GB total. The pool is one global cache shared across
all layers -- per-layer is the unit of intuition (a token activates 10
of its 512 per layer), not a quota: hot layers borrow slots from cold.

what a memory target buys (conservative warm-decode estimate from
measured M5 Pro anchors: 30/layer = 6.0, 150/layer = 11.6; the last
column is the wait before the first token of a prompt filling the
whole context, follow-up turns read only what is new):
  target     experts/layer  est. warm decode   pass    full 32768-token prompt
     8.1 GB         13/512      ~ 3 tok/s     256   ~6.4 min
    10.0 GB         20/512      ~ 4 tok/s     256   ~6.4 min
    12.0 GB         31/512      ~ 6 tok/s     512   ~4.4 min
    16.0 GB         54/512      ~ 8 tok/s    1024   ~3.3 min
    24.0 GB        104/512      ~10 tok/s    2048   ~3.1 min
    28.0 GB        134/512      ~11 tok/s    2048   ~3.1 min
    36.0 GB        174/512      ~12 tok/s    4096   ~3.0 min
    48.0 GB        265/512      ~12 tok/s    4096   ~3.0 min
    73.0 GB        453/512      ~12 tok/s    4096   ~3.0 min
```

### Cold generation

```text
-- prefill 28 tok in 10.85s (2.6 tok/s)
-- prefill split: io 8.68s + scatter 0.78s + compute 1.39s | 4778 records (13.2 GB, 1.5 GB/s)
-- decode 128 tok in 90.05s (1.42 tok/s)
-- expert cache ~21/512 experts per layer, hit rate 0.447 | ngram rows 136h/1912m | peak 6.3 GB | total 100.9s
```

### Warm decode

```text
decode 1.48 tok/s, prefill 2.6 tok/s
decode 1.48 tok/s, prefill 2.6 tok/s
decode 1.48 tok/s, prefill 2.6 tok/s
```

### Long prompt

```text
slotstream memory plan (auto)
  device: 17 GB RAM (12.5 GB reclaimable now), 12.7 GB Metal working set
  target: 10.7 GB total for this process   (override: --memory-gb N | --max-ram-percent P)
  cache:  ~25 of 512 experts per layer  (1193 global slots = 3.3 GB pool)
  expect: ~9.7 GB peak, ~5 tok/s warm decode (est. from M5 Pro anchors)
  prefill: 256 tokens per pass (~85 tok/s here; costs ~0.3 GB of the target)
  context: up to 32768 tokens per request (prompt + reply); a full-length prompt takes ~6.4 min before its first token here, follow-up turns read only what is new
  reuse:  up to 15961 tokens across 4 conversations (~0.8 GB), so a follow-up turn re-prefills only what is new
engine ready in 2.6s: expert cache ~25/512 per layer (1193 global slots = 3.3 GB), eos [248044, 248046]
  prefill: reading 8192 prompt tokens, ~1.6 min to the first token at this plan (follow-up turns read only what is new)
  prefill: 2048/8192 tokens (25%), ~8.4 min left
  prefill: 4096/8192 tokens (50%), ~5.7 min left
  prefill: 6144/8192 tokens (75%), ~2.9 min left
  prefill: done, 8192 tokens in 12.1 min (11 tok/s)
context-check   8192 tokens: read in 12.1 min (11 tok/s), peak RSS 8.1 GB vs plan 9.7 GB — OK
verdict: 8192 tokens stay inside the plan on this Mac; the ceiling is 32768 (prompt + reply), so no flag is needed.
```

### Notes

Closed all other apps, only Terminal running with slotstream. No noticeable fan spinning.

### Listing

- [x] You may add this row to docs/HARDWARE.md credited to my GitHub handle.
