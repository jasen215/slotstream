---
type: run
id: 01m3at22wk4t7sgskqjdtbn4c2
created: 2026-09-24T22:54:56.403048+00:00
updated: 2026-09-24T22:54:56.403048+00:00
summary: v0.2.25 published, publicly installed and accepted
binary: d960143c783dda94bd4d43d304e5f9f7c0e195f7d00feacc2934885dd3d3a951
captured_at: 2026-09-24
command: python3 qualify.py; gh release download; gh attestation verify; sh install.sh; Tools/e2e_release.sh
discarded: 'false'
machines: '[[records/machines/macbook-pro-m5-pro-48gb]]'
title: v0.2.25 published, publicly installed and accepted
tool: GitHub Actions, native acceptance, public installer and installed serving
---
[v0.2.25](https://github.com/carloslfu/slotstream/releases/tag/v0.2.25) was published at 2026-09-24T22:49:34Z from commit `a0cca848722bf27e7b896a948bff560936a14dbb`. Main engine CI 36064747416, Mac app CI 36064747352 and context proxies 36064747387 passed before publication; the commit changed no documentation, so the docs workflow did not run. Release workflow 36069482260 published the exact tested CI archive without rebuilding it.

Original bytes are preserved in [capture.tar.gz](../../../artifacts/release-0.2.25-2026-09-24/capture.tar.gz), with a [per-file manifest](../../../artifacts/release-0.2.25-2026-09-24/manifest.json) and [verification receipt](../../../artifacts/release-0.2.25-2026-09-24/receipt.json). Capture SHA-256: `80186732fef12433753b24f46355e17d131c6037e3f062f527b3def3ae8ee4e5`. All 233 included files were read back from the archive and checked against their recorded SHA-256. Tensor caches, release archives, candidate binaries and Metal libraries are excluded with their paths and sizes and are identified by the retained hashes; the superseded candidate's float dumps are excluded too, and the released candidate's are kept.

The archive SHA-256 is `24774d0755b16840f43b51e2a782ff0f68564ec5f9d75a8e4e17258515b3fb13`. The installed executable SHA-256 is `d960143c783dda94bd4d43d304e5f9f7c0e195f7d00feacc2934885dd3d3a951`. The MLX 0.32.2 metallib SHA-256 is `dc59d1cceb1a5c7e578232e6e41e28e2c73c9463ac6dbc3886c3ee17ffc270ed`. All 205 source inputs match the frozen checkout. CI and public archive/checksum bytes match, GitHub attestation verification passed, and the public installer was checked against source before it upgraded the standard installation from 0.2.24.

The release and instrumented CI catalogues each passed 75 groups and 32,004 assertions, with zero failures or skips. The exact downloaded candidate passed the full native battery in 1,838 s: 35 top-level gates, zero failures, including both elastic governor drills, `decode-overlap-check`, `draft-stream-check`, MTP parity and speculative gates, the memory promise, the issue-21 serving suite, quality 15/15, API robustness 74/74 and vision serving 25/25. Historical MLX 0.31 draft-head drift remains diagnostic beside the passing independent current-backend reference; tolerances were not widened.

The first candidate, commit `5a54b68fe4dacc8d7b3018bbd730f4f35bdaf1d4`, passed all four CI workflows but not the battery: 33 gates passed and both elastic drills failed. Plain decode now runs the decode lookahead, so the drills' `--mtp off` plans charge its reserve, and the live governor keeps it; the drill predicted each poll without it. The small-cache drill refused its own stimulus as larger than the starting arena, and the full drill read the governor's correct budget as stale. The fix, `a0cca84`, gives the drill's prediction the plan's lookahead decision and reserve and leaves the governor unchanged. Both drills passed on a local build of the fix before it was pushed, and again in the full battery on the released bytes. An earlier battery run on a local build of `5a54b68` was stopped by hand: its scratch checkout lacked the reference Python environments, so its two current-backend layer gates could not run. No candidate was tagged before it passed.

The publicly installed executable passed all 31 end-to-end checks with a 10 GB target, context 32768, MTP on and vision off; at that target the draft head streamed its experts through its 64-expert cache. Owned qualification and installed servers were stopped and reaped. In the released battery the full drill observed 8 global swap-ins and the small-cache drill 32; functional acceptance makes no timing claim. The release's decode measurements are in [[records/measurements/decode-perf-2026-09-24]].
