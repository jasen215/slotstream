---
type: community-report
id: 01m3a69xr34tasbbfgx14fmjrt
created: 2026-09-24T17:09:41.763070+00:00
updated: 2026-09-24T17:09:42.758700+00:00
summary: 'Measured: M4 Max MacBook Pro, 36 GB'
captured_at: 2026-09-24
machines: '[[records/machines/macbook-pro-m4-max-36gb]]'
reporter: JohnClarkson
title: 'Measured: M4 Max MacBook Pro, 36 GB'
url: https://github.com/carloslfu/slotstream/issues/26
---
Issue opened 2026-09-20T14:05:00Z; captured 2026-09-24.

The following issue body and comments are preserved verbatim from the
GitHub response. Numbers and interpretations inside them are the authors' reports.
One redaction: the weights path printed a macOS home directory, replaced
with `/Users/<user>/`. Nothing else is changed.

## Original issue body

### Mac

MacBook Pro, M4 Max, Nov 2024

### Unified memory

36 GB

### SSD

Internal 1TB

### macOS version

Tahoe 26.0.1

### slotstream --version

0.2.22

### Memory plan

```text
device: applegpu_g16s  |  39 GB RAM (31.6 GB reclaimable now), 30.2 GB Metal working set
model:  48 layers x 512 experts x 2.76 MB (24576 records = 67.9 GB streamed from SSD)
weights: present by size, 105.3 GB at /Users/<user>/.slotstream/models/qwen38-flash-next-mlx-4bit (run pull --verify for hashes)

slotstream memory plan (auto)
  device: 39 GB RAM (31.5 GB reclaimable now), 30.2 GB Metal working set
  target: 27.1 GB total process budget, not a RAM usage goal   (explicit target: --memory-gb N; auto RAM share: --max-ram-percent P)
  cache:  ~90 of 512 experts per layer  (4336 global slots = 12.0 GB pool)
  plan:   ~26.1 GB full-workload envelope, ~9 tok/s warm decode (est. from M5 Pro anchors)
  memory: 12.0 GB expert cache at load; 14.1 GB allowed for runtime, context and workspace; 1.0 GB budget headroom. Short requests can use less.
  disk:   that estimate assumes an SSD like the one it was measured on (17.3 GB/s). A base-storage Mac mini M2 reads 1.5 GB/s and decoded at 1.41 tok/s against a ~4 estimate, so on base storage expect well under the number above — see docs/HARDWARE.md
  prefill: 2048 tokens per pass (~205 tok/s here; costs ~2.7 GB of the target)
  mtp:    draft head on — speculative decode (1.6 GB resident, charged above)
  vision: images accepted — first image reserves +0.9 GB inside the target; refused if it cannot fit
  context: up to 65536 tokens per request (prompt + reply, +1.8 GB state and transient reserve charged above); a full-length prompt takes ~7.5 min before its first token here, follow-up turns read only what is new
  reuse:  up to 65536 tokens across 4 conversations (~2.2 GB), so a follow-up turn re-prefills only what is new
  lookahead: on, expert prefetch with the draft head, router cache and a GPU barrier every 4 layers (373 MiB, charged above)
memory-feasible window: 262144 tokens; separate from the 30.0-minute request-to-first-token policy

context window: automatic, 65536 tokens on this machine's memory tier. Auto takes the largest
window that keeps speculative decoding, retains one complete conversation, and adds at most 10%
to the estimated time of a 2000-token prompt with a 400-token reply:
Cache reductions above the measured decode range are declined, even when the estimate is flat.
   window   experts/layer   draft   lookahead    pass   typical request   full-window wait
    32768         112/512      on          on    2048     48.6 s (+0.0%)   ~3.1 min
    65536          90/512      on          on    2048     52.2 s (+7.3%)   ~7.5 min   <- auto
   131072          76/512     off         off    1024    57.8 s (+18.8%)   not yet calibrated   (turns speculative decoding off)
   262144   does not fit with one complete conversation retained
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
  target     experts/layer  est. warm decode   pass    full 65536-token prompt
     8.1 GB   too small for a 65536-token window
    10.0 GB         13/512      ~ 3 tok/s     256   ~12.9 min
    12.0 GB         13/512      ~ 3 tok/s     512   ~8.8 min
    16.0 GB         33/512      ~ 6 tok/s    1024   ~7.8 min
    24.0 GB         83/512      ~ 9 tok/s    2048   ~7.5 min
    28.0 GB        114/512      ~10 tok/s    2048   ~7.5 min
    36.0 GB   above this Mac's 30.2 GB Metal working set
    48.0 GB   above this Mac's 30.2 GB Metal working set
    73.0 GB   above this Mac's 30.2 GB Metal working set

time to first token at this plan, by prompt length (the pass shrinks past ~4k
tokens so its transient memory stays inside what was measured):
  2k ~10 s · 8k ~40 s · 16k ~1.4 min · 64k ~7.5 min (the cap)
  context state is ~27 KiB per token, up to the model's 262144-token limit.
  `slotstream context-check --tokens N` reads an N-token synthetic prompt on this Mac and
  stops early if reclaimable memory falls below its floor or its time limit passes.
```

### Cold generation

```text
-- prefill 28 tok in 3.37s (8.3 tok/s)
-- prefill split: io 2.41s + scatter 0.01s | 4775 records (13.2 GB, 5.5 GB/s)
-- decode 128 tok in 14.84s (8.63 tok/s)
-- decode split: io 4.47s + scatter 0.05s | 6256 records | mtp 74/106 drafts accepted (70%), 53 verify passes
-- expert cache ~90/512 experts per layer, hit rate 0.761 | ngram rows 192h/2352m | lifetime footprint peak 17.944 GB, current footprint 17.944 GB | total 18.3s
```

### Warm decode

```text
decode 8.48 tok/s, prefill 8.6 tok/s
decode 8.61 tok/s, prefill 35353535.4 tok/s
decode 8.41 tok/s, prefill 35398230.1 tok/s
```

### Long prompt

```text
slotstream memory plan (auto)
  device: 39 GB RAM (30.0 GB reclaimable now), 30.2 GB Metal working set
  target: 27.1 GB total process budget, not a RAM usage goal   (explicit target: --memory-gb N; auto RAM share: --max-ram-percent P)
  cache:  ~121 of 512 experts per layer  (5823 global slots = 16.1 GB pool)
  plan:   ~26.1 GB full-workload envelope, ~11 tok/s warm decode (est. from M5 Pro anchors)
  memory: 16.1 GB expert cache at load; 10.0 GB allowed for runtime, context and workspace; 1.0 GB budget headroom. Short requests can use less.
  disk:   that estimate assumes an SSD like the one it was measured on (17.3 GB/s). A base-storage Mac mini M2 reads 1.5 GB/s and decoded at 1.41 tok/s against a ~4 estimate, so on base storage expect well under the number above — see docs/HARDWARE.md
  prefill: 2048 tokens per pass (~205 tok/s here; costs ~2.7 GB of the target)
  mtp:    draft head on — speculative decode (1.6 GB resident, charged above)
  vision: images accepted — first image reserves +0.9 GB inside the target; refused if it cannot fit
  context: up to 8208 tokens per request (prompt + reply); a full-length prompt takes ~40 s before its first token here, follow-up turns read only what is new
  lookahead: on, expert prefetch with the draft head, router cache and a GPU barrier every 4 layers (373 MiB, charged above)
  note:   prefill and prefix retention reservations match the explicit runtime controls
[expert-lookahead] boundary forecast: no correction at lookahead/tap-correction-attention-rank128-v1.safetensors
engine ready in 2.0s: expert cache ~121/512 per layer (5823 global slots = 16.1 GB), mtp draft head on, eos [248044, 248046]
  prefill: reading 8192 prompt tokens, ~40 s to the first token at this plan (follow-up turns read only what is new)
  prefill: 2048/8192 tokens (25%), ~35 s left
  prefill: 4096/8192 tokens (50%), ~23 s left
  prefill: 6144/8192 tokens (75%), ~12 s left
  context-check progress: 6144/8192 missing tokens committed
  prefill: done, 8192 tokens in 49 s (166 tok/s)
context-check   8192 tokens: read in 49 s (166 tok/s), process peak 24.8 GB vs plan 26.1 GB: OK
verdict: 8192 prompt tokens plus 16 output tokens completed inside the plan on this Mac. Serving chooses its window per machine (see `slotstream doctor`) and accepts --max-context up to 262144. Diagnostic success does not change that choice.
```

### Notes

Directly after a reboot and opening one screen sharing window to another mac. Nothing else open other than the Terminal application (with 4 tabs).


### Listing

- [x] You may add this row to docs/HARDWARE.md credited to my GitHub handle.

## Comment by @carloslfu

2026-09-21T16:00:44Z · https://github.com/carloslfu/slotstream/issues/26#issuecomment-5763501802

Thanks @JohnClarkson!!
