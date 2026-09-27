---
type: decision
id: 01m3a7k67genw60ya71cwjsb74
created: 2026-09-24T17:32:13.936108+00:00
updated: 2026-09-24T17:32:13.936108+00:00
summary: 'A one-thread spin kernel keeps the GPU awake while a request generates, on AC power outside Low Power Mode by default: 1.22x with direct reads at 22 GB, energy per token +7%'
decided_on: 2026-09-24
evidence: '[[records/measurements/decode-perf-2026-09-24]]'
reversible_if: A paired comparison on another Mac shows no decode gain, a fanless Mac throttles with it on AC power, or macOS stops lowering an idle GPU's clock between short command buffers
title: The GPU stays awake while a request generates, on AC power by default
status: standing
---
Carlos approved landing the tested decode changes on September 24, 2026: "yes, land them in Slotstream". The proposal he accepted named a power setting for the keepalive; this records that setting.

**Decision.** While a request generates, the engine keeps the GPU awake with a one-thread kernel on its own Metal command queue. The kernel polls a shared flag up to 200,000 times per command buffer and computes nothing; two buffers stay in flight while any generation holds it, and the last `end` sets the flag, so the GPU is released within one buffer, tens of milliseconds. The policy defaults to `auto`: on with AC power outside Low Power Mode, off on battery or in Low Power Mode, read from IOKit and `ProcessInfo` at the start of each request. `--gpu-keepalive on|off` on `run` and `serve`, or `SLOTSTREAM_GPU_KEEPALIVE`, overrides it; an unknown value is refused. Saved statistics record `gpuKeptAwake`.

**Why it helps.** Streamed decode is stop-and-go: at each layer the host reads the routing back and reads the missing experts before it submits the next burst. An instrumented one-token pass with every expert resident was 337 command buffers with the GPU busy 58% of the time; with the keepalive the idle time per buffer fell from 68.3 to 49.5 µs and the pass from 55.2 to 47.4 ms. After any idle gap of 200 µs or more a small kernel ran 4.7 times slower than back to back, 230 against 49 µs; with the spin kernel resident it ran in 52. It touches no model memory, and every paired comparison kept identical output.

**Evidence.** [[records/measurements/decode-perf-2026-09-24]]: at 22 GB with the draft head and lookahead the keepalive alone gave 1.11x over five swap-free pairs (1.13x over all eight), and with direct demand reads 1.22x. At 16 GB on the streamed-head configuration it gave 1.17x over four swap-free pairs. The landed build, both changes against neither, gave 1.23x at 10 GB and 1.12x at 22 GB over eight pairs each under heavy paging, every pair above 1.

**Cost.** IOReport energy per generated token rose 7.1% over four swap-free pairs at 16 GB (6.7% over all eight), with average SoC power 26.7 to 32.5 W. On battery that trades runtime for speed, so `auto` leaves it off there. The best measured configuration with the keepalive still used 11% less energy per token than the shipped default, because it finished sooner.

**Alternatives measured.** A duty-cycled kernel with 200 µs or 1 ms idle gaps between buffers gave no reliable gain: the clock falls again in the gaps. MLX's host spin-wait instead of blocking waits was 0.71x. Committing every 10 operations, user-interactive QoS for the generating thread and short 5,000-poll buffers gave no gain over this design.

**Scope.** Measured on one M5 Pro 48 GB, macOS 26.6, with a live desktop. Other chips may clock differently; fanless Macs on AC power are not measured.
