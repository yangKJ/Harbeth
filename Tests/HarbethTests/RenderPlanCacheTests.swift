import XCTest
import Metal
@testable import Harbeth

final class RenderPlanCacheTests: XCTestCase {

    override func setUp() {
        super.setUp()
        HarbethContext.shared.textureAllocationStrategy = .exact
        // Ensure each test starts with a clean RenderPlan cache so we can
        // deterministically observe hits and misses.
        HarbethContext.shared.removeAllRenderPlans()
    }

    override func tearDown() {
        HarbethContext.shared.textureAllocationStrategy = .exact
        HarbethContext.shared.removeAllRenderPlans()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeTexture(width: Int = 4, height: Int = 4) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw XCTSkip("Could not create Metal texture.")
        }
        let bytes = [UInt8](repeating: 128, count: width * height * 4)
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func makeFilterChainNode() throws -> ImageNode {
        let texture = try makeTexture()
        return ImageNode
            .source(.texture(texture))
            .applying(filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.05)
            ])
    }

    /// Builds a real `RenderPlan` so we can exercise the LRU bookkeeping
    /// without hand-constructing every field of the plan/diagnostics.
    ///
    /// `ImageNode.makeRenderPlan` stores its result in the RenderPlan cache
    /// as a side effect. Tests that observe absolute cache counts must see
    /// a clean cache afterwards, so we drop that implicit entry before
    /// returning. Tests that want to exercise the implicit-write path
    /// call `makeRenderPlan` themselves instead.
    private func makeRealPlanStub() throws -> RenderPlan {
        let node = try makeFilterChainNode()
        let plan = try node.makeRenderPlan(profile: .stablePreview)
        HarbethContext.shared.removeAllRenderPlans()
        return plan
    }

    // MARK: - Cache key construction

    func testCacheKeyIsStableForSameInputs() {
        let key1 = ImageNode.makeRenderPlanCacheKey(
            nodeFingerprint: "node|abc",
            profile: .stablePreview,
            derivative: RenderProfile.stablePreview.defaultDerivativeSpec,
            samplerDescriptor: .default
        )
        let key2 = ImageNode.makeRenderPlanCacheKey(
            nodeFingerprint: "node|abc",
            profile: .stablePreview,
            derivative: RenderProfile.stablePreview.defaultDerivativeSpec,
            samplerDescriptor: .default
        )
        XCTAssertEqual(key1, key2)
        XCTAssertTrue(key1.contains("profile=stablePreview"))
        XCTAssertTrue(key1.contains("derivative=\(RenderProfile.stablePreview.defaultDerivativeSpec.fingerprint)"))
    }

    func testCacheKeyChangesWithNodeFingerprint() {
        let key1 = ImageNode.makeRenderPlanCacheKey(
            nodeFingerprint: "node|abc",
            profile: .stablePreview,
            derivative: RenderProfile.stablePreview.defaultDerivativeSpec,
            samplerDescriptor: .default
        )
        let key2 = ImageNode.makeRenderPlanCacheKey(
            nodeFingerprint: "node|xyz",
            profile: .stablePreview,
            derivative: RenderProfile.stablePreview.defaultDerivativeSpec,
            samplerDescriptor: .default
        )
        XCTAssertNotEqual(key1, key2)
    }

    func testCacheKeyChangesWithProfile() {
        let stableKey = ImageNode.makeRenderPlanCacheKey(
            nodeFingerprint: "node|abc",
            profile: .stablePreview,
            derivative: RenderProfile.stablePreview.defaultDerivativeSpec,
            samplerDescriptor: .default
        )
        let exportKey = ImageNode.makeRenderPlanCacheKey(
            nodeFingerprint: "node|abc",
            profile: .exportQuality,
            derivative: RenderProfile.exportQuality.defaultDerivativeSpec,
            samplerDescriptor: .default
        )
        XCTAssertNotEqual(stableKey, exportKey)
    }

    func testCacheKeyChangesWithDerivativeSpec() {
        let customDerivative = ImageDerivativeSpec(
            name: "custom-thumb",
            renderIntent: .delivery,
            sourceTier: .thumbnail,
            semantic: RenderProfile.stablePreview.defaultDerivativeSpec.semantic,
            outputSizePolicy: .maxPixelSize(160)
        )
        let defaultKey = ImageNode.makeRenderPlanCacheKey(
            nodeFingerprint: "node|abc",
            profile: .stablePreview,
            derivative: RenderProfile.stablePreview.defaultDerivativeSpec,
            samplerDescriptor: .default
        )
        let customKey = ImageNode.makeRenderPlanCacheKey(
            nodeFingerprint: "node|abc",
            profile: .stablePreview,
            derivative: customDerivative,
            samplerDescriptor: .default
        )
        XCTAssertNotEqual(defaultKey, customKey)
        XCTAssertTrue(customKey.contains("derivative=\(customDerivative.fingerprint)"))
    }

    func testCacheKeyChangesWhenSameNamedDerivativeChangesStructure() {
        let sourceDerivative = ImageDerivativeSpec(
            name: "same-name",
            renderIntent: .stable,
            sourceTier: .stableReusable,
            semantic: RenderProfile.stablePreview.defaultDerivativeSpec.semantic,
            outputSizePolicy: .source
        )
        let thumbnailDerivative = ImageDerivativeSpec(
            name: "same-name",
            renderIntent: .stable,
            sourceTier: .stableReusable,
            semantic: RenderProfile.stablePreview.defaultDerivativeSpec.semantic,
            outputSizePolicy: .maxPixelSize(160)
        )

        let sourceKey = ImageNode.makeRenderPlanCacheKey(
            nodeFingerprint: "node|abc",
            profile: .stablePreview,
            derivative: sourceDerivative,
            samplerDescriptor: .default
        )
        let thumbnailKey = ImageNode.makeRenderPlanCacheKey(
            nodeFingerprint: "node|abc",
            profile: .stablePreview,
            derivative: thumbnailDerivative,
            samplerDescriptor: .default
        )

        XCTAssertNotEqual(sourceKey, thumbnailKey)
    }

    func testCacheKeyChangesWithSamplerDescriptor() {
        let linearKey = ImageNode.makeRenderPlanCacheKey(
            nodeFingerprint: "node|abc",
            profile: .stablePreview,
            derivative: RenderProfile.stablePreview.defaultDerivativeSpec,
            samplerDescriptor: .default
        )
        let nearestKey = ImageNode.makeRenderPlanCacheKey(
            nodeFingerprint: "node|abc",
            profile: .stablePreview,
            derivative: RenderProfile.stablePreview.defaultDerivativeSpec,
            samplerDescriptor: .nearest
        )
        XCTAssertNotEqual(linearKey, nearestKey)
    }

    func testRecipeResolutionFingerprintChangesWithLocalEffectsAndLoadingOptions() throws {
        let mask = try makeTexture(width: 1, height: 1)
        let source = ImageSource.asset(
            ImageAsset(
                storage: .data(Data(repeating: 7, count: 16)),
                loadingOptions: .default
            )
        )
        let baseNode = ImageNode.recipe(source: source, recipe: EditRecipe())
        let changedNode = ImageNode.recipe(
            source: source,
            recipe: EditRecipe(
                sourceLoadingOptions: ImageLoadingOptions(sizePolicy: .maxPixelSize(512), flipsVertically: true),
                localEffects: [
                    LocalEffectRecipe(
                        filters: [C7Brightness(brightness: 0.1)],
                        mask: MaskDescriptor(texture: mask, opacity: 1),
                        foregroundBlendType: .normal,
                        foregroundBlendOpacity: 0.4
                    )
                ]
            )
        )

        let baseFingerprint = baseNode.resolutionFingerprint(profile: RenderProfile.stablePreview)
        let changedFingerprint = changedNode.resolutionFingerprint(profile: RenderProfile.stablePreview)

        XCTAssertNotEqual(baseFingerprint, changedFingerprint)
        XCTAssertTrue(changedFingerprint.contains("flip=1"))
        XCTAssertTrue(changedFingerprint.contains("localEffects="))
    }

    // MARK: - Context API

    func testCachedRenderPlanReturnsNilForUnknownKey() {
        XCTAssertNil(HarbethContext.shared.cachedRenderPlan(for: "missing"))
    }

    func testStoreRenderPlanThenCacheHit() throws {
        let plan = try makeRealPlanStub()
        let key = "stub-key"
        HarbethContext.shared.storeRenderPlan(plan, for: key)
        let hit = HarbethContext.shared.cachedRenderPlan(for: key)
        XCTAssertNotNil(hit)
        // RenderPlan is a value type — verify structural equivalence.
        XCTAssertEqual(hit?.profile, plan.profile)
        XCTAssertEqual(hit?.diagnostics.profile, plan.diagnostics.profile)
    }

    func testCacheCountReflectsStoredEntries() throws {
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), 0)
        let plan = try makeRealPlanStub()
        // `makeRealPlanStub` clears the cache after building so we can observe
        // absolute counts; the baseline must therefore be zero.
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), 0)
        HarbethContext.shared.storeRenderPlan(plan, for: "k1")
        HarbethContext.shared.storeRenderPlan(plan, for: "k2")
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), 2)
        HarbethContext.shared.removeAllRenderPlans()
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), 0)
    }

    func testCacheRespectsLRULimit() throws {
        let plan = try makeRealPlanStub()
        let limit = 100
        for index in 0..<(limit + 5) {
            HarbethContext.shared.storeRenderPlan(plan, for: "k-\(index)")
        }
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), limit)
        // The oldest entries (k-0..k-4) must have been evicted.
        XCTAssertNil(HarbethContext.shared.cachedRenderPlan(for: "k-0"))
        XCTAssertNil(HarbethContext.shared.cachedRenderPlan(for: "k-4"))
        // The newest entries survive.
        XCTAssertNotNil(HarbethContext.shared.cachedRenderPlan(for: "k-\(limit + 4)"))
    }

    func testLRUHitPromotesEntryToMostRecent() throws {
        let plan = try makeRealPlanStub()
        // Insert A, B, C — order should be [A, B, C].
        HarbethContext.shared.storeRenderPlan(plan, for: "A")
        HarbethContext.shared.storeRenderPlan(plan, for: "B")
        HarbethContext.shared.storeRenderPlan(plan, for: "C")

        // Touch A — moves it to most-recent. Order should become [B, C, A].
        XCTAssertNotNil(HarbethContext.shared.cachedRenderPlan(for: "A"))

        // Force eviction by inserting 98 more entries (filling up to 101).
        // The cache holds at most `renderPlanCacheLimit` entries (100), so the
        // oldest entry gets evicted on the 101st store.
        for index in 0..<98 {
            HarbethContext.shared.storeRenderPlan(plan, for: "fill-\(index)")
        }
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), 100)

        // B (now the oldest) should be evicted; A and C must still be present.
        XCTAssertNil(HarbethContext.shared.cachedRenderPlan(for: "B"))
        XCTAssertNotNil(HarbethContext.shared.cachedRenderPlan(for: "A"))
        XCTAssertNotNil(HarbethContext.shared.cachedRenderPlan(for: "C"))
    }

    func testResetCachesClearsRenderPlanCache() throws {
        let plan = try makeRealPlanStub()
        HarbethContext.shared.storeRenderPlan(plan, for: "k")
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), 1)
        HarbethContext.shared.resetCaches()
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), 0)
    }

    func testAllocationStrategyChangeInvalidatesRenderPlanCache() throws {
        let plan = try makeRealPlanStub()
        HarbethContext.shared.storeRenderPlan(plan, for: "strategy-sensitive")

        HarbethContext.shared.textureAllocationStrategy = .tolerant

        XCTAssertNil(HarbethContext.shared.cachedRenderPlan(for: "strategy-sensitive"))
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), 0)
    }

    func testDebugSnapshotIncludesRenderPlanCount() throws {
        let plan = try makeRealPlanStub()
        HarbethContext.shared.storeRenderPlan(plan, for: "k")
        let snapshot = HarbethContext.shared.debugCacheSnapshot()
        XCTAssertEqual(snapshot.renderPlanCount, 1)
    }

    // MARK: - Integration via ImageNode.makeRenderPlan

    func testMakeRenderPlanCachesResultOnSecondCall() throws {
        let node = try makeFilterChainNode()
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), 0)

        _ = try node.makeRenderPlan(profile: .stablePreview)
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), 1)

        _ = try node.makeRenderPlan(profile: .stablePreview)
        // Still 1 — the second call must have hit the cache, not added a new entry.
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), 1)
    }

    func testMakeRenderPlanDistinguishesProfile() throws {
        let node = try makeFilterChainNode()
        _ = try node.makeRenderPlan(profile: .stablePreview)
        _ = try node.makeRenderPlan(profile: .exportQuality)
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), 2)
    }

    func testMakeRenderPlanDistinguishesSamplerDescriptor() throws {
        let node = try makeFilterChainNode()
        XCTAssertEqual(HarbethContext.shared.renderPlanCacheCount(), 0)
        _ = try node.makeRenderPlan(profile: .stablePreview)
        let baseline = HarbethContext.shared.renderPlanCacheCount()
        XCTAssertGreaterThanOrEqual(baseline, 1)
        let nearestNode = node.withSamplerDescriptor(.nearest)
        _ = try nearestNode.makeRenderPlan(profile: .stablePreview)
        // The sampler override writes its own entry on top of any recursive
        // input writes, so we observe the delta relative to `baseline`
        // rather than expecting an absolute count of two.
        let final = HarbethContext.shared.renderPlanCacheCount()
        XCTAssertGreaterThan(final, baseline)
    }

    func testCachedPlanMatchesFreshPlanDiagnostics() throws {
        let node = try makeFilterChainNode()
        let first = try node.makeRenderPlan(profile: .stablePreview)
        let second = try node.makeRenderPlan(profile: .stablePreview)

        // Cache hit must return a plan structurally equivalent to a fresh compile.
        XCTAssertEqual(first.profile, second.profile)
        XCTAssertEqual(first.diagnostics.profile, second.diagnostics.profile)
        XCTAssertEqual(first.diagnostics.derivative, second.diagnostics.derivative)
        XCTAssertEqual(first.diagnostics.inputSize, second.diagnostics.inputSize)
        XCTAssertEqual(first.diagnostics.outputSize, second.diagnostics.outputSize)
        XCTAssertEqual(first.diagnostics.compilationSource, second.diagnostics.compilationSource)
    }
}
