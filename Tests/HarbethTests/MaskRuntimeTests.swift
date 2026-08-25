//
//  MaskRuntimeTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/7/28.
//

import Metal
import XCTest
@testable import Harbeth

final class MaskRuntimeTests: XCTestCase {
    func testMaskPlaneCarriesExplicitSpaceSamplingAndIdentity() throws {
        let texture = try MaskTestHelpers.makeTexture(width: 4, height: 3, red: 255, green: 255, blue: 255)
        let plane = MaskPlane(
            texture: texture,
            coordinateSpace: .sourcePixels,
            sourceToMaskTransform: MaskAffineTransform(a: 2, d: 3, tx: 4, ty: 5),
            sampling: MaskSamplingContract(filter: .nearest, edgeMode: .clamp),
            coverageSemantics: .binary(threshold: 0.4),
            resourceIdentity: MaskResourceIdentity(identifier: "plane", revision: 2, generation: 7)
        )

        XCTAssertEqual(plane.descriptor.width, 4)
        XCTAssertEqual(plane.descriptor.height, 3)
        XCTAssertEqual(plane.descriptor.coordinateSpace, .sourcePixels)
        XCTAssertEqual(plane.descriptor.sampling.filter, .nearest)
        XCTAssertEqual(plane.descriptor.coverageSemantics.threshold, 0.4)
        XCTAssertEqual(plane.descriptor.resourceIdentity.revision, 2)
        XCTAssertTrue(plane.descriptor.fingerprint.contains("generation=7"))
    }

    func testMaskPlaneDescriptorUsesTextureStorageAndHonorsSameExtentSamplingOverride() throws {
        let texture = try MaskTestHelpers.makeTexture(width: 4, height: 3)
        let plane = MaskPlane(
            texture: texture,
            sampling: .softCoverage,
            storageFormat: .coverage16Float,
            resourceIdentity: MaskResourceIdentity(identifier: "storage-truth", revision: 4)
        )
        let sampling = MaskSamplingContract(filter: .nearest, edgeMode: .mirror, pixelCentersAligned: false)

        XCTAssertEqual(plane.descriptor.storageFormat, .rgba8)

        let result = try plane.resampled(width: 4, height: 3, sampling: sampling)
        XCTAssertEqual(result.descriptor.sampling, sampling)
        XCTAssertEqual(result.descriptor.resourceIdentity, plane.descriptor.resourceIdentity)
    }

    func testAreaPreservingMaskDownsampleMaintainsCoverage() throws {
        let texture = try makeTexture(width: 2, height: 2, pixels: [
            255, 255, 255, 255, 0, 0, 0, 255,
            0, 0, 0, 255, 0, 0, 0, 255
        ])
        let output = try MaskPlane(
            texture: texture,
            sampling: .softCoverage,
            storageFormat: .rgba8
        ).resampled(width: 1, height: 1).texture
        let pixel = try MaskTestHelpers.firstPixel(in: output)
        XCTAssertEqual(pixel.red, 64, accuracy: 3)
    }

    func testIncrementalCanvasUpdatesDirtyRegionAndRejectsStaleGeneration() throws {
        let canvas = try IncrementalMaskCanvas(size: C7Size(width: 64, height: 64), identifier: "runtime-test")
        let update = try canvas.apply(
            points: [
                MaskBrushPoint(point: CGPoint(x: 0.45, y: 0.5)),
                MaskBrushPoint(point: CGPoint(x: 0.55, y: 0.5))
            ],
            settings: MaskBrushSettings(width: 0.08, hardness: 1),
            generation: 3
        )
        let dirty = try XCTUnwrap(update.dirtyBounds)
        XCTAssertLessThan(dirty.width, 32)
        XCTAssertLessThan(dirty.height, 24)
        XCTAssertEqual(update.revision, 1)
        XCTAssertEqual(canvas.snapshot().descriptor.resourceIdentity.generation, 3)
        XCTAssertGreaterThan(
            try MaskProcessingRecipe(mask: canvas.snapshot().maskDescriptor()).analysis().activePixelCount,
            0
        )

        XCTAssertThrowsError(try canvas.apply(points: [], generation: 2)) { error in
            XCTAssertEqual(
                error as? IncrementalMaskCanvasError,
                .staleGeneration(requested: 2, current: 3)
            )
        }
    }

    func testIncrementalCanvasCancellationDoesNotAdvanceIdentity() throws {
        let canvas = try IncrementalMaskCanvas(size: C7Size(width: 32, height: 32), identifier: "cancelled-stroke")
        let token = TextureMultiPassCancellationToken()
        token.cancel()

        XCTAssertThrowsError(try canvas.apply(
            points: [MaskBrushPoint(point: CGPoint(x: 0.5, y: 0.5))],
            generation: 4,
            cancellation: token
        ))
        XCTAssertEqual(canvas.snapshot().descriptor.resourceIdentity.revision, 0)
        XCTAssertEqual(canvas.snapshot().descriptor.resourceIdentity.generation, 0)
    }

    func testIncrementalCanvasNoOpBrushAdvancesGenerationWithoutInvalidatingContent() throws {
        let canvas = try IncrementalMaskCanvas(size: C7Size(width: 32, height: 32), identifier: "no-op-stroke")
        let points = [MaskBrushPoint(point: CGPoint(x: 0.5, y: 0.5))]

        let zeroFlow = try canvas.apply(
            points: points,
            settings: MaskBrushSettings(flow: 0),
            generation: 7
        )
        XCTAssertNil(zeroFlow.dirtyBounds)
        XCTAssertEqual(zeroFlow.encodedPointCount, 0)
        XCTAssertEqual(zeroFlow.revision, 0)
        XCTAssertEqual(zeroFlow.generation, 7)

        let zeroDensity = try canvas.apply(
            points: points,
            settings: MaskBrushSettings(density: 0),
            generation: 8
        )
        XCTAssertNil(zeroDensity.dirtyBounds)
        XCTAssertEqual(zeroDensity.encodedPointCount, 0)
        XCTAssertEqual(zeroDensity.revision, 0)
        XCTAssertEqual(zeroDensity.generation, 8)
        XCTAssertEqual(
            try MaskProcessingRecipe(mask: canvas.snapshot().maskDescriptor()).analysis().activePixelCount,
            0
        )
    }

    func testIncrementalCanvasSnapshotsRemainRevisionStable() throws {
        let canvas = try IncrementalMaskCanvas(size: C7Size(width: 64, height: 32), identifier: "snapshot-copy")
        _ = try canvas.apply(
            points: [MaskBrushPoint(point: CGPoint(x: 0.2, y: 0.5))],
            settings: MaskBrushSettings(width: 0.15, hardness: 1)
        )
        let first = canvas.snapshot()
        let originalCoverage = try MaskProcessingRecipe(mask: first.maskDescriptor()).analysis().activePixelCount

        _ = try canvas.apply(
            points: [MaskBrushPoint(point: CGPoint(x: 0.8, y: 0.5))],
            settings: MaskBrushSettings(width: 0.15, hardness: 1)
        )

        XCTAssertEqual(
            try MaskProcessingRecipe(mask: first.maskDescriptor()).analysis().activePixelCount,
            originalCoverage
        )
        XCTAssertGreaterThan(
            try MaskProcessingRecipe(mask: canvas.snapshot().maskDescriptor()).analysis().activePixelCount,
            originalCoverage
        )
    }

    func testIncrementalCanvasPreservesPathsLongerThanSingleKernelBatch() throws {
        let points = (0..<1_100).map { index in
            MaskBrushPoint(point: CGPoint(x: Double(index) / 1_099, y: 0.5))
        }
        let canvas = try IncrementalMaskCanvas(size: C7Size(width: 128, height: 32), identifier: "long-stroke")
        let update = try canvas.apply(
            points: points,
            settings: MaskBrushSettings(width: 0.01, hardness: 1, spacing: 0.02, smoothing: 0)
        )
        XCTAssertGreaterThan(update.encodedPointCount, MaskBrushRecipe.maximumPreparedPointCount)
        let analysis = try MaskProcessingRecipe(mask: canvas.snapshot().maskDescriptor()).analysis()
        XCTAssertEqual(analysis.bounds?.x, 0)
        XCTAssertGreaterThanOrEqual(analysis.bounds?.width ?? 0, 126)
    }

    func testIncrementalCanvasLongLowFlowStrokeHasNoKernelBatchSeam() throws {
        let size = C7Size(width: 2_048, height: 64)
        let points = [
            MaskBrushPoint(point: CGPoint(x: 0.1, y: 0.5)),
            MaskBrushPoint(point: CGPoint(x: 0.9, y: 0.5))
        ]
        let settings = MaskBrushSettings(width: 0.04, hardness: 1, spacing: 0.02, smoothing: 0, flow: 0.25)
        let prepared = MaskBrushRecipe.prepareIncremental(points: points, settings: settings)
        XCTAssertGreaterThan(prepared.count, MaskBrushRecipe.maximumPreparedPointCount)

        let canvas = try IncrementalMaskCanvas(size: size, identifier: "long-low-flow")
        _ = try canvas.apply(points: points, settings: settings)
        let texture = canvas.snapshot().texture
        let batchBoundaryX = Int(prepared[MaskBrushRecipe.maximumPreparedPointCount - 1].point.x * CGFloat(size.width))
        let referenceX = Int(prepared[MaskBrushRecipe.maximumPreparedPointCount / 2].point.x * CGFloat(size.width))
        let boundary = try MaskTestHelpers.pixel(in: texture, x: batchBoundaryX, y: size.height / 2).red
        let reference = try MaskTestHelpers.pixel(in: texture, x: referenceX, y: size.height / 2).red

        XCTAssertEqual(boundary, reference, accuracy: 2)

        let eraseSettings = MaskBrushSettings(
            width: 0.04, hardness: 1, spacing: 0.02, smoothing: 0, flow: 0.25, mode: .erase
        )
        _ = try canvas.apply(points: points, settings: eraseSettings)
        let erasedTexture = canvas.snapshot().texture
        let erasedBoundary = try MaskTestHelpers.pixel(in: erasedTexture, x: batchBoundaryX, y: size.height / 2).red
        let erasedReference = try MaskTestHelpers.pixel(in: erasedTexture, x: referenceX, y: size.height / 2).red

        XCTAssertEqual(erasedBoundary, erasedReference, accuracy: 2)
    }

    func testIncrementalCanvasPaintAndEraseRemainCoverageMonotonicAtPartialDensity() throws {
        let canvas = try IncrementalMaskCanvas(size: C7Size(width: 16, height: 16), identifier: "density-monotonicity")
        let point = [MaskBrushPoint(point: CGPoint(x: 0.5, y: 0.5))]
        let center = (x: 8, y: 8)

        _ = try canvas.apply(
            points: point,
            settings: MaskBrushSettings(width: 0.5, hardness: 1, flow: 1, density: 0.25, mode: .erase)
        )
        XCTAssertEqual(try MaskTestHelpers.pixel(in: canvas.snapshot().texture, x: center.x, y: center.y).red, 0)

        _ = try canvas.apply(
            points: point,
            settings: MaskBrushSettings(width: 0.5, hardness: 1, flow: 1, density: 1, mode: .paint)
        )
        let painted = try MaskTestHelpers.pixel(in: canvas.snapshot().texture, x: center.x, y: center.y).red

        _ = try canvas.apply(
            points: point,
            settings: MaskBrushSettings(width: 0.5, hardness: 1, flow: 1, density: 0.25, mode: .paint)
        )
        let repainted = try MaskTestHelpers.pixel(in: canvas.snapshot().texture, x: center.x, y: center.y).red
        XCTAssertEqual(repainted, painted)

        _ = try canvas.apply(
            points: point,
            settings: MaskBrushSettings(width: 0.5, hardness: 1, flow: 1, density: 0.25, mode: .erase)
        )
        let erased = try MaskTestHelpers.pixel(in: canvas.snapshot().texture, x: center.x, y: center.y).red
        XCTAssertLessThan(erased, repainted)
    }

    func testIncrementalCanvasGPUStorageFormatsPreserveSnapshotsAcrossReset() throws {
        for storageFormat in [MaskStorageFormat.coverage8, .coverage16Float, .rgba8, .rgba16Float] {
            let canvas = try IncrementalMaskCanvas(
                size: C7Size(width: 24, height: 16),
                storageFormat: storageFormat,
                identifier: "storage-\(storageFormat.rawValue)"
            )
            _ = try canvas.apply(
                points: [MaskBrushPoint(point: CGPoint(x: 0.5, y: 0.5))],
                settings: MaskBrushSettings(width: 0.25, hardness: 1)
            )
            let painted = canvas.snapshot()
            let paintedCount = try MaskProcessingRecipe(mask: painted.maskDescriptor()).analysis().activePixelCount

            XCTAssertEqual(painted.texture.pixelFormat, storageFormat.pixelFormat)
            XCTAssertGreaterThan(paintedCount, 0)

            _ = try canvas.reset()
            XCTAssertEqual(
                try MaskProcessingRecipe(mask: painted.maskDescriptor()).analysis().activePixelCount,
                paintedCount
            )
            XCTAssertEqual(
                try MaskProcessingRecipe(mask: canvas.snapshot().maskDescriptor()).analysis().activePixelCount,
                0
            )
        }
    }

    func testSignedDistanceRefinementCanExpandAndFeatherMask() throws {
        let texture = try makeTexture(width: 9, height: 9, pixels: pixels(width: 9, height: 9) { x, y in
            x >= 3 && x <= 5 && y >= 3 && y <= 5 ? [255, 255, 255, 255] : [0, 0, 0, 255]
        })
        let mask = MaskDescriptor(texture: texture, component: .red)
        let expanded = try MaskEdgeRefinementRecipe(shift: 2, maxDistance: 4)
            .makePlane(from: mask, storageFormat: .rgba8)
        let feathered = try MaskEdgeRefinementRecipe(innerFeather: 1, outerFeather: 2, maxDistance: 4)
            .makePlane(from: mask, storageFormat: .rgba8)

        XCTAssertGreaterThan(
            try MaskProcessingRecipe(mask: expanded.maskDescriptor()).analysis().activePixelCount,
            9
        )
        let featherPixel = try MaskTestHelpers.pixel(in: feathered.texture, x: 2, y: 4)
        XCTAssertGreaterThan(featherPixel.red, 0)
        XCTAssertLessThan(featherPixel.red, 255)
    }

    func testGuidedRefinementProducesFiniteCoverage() throws {
        let maskTexture = try makeTexture(width: 8, height: 8, pixels: pixels(width: 8, height: 8) { x, _ in
            x < 4 ? [255, 255, 255, 255] : [0, 0, 0, 255]
        })
        let guidance = try makeTexture(width: 8, height: 8, pixels: pixels(width: 8, height: 8) { x, _ in
            x < 4 ? [32, 32, 32, 255] : [224, 224, 224, 255]
        })
        let confidence = try MaskTestHelpers.makeTexture(width: 8, height: 8, red: 255, green: 128, blue: 0)
        let plane = try MaskGuidedRefinementRecipe(radius: 2, coefficientScale: 0.5, storageFormat: .rgba8)
            .makePlane(
                from: MaskDescriptor(texture: maskTexture, component: .red),
                guidanceTexture: guidance,
                confidenceTexture: confidence
            )
        let analysis = try MaskProcessingRecipe(mask: plane.maskDescriptor()).analysis()
        XCTAssertGreaterThan(analysis.activePixelCount, 0)
        XCTAssertLessThanOrEqual(analysis.coverageFraction, 1)
    }

    func testColorDecontaminationChangesForegroundRGBWithoutChangingMask() throws {
        let foreground = try makeTexture(width: 3, height: 1, pixels: [
            255, 0, 0, 255,
            0, 0, 255, 255,
            0, 255, 0, 255
        ])
        let maskTexture = try makeTexture(width: 3, height: 1, pixels: [
            255, 255, 255, 255,
            128, 128, 128, 255,
            0, 0, 0, 255
        ])
        let mask = MaskDescriptor(texture: maskTexture, component: .red)
        let output = try ImageNode.texture(foreground)
            .decontaminating(mask: mask, radius: 1, strength: 1)
            .makeTexture(profile: .inspectionQuality)
        let edge = try MaskTestHelpers.pixel(in: output, x: 1, y: 0)
        XCTAssertGreaterThan(edge.red, 0)
        XCTAssertLessThan(edge.blue, 255)
        XCTAssertEqual(
            try MaskProcessingRecipe(mask: mask).analysis().activePixelCount,
            2
        )
    }

    func testTopologyAnalysisReportsComponentsHolesAndCanCleanThem() throws {
        let texture = try makeTexture(width: 9, height: 7, pixels: pixels(width: 9, height: 7) { x, y in
            let ring = x >= 1 && x <= 5 && y >= 1 && y <= 5 && !(x >= 2 && x <= 4 && y >= 2 && y <= 4)
            let isolated = x == 8 && y == 6
            return ring || isolated ? [255, 255, 255, 255] : [0, 0, 0, 255]
        })
        let mask = MaskDescriptor(texture: texture, component: .red)
        let recipe = MaskTopologyRecipe()
        let analysis = try recipe.analyze(mask)
        XCTAssertEqual(analysis.componentCount, 2)
        XCTAssertEqual(analysis.holeCount, 1)
        XCTAssertEqual(analysis.isolatedPixelCount, 1)

        let cleaned = try recipe.removingComponents(smallerThan: 2, from: mask)
        let filled = try recipe.fillingHoles(in: cleaned.maskDescriptor())
        let result = try recipe.analyze(filled.maskDescriptor())
        XCTAssertEqual(result.componentCount, 1)
        XCTAssertEqual(result.holeCount, 0)
    }

    func testAuxiliaryRangeAndZeroFlowWarpRemainGenericPrimitives() throws {
        let auxiliary = try makeTexture(width: 2, height: 1, pixels: [
            32, 0, 0, 255,
            224, 0, 0, 255
        ])
        let plane = try MaskAuxiliaryPlane(texture: auxiliary, semantic: .depth)
            .rangeMask(lowerBound: 0.7, upperBound: 1, softness: 0.01, storageFormat: .rgba8)
        XCTAssertEqual(try MaskProcessingRecipe(mask: plane.maskDescriptor()).analysis().activePixelCount, 1)

        let zeroFlow = try makeTexture(width: 2, height: 1, pixels: [
            0, 0, 0, 255,
            0, 0, 0, 255
        ])
        let warped = try MaskWarpRecipe(flowTexture: zeroFlow)
            .makePlane(from: plane.maskDescriptor(), storageFormat: .rgba8)
        XCTAssertEqual(try MaskProcessingRecipe(mask: warped.maskDescriptor()).analysis().activePixelCount, 1)
    }

    func testMaskExpressionCompilerReusesCommonSubexpressionAndReportsHeapContract() throws {
        let texture = try MaskTestHelpers.makeTexture(width: 2, height: 2, red: 255, green: 255, blue: 255)
        let source = MaskExpression.source(MaskPlane(
            texture: texture,
            resourceIdentity: MaskResourceIdentity(identifier: "shared")
        ).maskDescriptor())
        let shared = MaskExpression.opacity(source, 0.5)
        let expression = MaskExpression.add(shared, shared)
        let result = try expression.execute(storageFormat: .rgba8)

        XCTAssertEqual(result.plan.commonSubexpressionCount, 1)
        XCTAssertEqual(result.plan.passCount, 1)
        XCTAssertGreaterThan(result.cacheHitCount, 0)
        XCTAssertEqual(result.plan.allocationStrategy, HarbethContext.shared.textureAllocationStrategy)
        XCTAssertEqual(try MaskProcessingRecipe(mask: result.plane.maskDescriptor()).analysis().activePixelCount, 4)
    }

    func testDerivedDiagnosticsExposeHaloCacheAndIntermediateCost() throws {
        let texture = try MaskTestHelpers.makeTexture(width: 12, height: 12, red: 255, green: 255, blue: 255)
        let plane = MaskPlane(
            texture: texture,
            resourceIdentity: MaskResourceIdentity(identifier: "diagnostics", revision: 1),
            lastModifiedBounds: MaskCoverageBounds(x: 5, y: 5, width: 1, height: 1)
        )
        let recipe = MaskDerivedRecipe(
            baseMask: plane.maskDescriptor(),
            sourceIdentifier: "diagnostics",
            operations: [.grow(radius: 3), .feather(innerRadius: 2, outerRadius: 4, maxDistance: 8)],
            storageFormat: .rgba8
        )
        let result = try recipe.execute(cachePolicy: .transient)
        XCTAssertEqual(result.diagnostics.passCount, 2)
        XCTAssertEqual(result.diagnostics.maximumHalo, 8)
        XCTAssertGreaterThan(result.diagnostics.estimatedIntermediateByteCount, 0)
        XCTAssertFalse(result.diagnostics.cacheHit)
        XCTAssertEqual(result.dirtyBounds, MaskCoverageBounds(x: 0, y: 0, width: 12, height: 12))
    }

    func testDerivedPublicCachePolicyKeepsTransientResultsOutOfSharedCache() throws {
        resetSharedMaskCache()
        defer { resetSharedMaskCache() }
        let texture = try MaskTestHelpers.makeTexture(width: 4, height: 4, red: 255, green: 255, blue: 255)
        let plane = MaskPlane(
            texture: texture,
            resourceIdentity: MaskResourceIdentity(identifier: "public-cache-policy", revision: 1)
        )
        let recipe = MaskDerivedRecipe(
            baseMask: plane.maskDescriptor(),
            sourceIdentifier: "public-cache-policy",
            operations: [.threshold(0.5)],
            storageFormat: .rgba8
        )

        XCTAssertFalse(try recipe.execute(cachePolicy: .transient).cacheHit)
        XCTAssertFalse(try recipe.execute(cachePolicy: .transient).cacheHit)
        XCTAssertFalse(try recipe.execute(cachePolicy: .persistent).cacheHit)
        XCTAssertTrue(try recipe.execute(cachePolicy: .persistent).cacheHit)
    }

    func testDerivedCacheSeparatesMaskResourceRevisions() throws {
        resetSharedMaskCache()
        defer { resetSharedMaskCache() }
        let texture = try MaskTestHelpers.makeTexture(width: 3, height: 3, red: 255, green: 255, blue: 255)
        func recipe(revision: UInt64) -> MaskDerivedRecipe {
            let plane = MaskPlane(
                texture: texture,
                resourceIdentity: MaskResourceIdentity(identifier: "mutable-mask", revision: revision)
            )
            return MaskDerivedRecipe(
                baseMask: plane.maskDescriptor(),
                sourceIdentifier: "same-graph",
                operations: [.threshold(0.5)],
                storageFormat: .rgba8
            )
        }

        XCTAssertFalse(try recipe(revision: 1).execute(cachePolicy: .persistent).cacheHit)
        XCTAssertFalse(try recipe(revision: 2).execute(cachePolicy: .persistent).cacheHit)
        XCTAssertTrue(try recipe(revision: 2).execute(cachePolicy: .persistent).cacheHit)
    }

    private func resetSharedMaskCache() {
        HarbethContext.shared.invalidateDerivedResources(domain: .mask)
    }
}

private extension MaskRuntimeTests {
    func makeTexture(width: Int, height: Int, pixels: [UInt8]) throws -> MTLTexture {
        let texture = try MaskTestHelpers.makeTexture(width: width, height: height)
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }

    func pixels(width: Int, height: Int, value: (Int, Int) -> [UInt8]) -> [UInt8] {
        (0..<height).flatMap { y in
            (0..<width).flatMap { x in value(x, y) }
        }
    }
}
