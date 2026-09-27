// What a request's death must leave behind in the log.
//
// serve.log's request lines are the only record a user has after a run, and a
// failure code is not evidence: on 2026-09-24 a 0.6 s refusal of an initial
// state allocation and a 5.5-minute prefill killed at 87% both read
// `insufficient_memory`, and nothing in the log told them apart. The message,
// the failing phase and the refusal quantities are what make the line usable.

import Foundation
import Slotstream

extension Diagnostics {
    public static func failureDiagnostics() -> CheckReport {
        var c = CheckBuilder("failure-diagnostics")

        // The refusal the log could not explain: which guard, and by how much.
        var memory = RequestFailure(.insufficientMemory,
            "insufficient memory for initial state allocation, queued requests and safety headroom; retry after other requests finish")
        memory.requiredBytes = 21_430_000_000
        memory.availableBytes = 19_870_000_000
        let refusal = memory.diagnosticDetail(phase: "initial state allocation")
        c.expect("the code is in the line", refusal.contains("insufficient_memory"), refusal)
        c.expect("the reason is in the line", refusal.contains("retry after other requests finish"), refusal)
        c.expect("the guard that refused it is in the line", refusal.contains("initial state allocation"), refusal)
        c.expect("the shortfall is in the line",
            refusal.contains("required 21.43 GB") && refusal.contains("available 19.87 GB"), refusal)

        // A failure that carries no quantities still names its code, reason and
        // phase — and must not grow an empty bracket where they would go.
        let deadline = RequestFailure(.prefillDeadlineExceeded, "the prefill deadline passed")
        c.equal("a failure without quantities stays one clean line",
            deadline.diagnosticDetail(phase: "prefill pass"),
            ", prefill_deadline_exceeded: the prefill deadline passed [phase prefill pass]")
        return c.report()
    }
}
