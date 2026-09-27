// Gates for the decode paths that overlap waiting: demand misses read straight
// into their pool slots, and the GPU kept awake while a generation runs. Both
// must leave the arithmetic untouched, and the direct reads must recover from
// a failed read without leaving a stale or partial slot behind.

import ArgumentParser
import Foundation
import SlotstreamDiagnostics

struct DecodeOverlapCheck: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "decode-overlap-check",
        abstract: "Prove direct demand reads and the GPU keepalive leave outputs exact and recover from read failures")
    @OptionGroup var model: ModelOptions
    @Option(help: "Tokens to generate per run")
    var tokens: Int = 24

    func run() throws {
        var failed = false
        for report in try Diagnostics.decodeOverlap(modelDir: model.modelURL, tokens: tokens) {
            for item in report.items {
                print("\(item.passed ? "PASS" : "FAIL")  \(report.name): \(item.name)\(item.passed ? "" : "  \(item.detail ?? "")")")
            }
            if !report.passed { failed = true }
        }
        if failed { throw ExitCode(2) }
        print("DECODE OVERLAP CHECK PASS")
    }
}
