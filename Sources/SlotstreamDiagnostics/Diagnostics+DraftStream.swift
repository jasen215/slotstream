import Foundation
import MLX
import Slotstream

extension Diagnostics {
    /// A streamed draft head and the plain-decode lookahead leave generation
    /// exact. Each engine loads from a real plan at a small target and is
    /// released before the next one loads, so one model is resident at a time.
    /// Requests run without end-of-sequence ids so every run decodes all its
    /// tokens; the head and the lookahead attach to the model at load.
    ///
    /// - The head decodes the same ids with its experts resident and streamed,
    ///   and the streamed head read experts on demand.
    /// - A failed draft expert read ends that request with an error; the next
    ///   request decodes the same ids again.
    /// - Plain decode with the lookahead matches plain decode without it, and
    ///   the lookahead forecast its passes.
    public static func draftStream(modelDir: URL, tokens: Int = 32) async throws -> [CheckReport] {
        var head = CheckBuilder("draft-stream-head")
        var lookahead = CheckBuilder("draft-stream-plain-lookahead")
        let prompt = (0 ..< 40).map { 1000 + (($0 * 7919) % 200_000) }
        var params = SampleParams.greedy
        params.maxTokens = tokens
        let correction = DecodeLookaheadPlanning.environment(modelDirectory: modelDir)

        func engine(memoryGB: Double, mtp: Planner.MTPMode, experts: Planner.MTPExpertPlacement = .automatic,
                    lookahead: DecodeLookaheadPlanning) async throws -> Engine {
            let plan = try Planner.plan(expertsPerLayer: nil, poolGB: nil, memoryGB: memoryGB,
                mtp: mtp, mtpAvailable: MTPWeights.present(modelDir: modelDir), vision: .off,
                qualification: false, decodeLookahead: lookahead, mtpExperts: experts)
            let engine = try await Engine(modelDir: modelDir, plan: plan)
            // The pass size decides prefill rounding; pin it so plans that
            // size their pools differently compute the same prompt.
            engine.generator.prefillChunk = 256
            engine.gpuKeepAlive = .off
            MLX.Memory.cacheLimit = 128 << 20
            return engine
        }

        if MTPWeights.present(modelDir: modelDir) {
            var residentIds: [Int] = []
            do {
                let resident = try await engine(memoryGB: 12, mtp: .on, experts: .resident, lookahead: .off)
                head.expect("the resident plan keeps the experts resident",
                    resident.currentPlan?.mtpStreamedExperts == false && resident.currentPlan?.mtpEnabled == true)
                let (ids, stats) = resident.generator.generate(promptIds: prompt, params: params, eosIds: [])
                head.expect("resident run succeeds", stats.runtimeError == nil, stats.runtimeError ?? "")
                head.expect("resident run verified drafts", stats.verifyPasses > 0)
                head.equal("resident run reports no draft cache", stats.draftExpertMisses == nil, true)
                head.equal("resident run generated every token", ids.count, tokens)
                residentIds = ids
            }
            MLX.Memory.clearCache()
            let streamed = try await engine(memoryGB: 12, mtp: .on, experts: .streamed, lookahead: .off)
            head.expect("the streamed plan streams the experts",
                streamed.currentPlan?.mtpStreamedExperts == true && streamed.currentPlan?.mtpEnabled == true)
            let (ids, stats) = streamed.generator.generate(promptIds: prompt, params: params, eosIds: [])
            head.expect("streamed run succeeds", stats.runtimeError == nil, stats.runtimeError ?? "")
            head.equal("streamed experts leave the ids unchanged", ids, residentIds)
            head.equal("streamed run generated every token", ids.count, tokens)
            head.expect("the streamed head read experts on demand", (stats.draftExpertMisses ?? 0) > 0,
                "\(String(describing: stats.draftExpertMisses))")
            head.expect("the streamed head reused cached experts", (stats.draftExpertHits ?? 0) > 0,
                "\(String(describing: stats.draftExpertHits))")
            streamed.model.mtpHead?.expertStream?.readFault = ModelError("injected draft expert read failure")
            let (_, failed) = streamed.generator.generate(promptIds: prompt, params: params, eosIds: [])
            head.expect("a failed draft read ends the request with an error", failed.runtimeError != nil)
            head.expect("the failure was consumed", streamed.model.mtpHead?.expertStream?.readFault == nil)
            let (againIds, again) = streamed.generator.generate(promptIds: prompt, params: params, eosIds: [])
            head.expect("the next request succeeds", again.runtimeError == nil, again.runtimeError ?? "")
            head.equal("the next request decodes the same ids", againIds, residentIds)
        } else {
            head.expect("mtp.safetensors is absent; streamed head not exercised", true)
        }
        MLX.Memory.clearCache()

        var plainIds: [Int] = []
        do {
            let plain = try await engine(memoryGB: 10, mtp: .off, lookahead: .off)
            lookahead.expect("the reference plan runs no lookahead", plain.currentPlan?.decodeLookahead == false)
            let (ids, stats) = plain.generator.generate(promptIds: prompt, params: params, eosIds: [])
            lookahead.expect("plain run succeeds", stats.runtimeError == nil, stats.runtimeError ?? "")
            lookahead.equal("plain run generated every token", ids.count, tokens)
            plainIds = ids
        }
        MLX.Memory.clearCache()
        let withLookahead = try await engine(memoryGB: 10, mtp: .off, lookahead: correction)
        lookahead.expect("the plan runs the lookahead without the head",
            withLookahead.currentPlan?.decodeLookahead == true && withLookahead.currentPlan?.mtpEnabled == false)
        let (ids, stats) = withLookahead.generator.generate(promptIds: prompt, params: params, eosIds: [])
        lookahead.expect("lookahead run succeeds", stats.runtimeError == nil, stats.runtimeError ?? "")
        lookahead.equal("the lookahead leaves plain decode's ids unchanged", ids, plainIds)
        lookahead.expect("plain decode passes were forecast", (stats.expertPrefetch?.forecastPasses ?? 0) > 0,
            "\(String(describing: stats.expertPrefetch?.forecastPasses))")
        lookahead.expect("the lookahead issued reads", (stats.expertPrefetch?.issued ?? 0) > 0,
            "\(String(describing: stats.expertPrefetch?.issued))")
        return [head.report(), lookahead.report()]
    }
}
