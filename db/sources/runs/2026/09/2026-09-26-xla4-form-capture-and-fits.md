---
type: run
id: 01m3epv0gf6ymw9cwhrvjaq12x
created: 2026-09-26T11:15:36.591110+00:00
updated: 2026-09-26T11:16:06.507471+00:00
summary: 'Protocol xla4-form-20260926: observer-only feature capture and the three forecast-form fits'
binary: .build/out/Products/Release/slotstream sha256 f449f0019cc2439a5436885a7c7d14dde033e57f71d7b790f64ef85d323f10b3
captured_at: 2026-09-26
command: Tools/expert_lookahead.py capture --protocol .build/expert-lookahead/xla4-form-20260926/protocol.json --out .build/expert-lookahead/xla4-form-20260926/capture --requests .build/expert-lookahead/xla4-form-20260926/requests.jsonl --memory-gb 10.0 --mtp on --features off --x2 on --capture on --resume --forecast-inputs on --forecast-taps attention --forecast-per-row 24
discarded: 'false'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
title: 'Protocol xla4-form-20260926: observer-only feature capture and the three forecast-form fits'
tool: Tools/expert_lookahead.py capture, Tools/expert_lookahead_learned.py fit, Tools/expert_lookahead_ranking.py fit
---
# Protocol `xla4-form-20260926`: observer-only feature capture and the three forecast-form fits

Captured 2026-09-26 on [[records/machines/macbook-air-m5-32gb-local]] (34 GB reported,
`applegpu_g17g`). Raw commands, identity and artifact hashes; interpretation is in
[[records/measurements/expert-lookahead-ranking-forms-2026-09-26]].

## Commands, in order

```
# capture, first attempt: 58 of 69 complete, then exit 1
Tools/expert_lookahead.py capture --protocol .build/expert-lookahead/xla4-form-20260926/protocol.json \
  --out .build/expert-lookahead/xla4-form-20260926/capture \
  --requests .build/expert-lookahead/xla4-form-20260926/requests.jsonl \
  --features off --x2 on --capture on --forecast-taps attention \
  --forecast-inputs on --forecast-per-row 24 --memory-gb 10.0 --mtp on --resume
# the same command again after the exit 1 below; 11 requests remained

Tools/expert_lookahead.py validate-data --run .build/expert-lookahead/xla4-form-20260926/capture
Tools/expert_lookahead_learned.py collect --capture .../capture --cache .../cache
Tools/expert_lookahead_learned.py fit    --cache .../cache --out .../fit-ridge
Tools/expert_lookahead_ranking.py  fit    --cache .../cache --out .../fit-lr  --arm linear    --search
Tools/expert_lookahead_ranking.py  fit    --cache .../cache --out .../fit-l2  --arm two_layer --search
Tools/expert_lookahead_ranking.py  compare --fits .../fit-ridge .../fit-lr .../fit-l2 --out .../compare.json
```

## What happened, including the failure

- Capture start 16:30:44 local, exit **1** at 18:30:31 after 7186 s: 58 of 69 requests
  complete and 11 rows `finish_reason: error`, every one reading `memory pressure
  interrupted generation queue; retry after memory becomes available`. The engine's own
  guard cancelled the queue; nothing was silently dropped, and the tool said
  `11 request(s) incomplete; rerun with --resume`.
- The identical command with `--resume` ran 18:30:40 to 18:57:45 (1624 s) and exited
  **0** with 69 of 69 unique ids complete. `capture/requests.jsonl` carries 75 rows for
  69 ids because the six retried requests appended a second row each.
- The offline stage then ran validate-data, collect and the three fits; the first
  `compare` failed on a key-name bug in that tool (`recall16` stored, `rec16` read),
  which was fixed and both ranking fits and `compare` were rerun from scratch.
- Memory: 15.7 GB reclaimable at the first preflight, 21.6 GB at the resume, and 13.2 to
  16.3 GB while the engine ran at its 10 GB target. Host swap stayed near 4.7 GB of
  6.1 GB used throughout. This is why the run was eligible for cancellation by the
  system's pressure guard and not for any timing claim.

## Identity

| Item | Value |
| --- | --- |
| `protocol.json` sha256 | `bf7fbfc068940c9e` (first 16 hex) |
| Binary | `.build/out/Products/Release/slotstream` sha256 `f449f0019cc2439a5436885a7c7d14dde033e57f71d7b790f64ef85d323f10b3` |
| git HEAD | `52400ace98eaba2bae3106ee8b39d0bacee8698a`, with the other session's dirty paths recorded in the protocol |
| Memory target | 10.0 GB, `preflight_satisfied_at_freeze: false` (13.374 GB reclaimable at freeze) |
| Pool at that target | 838 slots, about 17 of 512 experts per layer |
| Corpus | `Tools/fixtures/expert-lookahead/corpus.json` sha256 `adac22f1b1439be4638dad1e05809162924f796e1c7fe7ad80f3348d97ea17d5`, 69 pilot requests (56 train, 13 validation) |
| Training rows | 12,195 per target layer, 47 target layers |

## Artifacts

Git-ignored scratch under `.build/expert-lookahead/xla4-form-20260926/`; the hashes are
of the bytes these numbers came from.

| Artifact | sha256 (first 16) |
| --- | --- |
| `capture/shards/` | 51 files, 7.7 GB |
| `fit-ridge/fit.json` | `3650943aa1e4f4ae` |
| `fit-lr/fit.json` | `66359698b1e9ac7d` |
| `fit-l2/fit.json` | `987afcf7f2a09048` |
| `compare.json` | `609f52e271e7dc43` |

## Results

Validation pooled over targets 2 to 47, 142,968 rows, identical rows and splits for
every arm:

| form | top-10 agreement | exact top-10 | recall@16 | recall@24 | FP16 weights |
| --- | --- | --- | --- | --- | --- |
| attention tap | 0.7340 | 0.0555 | 0.8606 | 0.9192 | — |
| shipped ridge, rank-128 | 0.8028 | 0.1072 | 0.9204 | 0.9610 | 35.25 MiB |
| shipped ridge, dense | 0.8073 | 0.1129 | 0.9235 | 0.9628 | 117.5 MiB |
| LR: rank-128, ranking objective | 0.7663 | 0.0741 | 0.8924 | 0.9441 | 35.30 MiB |
| L2: two linear layers, SiLU, ranking objective | 0.7672 | 0.0750 | 0.8936 | 0.9449 | 35.31 MiB |

Both arms selected the grid's most conservative setting (learning rate 1e-4, weight
decay 0.01) and stopped early, at best epoch 3 to 12 of a 20-epoch cap, on 12,195 rows
per layer.

## What is not here

- **G2 and G3 are unevaluated.** This capture is observer-only: its rows carry feature
  shards and no `passes`, `events` or `tap_forecasts`, so `twin` cannot consume it and
  no coverage or wasted-read number exists. A residency capture was not run.
- **No timing evidence of any kind**, by the registration's section 9.
- The sealed test split was never read; folds group by request id.
