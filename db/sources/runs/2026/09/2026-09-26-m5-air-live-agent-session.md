---
type: run
id: 01m3dw2mwtw3f00acbtkcynpkx
created: 2026-09-26T03:27:55.285308+00:00
updated: 2026-09-26T03:28:30.515318+00:00
summary: 'A live agent session on the 32 GB Air: three memory refusals, one memory prefix reuse against 24 disk reuses, and the elastic shrink that pinned the in-memory retention ceiling below the conversation'
binary: slotstream (working tree at b45edd4 + uncommitted request-failure and prefix-cache instrumentation); the installed release 0.2.23 does not contain the strings this log prints
captured_at: 2026-09-26
command: slotstream serve (auto memory plan, no memory flag, --prefix-cache-dir ~/.slotstream/prefix-cache); repeated /v1/chat/completions turns over about 72 minutes
discarded: 'true'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
title: 'A live agent session on the 32 GB Air: the in-memory prefix tier pinned below the live conversation'
tool: slotstream serve (working-tree debug build) driven by the user agent client
---
A live agent session on the same 32 GB MacBook Air as
[[sources/runs/2026/09/2026-09-24-m5-air-live-agent-session]], captured from the
server's own `serve.log`. About 72 minutes of ordinary agent traffic: one 25k-token
prompt read cold, then 25 follow-up turns of a single conversation growing out to
41,829 tokens, served with `--prefix-cache-dir`.

**Why this is discarded.** No timing here is a measurement. The elastic governor
shrank the expert pool twice inside three minutes for availability, both times to a
*cold* pool, and the prefill rate moved from 126 to 20-30 tok/s within the one
session — the signature of a machine doing other work. What the capture is kept for
is structural: which requests failed, how they failed, and where the prefix cache
answered from.

**Provenance.** The installed release 0.2.23 does not contain the strings this log
prints (`memory offered 0`, `[required %.2f GB, available %.2f GB]`), so the session
ran a working-tree build carrying the uncommitted request-failure and prefix-cache
instrumentation, not a release. Nothing here qualifies a released build, and the
session is not attributable to a tag.

**What it settles.** Open question 12 in
[[records/plan/12-open-questions-answer-at-the-milestone-noted]] asked why the
in-memory prefix tier stops serving a conversation once it is large, and guessed
that a request which failed during preparation had consumed the state
(`mayRetainState == false`, `PrefixCache.takeForGeneration` removing a non-reusable
entry). This capture does not support that guess. The three refusals happen at
10:51:23-26 and the memory tier still served a 25,600-token state at 10:55:30, i.e.
*after* them; the switch to disk at 10:57:28 follows a request that **succeeded**.
The instrumentation answers the question directly instead: `memory offered 0` on all
24 disk reuses and exactly one prefix from memory in the whole session. What the
switch coincides with is the conversation crossing 29,659 tokens — the retention
ceiling that the 10:53 elastic shrink had just installed, below the live
conversation's length.

**The mechanism, from the log and the code.** `GovernorPolicy.liveControls` derives
the post-resize prefix ceiling from a pool-only share
(`Planner.prefixCacheTokensFor(poolBudgetGB:contextCap:)`, 10% of the pool budget at
27,648 bytes per token) whenever the decided target is not exactly the freshly
desired plan's slot count — the ordinary dead-band path, not only an OS pressure
event. That share has no `retentionFloor`, so it revokes the ceiling the planner
adopts so one complete conversation stays retained. At the 8.2 GB pool the share is
29,659 tokens; `PrefixCache.store` admits a state only while
`t.count <= _maxTokens`, so the boundary snapshot at 31,744 tokens (10:56:58) was
refused and every later turn of the 40k-token conversation was longer than the
ceiling. `PrefixCache.setBudgetLimit` was also `min`-only, so the ceiling could not
come back when the pool regrew to 10.3 GB at the end of the session: one shed pinned
the tier for the process lifetime.

**The three refusals.** `insufficient_memory` ended three requests in 3 s at
10:51:23-26, the first by 0.17 GB (`required 7.88 GB, available 7.71 GB`), the next
two worse (6.94, 7.06 GB). The governor had grown the pool to 10.4 GB two minutes
earlier and then shed it to 9.3 GB *cold*, so a request landed on the freshly
resized plan with no headroom. This is a different guard from the prefill wait:
`--max-prefill-wait` (default 30 minutes) does not apply, and the request is refused
in under a second rather than queued.

**The shrink.** The pool moved 8.1 -> 10.4 -> 9.3 -> 8.2 GB, two steps cold, and
settled at ~62 of 512 experts per layer; the prefill rate followed it down from 126
to 20-30 tok/s and the plan's own banner rate (165 tok/s, at a matched pool) was
never observed. The prompt's first token was predicted at ~2.6 minutes and arrived
after 6.0 (25,284 tokens at 70 tok/s), and the first attempt at that request was
abandoned by its client after 28.7 s.

The plan the server printed for this session, and the raw `serve.log` verbatim:

```text
slotstream memory plan (auto)
  device: 34 GB RAM (21.4 GB reclaimable now), 26.8 GB Metal working set
  target: 19.7 GB total process budget, not a RAM usage goal   (adaptive limit: --memory-limit-gb N; fixed cache: --memory-gb N)
  limit:  22.0 GB; cache adapts to available memory
  cache:  ~61 of 512 experts per layer  (2930 global slots = 8.1 GB pool)
  plan:   ~18.7 GB full-workload envelope, ~8 tok/s warm decode (est. from M5 Pro anchors)
  memory: 8.1 GB expert cache at load; 10.6 GB allowed for runtime, context and workspace; 1.0 GB budget headroom. Short requests can use less.
  disk:   that estimate assumes an SSD like the one it was measured on (17.3 GB/s). A base-storage Mac mini M2 reads 1.5 GB/s and decoded at 1.41 tok/s against a ~4 estimate, so on base storage expect well under the number above — see docs/HARDWARE.md
  prefill: 1024 tokens per pass (~165 tok/s here; costs ~1.3 GB of the target)
          that is the acceptance prompt's rate at a matched pool, on the same SSD; ordinary prose reads slower, the pass shrinks as the context grows, and a small expert cache reads most experts from disk — a long agent prompt can come in well under it (docs/HARDWARE.md)
  vision: images accepted — first image reserves +0.9 GB inside the target; refused if it cannot fit
  context: up to 65536 tokens per request (prompt + reply, +1.8 GB state and transient reserve charged above); a full-length prompt takes ~7.8 min before its first token here, follow-up turns read only what is new
  reuse:  up to 65536 tokens across 4 conversations (~2.2 GB), so a follow-up turn re-prefills only what is new
  note:   using up to 19.7 GB now; the cache can grow back toward 22.0 GB when memory is available
engine ready in 1.3s: expert cache ~61/512 per layer (2930 global slots = 8.1 GB), eos [248044, 248046]
prefix cache disk: /Users/jasen/.slotstream/prefix-cache holds 0 states (0.00 GB of 16.00 GB); writes states of 1024 tokens or more; forgets states unused for 30 days; removed 37 from other builds (5.20 GB)
elastic: on — cache auto-resizes with memory availability between requests (--no-elastic to pin)
slotstream listening on http://127.0.0.1:11434
try it:
  curl localhost:11434/api/chat -d '{"model": "qwen3.8-flash-next:4bit", "messages": [{"role": "user", "content": "hello"}]}'
or point any Ollama or OpenAI client at http://localhost:11434
[10:03:14] request B96582AB /v1/chat/completions: accepted
prefix cache: miss: no retained state (0 prior evictions)
[10:03:14] prefill: reading 25399 prompt tokens, ~2.6 min to the first token at this plan (follow-up turns read only what is new)
[10:03:29] request B96582AB /v1/chat/completions: 15 s elapsed, inference boundary
[10:03:42] request B96582AB /v1/chat/completions: ended after 28.7 s, client_cancelled: the client disconnected during inference boundary [phase inference boundary]
[10:03:51] request 33F989E1 /v1/chat/completions: accepted
prefix cache: miss: no retained state (0 prior evictions)
[10:03:51] prefill: reading 25284 prompt tokens, ~2.6 min to the first token at this plan (follow-up turns read only what is new)
[10:04:06] request 33F989E1 /v1/chat/completions: 15 s elapsed, inference boundary
[10:04:21] request 33F989E1 /v1/chat/completions: 30 s elapsed, inference boundary
[10:04:24] prefill: 4096/25284 tokens (16%), 126 tok/s recently, ~2.8 min left at this rate
[10:04:36] request 33F989E1 /v1/chat/completions: 45 s elapsed, inference boundary
[10:04:51] request 33F989E1 /v1/chat/completions: 60 s elapsed, inference boundary
[10:05:02] prefill: 8192/25284 tokens (32%), 107 tok/s recently, ~2.7 min left at this rate
[10:05:06] request 33F989E1 /v1/chat/completions: 75 s elapsed, inference boundary
[10:05:21] request 33F989E1 /v1/chat/completions: 90 s elapsed, inference boundary
[10:05:36] request 33F989E1 /v1/chat/completions: 105 s elapsed, inference boundary
[10:05:49] prefill: 12288/25284 tokens (49%), 87 tok/s recently, ~2.5 min left at this rate
[10:05:51] request 33F989E1 /v1/chat/completions: 120 s elapsed, inference boundary
[10:06:06] request 33F989E1 /v1/chat/completions: 135 s elapsed, inference boundary
[10:06:21] request 33F989E1 /v1/chat/completions: 150 s elapsed, inference boundary
[10:06:36] request 33F989E1 /v1/chat/completions: 165 s elapsed, inference boundary
[10:06:38] prefill: 16384/25284 tokens (65%), 84 tok/s recently, ~1.8 min left at this rate
[10:06:51] request 33F989E1 /v1/chat/completions: 180 s elapsed, prefill pass
[10:07:01] prefill: 17408/25284 tokens (69%), 44 tok/s recently, ~3.0 min left at this rate
[10:07:06] request 33F989E1 /v1/chat/completions: 195 s elapsed, prefill pass
[10:07:21] request 33F989E1 /v1/chat/completions: 210 s elapsed, prefill pass
[10:07:24] prefill: 18432/25284 tokens (73%), 45 tok/s recently, ~2.5 min left at this rate
[10:07:36] request 33F989E1 /v1/chat/completions: 225 s elapsed, prefill pass
[10:07:47] prefill: 19456/25284 tokens (77%), 44 tok/s recently, ~2.2 min left at this rate
[10:07:51] request 33F989E1 /v1/chat/completions: 240 s elapsed, prefill pass
[10:08:06] request 33F989E1 /v1/chat/completions: 255 s elapsed, prefill pass
[10:08:10] prefill: 20480/25284 tokens (81%), 46 tok/s recently, ~1.8 min left at this rate
[10:08:21] request 33F989E1 /v1/chat/completions: 270 s elapsed, prefill pass
[10:08:32] prefill: 21504/25284 tokens (85%), 46 tok/s recently, ~1.4 min left at this rate
[10:08:36] request 33F989E1 /v1/chat/completions: 285 s elapsed, prefill pass
[10:08:51] request 33F989E1 /v1/chat/completions: 300 s elapsed, prefill pass
[10:08:52] prefill: 22528/25284 tokens (89%), 51 tok/s recently, ~54 s left at this rate
[10:09:06] request 33F989E1 /v1/chat/completions: 315 s elapsed, prefill pass
[10:09:11] prefill: 23552/25284 tokens (93%), 54 tok/s recently, ~32 s left at this rate
[10:09:21] request 33F989E1 /v1/chat/completions: 330 s elapsed, prefill pass
[10:09:29] prefix cache disk: saved 24576 tokens (795.2 MB written) in 0.58 s
[10:09:29] prefill: 24576/25284 tokens (97%), 55 tok/s recently, ~13 s left at this rate
[10:09:29] prefix cache disk: saved shared 24576-token prefix (115.8 MB written, 679.5 MB of rows reused) in 0.08 s
[10:09:36] request 33F989E1 /v1/chat/completions: 345 s elapsed, prefill pass
[10:09:51] prefill: done, 25284 tokens in 6.0 min (70 tok/s)
[10:09:51] request 33F989E1 /v1/chat/completions: 360 s elapsed, inference boundary
[10:09:55] request 33F989E1 /v1/chat/completions: ended after 363.6 s
elastic: memory freed — cache ~61 → ~78 experts/layer (8.1 → 10.3 GB pool, contents kept)
elastic: memory freed — cache ~78 → ~78 experts/layer (10.3 → 10.4 GB pool, contents kept)
elastic: availability dropped — cache ~78 → ~70 experts/layer (10.4 → 9.3 GB pool, cold — refills from SSD)
[10:51:23] request 4525EE37 /v1/chat/completions: accepted
[10:51:23] prefix cache disk: restored 24576 tokens (795.2 MB) in 0.19 s
prefix cache: reusing 24576/25690 tokens from disk (memory offered 0)
[10:51:23] request 4525EE37 /v1/chat/completions: ended after 0.5 s, insufficient_memory: insufficient memory for prefill pass, queued requests and safety headroom; retry after other requests finish [phase prefill pass] [required 7.88 GB, available 7.71 GB]
[10:51:24] request DE5443C2 /v1/chat/completions: accepted
[10:51:24] prefix cache disk: restored 24576 tokens (795.2 MB) in 0.07 s
prefix cache: reusing 24576/25690 tokens from disk (memory offered 0)
[10:51:24] request DE5443C2 /v1/chat/completions: ended after 0.3 s, insufficient_memory: insufficient memory for prefill pass, queued requests and safety headroom; retry after other requests finish [phase prefill pass] [required 7.88 GB, available 6.94 GB]
[10:51:25] request 93155446 /v1/chat/completions: accepted
[10:51:26] prefix cache disk: restored 24576 tokens (795.2 MB) in 0.07 s
prefix cache: reusing 24576/25690 tokens from disk (memory offered 0)
[10:51:26] request 93155446 /v1/chat/completions: ended after 0.3 s, insufficient_memory: insufficient memory for prefill pass, queued requests and safety headroom; retry after other requests finish [phase prefill pass] [required 7.88 GB, available 7.06 GB]
elastic: availability dropped — cache ~70 → ~62 experts/layer (9.3 → 8.2 GB pool, cold — refills from SSD)
[10:54:57] request 7BDB1F64 /v1/chat/completions: accepted
[10:54:57] prefix cache disk: restored 24576 tokens (795.2 MB) in 0.07 s
prefix cache: reusing 24576/25780 tokens from disk (memory offered 0)
[10:55:12] request 7BDB1F64 /v1/chat/completions: 15 s elapsed, prefill commit
[10:55:12] prefix cache disk: saved 25600 tokens (144.1 MB written, 679.5 MB of rows reused) in 0.21 s
[10:55:12] prefill: reading 1204 prompt tokens, ~7 s to the first token at this plan (follow-up turns read only what is new)
[10:55:12] prefill: 1024/1204 tokens (85%), 69 tok/s recently, ~3 s left at this rate
[10:55:22] prefill: done, 1204 tokens in 25 s (48 tok/s)
[10:55:27] request 7BDB1F64 /v1/chat/completions: 30 s elapsed, decode cache growth
[10:55:30] request 7BDB1F64 /v1/chat/completions: ended after 33.3 s
[10:55:30] request F8D74BC2 /v1/chat/completions: accepted
prefix cache: reusing 25600/32078 tokens from memory
[10:55:30] prefill: reading 6478 prompt tokens, ~40 s to the first token at this plan (follow-up turns read only what is new)
[10:55:45] request F8D74BC2 /v1/chat/completions: 15 s elapsed, prefill pass
[10:55:45] prefill: 1024/6478 tokens (16%), 70 tok/s recently, ~1.3 min left at this rate
[10:55:59] prefill: 2048/6478 tokens (32%), 71 tok/s recently, ~1.0 min left at this rate
[10:56:00] request F8D74BC2 /v1/chat/completions: 30 s elapsed, prefill pass
[10:56:14] prefill: 3072/6478 tokens (47%), 72 tok/s recently, ~48 s left at this rate
[10:56:15] request F8D74BC2 /v1/chat/completions: 45 s elapsed, prefill pass
[10:56:28] prefill: 4096/6478 tokens (63%), 70 tok/s recently, ~34 s left at this rate
[10:56:30] request F8D74BC2 /v1/chat/completions: 60 s elapsed, prefill pass
[10:56:43] prefill: 5120/6478 tokens (79%), 70 tok/s recently, ~19 s left at this rate
[10:56:45] request F8D74BC2 /v1/chat/completions: 75 s elapsed, prefill pass
[10:56:58] prefix cache disk: saved 31744 tokens (285.7 MB written, 707.8 MB of rows reused) in 0.20 s
[10:56:58] prefill: 6144/6478 tokens (95%), 68 tok/s recently, ~5 s left at this rate
[10:57:00] request F8D74BC2 /v1/chat/completions: 90 s elapsed, prefill pass
[10:57:10] prefill: done, 6478 tokens in 1.7 min (65 tok/s)
[10:57:15] request F8D74BC2 /v1/chat/completions: 105 s elapsed, decode cache growth
[10:57:27] request F8D74BC2 /v1/chat/completions: ended after 117.4 s
[10:57:28] request 2AC87215 /v1/chat/completions: accepted
[10:57:28] prefix cache disk: restored 31744 tokens (993.4 MB) in 0.22 s
prefix cache: reusing 31744/32205 tokens from disk (memory offered 0)
[10:57:43] request 2AC87215 /v1/chat/completions: 15 s elapsed, prefill pass
[10:57:43] prefill: reading 461 prompt tokens, ~4 s to the first token at this plan (follow-up turns read only what is new)
[10:57:43] prefill: done, 461 tokens in 14 s (33 tok/s)
[10:57:56] request 2AC87215 /v1/chat/completions: ended after 28.5 s
[10:57:56] request A358D930 /v1/chat/completions: accepted
[10:57:57] prefix cache disk: restored 31744 tokens (993.4 MB) in 0.26 s
prefix cache: reusing 31744/33722 tokens from disk (memory offered 0)
[10:58:11] request A358D930 /v1/chat/completions: 15 s elapsed, prefill pass
[10:58:11] prefill: reading 1978 prompt tokens, ~16 s to the first token at this plan (follow-up turns read only what is new)
[10:58:11] prefill: 512/1978 tokens (26%), 36 tok/s recently, ~40 s left at this rate
[10:58:24] prefill: 1024/1978 tokens (52%), 39 tok/s recently, ~24 s left at this rate
[10:58:26] request A358D930 /v1/chat/completions: 30 s elapsed, prefill pass
[10:58:38] prefix cache disk: saved 33280 tokens (158.3 MB written, 877.7 MB of rows reused) in 0.28 s, removed 1 older file
[10:58:38] prefill: 1536/1978 tokens (78%), 37 tok/s recently, ~12 s left at this rate
[10:58:41] request A358D930 /v1/chat/completions: 45 s elapsed, prefill pass
[10:58:53] prefill: done, 1978 tokens in 56 s (36 tok/s)
[10:58:56] request A358D930 /v1/chat/completions: 60 s elapsed, decode cache growth
[10:59:11] request A358D930 /v1/chat/completions: 75 s elapsed, decode cache growth
[10:59:16] request A358D930 /v1/chat/completions: ended after 79.5 s
[10:59:16] request 6C540441 /v1/chat/completions: accepted
[10:59:17] prefix cache disk: restored 33280 tokens (1035.9 MB) in 0.22 s
prefix cache: reusing 33280/34952 tokens from disk (memory offered 0)
[10:59:31] request 6C540441 /v1/chat/completions: 15 s elapsed, prefill pass
[10:59:33] prefill: reading 1672 prompt tokens, ~13 s to the first token at this plan (follow-up turns read only what is new)
[10:59:33] prefill: 512/1672 tokens (31%), 32 tok/s recently, ~36 s left at this rate
[10:59:46] request 6C540441 /v1/chat/completions: 30 s elapsed, prefill pass
[10:59:50] prefill: 1024/1672 tokens (61%), 30 tok/s recently, ~21 s left at this rate
[11:00:01] request 6C540441 /v1/chat/completions: 45 s elapsed, prefill pass
[11:00:05] prefix cache disk: saved 34816 tokens (158.3 MB written, 920.1 MB of rows reused) in 0.25 s, removed 1 older file
[11:00:05] prefill: 1536/1672 tokens (92%), 34 tok/s recently, ~4 s left at this rate
[11:00:15] prefill: done, 1672 tokens in 58 s (29 tok/s)
[11:00:16] request 6C540441 /v1/chat/completions: 60 s elapsed, decode cache growth
[11:00:31] request 6C540441 /v1/chat/completions: ended after 75.0 s
[11:02:16] request CB1D25C0 /v1/chat/completions: accepted
[11:02:17] prefix cache disk: restored 34816 tokens (1078.4 MB) in 0.23 s
prefix cache: reusing 34816/35334 tokens from disk (memory offered 0)
[11:02:30] prefix cache disk: saved 35328 tokens (130.0 MB written, 962.6 MB of rows reused) in 0.24 s, removed 1 older file
[11:02:30] prefill: reading 518 prompt tokens, ~4 s to the first token at this plan (follow-up turns read only what is new)
[11:02:30] prefill: 512/518 tokens (99%), 38 tok/s recently, ~0 s left at this rate
[11:02:31] request CB1D25C0 /v1/chat/completions: 15 s elapsed, prefill pass
[11:02:32] prefill: done, 518 tokens in 15 s (35 tok/s)
[11:02:46] request CB1D25C0 /v1/chat/completions: 30 s elapsed, decode cache growth
[11:02:49] request CB1D25C0 /v1/chat/completions: ended after 33.7 s
[11:02:49] request 968C3A94 /v1/chat/completions: accepted
[11:02:51] prefix cache disk: restored 35328 tokens (1092.5 MB) in 0.27 s
prefix cache: reusing 35328/36277 tokens from disk (memory offered 0)
[11:03:04] prefix cache disk: saved 35840 tokens (130.0 MB written, 976.7 MB of rows reused) in 0.24 s, removed 1 older file
[11:03:04] prefill: reading 949 prompt tokens, ~8 s to the first token at this plan (follow-up turns read only what is new)
[11:03:04] prefill: 512/949 tokens (54%), 40 tok/s recently, ~11 s left at this rate
[11:03:04] request 968C3A94 /v1/chat/completions: 15 s elapsed, prefill pass
[11:03:18] prefill: done, 949 tokens in 27 s (35 tok/s)
[11:03:19] request 968C3A94 /v1/chat/completions: 30 s elapsed, decode cache growth
[11:03:34] request 968C3A94 /v1/chat/completions: 45 s elapsed, decode cache growth
[11:03:38] request 968C3A94 /v1/chat/completions: ended after 49.2 s
[11:03:38] request FE6D07A9 /v1/chat/completions: accepted
[11:03:40] prefix cache disk: restored 35840 tokens (1106.7 MB) in 0.33 s
prefix cache: reusing 35840/36433 tokens from disk (memory offered 0)
[11:03:53] prefix cache disk: saved 36352 tokens (130.0 MB written, 990.9 MB of rows reused) in 0.25 s, removed 1 older file
[11:03:53] prefill: reading 593 prompt tokens, ~5 s to the first token at this plan (follow-up turns read only what is new)
[11:03:53] prefill: 512/593 tokens (86%), 39 tok/s recently, ~2 s left at this rate
[11:03:54] request FE6D07A9 /v1/chat/completions: 15 s elapsed, prefill pass
[11:04:00] prefill: done, 593 tokens in 20 s (29 tok/s)
[11:04:09] request FE6D07A9 /v1/chat/completions: 30 s elapsed, decode cache growth
[11:04:16] request FE6D07A9 /v1/chat/completions: ended after 37.4 s
[11:04:16] request 22E393EE /v1/chat/completions: accepted
[11:04:18] prefix cache disk: restored 36352 tokens (1120.8 MB) in 0.25 s
prefix cache: reusing 36352/36551 tokens from disk (memory offered 0)
[11:04:28] prefill: reading 199 prompt tokens, ~2 s to the first token at this plan (follow-up turns read only what is new)
[11:04:28] prefill: done, 199 tokens in 11 s (19 tok/s)
[11:04:31] request 22E393EE /v1/chat/completions: 15 s elapsed, decode cache growth
[11:04:37] request 22E393EE /v1/chat/completions: ended after 21.3 s
[11:04:37] request C703CB3E /v1/chat/completions: accepted
[11:04:39] prefix cache disk: restored 36352 tokens (1120.8 MB) in 0.26 s
prefix cache: reusing 36352/37577 tokens from disk (memory offered 0)
[11:04:52] request C703CB3E /v1/chat/completions: 15 s elapsed, prefill pass
[11:04:59] prefill: reading 1225 prompt tokens, ~10 s to the first token at this plan (follow-up turns read only what is new)
[11:04:59] prefill: 512/1225 tokens (42%), 25 tok/s recently, ~28 s left at this rate
[11:05:07] request C703CB3E /v1/chat/completions: 30 s elapsed, prefill pass
[11:05:14] prefix cache disk: saved 37376 tokens (144.2 MB written, 1005.1 MB of rows reused) in 0.34 s, removed 1 older file
[11:05:14] prefill: 1024/1225 tokens (84%), 35 tok/s recently, ~6 s left at this rate
[11:05:22] request C703CB3E /v1/chat/completions: 45 s elapsed, prefill pass
[11:05:25] prefill: done, 1225 tokens in 45 s (27 tok/s)
[11:05:37] request C703CB3E /v1/chat/completions: 60 s elapsed, decode cache growth
[11:05:41] request C703CB3E /v1/chat/completions: ended after 63.3 s
[11:05:41] request CC73310E /v1/chat/completions: accepted
[11:05:43] prefix cache disk: restored 37376 tokens (1149.2 MB) in 0.51 s
prefix cache: reusing 37376/38155 tokens from disk (memory offered 0)
[11:05:56] request CC73310E /v1/chat/completions: 15 s elapsed, prefill pass
[11:06:00] prefix cache disk: saved 37888 tokens (130.0 MB written, 1033.4 MB of rows reused) in 0.22 s, removed 1 older file
[11:06:00] prefill: reading 779 prompt tokens, ~6 s to the first token at this plan (follow-up turns read only what is new)
[11:06:00] prefill: 512/779 tokens (66%), 31 tok/s recently, ~9 s left at this rate
[11:06:11] request CC73310E /v1/chat/completions: 30 s elapsed, prefill pass
[11:06:13] prefill: done, 779 tokens in 30 s (26 tok/s)
[11:06:24] request CC73310E /v1/chat/completions: ended after 43.0 s
[11:06:24] request 171209CA /v1/chat/completions: accepted
[11:06:26] prefix cache disk: restored 37888 tokens (1163.3 MB) in 0.31 s
prefix cache: reusing 37888/38674 tokens from disk (memory offered 0)
[11:06:39] request 171209CA /v1/chat/completions: 15 s elapsed, prefill pass
[11:06:42] prefix cache disk: saved 38400 tokens (130.0 MB written, 1047.5 MB of rows reused) in 0.40 s, removed 1 older file
[11:06:42] prefill: reading 786 prompt tokens, ~6 s to the first token at this plan (follow-up turns read only what is new)
[11:06:42] prefill: 512/786 tokens (65%), 31 tok/s recently, ~9 s left at this rate
[11:06:54] request 171209CA /v1/chat/completions: 30 s elapsed, prefill pass
[11:06:56] prefill: done, 786 tokens in 30 s (26 tok/s)
[11:07:09] request 171209CA /v1/chat/completions: 45 s elapsed, decode cache growth
[11:07:17] request 171209CA /v1/chat/completions: ended after 52.9 s
[11:07:17] request 99967E0F /v1/chat/completions: accepted
[11:07:20] prefix cache disk: restored 38400 tokens (1177.5 MB) in 1.77 s
prefix cache: reusing 38400/39437 tokens from disk (memory offered 0)
[11:07:32] request 99967E0F /v1/chat/completions: 15 s elapsed, prefill pass
[11:07:39] prefill: reading 1037 prompt tokens, ~8 s to the first token at this plan (follow-up turns read only what is new)
[11:07:39] prefill: 512/1037 tokens (49%), 27 tok/s recently, ~20 s left at this rate
[11:07:47] request 99967E0F /v1/chat/completions: 30 s elapsed, prefill pass
[11:07:58] prefix cache disk: saved 39424 tokens (144.2 MB written, 1061.7 MB of rows reused) in 0.38 s, removed 1 older file
[11:07:58] prefill: 1024/1037 tokens (99%), 28 tok/s recently, ~0 s left at this rate
[11:08:01] prefill: done, 1037 tokens in 40 s (26 tok/s)
[11:08:02] request 99967E0F /v1/chat/completions: 45 s elapsed, decode cache growth
[11:08:17] request 99967E0F /v1/chat/completions: 60 s elapsed, decode cache growth
[11:08:23] request 99967E0F /v1/chat/completions: ended after 66.6 s
[11:08:23] request 700E627D /v1/chat/completions: accepted
[11:08:26] prefix cache disk: restored 39424 tokens (1205.8 MB) in 0.53 s
prefix cache: reusing 39424/40074 tokens from disk (memory offered 0)
[11:08:38] request 700E627D /v1/chat/completions: 15 s elapsed, prefill pass
[11:08:45] prefix cache disk: saved 39936 tokens (130.0 MB written, 1090.0 MB of rows reused) in 0.44 s, removed 1 older file
[11:08:45] prefill: reading 650 prompt tokens, ~5 s to the first token at this plan (follow-up turns read only what is new)
[11:08:45] prefill: 512/650 tokens (79%), 27 tok/s recently, ~5 s left at this rate
[11:08:53] request 700E627D /v1/chat/completions: 30 s elapsed, prefill pass
[11:08:56] prefill: done, 650 tokens in 30 s (22 tok/s)
[11:09:08] request 700E627D /v1/chat/completions: 45 s elapsed, decode cache growth
[11:09:23] request 700E627D /v1/chat/completions: 60 s elapsed, decode cache growth
[11:09:33] request 700E627D /v1/chat/completions: ended after 69.3 s
[11:09:33] request C63C780B /v1/chat/completions: accepted
[11:09:35] prefix cache disk: restored 39936 tokens (1220.0 MB) in 0.31 s
prefix cache: reusing 39936/40283 tokens from disk (memory offered 0)
[11:09:48] request C63C780B /v1/chat/completions: 15 s elapsed, prefill pass
[11:09:53] prefill: reading 347 prompt tokens, ~3 s to the first token at this plan (follow-up turns read only what is new)
[11:09:53] prefill: done, 347 tokens in 18 s (20 tok/s)
[11:10:03] request C63C780B /v1/chat/completions: 30 s elapsed, decode cache growth
[11:10:06] request C63C780B /v1/chat/completions: ended after 33.3 s
[11:10:06] request 650A2528 /v1/chat/completions: accepted
[11:10:09] prefix cache disk: restored 39936 tokens (1220.0 MB) in 0.32 s
prefix cache: reusing 39936/40626 tokens from disk (memory offered 0)
[11:10:21] request 650A2528 /v1/chat/completions: 15 s elapsed, prefill pass
[11:10:29] prefix cache disk: saved 40448 tokens (130.0 MB written, 1104.2 MB of rows reused) in 0.46 s, removed 1 older file
[11:10:29] prefill: reading 690 prompt tokens, ~6 s to the first token at this plan (follow-up turns read only what is new)
[11:10:29] prefill: 512/690 tokens (74%), 26 tok/s recently, ~7 s left at this rate
[11:10:36] request 650A2528 /v1/chat/completions: 30 s elapsed, prefill pass
[11:10:40] prefill: done, 690 tokens in 31 s (22 tok/s)
[11:10:51] request 650A2528 /v1/chat/completions: 45 s elapsed, decode cache growth
[11:11:06] request 650A2528 /v1/chat/completions: 60 s elapsed, decode cache growth
[11:11:09] request 650A2528 /v1/chat/completions: ended after 63.3 s
[11:11:09] request 634E37A8 /v1/chat/completions: accepted
[11:11:14] prefix cache disk: restored 40448 tokens (1234.1 MB) in 1.82 s
prefix cache: reusing 40448/41206 tokens from disk (memory offered 0)
[11:11:24] request 634E37A8 /v1/chat/completions: 15 s elapsed, prefill pass
[11:11:33] prefix cache disk: saved 40960 tokens (130.0 MB written, 1118.3 MB of rows reused) in 0.22 s, removed 1 older file
[11:11:33] prefill: reading 758 prompt tokens, ~6 s to the first token at this plan (follow-up turns read only what is new)
[11:11:33] prefill: 512/758 tokens (68%), 27 tok/s recently, ~9 s left at this rate
[11:11:39] request 634E37A8 /v1/chat/completions: 30 s elapsed, prefill pass
[11:11:47] prefill: done, 758 tokens in 33 s (23 tok/s)
[11:11:54] request 634E37A8 /v1/chat/completions: 45 s elapsed, decode cache growth
[11:12:06] request 634E37A8 /v1/chat/completions: ended after 56.8 s
[11:12:06] request 519D9C8E /v1/chat/completions: accepted
[11:12:09] prefix cache disk: restored 40960 tokens (1248.3 MB) in 0.51 s
prefix cache: reusing 40960/41413 tokens from disk (memory offered 0)
[11:12:21] request 519D9C8E /v1/chat/completions: 15 s elapsed, prefill pass
[11:12:31] prefill: reading 453 prompt tokens, ~4 s to the first token at this plan (follow-up turns read only what is new)
[11:12:31] prefill: done, 453 tokens in 22 s (21 tok/s)
[11:12:36] request 519D9C8E /v1/chat/completions: 30 s elapsed, decode cache growth
[11:12:51] request 519D9C8E /v1/chat/completions: 45 s elapsed, decode cache growth
[11:12:52] request 519D9C8E /v1/chat/completions: ended after 45.9 s
[11:12:52] request B55D1238 /v1/chat/completions: accepted
[11:12:55] prefix cache disk: restored 40960 tokens (1248.3 MB) in 0.31 s
prefix cache: reusing 40960/41544 tokens from disk (memory offered 0)
[11:13:07] request B55D1238 /v1/chat/completions: 15 s elapsed, prefill pass
[11:13:16] prefix cache disk: saved 41472 tokens (130.0 MB written, 1132.5 MB of rows reused) in 0.27 s, removed 1 older file
[11:13:16] prefill: reading 584 prompt tokens, ~5 s to the first token at this plan (follow-up turns read only what is new)
[11:13:16] prefill: 512/584 tokens (88%), 25 tok/s recently, ~3 s left at this rate
[11:13:22] request B55D1238 /v1/chat/completions: 30 s elapsed, prefill pass
[11:13:23] prefill: done, 584 tokens in 28 s (21 tok/s)
[11:13:33] request B55D1238 /v1/chat/completions: ended after 41.1 s
[11:13:33] request 269A903F /v1/chat/completions: accepted
[11:13:38] prefix cache disk: restored 41472 tokens (1262.4 MB) in 1.55 s
prefix cache: reusing 41472/41643 tokens from disk (memory offered 0)
[11:13:48] request 269A903F /v1/chat/completions: 15 s elapsed, prefill pass
[11:13:49] prefill: reading 171 prompt tokens, ~1 s to the first token at this plan (follow-up turns read only what is new)
[11:13:49] prefill: done, 171 tokens in 12 s (15 tok/s)
[11:14:03] request 269A903F /v1/chat/completions: 30 s elapsed, decode cache growth
[11:14:04] request 269A903F /v1/chat/completions: ended after 31.1 s
[11:14:04] request 2137CC87 /v1/chat/completions: accepted
[11:14:08] prefix cache disk: restored 41472 tokens (1262.4 MB) in 0.21 s
prefix cache: reusing 41472/41735 tokens from disk (memory offered 0)
[11:14:19] request 2137CC87 /v1/chat/completions: 15 s elapsed, prefill pass
[11:14:21] prefill: reading 263 prompt tokens, ~2 s to the first token at this plan (follow-up turns read only what is new)
[11:14:21] prefill: done, 263 tokens in 13 s (20 tok/s)
[11:14:34] request 2137CC87 /v1/chat/completions: 30 s elapsed, decode cache growth
[11:14:34] request 2137CC87 /v1/chat/completions: ended after 30.0 s
[11:14:34] request DFBEEA77 /v1/chat/completions: accepted
[11:14:38] prefix cache disk: restored 41472 tokens (1262.4 MB) in 0.27 s
prefix cache: reusing 41472/41829 tokens from disk (memory offered 0)
[11:14:50] request DFBEEA77 /v1/chat/completions: 15 s elapsed, prefill pass
[11:14:54] prefill: reading 357 prompt tokens, ~3 s to the first token at this plan (follow-up turns read only what is new)
[11:14:54] prefill: done, 357 tokens in 16 s (22 tok/s)
[11:14:57] request DFBEEA77 /v1/chat/completions: ended after 22.4 s, client_cancelled: the client disconnected during inference boundary [phase inference boundary]
elastic: memory freed — cache ~62 → ~78 experts/layer (8.2 → 10.3 GB pool, contents kept)
```
