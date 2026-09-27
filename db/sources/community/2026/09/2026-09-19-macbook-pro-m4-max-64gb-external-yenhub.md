---
type: community-report
id: 01m3a69wrs5e4szvxg95ee19q8
created: 2026-09-24T17:09:40.761298+00:00
updated: 2026-09-24T17:09:41.660313+00:00
summary: 'Measured: M4 Max 16", 64 GB (External SSD)'
captured_at: 2026-09-24
machines: '[[records/machines/macbook-pro-m4-max-64gb]]'
reporter: YenHub
title: 'Measured: M4 Max 16", 64 GB (External SSD)'
url: https://github.com/carloslfu/slotstream/issues/23
---
Issue opened 2026-09-19T12:42:50Z; captured 2026-09-24.

The following issue body and comments are preserved verbatim from the
GitHub response. Numbers and interpretations inside them are the authors' reports.
One redaction: the weights path printed a macOS home directory, replaced
with `/Users/<user>/`. Nothing else is changed.

## Original issue body

### Mac

MacBook Pro 16, M4 Max, Nov 2024

### Unified memory

64 GB

### SSD

External, 1 TB, USB 3.2 Gen 2 (10 Gb/s)

### macOS version

27.0

### slotstream --version

0.2.22

### Memory plan

```text
device: applegpu_g16s  |  69 GB RAM (58.1 GB reclaimable now), 55.7 GB Metal working set
model:  48 layers x 512 experts x 2.76 MB (24576 records = 67.9 GB streamed from SSD)
weights: present by size, 105.3 GB at /Users/<user>/.slotstream/models/qwen38-flash-next-mlx-4bit (run pull --verify for hashes)

slotstream memory plan (auto)
  device: 69 GB RAM (58.1 GB reclaimable now), 55.7 GB Metal working set
  target: 48.1 GB total process budget, not a RAM usage goal   (explicit target: --memory-gb N; auto RAM share: --max-ram-percent P)
  cache:  ~119 of 512 experts per layer  (5722 global slots = 15.8 GB pool)
  plan:   ~47.1 GB full-workload envelope, ~11 tok/s warm decode (est. from M5 Pro anchors)
  memory: 15.8 GB expert cache at load; 31.3 GB allowed for runtime, context and workspace; 1.0 GB budget headroom. Short requests can use less.
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
Cache reductions above the measured decode range are declined, even when the estimate is flat.
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
    73.0 GB   above this Mac's 55.7 GB Metal working set

time to first token at this plan, by prompt length (the pass shrinks past ~4k
tokens so its transient memory stays inside what was measured):
  2k ~10 s · 8k ~40 s · 16k ~1.4 min · 256k not yet calibrated (the cap)
  context state is ~27 KiB per token, up to the model's 262144-token limit.
  `slotstream context-check --tokens N` reads an N-token synthetic prompt on this Mac and
  stops early if reclaimable memory falls below its floor or its time limit passes.
```

### Cold generation

```text
-- prefill 28 tok in 15.76s (1.8 tok/s)
-- prefill split: io 14.77s + scatter 0.00s | 4775 records (13.2 GB, 0.9 GB/s)
-- decode 128 tok in 44.36s (2.89 tok/s)
-- decode split: io 21.40s + scatter 0.03s | 4684 records | mtp 74/106 drafts accepted (70%), 53 verify passes
-- expert cache ~119/512 experts per layer, hit rate 0.837 | ngram rows 192h/2352m | lifetime footprint peak 21.851 GB, current footprint 21.851 GB | total 60.1s
```

### Warm decode

```text
decode 2.81 tok/s, prefill 1.8 tok/s
decode 3.04 tok/s, prefill 26897214.2 tok/s
decode 2.98 tok/s, prefill 32000000.0 tok/s
```

### Long prompt

```text
slotstream memory plan (auto)
  device: 69 GB RAM (58.8 GB reclaimable now), 55.7 GB Metal working set
  target: 34.6 GB total process budget, not a RAM usage goal   (explicit target: --memory-gb N; auto RAM share: --max-ram-percent P)
  cache:  ~158 of 512 experts per layer  (7588 global slots = 21.0 GB pool)
  plan:   ~33.6 GB full-workload envelope, ~12 tok/s warm decode (est. from M5 Pro anchors)
  memory: 21.0 GB expert cache at load; 12.6 GB allowed for runtime, context and workspace; 1.0 GB budget headroom. Short requests can use less.
  speed:  this cache exceeds the measured decode range; the estimate is capped, but extra cache may still improve speed
  disk:   that estimate assumes an SSD like the one it was measured on (17.3 GB/s). A base-storage Mac mini M2 reads 1.5 GB/s and decoded at 1.41 tok/s against a ~4 estimate, so on base storage expect well under the number above — see docs/HARDWARE.md
  prefill: 4096 tokens per pass (~220 tok/s here; costs ~5.3 GB of the target)
  mtp:    draft head on — speculative decode (1.6 GB resident, charged above)
  vision: images accepted — first image reserves +0.9 GB inside the target; refused if it cannot fit
  context: up to 8208 tokens per request (prompt + reply); a full-length prompt takes ~39 s before its first token here, follow-up turns read only what is new
  lookahead: on, expert prefetch with the draft head, router cache and a GPU barrier every 4 layers (373 MiB, charged above)
  note:   auto's default memory ceiling is 34.6 GB for this model, based on diminishing returns in development-Mac tests; other hardware may benefit from more. We revise defaults using real measurements; --memory-gb N selects a larger fixed target
  note:   prefill and prefix retention reservations match the explicit runtime controls
[expert-lookahead] boundary forecast: no correction at lookahead/tap-correction-attention-rank128-v1.safetensors
engine ready in 1.0s: expert cache ~158/512 per layer (7588 global slots = 21.0 GB), mtp draft head on, eos [248044, 248046]
  prefill: reading 8192 prompt tokens, ~39 s to the first token at this plan (follow-up turns read only what is new)
  prefill: 4096/8192 tokens (50%), ~57 s left
  context-check progress: 4096/8192 missing tokens committed
  prefill: 6144/8192 tokens (75%), ~35 s left
  context-check progress: 6144/8192 missing tokens committed
  prefill: done, 8192 tokens in 2.7 min (51 tok/s)
  context-check progress: 8192/8192 missing tokens committed
context-check   8192 tokens: read in 2.7 min (51 tok/s), process peak 30.2 GB vs plan 33.6 GB: OK
verdict: 8192 prompt tokens plus 16 output tokens completed inside the plan on this Mac. Serving chooses its window per machine (see `slotstream doctor`) and accepts --max-context up to 262144. Diagnostic success does not change that choice.
```

### Notes

Fresh system reboot, nothing running but iTerm terminal.

The test device is a Crucial X10 Pro 1TB

### Listing

- [x] You may add this row to docs/HARDWARE.md credited to my GitHub handle.

## Comment by @YenHub

2026-09-19T12:49:20Z · https://github.com/carloslfu/slotstream/issues/23#issuecomment-5742004276

Super impressive project @carloslfu 💪 

Speeds dropped massively on this measurement -vs- the internal SSD, though given the restriction to 10Gb/s on 3.2 gen 2 - that makes sense.

I'll explore getting a USB4 40 Gb/s drive so I can re-submit some results using that.

If you want me to conduct any further testing, please let me know! 

Kudos - this is amazing!! ❤️ 

## Comment by @spikezz

2026-09-19T15:15:18Z · https://github.com/carloslfu/slotstream/issues/23#issuecomment-5742974312

> Super impressive project [@carloslfu](https://github.com/carloslfu) 💪
> 
> Speeds dropped massively on this measurement -vs- the internal SSD, though given the restriction to 10Gb/s on 3.2 gen 2 - that makes sense.
> 
> I'll explore getting a USB4 40 Gb/s drive so I can re-submit some results using that.
> 
> If you want me to conduct any further testing, please let me know!
> 
> Kudos - this is amazing!! ❤️

I’ve already bought a WD SN8100 2TB + OWC 0TB Express 1M2 USB4 (80Gb/s) setup—highly recommended.

## Comment by @carloslfu

2026-09-21T03:48:19Z · https://github.com/carloslfu/slotstream/issues/23#issuecomment-5755122467

love this! thanks @YenHub!

## Comment by @YenHub

2026-09-21T19:07:32Z · https://github.com/carloslfu/slotstream/issues/23#issuecomment-5765984177

> love this! thanks @YenHub!

Let me know if I can do anything to be of assistance to you on your voyage 🫡

## Comment by @carloslfu

2026-09-23T14:46:38Z · https://github.com/carloslfu/slotstream/issues/23#issuecomment-5796987396

@YenHub, yes! Are you up for a quick virtual coffee to chat about local AI? I'd like to know more about what you are using it for
