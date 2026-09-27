---
type: run
id: 01m3adhxhmfk8xvkbxyfym3361
created: 2026-09-24T19:16:23.732823+00:00
updated: 2026-09-24T19:31:02.731309+00:00
summary: 'Landed streamed draft head and plain-decode lookahead: confirmation under paging, a prototype cross-check and gates'
binary: 'landed timing build: 353d99cf6c88d567051dea6821444a0a5373d60bf5fe3f581f382900cb087c94; prototype: 653c07ce52558b65 (first 16 hex digits); gated build: 9c43ad03e3df2354925c87da8e7db29a6e8b56d63f18715ae0f812c8b6a17e1d'
captured_at: 2026-09-24
command: python3 ab2.py (confirmation/README.md); slotstream-checks --tier t0 --tier t1; Tools/planner_gates.sh; slotstream draft-stream-check; slotstream decode-overlap-check; Tools/context_gates.py; Tools/context_proxy.py; Tools/static_gates.sh
discarded: 'true'
machines: '[[records/machines/macbook-pro-m5-pro-48gb]]'
title: 'Landed streamed draft head and plain-decode lookahead: confirmation under paging, a prototype cross-check and gates'
tool: ab2.py paired A/B harness, analyze.py, land2_screens.py, slotstream-checks, planner gates, draft-stream-check, decode-overlap-check, context gates and proxy, Tools/static_gates.sh
---
The landed streamed draft head, its 28-per-layer floor and the plain-decode lookahead, measured on their own build: [capture.tar.gz](../../../artifacts/draft-stream-2026-09-24/capture.tar.gz), [manifest](../../../artifacts/draft-stream-2026-09-24/manifest.json), [receipt](../../../artifacts/draft-stream-2026-09-24/receipt.json), capture SHA-256 `622e22d2ba99e73b5d9e00caa9cd45d6fa8ba9511cc86476ca969b89f4d89a65`. The experiments behind the change are [[sources/runs/2026/09/2026-09-24-decode-perf-experiments]].

**Timing.** `confirmation/README.md` names the binaries by SHA-256 and gives the exact commands: the landed build (`353d99cf…87c94`) at 10 GB with `--mtp auto` (the head stays off below its floor) with and without the lookahead (`SLOTSTREAM_OPT_EXPERT_PREFETCH=0`); at 12 GB in automatic mode (streamed head and lookahead) against `--mtp off` (plain decode with the lookahead); at 22 GB with `--mtp off` with and without the lookahead, where both arms chose the 65,536-token automatic window. A fourth run interleaved the landed build and the environment-guarded prototype (`653c07ce…`), each with and without its lookahead, at 10 GB. Four prompts, 192 greedy tokens, two rounds, one model process at a time. Every run completed. Every pair recorded global swap-ins, so no comparison keeps a pair free of swap activity and the record is discarded for timing claims; it confirms direction. `analysis/` holds the screens.

**Gates.** On the gated build (`9c43ad03…17e1d`), which differs from the timing build only by a documentation comment: `slotstream-checks --tier t0 --tier t1` passed 75 checks and 31,991 assertions; `Tools/planner_gates.sh` passed 97; `draft-stream-check` passed 23 assertions, with every run decoding all 32 tokens and an injected read failure ending only its request; `decode-overlap-check` passed 1,672; `Tools/context_gates.py` passed 130 against `context-default-v3.json` and `context-automatic-v2.json`; the context proxy passed 965,028 contract assertions; `Tools/static_gates.sh` passed. Outputs are in `gates/`; `fixtures/` holds the scripts that derived the two new fixture versions.
