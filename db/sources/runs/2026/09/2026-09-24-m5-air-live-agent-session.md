---
type: run
id: 01m3a462pr4cty5nsh2hy8nh4m
created: 2026-09-24T16:32:38.616677+00:00
updated: 2026-09-24T16:32:52.888737+00:00
summary: 'A live 0.2.23 agent session on the 32 GB MacBook Air: two requests refused for memory, one after a 333 s prefill, and the prefix cache answering from disk for 18 of 23 reusable prefixes'
binary: slotstream 0.2.23 (tag v0.2.23); binary_sha256 5cb612361887c2a317376721dbe5df94810da5230759c47169fc6fa2e9b30b89; source_archive_sha256 cc03e14655154bc6a6205249eb5e302d2fcad19820e9dcdcbb44d62021b3ed38
captured_at: 2026-09-24
command: slotstream serve (auto memory plan, no memory flag); repeated /v1/chat/completions turns over about 52 minutes
discarded: 'true'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
title: 'A live agent session on the 32 GB Air: memory refusals and a prefix cache that falls back to disk'
tool: slotstream serve 0.2.23 (installed release binary) driven by the user's agent client
---
A live agent session against the installed **0.2.23** release on the 32 GB MacBook
Air, captured from the server's own `serve.log` — the only record a user has after
a run. About 52 minutes of ordinary agent traffic: two long prompts read cold, then
a growing conversation of follow-up turns.

**Why this is discarded.** The machine was in ordinary use and the session swapped:
`vm.swapusage` still reported 5.5 GB of 7 GB used afterwards, and the elastic
governor logged two `memory pressure (warning)` events during it. No timing here is
a measurement and none is treated as one. What the capture is kept for is
structural: which requests failed, how they failed, and where the prefix cache
answered from.

**The two failures.** `insufficient_memory` ended two requests in this session: one
0.6 s after a memory prefix hit, and one after 333.4 s with its prefill 87 % read.
Both printed only the code. That is why `RequestFailure.diagnosticDetail` now
carries the reason, the failing phase and the refusal quantities into the same line,
and why the `failure-diagnostics` T0 check exists.

**Where the prefix cache answered from.** 3 of 23 reusable prefixes came from
memory and 18 from disk, and the switch to disk begins immediately after the
request that failed during preparation. `PrefixCache.takeForGeneration` hands a
non-reusable entry out with `entries.remove(at: i)`, and `mayRetainState` is false
once a request has failed — so a request that dies during preparation consumes the
retained conversation state and never returns it. Whether that alone explains the
following 18 turns on disk, or the retention ceiling and `reserveForRestore` kept
it there, is **not** established by this capture. `PrefixCache.retainedMatchLength`
is now printed on the disk path (`memory offered N`) to settle it.

**Provenance.** The binary that produced this is the installed release 0.2.23, not
the working tree. Each source file's SHA-256 in
`~/.slotstream/bin/build-identity.json` was compared against `git show HEAD:<path>`:
of six sampled files, four matched HEAD byte-for-byte and `PrefixCache.swift` and
`Version.swift` differed, which pins the session to the `v0.2.23` tag. Over the
prefix-cache path, `git diff v0.2.23..HEAD` touches only
`PrefixCache.peek(extending:)` — the transcript-splicing path — and leaves
`takeForGeneration`, `store`, `storeCheckpoint`, `reserveActiveTokens`,
`reserveForRestore`, `retainedMatchLength` and `bestEntry` unchanged, so the
reading above applies to the version that ran.

The plan the server printed for this session, and the raw `serve.log` verbatim:

```text
slotstream memory plan (auto)
  device: 34 GB RAM (23.4 GB reclaimable now), 26.8 GB Metal working set
  target: 21.7 GB total process budget, not a RAM usage goal   (adaptive limit: --memory-limit-gb N; fixed cache: --memory-gb N)
  limit:  22.0 GB; cache adapts to available memory
  cache:  ~76 of 512 experts per layer  (3639 global slots = 10.1 GB pool)
  plan:   ~20.7 GB full-workload envelope, ~9 tok/s warm decode (est. from M5 Pro anchors)
  memory: 10.1 GB expert cache at load; 10.6 GB allowed for runtime, context and workspace; 1.0 GB budget headroom. Short requests can use less.
  disk:   that estimate assumes an SSD like the one it was measured on (17.3 GB/s). A base-storage Mac mini M2 reads 1.5 GB/s and decoded at 1.41 tok/s against a ~4 estimate, so on base storage expect well under the number above — see docs/HARDWARE.md
  prefill: 1024 tokens per pass (~165 tok/s here; costs ~1.3 GB of the target)
  vision: images accepted — first image reserves +0.9 GB inside the target; refused if it cannot fit
  context: up to 65536 tokens per request (prompt + reply, +1.8 GB state and transient reserve charged above); a full-length prompt takes ~7.8 min before its first token here, follow-up turns read only what is new
  reuse:  up to 65536 tokens across 4 conversations (~2.2 GB), so a follow-up turn re-prefills only what is new
  note:   using up to 21.7 GB now; the cache can grow back toward 22.0 GB when memory is available
engine ready in 1.3s: expert cache ~76/512 per layer (3639 global slots = 10.1 GB), eos [248044, 248046]
prefix cache disk: /Users/jasen/.slotstream/prefix-cache holds 6 states (2.84 GB of 16.00 GB); writes states of 1024 tokens or more; forgets states unused for 30 days
elastic: on — cache auto-resizes with memory availability between requests (--no-elastic to pin)
slotstream listening on http://127.0.0.1:11434
try it:
  curl localhost:11434/api/chat -d '{"model": "qwen3.8-flash-next:4bit", "messages": [{"role": "user", "content": "hello"}]}'
or point any Ollama or OpenAI client at http://localhost:11434
[22:01:42] request 1AFDCC96 /v1/chat/completions: accepted
prefix cache: miss: no retained state (0 prior evictions)
[22:01:42] prefill: reading 25285 prompt tokens, ~2.6 min to the first token at this plan (follow-up turns read only what is new)
[22:01:57] request 1AFDCC96 /v1/chat/completions: 15 s elapsed, inference boundary
[22:02:12] request 1AFDCC96 /v1/chat/completions: 30 s elapsed, inference boundary
[22:02:15] prefill: 4096/25285 tokens (16%), 125 tok/s recently, ~2.8 min left at this rate
[22:02:27] request 1AFDCC96 /v1/chat/completions: 45 s elapsed, inference boundary
[22:02:42] request 1AFDCC96 /v1/chat/completions: 60 s elapsed, inference boundary
[22:02:57] request 1AFDCC96 /v1/chat/completions: 75 s elapsed, inference boundary
[22:02:59] prefill: 8192/25285 tokens (32%), 94 tok/s recently, ~3.0 min left at this rate
[22:03:12] request 1AFDCC96 /v1/chat/completions: 90 s elapsed, inference boundary
[22:03:27] request 1AFDCC96 /v1/chat/completions: 105 s elapsed, inference boundary
[22:03:42] request 1AFDCC96 /v1/chat/completions: 120 s elapsed, inference boundary
[22:03:57] request 1AFDCC96 /v1/chat/completions: 135 s elapsed, inference boundary
[22:03:58] prefill: 12288/25285 tokens (49%), 69 tok/s recently, ~3.1 min left at this rate
[22:04:12] request 1AFDCC96 /v1/chat/completions: 150 s elapsed, inference boundary
[22:04:27] request 1AFDCC96 /v1/chat/completions: 165 s elapsed, inference boundary
[22:04:42] request 1AFDCC96 /v1/chat/completions: 180 s elapsed, inference boundary
[22:04:56] prefill: 16384/25285 tokens (65%), 70 tok/s recently, ~2.1 min left at this rate
[22:04:57] request 1AFDCC96 /v1/chat/completions: 195 s elapsed, prefill pass
[22:05:12] request 1AFDCC96 /v1/chat/completions: 210 s elapsed, prefill pass
[22:05:24] prefill: 17408/25285 tokens (69%), 37 tok/s recently, ~3.5 min left at this rate
[22:05:27] request 1AFDCC96 /v1/chat/completions: 225 s elapsed, prefill pass
[22:05:42] request 1AFDCC96 /v1/chat/completions: 240 s elapsed, prefill pass
[22:05:51] prefill: 18432/25285 tokens (73%), 38 tok/s recently, ~3.0 min left at this rate
[22:05:57] request 1AFDCC96 /v1/chat/completions: 255 s elapsed, prefill pass
[22:06:12] request 1AFDCC96 /v1/chat/completions: 270 s elapsed, prefill pass
[22:06:19] prefill: 19456/25285 tokens (77%), 36 tok/s recently, ~2.7 min left at this rate
[22:06:27] request 1AFDCC96 /v1/chat/completions: 285 s elapsed, prefill pass
[22:06:42] request 1AFDCC96 /v1/chat/completions: 300 s elapsed, prefill pass
[22:06:48] prefill: 20480/25285 tokens (81%), 36 tok/s recently, ~2.2 min left at this rate
[22:06:57] request 1AFDCC96 /v1/chat/completions: 315 s elapsed, prefill pass
[22:07:12] request 1AFDCC96 /v1/chat/completions: 330 s elapsed, prefill pass
[22:07:18] prefill: 21504/25285 tokens (85%), 34 tok/s recently, ~1.9 min left at this rate
[22:07:27] request 1AFDCC96 /v1/chat/completions: 345 s elapsed, prefill pass
[22:07:42] request 1AFDCC96 /v1/chat/completions: 360 s elapsed, prefill pass
[22:07:47] prefill: 22528/25285 tokens (89%), 36 tok/s recently, ~1.3 min left at this rate
[22:07:57] request 1AFDCC96 /v1/chat/completions: 375 s elapsed, prefill pass
[22:08:12] request 1AFDCC96 /v1/chat/completions: 390 s elapsed, prefill pass
[22:08:14] prefill: 23552/25285 tokens (93%), 38 tok/s recently, ~45 s left at this rate
[22:08:27] request 1AFDCC96 /v1/chat/completions: 405 s elapsed, prefill pass
[22:08:39] prefix cache disk: saved 24576 tokens (795.2 MB written) in 0.89 s
[22:08:39] prefill: 24576/25285 tokens (97%), 40 tok/s recently, ~18 s left at this rate
[22:08:42] request 1AFDCC96 /v1/chat/completions: 420 s elapsed, prefill pass
[22:08:57] request 1AFDCC96 /v1/chat/completions: 435 s elapsed, prefill pass
[22:09:11] prefill: done, 25285 tokens in 7.5 min (56 tok/s)
[22:09:12] request 1AFDCC96 /v1/chat/completions: 450 s elapsed, decode cache growth
[22:09:17] request 1AFDCC96 /v1/chat/completions: ended after 455.2 s
elastic: memory freed — cache ~76 → ~78 experts/layer (10.1 → 10.4 GB pool, contents kept)
[22:22:02] request F69C2F43 /v1/chat/completions: accepted
[22:22:03] prefix cache disk: restored 24576 tokens (795.2 MB) in 0.64 s
prefix cache: reusing 24576/25704 tokens from disk
[22:22:16] prefix cache disk: saved 25600 tokens (144.1 MB written, 679.5 MB of rows reused) in 0.17 s
[22:22:16] prefill: reading 1128 prompt tokens, ~7 s to the first token at this plan (follow-up turns read only what is new)
[22:22:16] prefill: 1024/1128 tokens (91%), 78 tok/s recently, ~1 s left at this rate
[22:22:17] request F69C2F43 /v1/chat/completions: 15 s elapsed, prefill pass
[22:22:22] prefill: done, 1128 tokens in 20 s (57 tok/s)
[22:22:27] request F69C2F43 /v1/chat/completions: ended after 25.2 s
[22:22:27] request DD1F28EE /v1/chat/completions: accepted
prefix cache: reusing 25600/26951 tokens from memory
[22:22:42] prefix cache disk: saved 26624 tokens (144.1 MB written, 707.8 MB of rows reused) in 0.17 s, removed 1 older file
[22:22:42] prefill: reading 1351 prompt tokens, ~8 s to the first token at this plan (follow-up turns read only what is new)
[22:22:42] prefill: 1024/1351 tokens (76%), 71 tok/s recently, ~5 s left at this rate
[22:22:42] request DD1F28EE /v1/chat/completions: 15 s elapsed, prefill pass
[22:22:54] prefill: done, 1351 tokens in 26 s (51 tok/s)
[22:22:57] request DD1F28EE /v1/chat/completions: 30 s elapsed, decode cache growth
[22:23:08] request DD1F28EE /v1/chat/completions: ended after 41.3 s
[22:23:08] request 484C09F9 /v1/chat/completions: accepted
prefix cache: reusing 26624/28150 tokens from memory
[22:23:09] request 484C09F9 /v1/chat/completions: ended after 0.6 s, insufficient_memory
[22:23:09] request 0C2730EB /v1/chat/completions: accepted
[22:23:10] prefix cache disk: restored 26624 tokens (851.8 MB) in 0.16 s
prefix cache: reusing 26624/28150 tokens from disk
[22:23:24] request 0C2730EB /v1/chat/completions: 15 s elapsed, prefill pass
[22:23:25] prefix cache disk: saved 27648 tokens (144.1 MB written, 736.1 MB of rows reused) in 0.20 s, removed 1 older file
[22:23:25] prefill: reading 1526 prompt tokens, ~9 s to the first token at this plan (follow-up turns read only what is new)
[22:23:25] prefill: 1024/1526 tokens (67%), 70 tok/s recently, ~7 s left at this rate
[22:23:39] prefill: done, 1526 tokens in 29 s (53 tok/s)
[22:23:39] request 0C2730EB /v1/chat/completions: 30 s elapsed, decode cache growth
[22:23:53] request 0C2730EB /v1/chat/completions: ended after 43.3 s
[22:23:53] request 8063DF3F /v1/chat/completions: accepted
prefix cache: reusing 27648/28899 tokens from memory
[22:24:08] request 8063DF3F /v1/chat/completions: 15 s elapsed, prefill pass
[22:24:09] prefix cache disk: saved 28672 tokens (144.1 MB written, 764.4 MB of rows reused) in 0.19 s, removed 1 older file
[22:24:09] prefill: reading 1251 prompt tokens, ~8 s to the first token at this plan (follow-up turns read only what is new)
[22:24:09] prefill: 1024/1251 tokens (82%), 67 tok/s recently, ~3 s left at this rate
[22:24:19] prefill: done, 1251 tokens in 26 s (48 tok/s)
[22:24:23] request 8063DF3F /v1/chat/completions: 30 s elapsed, decode cache growth
[22:24:31] request 8063DF3F /v1/chat/completions: ended after 37.7 s
[22:24:31] request 2915E172 /v1/chat/completions: accepted
[22:24:34] prefix cache disk: restored 28672 tokens (908.5 MB) in 2.46 s
prefix cache: reusing 28672/29560 tokens from disk
[22:24:46] request 2915E172 /v1/chat/completions: 15 s elapsed, prefill pass
[22:24:59] prefill: reading 888 prompt tokens, ~5 s to the first token at this plan (follow-up turns read only what is new)
[22:24:59] prefill: done, 888 tokens in 25 s (35 tok/s)
[22:25:01] request 2915E172 /v1/chat/completions: 30 s elapsed, decode cache growth
[22:25:11] request 2915E172 /v1/chat/completions: ended after 40.5 s
[22:25:11] request 3AF57D50 /v1/chat/completions: accepted
[22:25:13] prefix cache disk: restored 28672 tokens (908.5 MB) in 0.26 s
prefix cache: reusing 28672/30737 tokens from disk
[22:25:13] prefill: reading 2065 prompt tokens, ~13 s to the first token at this plan (follow-up turns read only what is new)
[22:25:26] request 3AF57D50 /v1/chat/completions: 15 s elapsed, prefill pass
[22:25:33] prefill: 1024/2065 tokens (50%), 51 tok/s recently, ~20 s left at this rate
[22:25:41] request 3AF57D50 /v1/chat/completions: 30 s elapsed, prefill pass
[22:25:52] prefix cache disk: saved 30720 tokens (172.4 MB written, 792.7 MB of rows reused) in 0.33 s, removed 1 older file
[22:25:52] prefill: 2048/2065 tokens (99%), 53 tok/s recently, ~0 s left at this rate
[22:25:55] prefill: done, 2065 tokens in 43 s (49 tok/s)
[22:25:56] request 3AF57D50 /v1/chat/completions: 45 s elapsed, decode cache growth
[22:26:07] request 3AF57D50 /v1/chat/completions: ended after 56.0 s
[22:26:07] request ADCDEB6D /v1/chat/completions: accepted
[22:26:11] prefix cache disk: restored 30720 tokens (965.1 MB) in 2.69 s
prefix cache: reusing 30720/31810 tokens from disk
[22:26:22] request ADCDEB6D /v1/chat/completions: 15 s elapsed, prefill pass
[22:26:32] prefix cache disk: saved 31744 tokens (144.1 MB written, 849.3 MB of rows reused) in 0.27 s, removed 1 older file
[22:26:32] prefill: reading 1090 prompt tokens, ~7 s to the first token at this plan (follow-up turns read only what is new)
[22:26:32] prefill: 1024/1090 tokens (94%), 50 tok/s recently, ~1 s left at this rate
[22:26:37] request ADCDEB6D /v1/chat/completions: 30 s elapsed, prefill pass
[22:26:38] prefill: done, 1090 tokens in 27 s (40 tok/s)
[22:26:51] request ADCDEB6D /v1/chat/completions: ended after 43.7 s
[22:26:51] request 1AEB9362 /v1/chat/completions: accepted
[22:26:53] prefix cache disk: restored 31744 tokens (993.4 MB) in 0.78 s
prefix cache: reusing 31744/32615 tokens from disk
[22:27:06] request 1AEB9362 /v1/chat/completions: 15 s elapsed, prefill pass
[22:27:15] prefix cache disk: saved 32256 tokens (130.0 MB written, 877.7 MB of rows reused) in 0.34 s, removed 1 older file
[22:27:15] prefill: reading 871 prompt tokens, ~7 s to the first token at this plan (follow-up turns read only what is new)
[22:27:15] prefill: 512/871 tokens (59%), 23 tok/s recently, ~15 s left at this rate
[22:27:21] request 1AEB9362 /v1/chat/completions: 30 s elapsed, prefill pass
[22:27:36] request 1AEB9362 /v1/chat/completions: 45 s elapsed, prefill pass
[22:27:36] prefill: done, 871 tokens in 43 s (20 tok/s)
[22:27:51] request 1AEB9362 /v1/chat/completions: 60 s elapsed, decode cache growth
[22:28:02] request 1AEB9362 /v1/chat/completions: ended after 71.2 s
[22:28:02] request 912B7985 /v1/chat/completions: accepted
[22:28:04] prefix cache disk: restored 32256 tokens (1007.6 MB) in 0.25 s
prefix cache: reusing 32256/32768 tokens from disk
[22:28:17] request 912B7985 /v1/chat/completions: 15 s elapsed, prefill pass
[22:28:27] prefill: reading 512 prompt tokens, ~4 s to the first token at this plan (follow-up turns read only what is new)
[22:28:27] prefill: done, 512 tokens in 23 s (23 tok/s)
[22:28:32] request 912B7985 /v1/chat/completions: 30 s elapsed, decode cache growth
[22:28:44] request 912B7985 /v1/chat/completions: ended after 41.9 s
elastic: memory pressure (warning) — cache ~78 → ~63 experts/layer (10.4 → 8.4 GB pool, cold — refills from SSD)
elastic: memory freed — cache ~63 → ~78 experts/layer (8.4 → 10.4 GB pool, contents kept)
[22:34:46] request 7E2C3B23 /v1/chat/completions: accepted
[22:34:47] prefix cache disk: restored 32256 tokens (1007.6 MB) in 0.18 s
prefix cache: reusing 32256/32944 tokens from disk
[22:35:01] request 7E2C3B23 /v1/chat/completions: 15 s elapsed, prefill pass
[22:35:02] prefix cache disk: saved 32768 tokens (130.0 MB written, 891.8 MB of rows reused) in 0.21 s, removed 1 older file
[22:35:02] prefill: reading 688 prompt tokens, ~6 s to the first token at this plan (follow-up turns read only what is new)
[22:35:02] prefill: 512/688 tokens (74%), 35 tok/s recently, ~5 s left at this rate
[22:35:12] prefill: done, 688 tokens in 25 s (28 tok/s)
[22:35:16] request 7E2C3B23 /v1/chat/completions: 30 s elapsed, decode cache growth
[22:35:31] request 7E2C3B23 /v1/chat/completions: 45 s elapsed, inference boundary
[22:35:39] request 7E2C3B23 /v1/chat/completions: ended after 53.6 s
[22:35:39] request B794A616 /v1/chat/completions: accepted
[22:35:41] prefix cache disk: restored 32768 tokens (1021.7 MB) in 0.31 s
prefix cache: reusing 32768/33276 tokens from disk
[22:35:55] request B794A616 /v1/chat/completions: 15 s elapsed, prefill pass
[22:35:55] prefill: reading 508 prompt tokens, ~4 s to the first token at this plan (follow-up turns read only what is new)
[22:35:55] prefill: done, 508 tokens in 14 s (36 tok/s)
[22:36:04] request B794A616 /v1/chat/completions: ended after 24.1 s
[22:36:04] request 0100EE8E /v1/chat/completions: accepted
[22:36:06] prefix cache disk: restored 32768 tokens (1021.7 MB) in 0.23 s
prefix cache: reusing 32768/33396 tokens from disk
[22:36:18] prefix cache disk: saved 33280 tokens (130.0 MB written, 906.0 MB of rows reused) in 0.24 s, removed 1 older file
[22:36:18] prefill: reading 628 prompt tokens, ~5 s to the first token at this plan (follow-up turns read only what is new)
[22:36:18] prefill: 512/628 tokens (82%), 41 tok/s recently, ~3 s left at this rate
[22:36:19] request 0100EE8E /v1/chat/completions: 15 s elapsed, prefill pass
[22:36:25] prefill: done, 628 tokens in 20 s (32 tok/s)
[22:36:34] request 0100EE8E /v1/chat/completions: 30 s elapsed, inference boundary
[22:36:37] request 0100EE8E /v1/chat/completions: ended after 32.9 s
[22:36:37] request DA3A32D1 /v1/chat/completions: accepted
[22:36:38] prefix cache disk: restored 33280 tokens (1035.9 MB) in 0.24 s
prefix cache: reusing 33280/33550 tokens from disk
[22:36:48] prefill: reading 270 prompt tokens, ~2 s to the first token at this plan (follow-up turns read only what is new)
[22:36:48] prefill: done, 270 tokens in 9 s (29 tok/s)
[22:36:52] request DA3A32D1 /v1/chat/completions: 15 s elapsed, decode cache growth
[22:37:07] request DA3A32D1 /v1/chat/completions: 30 s elapsed, decode cache growth
[22:37:11] request DA3A32D1 /v1/chat/completions: ended after 34.0 s
[22:37:11] request 76F1B399 /v1/chat/completions: accepted
[22:37:13] prefix cache disk: restored 33280 tokens (1035.9 MB) in 0.22 s
prefix cache: reusing 33280/33783 tokens from disk
[22:37:26] request 76F1B399 /v1/chat/completions: 15 s elapsed, prefill pass
[22:37:34] prefill: reading 503 prompt tokens, ~4 s to the first token at this plan (follow-up turns read only what is new)
[22:37:34] prefill: done, 503 tokens in 21 s (24 tok/s)
[22:37:41] request 76F1B399 /v1/chat/completions: 30 s elapsed, decode cache growth
[22:37:51] request 76F1B399 /v1/chat/completions: ended after 40.4 s
[22:37:51] request AF1D749E /v1/chat/completions: accepted
[22:37:55] prefix cache disk: restored 33280 tokens (1035.9 MB) in 0.68 s
prefix cache: reusing 33280/34769 tokens from disk
[22:38:06] request AF1D749E /v1/chat/completions: 15 s elapsed, prefill pass
[22:38:15] prefill: reading 1489 prompt tokens, ~12 s to the first token at this plan (follow-up turns read only what is new)
[22:38:15] prefill: 512/1489 tokens (34%), 25 tok/s recently, ~39 s left at this rate
[22:38:21] request AF1D749E /v1/chat/completions: 30 s elapsed, prefill pass
[22:38:36] prefix cache disk: saved 34304 tokens (144.1 MB written, 920.1 MB of rows reused) in 0.41 s, removed 1 older file
[22:38:36] prefill: 1024/1489 tokens (69%), 25 tok/s recently, ~18 s left at this rate
[22:38:36] request AF1D749E /v1/chat/completions: 45 s elapsed, prefill pass
[22:38:51] request AF1D749E /v1/chat/completions: 60 s elapsed, prefill pass
[22:38:57] prefill: done, 1489 tokens in 1.0 min (24 tok/s)
[22:39:06] request AF1D749E /v1/chat/completions: 75 s elapsed, decode cache growth
[22:39:13] request AF1D749E /v1/chat/completions: ended after 82.2 s
[22:39:13] request 19239423 /v1/chat/completions: accepted
[22:39:17] prefix cache disk: restored 34304 tokens (1064.2 MB) in 0.67 s
prefix cache: reusing 34304/34863 tokens from disk
[22:39:28] request 19239423 /v1/chat/completions: 15 s elapsed, prefill pass
[22:39:37] prefix cache disk: saved 34816 tokens (130.0 MB written, 948.4 MB of rows reused) in 0.38 s, removed 1 older file
[22:39:37] prefill: reading 559 prompt tokens, ~4 s to the first token at this plan (follow-up turns read only what is new)
[22:39:37] prefill: 512/559 tokens (92%), 25 tok/s recently, ~2 s left at this rate
[22:39:43] request 19239423 /v1/chat/completions: 30 s elapsed, prefill pass
[22:39:45] prefill: done, 559 tokens in 28 s (20 tok/s)
[22:39:58] request 19239423 /v1/chat/completions: 45 s elapsed, decode cache growth
[22:40:02] request 19239423 /v1/chat/completions: ended after 48.9 s
[22:40:02] request 092EBE81 /v1/chat/completions: accepted
[22:40:05] prefix cache disk: restored 34816 tokens (1078.4 MB) in 0.33 s
prefix cache: reusing 34816/34965 tokens from disk
[22:40:17] request 092EBE81 /v1/chat/completions: 15 s elapsed, prefill pass
[22:40:18] prefill: reading 149 prompt tokens, ~1 s to the first token at this plan (follow-up turns read only what is new)
[22:40:18] prefill: done, 149 tokens in 13 s (12 tok/s)
[22:40:30] request 092EBE81 /v1/chat/completions: ended after 28.2 s
[22:40:30] request A964EC44 /v1/chat/completions: accepted
[22:40:34] prefix cache disk: restored 34816 tokens (1078.4 MB) in 0.91 s
prefix cache: reusing 34816/35036 tokens from disk
[22:40:45] request A964EC44 /v1/chat/completions: 15 s elapsed, prefill pass
[22:40:51] prefill: reading 220 prompt tokens, ~2 s to the first token at this plan (follow-up turns read only what is new)
[22:40:51] prefill: done, 220 tokens in 16 s (14 tok/s)
[22:41:00] request A964EC44 /v1/chat/completions: 30 s elapsed, decode cache growth
[22:41:12] request A964EC44 /v1/chat/completions: ended after 41.4 s
[22:41:12] request F398F405 /v1/chat/completions: accepted
[22:41:15] prefix cache disk: restored 34816 tokens (1078.4 MB) in 0.14 s
prefix cache: reusing 34816/35213 tokens from disk
[22:41:27] request F398F405 /v1/chat/completions: 15 s elapsed, prefill pass
[22:41:32] prefill: reading 397 prompt tokens, ~3 s to the first token at this plan (follow-up turns read only what is new)
[22:41:32] prefill: done, 397 tokens in 18 s (23 tok/s)
[22:41:42] request F398F405 /v1/chat/completions: 30 s elapsed, decode cache growth
[22:41:43] request F398F405 /v1/chat/completions: ended after 31.2 s
[22:41:43] request FA5C0EC1 /v1/chat/completions: accepted
[22:41:47] prefix cache disk: restored 34816 tokens (1078.4 MB) in 0.28 s
prefix cache: reusing 34816/35278 tokens from disk
[22:41:58] request FA5C0EC1 /v1/chat/completions: 15 s elapsed, prefill pass
[22:42:06] request FA5C0EC1 /v1/chat/completions: ended after 22.9 s, client_cancelled
[22:47:39] request CCCD5FB0 /v1/chat/completions: accepted
prefix cache: miss: no retained state (25 prior evictions)
[22:47:39] prefill: reading 25796 prompt tokens, ~2.6 min to the first token at this plan (follow-up turns read only what is new)
[22:47:54] request CCCD5FB0 /v1/chat/completions: 15 s elapsed, inference boundary
[22:48:09] request CCCD5FB0 /v1/chat/completions: 30 s elapsed, inference boundary
[22:48:12] prefill: 4096/25796 tokens (16%), 126 tok/s recently, ~2.9 min left at this rate
[22:48:24] request CCCD5FB0 /v1/chat/completions: 45 s elapsed, inference boundary
[22:48:39] request CCCD5FB0 /v1/chat/completions: 60 s elapsed, inference boundary
[22:48:43] prefill: 8192/25796 tokens (32%), 132 tok/s recently, ~2.2 min left at this rate
[22:48:54] request CCCD5FB0 /v1/chat/completions: 75 s elapsed, inference boundary
[22:49:09] request CCCD5FB0 /v1/chat/completions: 90 s elapsed, inference boundary
[22:49:16] prefill: 12288/25796 tokens (48%), 126 tok/s recently, ~1.8 min left at this rate
[22:49:24] request CCCD5FB0 /v1/chat/completions: 105 s elapsed, prefill pass
[22:49:33] prefill: 13312/25796 tokens (52%), 57 tok/s recently, ~3.6 min left at this rate
[22:49:39] request CCCD5FB0 /v1/chat/completions: 120 s elapsed, prefill pass
[22:49:54] request CCCD5FB0 /v1/chat/completions: 135 s elapsed, prefill pass
[22:49:54] prefill: 14336/25796 tokens (56%), 49 tok/s recently, ~3.9 min left at this rate
[22:50:09] request CCCD5FB0 /v1/chat/completions: 150 s elapsed, prefill pass
[22:50:20] prefill: 15360/25796 tokens (60%), 41 tok/s recently, ~4.3 min left at this rate
[22:50:24] request CCCD5FB0 /v1/chat/completions: 165 s elapsed, prefill pass
[22:50:39] request CCCD5FB0 /v1/chat/completions: 180 s elapsed, prefill pass
[22:50:45] prefill: 16384/25796 tokens (64%), 41 tok/s recently, ~3.9 min left at this rate
[22:50:54] request CCCD5FB0 /v1/chat/completions: 195 s elapsed, prefill pass
[22:51:09] request CCCD5FB0 /v1/chat/completions: 210 s elapsed, prefill pass
[22:51:09] prefill: 17408/25796 tokens (67%), 42 tok/s recently, ~3.3 min left at this rate
[22:51:24] request CCCD5FB0 /v1/chat/completions: 225 s elapsed, prefill pass
[22:51:31] prefill: 18432/25796 tokens (71%), 48 tok/s recently, ~2.6 min left at this rate
[22:51:39] request CCCD5FB0 /v1/chat/completions: 240 s elapsed, prefill pass
[22:51:52] prefill: 19456/25796 tokens (75%), 49 tok/s recently, ~2.2 min left at this rate
[22:51:54] request CCCD5FB0 /v1/chat/completions: 255 s elapsed, prefill pass
[22:52:09] request CCCD5FB0 /v1/chat/completions: 270 s elapsed, prefill pass
[22:52:11] prefill: 20480/25796 tokens (79%), 52 tok/s recently, ~1.7 min left at this rate
[22:52:24] request CCCD5FB0 /v1/chat/completions: 285 s elapsed, prefill pass
[22:52:33] prefill: 21504/25796 tokens (83%), 47 tok/s recently, ~1.5 min left at this rate
[22:52:39] request CCCD5FB0 /v1/chat/completions: 300 s elapsed, prefill pass
[22:52:53] prefill: 22528/25796 tokens (87%), 52 tok/s recently, ~1.1 min left at this rate
[22:52:54] request CCCD5FB0 /v1/chat/completions: 315 s elapsed, prefill pass
[22:53:09] request CCCD5FB0 /v1/chat/completions: 330 s elapsed, prefill pass
[22:53:12] request CCCD5FB0 /v1/chat/completions: ended after 333.4 s, insufficient_memory
elastic: memory pressure (warning) — cache ~78 → ~63 experts/layer (10.4 → 8.4 GB pool, cold — refills from SSD)
elastic: memory freed — cache ~63 → ~78 experts/layer (8.4 → 10.4 GB pool, contents kept)
```
