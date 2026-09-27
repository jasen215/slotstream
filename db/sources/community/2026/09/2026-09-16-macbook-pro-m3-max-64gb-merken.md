---
type: community-report
id: 01m3a68vj0cdb0r83wwreabwss
created: 2026-09-24T17:09:06.752486+00:00
updated: 2026-09-24T17:09:24.672968+00:00
summary: 'Measured: M3 MAX, 64 GB'
captured_at: 2026-09-24
machines: '[[records/machines/macbook-pro-m3-max-64gb]]'
reporter: merken
title: 'Measured: M3 MAX, 64 GB'
url: https://github.com/carloslfu/slotstream/issues/20
---
Issue opened 2026-09-16T09:50:28Z; captured 2026-09-24.

The following issue body and comments are preserved verbatim from the
GitHub response. Numbers and interpretations inside them are the authors' reports.
One redaction: the weights path printed a macOS home directory, replaced
with `/Users/<user>/`. Nothing else is changed.

## Original issue body

### Mac

MacBook PRO 14 Inch, 2023

### Unified memory

64

### SSD

512

### macOS version

27.0

### slotstream --version

0.2.18

### Memory plan

```text
device: applegpu_g15s  |  69 GB RAM (60.2 GB reclaimable now), 64.4 GB Metal working set
model:  48 layers x 512 experts x 2.76 MB (24576 records = 67.9 GB streamed from SSD)
weights: present by size, 105.3 GB at /Users/<user>/.slotstream/models/qwen38-flash-next-mlx-4bit (run pull --verify for hashes)

slotstream memory plan (auto)
  device: 69 GB RAM (60.2 GB reclaimable now), 64.4 GB Metal working set
  target: 48.1 GB total for this process   (explicit target: --memory-gb N; auto RAM share: --max-ram-percent P)
  cache:  ~119 of 512 experts per layer  (5722 global slots = 15.8 GB pool)
  expect: ~47.1 GB peak, ~11 tok/s warm decode (est. from M5 Pro anchors)
  disk:   that estimate assumes an SSD like the one it was measured on (17.3 GB/s). A base-storage Mac mini M2 reads 1.5 GB/s and decoded at 1.41 tok/s against a ~4 estimate, so on base storage expect well under the number above — see docs/HARDWARE.md
  prefill: 2048 tokens per pass (~205 tok/s here; costs ~2.7 GB of the target)
  mtp:    draft head on — speculative decode (1.6 GB resident, charged above)
  vision: images accepted — first image reserves +0.9 GB inside the target; refused if it cannot fit
  context: up to 262144 tokens per request (prompt + reply, +12.7 GB state and transient reserve charged above); a full-length prompt has no calibrated wait yet (passes under 256 tokens are not yet measured), follow-up turns read only what is new
  reuse:  up to 262144 tokens across 4 conversations (~7.6 GB), so a follow-up turn re-prefills only what is new
  lookahead: on, expert prefetch with the draft head, router cache and a GPU barrier every 4 layers (373 MiB, charged above)
memory-feasible window: 262144 tokens; separate from the 30.0-minute request-to-first-token policy

context window: automatic, 262144 tokens on this machine's memory tier. Auto takes the largest
window that keeps speculative decoding, retains one complete conversation, and adds at most 10%
to the estimated time of a 2000-token prompt with a 400-token reply:
   window   experts/layer   draft   lookahead    pass   typical request   full-window wait
    32768         149/512      on          on    4096     43.7 s (+0.0%)   ~3.0 min
    65536         149/512      on          on    4096     43.7 s (+0.0%)   ~7.5 min
   131072         149/512      on          on    4096     43.7 s (+0.0%)   not yet calibrated
   262144         119/512      on          on    2048     47.6 s (+9.0%)   not yet calibrated   <- auto
  --max-context N chooses any window up to 262144. A larger window costs memory and
  reading time; it does not guarantee answer quality over very long context.

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
  target     experts/layer  est. warm decode   pass    full 262144-token prompt
     8.1 GB   too small for a 262144-token window
    10.0 GB   too small for a 262144-token window
    12.0 GB   too small for a 262144-token window
    16.0 GB   too small for a 262144-token window
    24.0 GB         26/512      ~ 5 tok/s     512   not yet calibrated
    28.0 GB         49/512      ~ 7 tok/s    1024   not yet calibrated
    36.0 GB         61/512      ~ 8 tok/s    1024   not yet calibrated
    48.0 GB        141/512      ~11 tok/s    2048   not yet calibrated
    73.0 GB   above this Mac's 64.4 GB Metal working set

time to first token at this plan, by prompt length (the pass shrinks past ~4k
tokens so its transient memory stays inside what was measured):
  2k ~10 s · 8k ~40 s · 16k ~1.4 min · 256k not yet calibrated (the cap)
  context state is ~27 KiB per token, up to the model's 262144-token limit.
  `slotstream context-check --tokens N` reads an N-token synthetic prompt on this Mac and
  stops early if reclaimable memory falls below its floor or its time limit passes.
```

### Cold generation

```text
-- prefill 18 tok in 2.22s (8.1 tok/s)
-- prefill split: io 1.54s + scatter 0.00s | 3412 records (9.4 GB, 6.1 GB/s)
-- decode 128 tok in 11.16s (11.47 tok/s)
-- decode split: io 4.00s + scatter 0.05s | 5351 records | mtp 74/106 drafts accepted (70%), 53 verify passes
-- expert cache ~119/512 experts per layer, hit rate 0.796 | ngram rows 64h/2480m | lifetime footprint peak 21.578 GB, current footprint 21.578 GB | total 13.4s
```

### Warm decode

```text
decode 11.68 tok/s, prefill 9.2 tok/s
decode 12.49 tok/s, prefill 33613445.4 tok/s
decode 12.38 tok/s, prefill 35353535.4 tok/s
```

### Long prompt

```text
slotstream memory plan (auto)
  device: 69 GB RAM (59.6 GB reclaimable now), 64.4 GB Metal working set
  target: 34.6 GB total for this process   (explicit target: --memory-gb N; auto RAM share: --max-ram-percent P)
  cache:  ~158 of 512 experts per layer  (7588 global slots = 21.0 GB pool)
  expect: ~33.6 GB peak, ~12 tok/s warm decode (est. from M5 Pro anchors)
  disk:   that estimate assumes an SSD like the one it was measured on (17.3 GB/s). A base-storage Mac mini M2 reads 1.5 GB/s and decoded at 1.41 tok/s against a ~4 estimate, so on base storage expect well under the number above — see docs/HARDWARE.md
  prefill: 4096 tokens per pass (~220 tok/s here; costs ~5.3 GB of the target)
  mtp:    draft head on — speculative decode (1.6 GB resident, charged above)
  vision: images accepted — first image reserves +0.9 GB inside the target; refused if it cannot fit
  context: up to 8208 tokens per request (prompt + reply); a full-length prompt takes ~39 s before its first token here, follow-up turns read only what is new
  lookahead: on, expert prefetch with the draft head, router cache and a GPU barrier every 4 layers (373 MiB, charged above)
  note:   auto's default memory ceiling is 34.6 GB for this model, based on diminishing returns in development-Mac tests; other hardware may benefit from more. We revise defaults using real measurements; --memory-gb N selects a larger fixed target
  note:   prefill and prefix retention reservations match the explicit runtime controls
engine ready in 2.1s: expert cache ~158/512 per layer (7588 global slots = 21.0 GB), mtp draft head on, eos [248044, 248046]
  prefill: reading 8192 prompt tokens, ~39 s to the first token at this plan (follow-up turns read only what is new)
  prefill: 4096/8192 tokens (50%), ~17 s left
  prefill: 6144/8192 tokens (75%), ~8 s left
  prefill: done, 8192 tokens in 39 s (213 tok/s)
  context-check progress: 8192/8192 missing tokens committed
context-check   8192 tokens: read in 39 s (213 tok/s), process peak 30.1 GB vs plan 33.6 GB: OK
verdict: 8192 prompt tokens plus 16 output tokens completed inside the plan on this Mac. Serving chooses its window per machine (see `slotstream doctor`) and accepts --max-context up to 262144. Diagnostic success does not change that choice.
```

### Notes

_No response_

### Listing

- [x] You may add this row to docs/HARDWARE.md credited to my GitHub handle.

## Comment by @carloslfu

2026-09-16T12:51:01Z · https://github.com/carloslfu/slotstream/issues/20#issuecomment-5697715238

thanks @merken!
