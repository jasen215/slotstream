import Foundation
import Metal
import MLX
import Slotstream

extension Diagnostics {
    /// The keepalive's power policy: `auto` keeps the GPU awake on AC power
    /// outside Low Power Mode only, `on` and `off` ignore the power state, and
    /// the environment names exactly one of the three.
    public static func gpuKeepAlivePolicy() throws -> CheckReport {
        var c = CheckBuilder("gpu-keepalive-policy")
        let states = [
            GPUKeepAlive.PowerState(onBattery: false, lowPowerMode: false),
            GPUKeepAlive.PowerState(onBattery: true, lowPowerMode: false),
            GPUKeepAlive.PowerState(onBattery: false, lowPowerMode: true),
            GPUKeepAlive.PowerState(onBattery: true, lowPowerMode: true),
        ]
        let auto = states.map { GPUKeepAlive.keepsAwake(.auto, power: $0) }
        c.equal("auto: only AC power outside Low Power Mode", auto, [true, false, false, false])
        c.expect("on ignores the power state", states.allSatisfy { GPUKeepAlive.keepsAwake(.on, power: $0) })
        c.expect("off ignores the power state", states.allSatisfy { !GPUKeepAlive.keepsAwake(.off, power: $0) })
        var consulted = false
        _ = GPUKeepAlive.keepsAwake(.on, power: { consulted = true; return states[0] }())
        c.expect("an explicit policy never reads the power state", !consulted)
        c.equal("unset environment is auto", try GPUKeepAlive.environmentPolicy([:]), .auto)
        for policy in GPUKeepAlive.Policy.allCases {
            c.equal("environment \(policy.rawValue)",
                try GPUKeepAlive.environmentPolicy(["SLOTSTREAM_GPU_KEEPALIVE": policy.rawValue]), policy)
        }
        var refused = false
        do { _ = try GPUKeepAlive.environmentPolicy(["SLOTSTREAM_GPU_KEEPALIVE": "sometimes"]) } catch { refused = true }
        c.expect("an unknown value is refused", refused)
        return c.report()
    }

    /// The keepalive submits work while held, nests, and stops submitting
    /// within one buffer of its last `end`.
    public static func gpuKeepAliveRuns() -> CheckReport {
        var c = CheckBuilder("gpu-keepalive-runs")
        guard let keepAlive = GPUKeepAlive.shared else {
            c.expect("a Metal device builds the keepalive", MTLCreateSystemDefaultDevice() == nil)
            return c.report()
        }
        func waitForBuffers(above count: Int) -> Bool {
            for _ in 0 ..< 400 where keepAlive.submittedBuffers <= count { usleep(5_000) }
            return keepAlive.submittedBuffers > count
        }
        let idle = keepAlive.submittedBuffers
        usleep(50_000)
        c.equal("nothing runs before begin", keepAlive.submittedBuffers, idle)
        keepAlive.begin()
        c.expect("begin submits work", waitForBuffers(above: idle))
        keepAlive.begin()
        keepAlive.end()
        let held = keepAlive.submittedBuffers
        c.expect("a nested end keeps it running", waitForBuffers(above: held))
        keepAlive.end()
        // The running buffer stops at its next flag poll; at most two were in
        // flight, so submission settles quickly.
        usleep(200_000)
        let settled = keepAlive.submittedBuffers
        usleep(200_000)
        c.equal("the last end stops submission", keepAlive.submittedBuffers, settled)
        return c.report()
    }

    /// Direct demand reads and the keepalive leave generation exact: the same
    /// ids with each on and off, with and without the draft head, on a cold
    /// floor-sized pool where decode misses at every layer. Then the failure
    /// paths of the direct reads, at the pool and request levels. Each part
    /// loads and releases its own model, so only one is resident at a time.
    public static func decodeOverlap(modelDir: URL, tokens: Int = 24) throws -> [CheckReport] {
        let generation = try decodeOverlapGeneration(modelDir: modelDir, tokens: tokens)
        MLX.Memory.clearCache()
        let head = MTPWeights.present(modelDir: modelDir)
        return [
            generation,
            try optimizationReadRecovery(modelDir: modelDir, directReads: true),
            try optimizationRequestReadRecovery(modelDir: modelDir, mtp: false, directReads: true),
        ] + (head ? [try optimizationRequestReadRecovery(modelDir: modelDir, mtp: true, directReads: true)] : [])
    }

    static func decodeOverlapGeneration(modelDir: URL, tokens: Int) throws -> CheckReport {
        var c = CheckBuilder("decode-overlap")
        MLX.Memory.cacheLimit = 128 << 20
        let model = try Qwen4ExpModel(index: CheckpointIndex(dir: modelDir), poolSlots: Geometry.floorSlots)
        let head = MTPWeights.present(modelDir: modelDir)
        if head { try model.enableMTP(modelDir: modelDir) }
        let generator = Generator(model: model)
        generator.prefillChunk = 256
        var params = SampleParams.greedy
        params.maxTokens = tokens
        let prompt = (0 ..< 40).map { 1000 + (($0 * 7919) % 200_000) }
        func cold() {
            // Shrinking starts a pool cold; growing back keeps it empty.
            model.pool.unpinAll()
            model.pool.resize(to: Geometry.floorSlots - 1)
            model.pool.resize(to: Geometry.floorSlots)
        }
        for speculative in head ? [false, true] : [false] {
            let mode = speculative ? "speculative" : "plain"
            generator.speculationEnabled = speculative
            var staged = InferenceOptimizations.deploymentCandidate()
            staged.directDemandReads = nil
            var direct = staged
            direct.directDemandReads = true
            model.optimizations = staged
            cold()
            let a = generator.generate(promptIds: prompt, params: params, eosIds: [])
            model.optimizations = direct
            cold()
            let b = generator.generate(promptIds: prompt, params: params, eosIds: [])
            cold()
            GPUKeepAlive.shared?.begin()
            let k = generator.generate(promptIds: prompt, params: params, eosIds: [])
            GPUKeepAlive.shared?.end()
            c.expect("\(mode): every run succeeds",
                a.1.runtimeError == nil && b.1.runtimeError == nil && k.1.runtimeError == nil)
            c.equal("\(mode): staged run generated every token", a.0.count, tokens)
            c.equal("\(mode): direct reads leave the ids unchanged", b.0, a.0)
            c.equal("\(mode): the keepalive leaves the ids unchanged", k.0, a.0)
            c.expect("\(mode): the staged run scattered its misses",
                a.1.decodeSlotScatterBatches > 0 && (a.1.decodeSlotDirectBatches ?? 0) == 0)
            c.expect("\(mode): the direct run read its misses in place",
                (b.1.decodeSlotDirectBatches ?? 0) > 0 && b.1.decodeSlotScatterBatches == 0)
            c.equal("\(mode): both runs read the same records", b.1.decodeRecords, a.1.decodeRecords)
            if speculative {
                c.expect("\(mode): the draft head verified", b.1.verifyPasses > 0)
            }
        }
        return c.report()
    }
}
