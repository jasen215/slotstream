// Expert Lookahead: causal pass/position events, the per-model session that
// routes them, and the demand-time bookkeeping the collector and the bounded
// prefetch runtime share. Nothing here changes routing, expert bytes or math:
// the session observes existing boundaries (pass start, completed layer,
// demand reservation, reconciliation) and, when a prefetch scheduler is
// installed, hands it forecasts and layer-completion ticks.
//
// The three forecast positions of a depth-two verification pass are causal:
// position zero is the committed main multi stream plus the pending token's
// embedding; positions one and two are the draft head's proxy multis after
// consuming the pending token and the first draft, each with the next draft's
// embedding. All of them exist before `allLogitsWithMultiChecked` runs. No
// feature ever comes from the pass it forecasts.

import Foundation
import MLX

package enum ExpertLookaheadPhase: String, Codable {
    case prefill
    case mainVerify = "main-verify"
    case mainPlain = "main-plain"
}

/// One forecast position's inputs. `kind` 0 is the committed main state and
/// the pending token; 1 and 2 are draft-head proxies with draft embeddings.
package struct ExpertLookaheadStartFeature {
    package let kind: Int
    package let token: Int
    package let context: MLXArray
    package let embedding: MLXArray
    package init(kind: Int, token: Int, context: MLXArray, embedding: MLXArray) {
        self.kind = kind; self.token = token; self.context = context; self.embedding = embedding
    }
}

/// What one `ensureCore` call demanded and how it was served. Expert IDs are
/// within `layer`; a mixed-layer diagnostic request records `mixedLayers`.
package struct ExpertLookaheadDemandEvent {
    package var pass: Int
    package var layer: Int
    package var mixedLayers: Bool
    package var uniqueExperts: [Int32]
    package var hitExperts: [Int32]
    package var missExperts: [Int32]
    package var victimSlots: [Int32]
    package var adoptedExperts: [Int32]
    package var promotedExperts: [Int32]
    package var startNanos: UInt64
    package var readNanos: UInt64
    package var adoptNanos: UInt64
    package var endNanos: UInt64
}

/// Exact pool residency at a replay boundary: one key per slot (layer * 512
/// + expert, or -1), the CLOCK reference bits and the hand.
package struct ExpertLookaheadResidency {
    package var slotKeys: [Int32]
    package var referenceBits: [Bool]
    package var hand: Int
    package init(slotKeys: [Int32], referenceBits: [Bool], hand: Int) {
        self.slotKeys = slotKeys; self.referenceBits = referenceBits; self.hand = hand
    }
}

package protocol ExpertLookaheadObserver: AnyObject {
    func beginPass(id: Int, phase: ExpertLookaheadPhase, tokens: [Int], features: [ExpertLookaheadStartFeature], nanos: UInt64)
    func routes(pass: Int, layer: Int, rows: Int, topK: Int, ids: [Int32])
    func layerCompleted(pass: Int, layer: Int, x2: MLXArray, nanos: UInt64)
    func demand(_ event: ExpertLookaheadDemandEvent)
    func admissions(pass: Int, layer: Int, experts: [Int32])
    func residency(_ snapshot: ExpertLookaheadResidency, afterPass: Int)
    func passReconciled(id: Int, kept: Int)
    func endPass(id: Int, nanos: UInt64, aborted: Bool)
    /// Router-reuse forecast: target `targetLayer`'s router applied to the
    /// streams read at `tap` of `sourceLayer` (for the boundary tap, stride 0
    /// is the C12 self-check). `ids` holds `rows * candidatesPerRow` expert IDs
    /// in rank order with one margin each (logit minus the row's tenth logit);
    /// `inputs` carries the target's mixed input rows only when the capture
    /// asks for them.
    func forecast(pass: Int, sourceLayer: Int, targetLayer: Int, tap: RouterForecastTap, rows: Int, ids: [Int32],
                  margins: [Float], inputs: MLXArray?)
}

extension ExpertLookaheadObserver {
    package func forecast(pass: Int, sourceLayer: Int, targetLayer: Int, tap: RouterForecastTap, rows: Int, ids: [Int32],
                          margins: [Float], inputs: MLXArray?) {}
}

/// Where a router-reuse forecast reads the residual streams.
///
/// `boundary`, the qualified default, reads them after `sourceLayer`'s MoE add,
/// for targets `sourceLayer + stride`. The attention taps read the streams of
/// the layer just before the target (`sourceLayer = target - 1`) once that
/// layer's attention output has been added, and ride that layer's routing
/// readback. Between deferred barriers a stride-2 boundary forecast arrives at
/// that same readback, so an attention tap arrives as early while missing one
/// layer's routed experts and the target's attention instead of two whole
/// layers. `attentionShared` also adds that layer's shared expert, which is
/// resident and needs no routing.
package enum RouterForecastTap: String, CaseIterable {
    case boundary
    case attention
    case attentionShared = "attention-shared"
    /// The attention tap with a learned correction of its logits
    /// (`RouterTapCorrection`); it is evaluated only when a correction is loaded.
    case attentionCorrected = "attention-corrected"
    /// The attention tap plus the target's own attention sublayer, run on
    /// that approximate input against the target's caches without writing
    /// them (`Qwen4ExpModel.readoutForecast`): what stays missing is the
    /// source layer's routed experts.
    case attentionReadout = "attention-readout"
    /// The same readout on the streams after the source layer's MoE add,
    /// the target's exact input: a self-check that should reproduce the
    /// target's routing. Observer only; never a scheduler tap.
    case boundaryReadout = "boundary-readout"
    /// The readout tap with a learned correction of its logits, fitted on the
    /// readout's input; evaluated only when such a correction is loaded.
    case attentionReadoutCorrected = "attention-readout-corrected"

    /// Stable code for the capture's forecast record (see the collector).
    package var code: UInt32 {
        switch self {
        case .boundary: return 0
        case .attention: return 1
        case .attentionShared: return 2
        case .attentionCorrected: return 3
        case .attentionReadout: return 4
        case .boundaryReadout: return 5
        case .attentionReadoutCorrected: return 6
        }
    }

    /// The taps that apply a loaded correction, and so evaluate only with one.
    package var isCorrected: Bool { self == .attentionCorrected || self == .attentionReadoutCorrected }
}

/// Per-model routing of lookahead events. Owned by the model, called only on
/// the serialized model thread. A session without observer or scheduler does
/// nothing and allocates nothing; the generator checks `wantsStartFeatures`
/// before materializing any extra embedding.
package final class ExpertLookaheadSession {
    package var observer: ExpertLookaheadObserver?
    package var prefetch: ExpertPrefetchScheduler?
    package private(set) var currentPass = -1
    package private(set) var currentPhase: ExpertLookaheadPhase?
    /// The most recently ended pass: replay boundaries are stamped with it.
    package private(set) var lastEndedPass = -1
    private var nextPass = 0
    package private(set) var passesForecast = 0
    private var passTokens: [Int] = []
    /// Router-reuse forecast controls. The strides come from the router
    /// prefetch policy when one is installed, otherwise from an observer-only
    /// list set by the capture command; stride 0 (the self-check) and the
    /// optional input capture are diagnostics set by the capture command.
    package var observerForecastStrides: [Int] = []
    /// Observer-only attention taps and candidates per row, also set by the
    /// capture command. An installed router policy uses its own tap and top.
    package var observerForecastTaps: [RouterForecastTap] = []
    package var observerCandidatesPerRow = 10
    package var forecastSelfCheck = false
    package var captureForecastInputs = false
    /// Plain decode passes forecast and prefetch like verification passes.
    /// The engine sets it when a plan runs the lookahead without the draft
    /// head; with the head, plain passes stay exactly as they were.
    package var forecastsPlainPasses = false
    /// The capture command's correction for an observer-only corrected tap.
    package var observerTapCorrection: RouterTapCorrection?

    package init() {}

    /// The correction the corrected attention tap applies: the installed
    /// scheduler's own when it has one, otherwise the capture command's.
    package var tapCorrection: RouterTapCorrection? { prefetch?.tapCorrection ?? observerTapCorrection }

    /// The installed policy's placement of the readout tap's evaluation
    /// (`ExpertPrefetchConfiguration.readoutAfterDemand`); observers keep the readback.
    package var readoutAfterDemand: Bool { prefetch?.configuration.readoutAfterDemand ?? false }

    /// The installed router policy's tap, if a router policy is installed.
    private var schedulerTap: RouterForecastTap? {
        guard let prefetch, prefetch.usesRouterForecast else { return nil }
        return prefetch.configuration.tap
    }

    package var routerForecastStrides: [Int] {
        if let prefetch, prefetch.usesRouterForecast {
            // A policy on an attention tap reads no boundary strides of its own.
            return prefetch.configuration.tap == .boundary ? prefetch.configuration.strides : observerForecastStrides
        }
        return observerForecastStrides
    }
    package var forecastCandidatesPerRow: Int {
        if let prefetch, prefetch.usesRouterForecast { return prefetch.configuration.topPerLayer }
        return observerCandidatesPerRow
    }
    /// Main verification passes forecast, and plain decode passes when
    /// `forecastsPlainPasses` is set; prefill never does.
    package var wantsRouterForecast: Bool {
        forecasts(currentPhase) && (forecastSelfCheck || !routerForecastStrides.isEmpty)
    }
    package func forecasts(_ phase: ExpertLookaheadPhase?) -> Bool {
        phase == .mainVerify || (forecastsPlainPasses && phase == .mainPlain)
    }
    /// The attention taps a main verification pass evaluates: the policy's tap
    /// when it is not the boundary, then the observer-only taps. The corrected
    /// tap is evaluated only when a correction is loaded.
    package var attentionForecastTaps: [RouterForecastTap] {
        guard forecasts(currentPhase) else { return [] }
        // A corrected tap evaluates only with a correction fitted for it.
        let served = tapCorrection?.correctedTap
        func evaluates(_ tap: RouterForecastTap) -> Bool { tap != .boundary && (!tap.isCorrected || served == tap) }
        var taps: [RouterForecastTap] = []
        if let tap = schedulerTap, evaluates(tap) { taps.append(tap) }
        for tap in observerForecastTaps where evaluates(tap) && !taps.contains(tap) { taps.append(tap) }
        return taps
    }

    /// Hand one target's forecast to the observer and, when it comes from the
    /// policy's own tap (for the boundary tap, at one of its strides), to the
    /// scheduler. Called on the model thread before the source layer's tick;
    /// an attention tap arrives before the source layer's demand.
    package func forecast(sourceLayer: Int, targetLayer: Int, tap: RouterForecastTap = .boundary, rows: Int,
                          ids: [Int32], margins: [Float], inputs: MLXArray?) {
        guard currentPass >= 0 else { return }
        observer?.forecast(pass: currentPass, sourceLayer: sourceLayer, targetLayer: targetLayer, tap: tap, rows: rows,
                           ids: ids, margins: margins, inputs: inputs)
        guard targetLayer > sourceLayer, forecasts(currentPhase), let prefetch else { return }
        if let policyTap = schedulerTap {
            guard policyTap == tap,
                  tap != .boundary || prefetch.configuration.strides.contains(targetLayer - sourceLayer) else { return }
        }
        prefetch.forecast(target: targetLayer, ids: ids, margins: margins)
    }

    package var isActive: Bool { observer != nil || prefetch != nil }
    /// Prefetch and the collector both need the three-position features.
    package var wantsStartFeatures: Bool { observer != nil || (prefetch?.wantsForecast ?? false) }
    package var inMainPass: Bool { currentPhase == .mainVerify || currentPhase == .mainPlain }

    @discardableResult
    package func beginPass(phase: ExpertLookaheadPhase, tokens: [Int],
                           features: [ExpertLookaheadStartFeature]) -> Int {
        let id = nextPass
        nextPass += 1
        currentPass = id
        currentPhase = phase
        passTokens = tokens
        let now = RuntimeClock.now()
        observer?.beginPass(id: id, phase: phase, tokens: tokens, features: features, nanos: now)
        if let prefetch, forecasts(phase) {
            prefetch.beginPass(id: id, features: features)
            passesForecast += 1
        }
        return id
    }

    package func routes(layer: Int, rows: Int, topK: Int, ids: [Int32]) {
        guard currentPass >= 0 else { return }
        observer?.routes(pass: currentPass, layer: layer, rows: rows, topK: topK, ids: ids)
        if inMainPass { prefetch?.observeRoutes(layer: layer, ids: ids) }
    }

    package func layerCompleted(layer: Int, x2: MLXArray) {
        guard currentPass >= 0 else { return }
        let now = RuntimeClock.now()
        observer?.layerCompleted(pass: currentPass, layer: layer, x2: x2, nanos: now)
        if inMainPass { prefetch?.layerCompleted(layer) }
    }

    package func demand(_ event: ExpertLookaheadDemandEvent) {
        observer?.demand(event)
    }

    package func admissions(layer: Int, experts: [Int32]) {
        observer?.admissions(pass: currentPass, layer: layer, experts: experts)
    }

    package func residency(_ snapshot: ExpertLookaheadResidency) {
        observer?.residency(snapshot, afterPass: currentPass >= 0 ? currentPass : lastEndedPass)
    }

    package func passReconciled(kept: Int) {
        guard currentPass >= 0 else { return }
        observer?.passReconciled(id: currentPass, kept: kept)
    }

    package func endPass(aborted: Bool = false) {
        guard currentPass >= 0 else { return }
        let now = RuntimeClock.now()
        observer?.endPass(id: currentPass, nanos: now, aborted: aborted)
        if inMainPass { prefetch?.passEnded() }
        lastEndedPass = currentPass
        currentPass = -1
        currentPhase = nil
        passTokens = []
    }

    /// Request completion, error or cancellation: no future-pass ticket may
    /// survive into the next request, and every owned reader is joined.
    package func requestFinished() {
        if currentPass >= 0 { endPass(aborted: true) }
        prefetch?.requestFinished()
    }
}
