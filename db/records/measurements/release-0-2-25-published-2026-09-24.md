---
type: measurement
id: 01m3at2wm9v1kgp1qd3vqze57z
created: 2026-09-24T22:55:22.761465+00:00
updated: 2026-09-24T22:55:22.761465+00:00
summary: v0.2.25 published, installed and accepted
date: 2026-09-24
doc: measurements
level: '3'
machines: '[[records/machines/macbook-pro-m5-pro-48gb]]'
note: Published exact CI bytes after a drill-only fix; full native and installed acceptance pass. The decode gains are in the decode measurement.
order: '1680'
runs: '[[sources/runs/2026/09/2026-09-24-release-0-2-25-published-and-installed]]'
title: v0.2.25 published, installed and accepted
status: measured
---
**v0.2.25 is public, installed and accepted.** It ships the GPU keepalive and direct demand reads, the draft head streaming its experts with an automatic floor of 28 experts per layer, and the decode lookahead in plain decode. It also carries the shared-prefix boundary fix from [#27](https://github.com/carloslfu/slotstream/pull/27), the decode-forecast download from [#28](https://github.com/carloslfu/slotstream/pull/28) and the documented Mac app changes.

Release: [v0.2.25](https://github.com/carloslfu/slotstream/releases/tag/v0.2.25), published 2026-09-24T22:49:34Z from `a0cca848722bf27e7b896a948bff560936a14dbb`. The CI candidate, public archive and installed executable match exactly. Archive SHA-256: `24774d0755b16840f43b51e2a782ff0f68564ec5f9d75a8e4e17258515b3fb13`. Executable SHA-256: `d960143c783dda94bd4d43d304e5f9f7c0e195f7d00feacc2934885dd3d3a951`.

| Acceptance | Result |
| --- | --- |
| Exact-commit hosted CI | Engine, instrumented coverage, external library consumer, Mac app and context contracts passed |
| Engine catalogue | 75 groups, 32,004 assertions, no failures or skips, in release and instrumented builds |
| Full native battery | 35 top-level gates passed, including both elastic governor drills, `draft-stream-check`, `decode-overlap-check`, quality 15/15, robustness 74/74 and vision serving 25/25 |
| Public distribution | Preserved CI archive published, public checksum/provenance verified, public installer upgraded the standard installation from 0.2.24 |
| Installed serving | 31/31 with a 10 GB target and MTP on, the draft head streaming its experts; owned server reaped |

The first candidate, `5a54b68`, passed CI but failed both elastic drills and was not tagged. The drill predicted the governor without the decode lookahead's reserve, which plain decode now charges; the governor was right. The fix, `a0cca84`, changes only the drill, and both drills then passed on the released bytes. [[sources/runs/2026/09/2026-09-24-release-0-2-25-published-and-installed]] retains the commands, both candidates' native logs, the fix confirmation, source/build identity, workflow output, installer and process-cleanup receipts. The historical backend reference remains visible beside the passing current-backend reference; no tolerance was widened.

These are functional acceptance results, not speed claims. The decode gains this release ships, and their limits, are in [[records/measurements/decode-perf-2026-09-24]].
