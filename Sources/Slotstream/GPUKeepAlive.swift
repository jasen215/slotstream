import Foundation
import IOKit.ps
import Metal

/// Keeps the GPU busy while a generation runs.
///
/// Streamed decode is stop-and-go: at every layer the host reads the routing
/// back, reads the missing experts and only then submits the next burst. In
/// those gaps an idle Apple GPU lowers its clock. On an M5 Pro a small kernel
/// that takes 49 µs back to back took 230 µs after a 200 µs gap, and the next
/// buffer started 0.12 ms after commit after that gap and 0.62 ms after a 5 ms
/// one. A one-thread kernel that polls a flag, resubmitted on its own command
/// queue, keeps the GPU from idling: 52 µs and 0.07 ms. It computes nothing
/// and touches no model memory, so outputs are unchanged.
///
/// Measured on the M5 Pro 48 GB, paired and interleaved, over pairs with no
/// swap activity: decode 1.11x faster with the draft head at a 22 GB target,
/// 1.07x without it at 10 GB, and 1.28x there with direct demand reads. The
/// cost is power: energy per generated token rose 7.1% at 16 GB (IOReport).
/// So `auto`, the default, runs it on AC power outside Low Power Mode only.
/// db/records/decisions/gpu-keepalive-on-ac-power.md
public final class GPUKeepAlive: @unchecked Sendable {
    /// When a generation keeps the GPU awake.
    public enum Policy: String, Codable, Sendable, CaseIterable {
        /// On AC power outside Low Power Mode; off on battery.
        case auto
        case on
        case off
    }

    /// What `auto` looks at, read at the start of each generation.
    public struct PowerState: Equatable, Sendable {
        public var onBattery: Bool
        public var lowPowerMode: Bool

        public init(onBattery: Bool, lowPowerMode: Bool) {
            self.onBattery = onBattery
            self.lowPowerMode = lowPowerMode
        }

        /// The providing power source and Low Power Mode right now. A Mac
        /// without a battery reports AC power.
        public static var current: PowerState {
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
            let source = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
            return PowerState(onBattery: source == kIOPMBatteryPowerKey,
                              lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled)
        }
    }

    /// Whether a generation starting under `power` keeps the GPU awake.
    public static func keepsAwake(_ policy: Policy, power: @autoclosure () -> PowerState) -> Bool {
        switch policy {
        case .on: return true
        case .off: return false
        case .auto:
            let state = power()
            return !state.onBattery && !state.lowPowerMode
        }
    }

    /// `SLOTSTREAM_GPU_KEEPALIVE`, `auto` when unset.
    public static func environmentPolicy(_ env: [String: String] = ProcessInfo.processInfo.environment) throws -> Policy {
        guard let raw = env["SLOTSTREAM_GPU_KEEPALIVE"] else { return .auto }
        guard let policy = Policy(rawValue: raw) else {
            throw ModelError("SLOTSTREAM_GPU_KEEPALIVE must be auto, on or off (got \(raw))")
        }
        return policy
    }

    /// The process-wide instance, built on first use; nil without Metal.
    public static let shared: GPUKeepAlive? = GPUKeepAlive()

    /// Flag polls per command buffer. One buffer lasts tens of milliseconds,
    /// so an ended generation releases the GPU within one buffer.
    static let iterations: UInt32 = 200_000

    private let queue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let flag: MTLBuffer
    private let condition = NSCondition()
    private var holders = 0
    private var buffers = 0

    private init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return nil }
        let source = """
            #include <metal_stdlib>
            using namespace metal;
            kernel void slotstream_keepalive(device atomic_uint* flag [[buffer(0)]],
                                             constant uint& iterations [[buffer(1)]],
                                             uint i [[thread_position_in_grid]]) {
              for (uint j = 0; j < iterations; j++) {
                if (atomic_load_explicit(flag, memory_order_relaxed) != 0u) break;
              }
            }
            """
        guard let library = try? device.makeLibrary(source: source, options: nil),
              let function = library.makeFunction(name: "slotstream_keepalive"),
              let pipeline = try? device.makeComputePipelineState(function: function),
              let flag = device.makeBuffer(length: 16, options: .storageModeShared) else { return nil }
        self.queue = queue
        self.pipeline = pipeline
        self.flag = flag
        flag.contents().storeBytes(of: UInt32(1), as: UInt32.self)
        let thread = Thread { [unowned self] in self.run() }
        thread.qualityOfService = .userInitiated
        thread.name = "slotstream.gpu-keepalive"
        thread.start()
    }

    /// Start keeping the GPU awake; calls nest.
    public func begin() {
        condition.lock()
        holders += 1
        if holders == 1 {
            flag.contents().storeBytes(of: UInt32(0), as: UInt32.self)
            condition.signal()
        }
        condition.unlock()
    }

    /// Balance one `begin`. The last one stops the running buffer early.
    public func end() {
        condition.lock()
        holders = max(0, holders - 1)
        if holders == 0 {
            flag.contents().storeBytes(of: UInt32(1), as: UInt32.self)
            condition.signal()
        }
        condition.unlock()
    }

    /// Command buffers submitted so far, for checks.
    public var submittedBuffers: Int {
        condition.lock(); defer { condition.unlock() }
        return buffers
    }

    private func submit() -> MTLCommandBuffer? {
        guard let buffer = queue.makeCommandBufferWithUnretainedReferences(),
              let encoder = buffer.makeComputeCommandEncoder() else { return nil }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(flag, offset: 0, index: 0)
        var count = Self.iterations
        encoder.setBytes(&count, length: MemoryLayout<UInt32>.size, index: 1)
        encoder.dispatchThreads(MTLSize(width: 1, height: 1, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        encoder.endEncoding()
        buffer.commit()
        condition.lock(); buffers += 1; condition.unlock()
        return buffer
    }

    /// Two buffers in flight while anyone holds it, so the GPU never waits on
    /// this thread; none, and the thread asleep, otherwise.
    private func run() {
        var inFlight: [MTLCommandBuffer] = []
        while true {
            condition.lock()
            if holders == 0 {
                condition.unlock()
                for buffer in inFlight { buffer.waitUntilCompleted() }
                inFlight.removeAll()
                condition.lock()
                while holders == 0 { condition.wait() }
            }
            condition.unlock()
            while inFlight.count < 2, let buffer = submit() { inFlight.append(buffer) }
            guard let first = inFlight.first else {
                // Metal refused a buffer; stop rather than spin on the CPU.
                condition.lock()
                while holders > 0 { condition.wait() }
                condition.unlock()
                continue
            }
            first.waitUntilCompleted()
            inFlight.removeFirst()
        }
    }
}
