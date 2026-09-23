import CryptoKit
import Foundation
import SevraRuntime
import Slotstream

/// Real-model app cache lifecycle, using only an explicitly disposable Home.
func realCacheCheckIfRequested() async throws -> Bool {
    guard CommandLine.arguments.contains("--real-cache") else { return false }
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: "--home"), i + 1 < args.count else { throw SevraError.refused("A real cache check requires a new --home directory.") }
    let home = URL(fileURLWithPath: args[i + 1]).standardizedFileURL
    guard !FileManager.default.fileExists(atPath: home.path), (Machine.current().availableGB ?? 0) >= 13 else {
        throw SevraError.refused("Use a new disposable Home and at least 13 GB reclaimable memory.")
    }
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    let engine = LocalInference(memoryGB: 10)
    let thread = WorkThread(title: "Cache fixture")
    let context = InferenceCacheContext(home: home, thread: thread, thinking: false)
    func files() throws -> [String: String] {
        guard let directory = context.directory,
              let walker = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) else { return [:] }
        var result: [String: String] = [:]
        for case let file as URL in walker where try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
            var hash = SHA256()
            while let data = try handle.read(upToCount: 1 << 20), !data.isEmpty { hash.update(data: data) }
            result[file.lastPathComponent] = hash.finalize().map { String(format: "%02x", $0) }.joined()
        }
        return result
    }
    func ask(_ history: [ChatMessage], thinking: ThinkingRequest? = nil) async throws -> EngineTurn {
        try await engine.turn(history: history, tools: [], thinking: thinking, replyTokens: 256,
            control: ThinkingControl(), cancellation: Cancellation(), buffer: TurnBuffer())
    }
    do {
        try await engine.prepareCache(context)
        let inventory = (1 ... 128).map { "Crate \($0) holds \($0 * 3) bolts and ships on day \($0 % 7 + 1)." }.joined(separator: " ")
        var history = [ChatMessage(role: "user", content: inventory + " How many bolts are in crate 37? Answer with just the number.")]
        let first = try await ask(history)
        let firstStats = await engine.lastStats[0]
        try require((firstStats.persistentPrefix?.savedTokens ?? 0) >= 2048, "ordinary app turn saves an eligible checkpoint")
        try require(first.text.contains("111"), "first inventory answer is correct")
        await engine.unload()
        history += [ChatMessage(role: "assistant", content: first.text), ChatMessage(role: "user", content: "And crate 12? Just the number.")]
        let warm = try await ask(history)
        let warmStats = await engine.lastStats[0]
        try require((warmStats.persistentPrefix?.restoredTokens ?? 0) >= 2048, "app reload restores a real disk checkpoint")
        try require(warm.text.contains("36"), "restored inventory answer is correct")
        let privateContext = InferenceCacheContext(home: home, thread: WorkThread(title: "Private", mode: .incognito), thinking: false)
        try await engine.prepareCache(privateContext)
        let before = try files()
        let cold = try await ask(history)
        let coldStats = await engine.lastStats[0]
        try require(cold.text == warm.text && coldStats.reusedPrefixTokens == 0, "private context drops held state and matches cold output")
        let afterPrivate = try files()
        try require(coldStats.persistentPrefix == nil && afterPrivate == before, "incognito neither restores nor changes disk cache")
        try require(warmStats.prefillTokens < coldStats.prefillTokens, "disk hit avoids real prompt work")

        // Direct callers are protected even without another prepareCache call.
        try await engine.prepareCache(context)
        let beforeThought = try files()
        _ = try await ask([ChatMessage(role: "user", content: "What is 17 times 23? Answer with the number.")],
            thinking: ThinkingRequest(level: ThinkingPolicy.level, budgetTokens: 8, replyTokens: 256, seed: 5))
        let thoughtStats = await engine.lastStats
        try require(thoughtStats.count == 2 && thoughtStats.allSatisfy { $0.persistentPrefix == nil }, "direct thinking call detaches disk before encoding")
        try require(([firstStats, warmStats, coldStats] + thoughtStats).allSatisfy { $0.peakMemoryGB <= 10 },
            "app cache and both phases stay within the 10 GB process limit")
        let afterThought = try files()
        try require(afterThought == beforeThought, "thought transition leaves all cache files byte-identical")
        print(String(decoding: try JSONSerialization.data(withJSONObject: [
            "saved_tokens": firstStats.persistentPrefix?.savedTokens ?? 0,
            "restored_tokens": warmStats.persistentPrefix?.restoredTokens ?? 0,
            "warm_read_tokens": warmStats.prefillTokens, "cold_read_tokens": coldStats.prefillTokens,
            "warm_read_seconds": warmStats.prefillSeconds, "cold_read_seconds": coldStats.prefillSeconds,
            "answer": warm.text, "privacy_files_unchanged": true,
            "peak_physical_gb": ([firstStats, warmStats, coldStats] + thoughtStats).map(\.peakMemoryGB).max() ?? 0,
            "disk_files_before_private": before, "disk_files_after_private": afterPrivate,
            "disk_files_before_thinking": beforeThought, "disk_files_after_thinking": afterThought
        ], options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
        await engine.unload()
        return true
    } catch { await engine.unload(); throw error }
}
