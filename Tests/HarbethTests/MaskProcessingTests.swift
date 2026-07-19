//
//  MaskProcessingTests.swift
//  HarbethTests
//

import XCTest
import Metal
@testable import Harbeth

final class MaskProcessingTests: XCTestCase {

    func testGPUAnalysisReportsBoundsCoverageCentroidAndEdges() throws {
        let texture = try makeTexture(
            width: 4,
            height: 4,
            pixels: pixels(width: 4, height: 4) { x, y in
                x >= 1 && x <= 2 && y >= 1 && y <= 2 ? [255, 255, 255, 255] : [0, 0, 0, 255]
            }
        )
        let analysis = try MaskProcessingRecipe(
            mask: MaskDescriptor(texture: texture, component: .red)
        ).analysis()
        XCTAssertEqual(analysis.bounds, MaskCoverageBounds(x: 1, y: 1, width: 2, height: 2))
        XCTAssertEqual(analysis.activePixelCount, 4)
        XCTAssertEqual(analysis.coverageFraction, 0.25, accuracy: 0.01)
        XCTAssertEqual(analysis.centroid?.x ?? -1, 0.5, accuracy: 0.01)
        XCTAssertEqual(analysis.centroid?.y ?? -1, 0.5, accuracy: 0.01)
        XCTAssertGreaterThan(analysis.edgePixelFraction, 0.9)
    }

    func testDerivedMaskCompilerFusesOperationsAndCacheReturnsSameResult() throws {
        let plan = MaskGraphCompiler.compile([
            .grow(radius: 2), .grow(radius: 3), .threshold(0.2), .threshold(0.6), .shrink(radius: 0)
        ])
        XCTAssertEqual(plan.operations, [.grow(radius: 5), .threshold(0.6)])
        XCTAssertEqual(plan.eliminatedOperationCount, 3)

        let texture = try makeTexture(
            width: 5,
            height: 5,
            pixels: pixels(width: 5, height: 5) { x, y in
                x == 2 && y == 2 ? [255, 255, 255, 255] : [0, 0, 0, 255]
            }
        )
        let cache = MaskExecutionCache(countLimit: 2)
        let recipe = MaskDerivedRecipe(
            baseMask: MaskDescriptor(texture: texture, component: .red),
            sourceIdentifier: "single-dot",
            operations: [.grow(radius: 1), .edgeCleanup(blackPoint: 0.1, whitePoint: 0.9)],
            storageFormat: .rgba8
        )
        let first = try recipe.execute(cache: cache)
        let second = try recipe.execute(cache: cache)
        XCTAssertFalse(first.cacheHit)
        XCTAssertTrue(second.cacheHit)
        XCTAssertEqual(first.analysis.bounds, MaskCoverageBounds(x: 1, y: 1, width: 3, height: 3))
        XCTAssertEqual(first.dirtyBounds, first.analysis.bounds)
    }

    func testDerivedMaskHonorsCancellationBeforeExecution() throws {
        let texture = try makeTexture(width: 2, height: 2, pixels: Array(repeating: UInt8(255), count: 16))
        let token = TextureMultiPassCancellationToken()
        token.cancel()
        let recipe = MaskDerivedRecipe(
            baseMask: MaskDescriptor(texture: texture, component: .red),
            sourceIdentifier: "cancelled",
            operations: [.threshold(0.5)]
        )
        XCTAssertThrowsError(try recipe.execute(cancellation: token, cache: nil)) { error in
            XCTAssertEqual(error as? TextureMultiPassError, .cancelled)
        }
    }

    func testCompositeCompilerBatchesBooleanStepsAndEliminatesNeutralCoverage() throws {
        let texture = try makeTexture(width: 1, height: 1, pixels: [255, 255, 255, 255])
        let visible = MaskDescriptor(texture: texture, component: .red, opacity: 1)
        let neutral = MaskDescriptor(texture: texture, component: .red, opacity: 0)
        let steps = [
            MaskCompositeStep.add(neutral),
            MaskCompositeStep.add(visible), MaskCompositeStep.subtract(visible),
            MaskCompositeStep.intersect(visible), MaskCompositeStep.exclude(visible),
            MaskCompositeStep.add(visible), MaskCompositeStep.subtract(visible),
            MaskCompositeStep.intersect(visible), MaskCompositeStep.exclude(visible)
        ]

        let plan = MaskCompositeGraphCompiler.compile(steps)
        XCTAssertEqual(plan.batchSizes, [4, 4])
        XCTAssertEqual(plan.eliminatedStepCount, 1)
        XCTAssertEqual(plan.passCount, 3)
    }

    func testCompositeBatchShaderMatchesSequentialBooleanSemantics() throws {
        let baseTexture = try makeTexture(width: 2, height: 1, pixels: [64, 64, 64, 255, 192, 192, 192, 255])
        let values: [UInt8] = [40, 90, 170, 220, 80, 130, 200]
        let modes: [MaskBlendMode] = [.add, .subtract, .multiply, .exclude, .add, .subtract, .multiply]
        let masks = try zip(values, modes).map { value, mode in
            MaskDescriptor(
                texture: try makeTexture(width: 2, height: 1, pixels: Array(repeating: [value, value, value, UInt8(255)], count: 2).flatMap { $0 }),
                component: .red,
                blendMode: mode,
                opacity: 0.83
            )
        }
        let steps = masks.enumerated().map { MaskCompositeStep(name: "step\($0.offset)", mask: $0.element) }
        let base = MaskDescriptor(texture: baseTexture, component: .red)

        var sequential = try HarbethIO(element: baseTexture, filter: MaskCoverageExtract(mask: base)).output()
        for mask in masks {
            sequential = try HarbethIO(element: sequential, filter: MaskCoverageBlend(baseComponent: .red, mask: mask)).output()
        }
        let compiled = try MaskCompositeRecipe(baseMask: base, steps: steps).makeTexture()

        XCTAssertEqual(try coverageByte(in: compiled, x: 0, y: 0), try coverageByte(in: sequential, x: 0, y: 0), accuracy: 2)
        XCTAssertEqual(try coverageByte(in: compiled, x: 1, y: 0), try coverageByte(in: sequential, x: 1, y: 0), accuracy: 2)
    }

    func testMaskProcessingNormalizesSelectedComponentCoverage() throws {
        let texture = try makeTexture(
            width: 2,
            height: 2,
            pixels: [
                255, 0, 0, 64,
                0, 255, 0, 128,
                0, 0, 255, 255,
                255, 255, 255, 32
            ]
        )

        let alphaCoverage = try MaskProcessingRecipe(
            mask: MaskDescriptor(texture: texture, component: .alpha)
        ).makeCoverageTexture()
        XCTAssertEqual(try coverageByte(in: alphaCoverage, x: 0, y: 0), 64, accuracy: 1)
        XCTAssertEqual(try coverageByte(in: alphaCoverage, x: 1, y: 0), 128, accuracy: 1)

        let redCoverage = try MaskProcessingRecipe(
            mask: MaskDescriptor(texture: texture, component: .red)
        ).makeCoverageTexture()
        XCTAssertEqual(try coverageByte(in: redCoverage, x: 0, y: 0), 255, accuracy: 1)
        XCTAssertEqual(try coverageByte(in: redCoverage, x: 1, y: 0), 0, accuracy: 1)

        let luminanceCoverage = try MaskProcessingRecipe(
            mask: MaskDescriptor(texture: texture, component: .luminance)
        ).makeCoverageTexture()
        XCTAssertEqual(try coverageByte(in: luminanceCoverage, x: 0, y: 0), 76, accuracy: 2)
        XCTAssertEqual(try coverageByte(in: luminanceCoverage, x: 1, y: 0), 150, accuracy: 2)
    }

    func testMaskProcessingAppliesInvertOpacityAndHardThreshold() throws {
        let texture = try makeTexture(
            width: 2,
            height: 1,
            pixels: [
                0, 0, 0, 255,
                0, 0, 0, 0
            ]
        )
        let recipe = MaskProcessingRecipe(
            mask: MaskDescriptor(texture: texture, component: .alpha, invert: true, opacity: 0.5),
            threshold: .hard(0.5)
        )

        let coverage = try recipe.makeCoverageTexture()
        XCTAssertEqual(try coverageByte(in: coverage, x: 0, y: 0), 0, accuracy: 1)
        XCTAssertEqual(try coverageByte(in: coverage, x: 1, y: 0), 255, accuracy: 1)
        XCTAssertEqual(try recipe.coverageBounds(), MaskCoverageBounds(x: 1, y: 0, width: 1, height: 1))
    }

    func testMaskProcessingReturnsNilBoundsForEmptyMask() throws {
        let texture = try makeTexture(
            width: 2,
            height: 2,
            pixels: Array(repeating: UInt8(0), count: 16)
        )
        let recipe = MaskProcessingRecipe(mask: MaskDescriptor(texture: texture, component: .alpha))

        XCTAssertNil(try recipe.coverageBounds())
        XCTAssertTrue(try recipe.isEmpty())
    }

    func testMaskProcessingComputesBoundsForDisconnectedRegionsAndHoles() throws {
        let texture = try makeTexture(
            width: 4,
            height: 4,
            pixels: [
                0, 0, 0, 0,    0, 0, 0, 0,    0, 0, 0, 0,    0, 0, 0, 0,
                255, 0, 0, 255, 0, 0, 0, 0,    0, 0, 0, 0,    255, 0, 0, 255,
                0, 0, 0, 0,    0, 0, 0, 0,    0, 0, 0, 0,    0, 0, 0, 0,
                0, 0, 0, 0,    255, 0, 0, 255, 0, 0, 0, 0,    0, 0, 0, 0
            ]
        )
        let recipe = MaskProcessingRecipe(mask: MaskDescriptor(texture: texture, component: .red))

        XCTAssertEqual(try recipe.coverageBounds(), MaskCoverageBounds(x: 0, y: 1, width: 4, height: 3))
    }

    func testMaskProcessingUsesRequestedMaskComponentRatherThanRGBBlackAssumption() throws {
        let texture = try makeTexture(
            width: 2,
            height: 2,
            pixels: Array(repeating: [UInt8(0), 0, 0, 255], count: 4).flatMap { $0 }
        )
        let recipe = MaskProcessingRecipe(mask: MaskDescriptor(texture: texture, component: .alpha))

        XCTAssertEqual(try recipe.coverageBounds(), MaskCoverageBounds(x: 0, y: 0, width: 2, height: 2))
    }

    func testMaskProcessingRejectsSourceTextureSizeMismatch() throws {
        let mask = try MaskTestHelpers.makeTexture(width: 2, height: 2, red: 255, green: 0, blue: 0, alpha: 255)
        let source = try MaskTestHelpers.makeTexture(width: 3, height: 3, red: 0, green: 0, blue: 0, alpha: 255)
        let recipe = MaskProcessingRecipe(mask: MaskDescriptor(texture: mask, component: .red))

        XCTAssertThrowsError(try recipe.makeCoverageTexture(matching: source)) { error in
            guard case HarbethError.textureSizeMismatch = error else {
                return XCTFail("Expected textureSizeMismatch, got \(error)")
            }
        }
    }

    func testMaskMorphologyNormalizesKernelAndDeclaresHalo() {
        XCTAssertEqual(C7Morphology(operation: .erosion, kernelSize: 2).normalizedKernelSize, 3)
        XCTAssertEqual(C7Morphology(operation: .dilation, kernelSize: 10).normalizedKernelSize, 9)
        XCTAssertEqual(
            C7Morphology(operation: .erosion, kernelSize: 4).samplingFootprint,
            .neighborhood(radius: 2)
        )
    }

    func testMaskMorphologyOpeningRemovesIsolatedPixel() throws {
        let texture = try makeTexture(
            width: 5,
            height: 5,
            pixels: pixels(width: 5, height: 5) { x, y in
                x == 2 && y == 2 ? [0, 0, 0, 255] : [0, 0, 0, 0]
            }
        )
        let output = try MaskMorphologyRecipe(operation: .opening, kernelSize: 3)
            .makeTexture(from: MaskDescriptor(texture: texture, component: .alpha))

        XCTAssertNil(try MaskProcessingRecipe(mask: MaskDescriptor(texture: output, component: .red)).coverageBounds())
    }

    func testMaskMorphologyClosingFillsSmallHole() throws {
        let texture = try makeTexture(
            width: 7,
            height: 7,
            pixels: pixels(width: 7, height: 7) { x, y in
                let inside = x >= 2 && x <= 4 && y >= 2 && y <= 4
                let hole = x == 3 && y == 3
                return inside && !hole ? [0, 0, 0, 255] : [0, 0, 0, 0]
            }
        )
        let output = try MaskMorphologyRecipe(operation: .closing, kernelSize: 3)
            .makeTexture(from: MaskDescriptor(texture: texture, component: .alpha))

        XCTAssertEqual(
            try MaskProcessingRecipe(mask: MaskDescriptor(texture: output, component: .red)).coverageBounds(),
            MaskCoverageBounds(x: 2, y: 2, width: 3, height: 3)
        )
        XCTAssertEqual(try coverageByte(in: output, x: 3, y: 3), 255, accuracy: 2)
    }

    func testMaskMorphologyProducesInnerOuterAndBlendBands() throws {
        let texture = try makeTexture(
            width: 5,
            height: 5,
            pixels: pixels(width: 5, height: 5) { x, y in
                x >= 1 && x <= 3 && y >= 1 && y <= 3 ? [0, 0, 0, 255] : [0, 0, 0, 0]
            }
        )
        let recipe = MaskMorphologyRecipe(operation: .dilation, kernelSize: 3)
        let descriptor = MaskDescriptor(texture: texture, component: .alpha)
        let inner = try recipe.makeEdgeBand(from: descriptor, kind: .inner)
        let outer = try recipe.makeEdgeBand(from: descriptor, kind: .outer)
        let blend = try recipe.makeEdgeBand(from: descriptor, kind: .blend)

        XCTAssertEqual(try coverageByte(in: inner, x: 2, y: 2), 0, accuracy: 2)
        XCTAssertEqual(try coverageByte(in: inner, x: 1, y: 1), 255, accuracy: 2)
        XCTAssertEqual(try coverageByte(in: outer, x: 0, y: 0), 255, accuracy: 2)
        XCTAssertEqual(try coverageByte(in: outer, x: 0, y: 2), 255, accuracy: 2)
        XCTAssertEqual(try coverageByte(in: blend, x: 0, y: 2), 255, accuracy: 2)
        XCTAssertEqual(try coverageByte(in: blend, x: 1, y: 1), 255, accuracy: 2)
    }

    func testMaskDistanceFieldIsFiniteAndMonotonicAroundBoundary() throws {
        let texture = try makeTexture(
            width: 5,
            height: 5,
            pixels: pixels(width: 5, height: 5) { x, y in
                x >= 1 && x <= 3 && y >= 1 && y <= 3 ? [0, 0, 0, 255] : [0, 0, 0, 0]
            }
        )
        let output = try MaskDistanceFieldRecipe(maxDistance: 4)
            .makeTexture(from: MaskDescriptor(texture: texture, component: .alpha))

        let outer = try coverageByte(in: output, x: 0, y: 2)
        let edge = try coverageByte(in: output, x: 1, y: 2)
        let center = try coverageByte(in: output, x: 2, y: 2)
        XCTAssertGreaterThanOrEqual(edge, outer)
        XCTAssertGreaterThanOrEqual(center, edge)
        XCTAssertLessThanOrEqual(center, 255)
    }

    func testMaskDistanceFieldHandlesEmptyAndFullMasksWithoutNaNOrInf() throws {
        let empty = try makeTexture(width: 3, height: 3, pixels: Array(repeating: UInt8(0), count: 36))
        let full = try makeTexture(
            width: 3,
            height: 3,
            pixels: Array(repeating: [UInt8(0), 0, 0, 255], count: 9).flatMap { $0 }
        )
        let recipe = MaskDistanceFieldRecipe(maxDistance: .infinity, threshold: .nan)

        let emptyOutput = try recipe.makeTexture(from: MaskDescriptor(texture: empty, component: .alpha))
        let fullOutput = try recipe.makeTexture(from: MaskDescriptor(texture: full, component: .alpha))
        XCTAssertEqual(try coverageByte(in: emptyOutput, x: 1, y: 1), 255, accuracy: 2)
        XCTAssertEqual(try coverageByte(in: fullOutput, x: 1, y: 1), 255, accuracy: 2)
    }
}

private extension MaskProcessingTests {
    func makeTexture(width: Int, height: Int, pixels: [UInt8]) throws -> MTLTexture {
        XCTAssertEqual(pixels.count, width * height * 4)
        let device = try MaskTestHelpers.requireDevice()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create \(width)x\(height) texture.")
            throw HarbethError.makeTexture
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }

    func coverageByte(in texture: MTLTexture, x: Int, y: Int) throws -> UInt8 {
        try MaskTestHelpers.pixel(in: texture, x: x, y: y).red
    }

    func pixels(width: Int, height: Int, _ builder: (Int, Int) -> [UInt8]) -> [UInt8] {
        (0..<height).flatMap { y in
            (0..<width).flatMap { x in builder(x, y) }
        }
    }
}
