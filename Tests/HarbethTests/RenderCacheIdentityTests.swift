import XCTest
@testable import Harbeth

final class RenderCacheIdentityTests: XCTestCase {

    func testReplayBaseContractTracksRenderIntent() {
        XCTAssertEqual(RenderProfile.stablePreview.defaultDerivativeSpec.replayBaseContract.preferredSourceTier, .stableReusable)
        XCTAssertTrue(RenderProfile.stablePreview.defaultDerivativeSpec.replayBaseContract.allowsDerivedReuse)

        let exportContract = RenderProfile.exportQuality.defaultDerivativeSpec.replayBaseContract
        XCTAssertEqual(exportContract.preferredSourceTier, .original)
        XCTAssertTrue(exportContract.requiresOriginalSource)
        XCTAssertFalse(exportContract.allowsDerivedReuse)
    }

    func testSourceTierCanSatisfyReplayBaseContract() {
        let stableContract = RenderProfile.stablePreview.defaultDerivativeSpec.replayBaseContract
        let inspectionContract = RenderProfile.inspectionQuality.defaultDerivativeSpec.replayBaseContract
        let exportContract = RenderProfile.exportQuality.defaultDerivativeSpec.replayBaseContract

        let displaySource = ImageSourceDescriptor(
            kind: "cgImage",
            sourceTier: .stableReusable,
            alphaType: .premultiplied,
            orientation: .up,
            cachePolicy: .persistent
        )
        let originalSource = ImageSourceDescriptor(
            kind: "cgImage",
            sourceTier: .original,
            alphaType: .premultiplied,
            orientation: .up,
            cachePolicy: .persistent
        )

        XCTAssertTrue(displaySource.satisfies(stableContract))
        XCTAssertFalse(displaySource.satisfies(inspectionContract))
        XCTAssertFalse(displaySource.satisfies(exportContract))
        XCTAssertTrue(originalSource.satisfies(stableContract))
        XCTAssertTrue(originalSource.satisfies(inspectionContract))
        XCTAssertTrue(originalSource.satisfies(exportContract))
    }

    func testRenderRecipeExposesReplayBaseContractAndStableCacheIdentity() {
        let derivative = ImageDerivativeSpec(
            name: "panelThumbnail",
            renderIntent: .delivery,
            sourceTier: .thumbnail,
            semantic: ImageSemanticDescriptor(role: .derivative, purpose: .thumbnail, fidelity: .thumbnailOptimized),
            outputSizePolicy: .maxPixelSize(160)
        )
        let source = ImageSourceDescriptor(
            kind: "cgImage",
            sourceTier: .thumbnail,
            alphaType: .premultiplied,
            orientation: .up,
            cachePolicy: .persistent
        )
        let recipe = RenderRecipe(
            renderProfile: "stablePreview",
            renderIntent: .delivery,
            source: source,
            outputDerivative: derivative,
            outputCachePolicy: .transient,
            outputSemantic: derivative.semantic,
            alphaType: .premultiplied,
            orientation: .up,
            filters: [
                C7Brightness(brightness: 0.2).recipeDescriptor,
                C7Contrast(contrast: 1.1).recipeDescriptor
            ],
            localEffects: nil,
            layerMasks: nil
        )

        XCTAssertEqual(recipe.replayBaseContract.preferredSourceTier, .thumbnail)
        XCTAssertTrue(recipe.cacheIdentity.fingerprint.contains("intent=delivery"))
        XCTAssertTrue(recipe.cacheIdentity.fingerprint.contains("name=panelThumbnail"))
        XCTAssertTrue(recipe.cacheIdentity.fingerprint.contains("preferredTier=thumbnail"))
        XCTAssertTrue(recipe.cacheIdentity.fingerprint.contains("C7Brightness"))
        XCTAssertTrue(recipe.cacheIdentity.fingerprint.contains("C7Contrast"))
    }

    func testRenderCacheIdentityChangesWithDerivativeFingerprint() {
        let source = ImageSourceDescriptor(
            kind: "cgImage",
            sourceTier: .stableReusable,
            alphaType: .premultiplied,
            orientation: .up,
            cachePolicy: .persistent
        )
        let smallDerivative = ImageDerivativeSpec(
            name: "smallStable",
            renderIntent: .stable,
            sourceTier: .stableReusable,
            semantic: ImageSemanticDescriptor(role: .derivative, purpose: .stable, fidelity: .displayOptimized),
            outputSizePolicy: .maxPixelSize(960)
        )
        let largeDerivative = ImageDerivativeSpec(
            name: "largeStable",
            renderIntent: .stable,
            sourceTier: .stableReusable,
            semantic: ImageSemanticDescriptor(role: .derivative, purpose: .stable, fidelity: .displayOptimized),
            outputSizePolicy: .maxPixelSize(1440)
        )

        let first = RenderCacheIdentity(
            sourceFingerprint: source.fingerprint,
            renderIntent: .stable,
            derivativeFingerprint: smallDerivative.fingerprint,
            replayBaseFingerprint: smallDerivative.replayBaseContract.fingerprint,
            filterChainFingerprint: FilterChainRecipe(filters: [C7Brightness(brightness: 0.2).recipeDescriptor]).fingerprint
        )
        let second = RenderCacheIdentity(
            sourceFingerprint: source.fingerprint,
            renderIntent: .stable,
            derivativeFingerprint: largeDerivative.fingerprint,
            replayBaseFingerprint: largeDerivative.replayBaseContract.fingerprint,
            filterChainFingerprint: FilterChainRecipe(filters: [C7Brightness(brightness: 0.2).recipeDescriptor]).fingerprint
        )

        XCTAssertNotEqual(first.fingerprint, second.fingerprint)
    }

    func testReplaySourceSelectionPrefersLowestSatisfyingTier() {
        let derivative = RenderProfile.stablePreview.defaultDerivativeSpec
        let candidates = [
            ReplaySourceCandidate(
                identifier: "original",
                descriptor: ImageSourceDescriptor(
                    kind: "cgImage",
                    sourceTier: .original,
                    alphaType: .premultiplied,
                    orientation: .up,
                    cachePolicy: .persistent,
                    semantic: .sourceOriginal
                ),
                pixelSize: nil
            ),
            ReplaySourceCandidate(
                identifier: "display",
                descriptor: ImageSourceDescriptor(
                    kind: "cgImage",
                    sourceTier: .stableReusable,
                    alphaType: .premultiplied,
                    orientation: .up,
                    cachePolicy: .persistent,
                    semantic: ImageSemanticDescriptor(role: .derivative, purpose: .stable, fidelity: .displayOptimized)
                ),
                pixelSize: nil
            )
        ]

        let selection = derivative.selectReplaySource(from: candidates)

        XCTAssertEqual(selection.strategy, .exactPreferredTier)
        XCTAssertEqual(selection.selectedCandidate?.identifier, "display")
        XCTAssertFalse(selection.requiresOriginalReplay)
        XCTAssertTrue(selection.reusesExistingDerivedSource)
    }

    func testReplaySourceSelectionFallsBackToHigherTierWhenNeeded() {
        let derivative = RenderProfile.inspectionQuality.defaultDerivativeSpec
        let candidates = [
            ReplaySourceCandidate(
                identifier: "original",
                descriptor: ImageSourceDescriptor(
                    kind: "cgImage",
                    sourceTier: .original,
                    alphaType: .premultiplied,
                    orientation: .up,
                    cachePolicy: .persistent,
                    semantic: .sourceOriginal
                ),
                pixelSize: nil
            ),
            ReplaySourceCandidate(
                identifier: "display",
                descriptor: ImageSourceDescriptor(
                    kind: "cgImage",
                    sourceTier: .stableReusable,
                    alphaType: .premultiplied,
                    orientation: .up,
                    cachePolicy: .persistent,
                    semantic: ImageSemanticDescriptor(role: .derivative, purpose: .stable, fidelity: .displayOptimized)
                ),
                pixelSize: nil
            )
        ]

        let selection = derivative.selectReplaySource(from: candidates)

        XCTAssertEqual(selection.strategy, .higherTierFallback)
        XCTAssertEqual(selection.selectedCandidate?.identifier, "original")
        XCTAssertFalse(selection.requiresOriginalReplay)
    }

    func testReplaySourceSelectionRequiresOriginalForExport() {
        let derivative = RenderProfile.exportQuality.defaultDerivativeSpec
        let candidates = [
            ReplaySourceCandidate(
                identifier: "fullres",
                descriptor: ImageSourceDescriptor(
                    kind: "cgImage",
                    sourceTier: .fullResolutionReusable,
                    alphaType: .premultiplied,
                    orientation: .up,
                    cachePolicy: .persistent,
                    semantic: ImageSemanticDescriptor(role: .derivative, purpose: .inspection, fidelity: .fullResolution)
                ),
                pixelSize: nil
            ),
            ReplaySourceCandidate(
                identifier: "original",
                descriptor: ImageSourceDescriptor(
                    kind: "cgImage",
                    sourceTier: .original,
                    alphaType: .premultiplied,
                    orientation: .up,
                    cachePolicy: .persistent,
                    semantic: .sourceOriginal
                ),
                pixelSize: nil
            )
        ]

        let selection = derivative.selectReplaySource(from: candidates)

        XCTAssertEqual(selection.strategy, .requiresOriginalReplay)
        XCTAssertEqual(selection.selectedCandidate?.identifier, "original")
        XCTAssertTrue(selection.requiresOriginalReplay)
    }

    func testReplaySourceSelectionReturnsNoReusableSourceWhenContractCannotBeSatisfied() {
        let derivative = RenderProfile.stablePreview.defaultDerivativeSpec
        let candidates = [
            ReplaySourceCandidate(
                identifier: "thumbnail",
                descriptor: ImageSourceDescriptor(
                    kind: "cgImage",
                    sourceTier: .thumbnail,
                    alphaType: .premultiplied,
                    orientation: .up,
                    cachePolicy: .persistent,
                    semantic: ImageSemanticDescriptor(role: .derivative, purpose: .thumbnail, fidelity: .thumbnailOptimized)
                ),
                pixelSize: nil
            )
        ]

        let selection = derivative.selectReplaySource(from: candidates)

        XCTAssertEqual(selection.strategy, .noReusableSource)
        XCTAssertNil(selection.selectedCandidate)
        XCTAssertFalse(selection.requiresOriginalReplay)
    }

    func testReplaySourceRequestPlanCanReuseExactPreferredCandidateDirectly() {
        let derivative = ImageDerivativeSpec(
            name: "panelDelivery",
            renderIntent: .delivery,
            sourceTier: .deliveryReusable,
            semantic: ImageSemanticDescriptor(role: .derivative, purpose: .delivery, fidelity: .displayOptimized),
            outputSizePolicy: .source
        )
        let candidate = ReplaySourceCandidate(
            identifier: "delivery",
            descriptor: ImageSourceDescriptor(
                kind: "cgImage",
                sourceTier: .deliveryReusable,
                alphaType: .premultiplied,
                orientation: .up,
                cachePolicy: .persistent,
                semantic: derivative.semantic,
                loadingOptions: ImageLoadingOptions(sizePolicy: .maxPixelSize(1200))
            ),
            pixelSize: C7Size(width: 1200, height: 900)
        )

        let selection = derivative.selectReplaySource(from: [candidate])
        let plan = derivative.makeReplaySourceRequestPlan(from: selection)

        XCTAssertEqual(plan.requestedSourceTier, .deliveryReusable)
        XCTAssertTrue(plan.canReuseSelectedCandidateDirectly)
        XCTAssertFalse(plan.requiresPostLoadResize)
        XCTAssertEqual(plan.loadingOptions.sizePolicy, .maxPixelSize(1200))
        XCTAssertFalse(plan.shouldDecodeFromUnderlyingSource)
    }

    func testReplaySourceRequestPlanRequestsDecodeForDerivedResize() {
        let derivative = ImageDerivativeSpec(
            name: "thumbnail",
            renderIntent: .delivery,
            sourceTier: .thumbnail,
            semantic: ImageSemanticDescriptor(role: .derivative, purpose: .thumbnail, fidelity: .thumbnailOptimized),
            outputSizePolicy: .maxPixelSize(160)
        )
        let candidate = ReplaySourceCandidate(
            identifier: "original",
            descriptor: ImageSourceDescriptor(
                kind: "cgImage",
                sourceTier: .original,
                alphaType: .premultiplied,
                orientation: .up,
                cachePolicy: .persistent,
                semantic: .sourceOriginal
            ),
            pixelSize: C7Size(width: 4000, height: 3000)
        )

        let selection = derivative.selectReplaySource(from: [candidate])
        let plan = derivative.makeReplaySourceRequestPlan(from: selection)

        XCTAssertEqual(plan.requestedSourceTier, .original)
        XCTAssertFalse(plan.canReuseSelectedCandidateDirectly)
        XCTAssertTrue(plan.requiresPostLoadResize)
        XCTAssertEqual(plan.loadingOptions.sizePolicy, .maxPixelSize(160))
        XCTAssertTrue(plan.shouldDecodeFromUnderlyingSource)
    }

    func testReplaySourceRequestPlanRequiresOriginalForExport() {
        let derivative = RenderProfile.exportQuality.defaultDerivativeSpec
        let selection = derivative.selectReplaySource(from: [])
        let plan = derivative.makeReplaySourceRequestPlan(from: selection)

        XCTAssertEqual(plan.requestedSourceTier, .original)
        XCTAssertFalse(plan.canReuseSelectedCandidateDirectly)
        XCTAssertFalse(plan.requiresPostLoadResize)
        XCTAssertEqual(plan.loadingOptions.sizePolicy, .original)
    }

    func testSourceProvisionPolicyKeepsInteractiveLatencyTransient() {
        let derivative = RenderProfile.interactiveLatency.defaultDerivativeSpec
        let selection = derivative.selectReplaySource(from: [])
        let requestPlan = derivative.makeReplaySourceRequestPlan(from: selection)
        let policy = derivative.makeSourceProvisionPolicy(from: requestPlan)

        XCTAssertEqual(policy.deliveryMode, .decodeUnderlyingSource)
        XCTAssertEqual(policy.producedCachePolicy, .transient)
        XCTAssertFalse(policy.shouldPersistProducedDerivative)
        XCTAssertFalse(policy.shouldStoreAsReusableReplayBase)
    }

    func testSourceProvisionPolicyPersistsStableDerivativeWhenItNeedsRegeneration() {
        let derivative = RenderProfile.stablePreview.defaultDerivativeSpec
        let selection = derivative.selectReplaySource(from: [])
        let requestPlan = derivative.makeReplaySourceRequestPlan(from: selection)
        let policy = derivative.makeSourceProvisionPolicy(from: requestPlan)

        XCTAssertEqual(policy.deliveryMode, .decodeUnderlyingSource)
        XCTAssertEqual(policy.producedCachePolicy, .persistent)
        XCTAssertTrue(policy.shouldPersistProducedDerivative)
        XCTAssertTrue(policy.shouldStoreAsReusableReplayBase)
    }

    func testSourceProvisionPolicyReusesDeliveryCandidateWithoutPersistingAgain() {
        let derivative = ImageDerivativeSpec(
            name: "deliveryHero",
            renderIntent: .delivery,
            sourceTier: .deliveryReusable,
            semantic: ImageSemanticDescriptor(role: .derivative, purpose: .delivery, fidelity: .displayOptimized),
            outputSizePolicy: .source
        )
        let candidate = ReplaySourceCandidate(
            identifier: "hero",
            descriptor: ImageSourceDescriptor(
                kind: "cgImage",
                sourceTier: .deliveryReusable,
                alphaType: .premultiplied,
                orientation: .up,
                cachePolicy: .persistent,
                semantic: derivative.semantic
            ),
            pixelSize: nil
        )

        let selection = derivative.selectReplaySource(from: [candidate])
        let requestPlan = derivative.makeReplaySourceRequestPlan(from: selection)
        let policy = derivative.makeSourceProvisionPolicy(from: requestPlan)

        XCTAssertEqual(policy.deliveryMode, .reuseExistingCandidate)
        XCTAssertEqual(policy.producedCachePolicy, .persistent)
        XCTAssertFalse(policy.shouldPersistProducedDerivative)
        XCTAssertTrue(policy.shouldStoreAsReusableReplayBase)
    }

    func testSourceProvisionPolicyForExportForcesOriginalReplayAndNoPersistence() {
        let derivative = RenderProfile.exportQuality.defaultDerivativeSpec
        let selection = derivative.selectReplaySource(from: [])
        let requestPlan = derivative.makeReplaySourceRequestPlan(from: selection)
        let policy = derivative.makeSourceProvisionPolicy(from: requestPlan)

        XCTAssertEqual(policy.deliveryMode, .replayFromOriginal)
        XCTAssertEqual(policy.producedCachePolicy, .transient)
        XCTAssertFalse(policy.shouldPersistProducedDerivative)
        XCTAssertFalse(policy.shouldStoreAsReusableReplayBase)
    }
}
