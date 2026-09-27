---
type: run
id: 01m3a7h4e4h2a8yy68nhk12rsd
created: 2026-09-24T17:31:06.564482+00:00
updated: 2026-09-24T17:31:06.564482+00:00
summary: 'Decode speed experiments: keepalive, direct demand reads, streamed draft head, plain-decode lookahead and rejected ideas'
binary: environment-guarded experiment build of 37fcb8e plus experiments/patches/slotstream-experiments.diff
captured_at: 2026-09-24
command: bash harness/queue*.sh; python3 harness/summary.py; python3 analysis/screens.py
discarded: 'false'
machines: '[[records/machines/macbook-pro-m5-pro-48gb]]'
title: 'Decode speed experiments: keepalive, direct demand reads, streamed draft head, plain-decode lookahead and rejected ideas'
tool: ab.py and ab2.py paired A/B harness, IOReport energy sampler, MLX GPU span instrumentation, Metal wake microbenchmarks
---
Environment-guarded decode experiments on an export of commit 37fcb8e with the patch in the capture (`experiments/patches/slotstream-experiments.diff`); the MLX-side instrumentation patch (`experiments/patches/mlx-experiments.diff`) was built only into the instrumented pass-cost runs. `experiments/README.md` lists every switch, and `experiments/SUMMARY.txt` and `analysis/screens.txt` every comparison.

Original bytes are preserved in [capture.tar.gz](../../../artifacts/decode-perf-2026-09-24/capture.tar.gz), with a [per-file manifest](../../../artifacts/decode-perf-2026-09-24/manifest.json) and [verification receipt](../../../artifacts/decode-perf-2026-09-24/receipt.json). Capture SHA-256: `49b65f84b4e19cf7c833e4c9f1ec1f5664b4996d3572e703be6b7669e26a2b97`. All 2,411 files were read back from the archive and checked against their recorded SHA-256; nothing was excluded. This record covers `experiments/`, `analysis/` and `micro-rerun/`; [[sources/runs/2026/09/2026-09-24-decode-overlap-landed]] covers the rest.

The 48 GiB M5 Pro ran macOS 26.6 (build 25G83) with a live desktop and 4.6 to 6.7 GB of swap in use. `ab.py` and `ab2.py` ran one model process at a time, every arm on every prompt per round in rotated order, after waiting for reclaimable memory above the target plus 6 GB; each run records global swap-in and swap-out deltas, thermal state and load. Workload: four corpus prompts, greedy, 192 output tokens, two rounds. `--energy` integrated IOReport SoC energy without root (`experiments/energy/iorep.c`). The GPU span timings come from the instrumented MLX build (`MLX_GPU_TIMING`) and `gpu_windows.py`. The wake microbenchmarks were re-run on a quiet GPU after the timing runs.

Most runs recorded global swap-ins. The record is not discarded, because comparisons with three or more pairs free of swap-ins and swap-outs exist and only those support timing claims; the rest are kept as directional evidence. The derived results and limits are in [[records/measurements/decode-perf-2026-09-24]].
