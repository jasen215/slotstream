---
type: run
id: 01m3a7jad1v6x24qeefr7be8gx
created: 2026-09-24T17:31:45.441981+00:00
updated: 2026-09-24T17:31:45.441981+00:00
summary: 'Landed GPU keepalive and direct demand reads: release and on/off confirmation under paging, and gates'
binary: 'v0.2.24: bbdfcaffa8959ac1ca3e39d1f804cc4491aaa98dd8f649d5f239713a6ba10499; landed build: abcd05c059fa0abd7757af387d37ede936ebf367c58fda68f36e2b81a726615a'
captured_at: 2026-09-24
command: python3 ab2.py (confirmation/README.md); slotstream-checks --tier t0 --tier t1; slotstream decode-overlap-check; Tools/static_gates.sh
discarded: 'true'
machines: '[[records/machines/macbook-pro-m5-pro-48gb]]'
title: 'Landed GPU keepalive and direct demand reads: release and on/off confirmation under paging, and gates'
tool: ab2.py paired A/B harness, analyze.py, slotstream-checks, decode-overlap-check, Tools/static_gates.sh
---
The landed GPU keepalive and direct demand reads, measured in the same capture as [[sources/runs/2026/09/2026-09-24-decode-perf-experiments]]: [capture.tar.gz](../../../artifacts/decode-perf-2026-09-24/capture.tar.gz), [manifest](../../../artifacts/decode-perf-2026-09-24/manifest.json), [receipt](../../../artifacts/decode-perf-2026-09-24/receipt.json), capture SHA-256 `49b65f84b4e19cf7c833e4c9f1ec1f5664b4996d3572e703be6b7669e26a2b97`. This record covers `confirmation/` and `gates/`.

**Timing.** `confirmation/README.md` names both binaries by SHA-256 and gives the exact commands: the installed v0.2.24 release (`bbdfcaff…10499`) against the landed build (`abcd05c0…6615a`), and the landed build with both changes on against both off through `SLOTSTREAM_GPU_KEEPALIVE=off` and `SLOTSTREAM_OPT_DIRECT_DEMAND=0`, each at 10 and 22 GB with `--mtp auto`, four prompts, 192 greedy tokens, two rounds. Every one of the 64 runs completed, with identical output ids within each pair. The Mac was paging throughout: 63 of 64 runs recorded global swap-ins, and a few recorded swap-outs. The record is discarded for timing claims because no comparison keeps a pair free of swap activity; it confirms direction only. `confirmation/analysis-*.txt` hold the analyzer output.

**Gates.** Built from HEAD bf29505 plus only the files of this change, in a separate tree, with the pinned dependencies and `mlx-0.32.2.metallib`: `slotstream-checks --tier t0 --tier t1` passed 75 checks and 31,934 assertions; `decode-overlap-check` passed 1,672 assertions with no process left; `Tools/static_gates.sh` passed. Outputs are in `gates/`.

The derived results are in [[records/measurements/decode-perf-2026-09-24]].
