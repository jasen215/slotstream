---
type: run
id: 01m3e76nm9zkza54hdmz8cjyz4
created: 2026-09-26T06:42:21.449524+00:00
updated: 2026-09-26T06:42:25.247701+00:00
summary: 'The full acceptance battery on the 34 GB Air after the current-backend reference environment landed: passed 30, failed 3, all four parity gates green, and two of the three reds are headroom skips'
binary: slotstream (working tree at cdf8707 plus the uncommitted engine WIP), release build, frozen identity refreshed with Tools/build_identity.py
captured_at: 2026-09-26
command: SLOTSTREAM_TEST_BINARY=$PWD/.build/release/slotstream SLOTSTREAM_VERIFY_OUT=/tmp/ss/verify-out bash Tools/verify.sh, run with process listing available because the weights-provenance gate shells out to ps
discarded: 'true'
machines: '[[records/machines/macbook-air-m5-32gb-local]]'
title: 'The full acceptance battery on the 34 GB Air: 30 passed, 3 failed, and two of the reds are headroom skips'
tool: slotstream Tools/verify.sh (frozen-binary path)
---
## Why this was captured

The same four commits had already been run through `Tools/verify.sh` on
2026-09-26 and read `passed 26, failed 7`. Four of those seven were one cause:
the independent current-backend reference had no environment, so
`Tools/current_backend_reference.py` could not start and the parity pair that
depends on it could not either. This is the same battery, same tree, after
installing what `docs/TESTING.md` requires (`.venv` with `mlx==0.32.2`,
`mlx-lm` and `numpy`) and with more real headroom at the start (17.5 GB
reclaimable against the earlier 11.9 GB). It is the acceptance evidence for the
retention-ceiling fix and the governor trace.

## Result

```text
PASS  independent current-backend layer reference
PASS  production layer parity against current backend
PASS  independent current-backend draft-head reference
PASS  mtp head parity vs current Python reference (mtp-parity)
DIAGNOSTIC  historical MLX 0.31 draft-head reference differs (retained)
...
robustness: passed 74, failed 0
passed 30, failed 3
```

The four current-backend gates are green, which is the whole difference from
the earlier run. The retained diagnostic is expected across a backend upgrade
and is left visible on purpose.

## The three reds

1. `FAIL  ELASTIC DRILL FAIL: exit 2`. The arena limit traced the same day:
   the 13 GB plan leaves a 4.4 GB pool, the availability seam shrinks 1576
   slots to 941, and the 635-slot growth back is about 1.75 GB, under
   `GovernorPolicy.growDeadbandGB`. See
   [[sources/runs/2026/09/2026-09-26-elastic-drill-arena-trace]].
2. `FAIL  small adaptive cache recovery` — a skip inside the check: it needs
   about 13 GB reclaimable to leave room for a shrink and found 11.2 GB at its
   turn, because the battery had just run other model processes. Headroom, not
   the product.
3. `SKIP  vision serving suite (only 18.9 GB reclaimable, needs 20.5)`. Not
   covered by intent as well as by headroom: this development machine does not
   use the vision path. The cheap vision gates did run and pass in the same
   battery — the vision tower parity against the float32 reference (`VISION
   PARITY PASS`, cosine 0.99846 swift against mlx f32) — and so did the priced
   image/MTP diagnostic.

## Environment notes for the next run

- `make build` cannot run under the DSH file sandbox: SwiftPM's own
  `sandbox-exec` is refused, so `verify.sh` stops at `== build ==`. Use the
  frozen path (`SLOTSTREAM_TEST_BINARY` set) after refreshing the receipt with
  `Tools/build_identity.py before|after <bin-path>`, which also rewrites
  `build-source.tar.gz`.
- An **absolute** `SLOTSTREAM_TEST_BINARY` flips `verify.sh` into that frozen
  mode even when it names the default binary, because line 44 compares the
  string against the relative `.build/release/slotstream`. Name it relatively,
  or refresh the identity.
- The weights-provenance gate shells out to `ps`
  (`Tools/context_qualification.py`), which the file sandbox denies; the
  battery must run with process listing available or that gate fails early.
- The binary under test is the working tree (the commits above plus the engine
  WIP that is still uncommitted), the same as the `passed 26` baseline, so the
  comparison between the two runs is like for like.
