// One versioned empirical envelope for planning, reporting and dispatch guards.
// These are the existing conservative allowances and throughput anchors. This
// consolidation grants no new memory credit and claims no new speedup. Update
// the family only with a complete measured envelope and policy comparison.
package enum PlannerCostModel {
    package static let identity = "m5-pro-reference-envelope-v1"
    package static let fixedBytes = 5_300_000_000
    package static let planningMarginBytes = 1_000_000_000
    package static let prefillBytesPerToken = 1_300_000
    package static let mtpResidentBytes = 1_600_000_000
    /// The draft head's routed experts: 512 records of 2,764,800 bytes, the
    /// same geometry as the main model's. A streamed head keeps its other
    /// weights, a cache of `mtpStreamSlots` records and one row of read
    /// scratch (top 10) resident; the resident charge's allowance above the
    /// file size carries over unchanged.
    package static let mtpExpertCount = 512
    package static let mtpExpertBytes = 2_764_800
    package static let mtpStreamSlots = 64
    package static let mtpStreamScratchExperts = 10
    package static let mtpStreamedBytes = mtpResidentBytes - mtpExpertCount * mtpExpertBytes
        + (mtpStreamSlots + mtpStreamScratchExperts) * mtpExpertBytes
    package static let visionResidentBytes = 900_000_000
    package static let visionLoadMarginBytes = 1_000_000_000
    package static let tuningPromptTokens = 2000.0
    package static let tuningReplyTokens = 400.0
    package static let decodeLowExpertsPerLayer = 30.0
    package static let decodeLowTokensPerSecond = 6.0
    package static let decodePlateauPerLayer = 150.0
    package static let decodePlateauTokensPerSecond = 11.6
    package static let prefill256TokensPerSecond = 85.0
    package static let prefill512TokensPerSecond = 125.0
    package static let prefill1024TokensPerSecond = 165.0
    package static let prefill2048TokensPerSecond = 205.0
    package static let prefill4096TokensPerSecond = 220.0
}
