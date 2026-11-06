//
//  ImageNodeExecutionPreparationTests.swift
//  Harbeth
//
//  Created by Condy on 2026/10/7.
//

import Foundation
import CoreImage
import Metal
import XCTest
@testable import Harbeth

final class ImageNodeExecutionPreparationTests: XCTestCase {
    func testEditFrameEncodesUpstreamOnceWithColdAndWarmPlans() throws {
        let recorder = PreparationEncodingRecorder()
        let node = try makeNode(recorder).editing(EditRecipe())
        HarbethContext.shared.resetCaches()
        for _ in 0..<2 {
            recorder.reset()
            let frame = try node.makeFrame()
            XCTAssertEqual(recorder.encodingCount, 1)
            XCTAssertEqual(Array(try XCTUnwrap(frame.texture.c7.bytes()).prefix(4)), [64, 96, 128, 255])
        }
    }

    func testRequestPlanningDoesNotEncodeUpstreamAndEachExecutionEncodesOnce() throws {
        let recorder = PreparationEncodingRecorder()
        let node = try makeNode(recorder).editing(EditRecipe())
        HarbethContext.shared.resetCaches()
        let request = try node.makeRenderRequest()
        XCTAssertEqual(recorder.encodingCount, 0)
        _ = try request.renderTexture()
        XCTAssertEqual(recorder.encodingCount, 1)
        recorder.reset()
        _ = try request.renderFrame()
        XCTAssertEqual(recorder.encodingCount, 1)
    }

    func testChainedAndArrayFiltersUseOneCommandBuffer() throws {
        let recorder = PreparationEncodingRecorder()
        let source = ImageNode.texture(try makeTexture())
        let filter = PreparationCountingFilter(recorder: recorder)
        let chained = source.applying(filter).applying(filter).applying(filter)
        let array = source.applying(filters: [filter, filter, filter])
        for node in [chained, array] {
            for frameOutput in [false, true] {
                recorder.reset()
                let texture = try frameOutput ? node.makeFrame().texture : node.makeTexture()
                XCTAssertEqual(recorder.encodingCount, 3)
                XCTAssertEqual(recorder.commandBufferCount, 1)
                XCTAssertEqual(Array(try XCTUnwrap(texture.c7.bytes()).prefix(4)), [64, 96, 128, 255])
            }
        }
    }

    func testNestedEditingAndSamplerWrappersKeepSingleUpstreamExecution() throws {
        let recorder = PreparationEncodingRecorder()
        let node = try makeNode(recorder)
            .editing(EditRecipe(geometry: ImageTransformRecipe(targetSize: CGSize(width: 3, height: 3), aspectPolicy: .fit)))
            .withSamplerDescriptor(.nearest)
            .editing(EditRecipe())
        HarbethContext.shared.resetCaches()
        let request = try node.makeRenderRequest()
        XCTAssertEqual(recorder.encodingCount, 0)
        let frame = try request.renderFrame()
        XCTAssertEqual(recorder.encodingCount, 1)
        XCTAssertEqual(frame.texture.width, 3)
        XCTAssertEqual(frame.sourceDescriptor, try node.makeRenderRecipe().source)
        XCTAssertEqual(recorder.encodingCount, 1, "生成描述不得再次执行滤镜。")
    }

    func testChainedFilterGroupsPreserveOrderAcrossWrappers() throws {
        let source = ImageNode.texture(try makeTexture())
        let groups: [[C7FilterProtocol]] = [
            [C7Brightness(brightness: 0.13), C7Contrast(contrast: 1.2)],
            [],
            [C7Saturation(saturation: 0.6)],
            [C7Brightness(brightness: -0.08)]
        ]
        let boundaries = [
            source,
            source.editing(EditRecipe()),
            source.withSamplerDescriptor(.nearest),
            source.withCachePolicy(.transient),
            source.applyingWithContract(C7Brightness(brightness: 0))
        ]
        for boundary in boundaries {
            let chained = groups.reduce(boundary) { $0.applying(filters: $1) }
            let array = boundary.applying(filters: groups.flatMap { $0 })
            for profile in [RenderProfile.stablePreview, .exportQuality] {
                let expected = try XCTUnwrap(array.makeTexture(profile: profile).c7.bytes())
                XCTAssertEqual(try chained.makeTexture(profile: profile).c7.bytes(), expected)
                XCTAssertEqual(try chained.makeFrame(profile: profile).texture.c7.bytes(), expected)
            }
        }
    }

    func testFilterGraphPreservesEveryPrefixAndWrapperBoundary() throws {
        let source = ImageNode.texture(try makeTexture())
        let bases = [source, source.withCachePolicy(.persistent).withSamplerDescriptor(.nearest),
                     source.editing(EditRecipe()), source.applyingWithContract(C7Contrast(contrast: 1.1))]
        let groups: [[C7FilterProtocol]] = [[C7Brightness(brightness: 0.1)], [],
                                          [C7Contrast(contrast: 1.2), C7Saturation(saturation: 0.8)]]
        for base in bases {
            for profile in [RenderProfile.stablePreview, .exportQuality] {
                let derivative = ImageDerivativeSpec(
                    name: "graph-prefix-thumbnail", renderIntent: .delivery, sourceTier: .thumbnail,
                    semantic: profile.defaultImageSemantic, outputSizePolicy: .maxPixelSize(3)
                )
                var node = base
                let baseGraph = try base.makeImageGraph(profile: profile, derivative: derivative)
                var expected = baseGraph.nodes
                var edges = baseGraph.edges
                var previousID = baseGraph.rootNodeID
                for filters in groups {
                    // 直接构造空组，覆盖内部图仍然允许的空 filters 节点。
                    node = ImageNode.filters(input: node, filters: filters)
                    let id = ImageGraphNodeID(rawValue: expected.count)
                    expected.append(ImageGraphNode(
                        id: id, kind: .filters, name: "Filters",
                        cachePolicy: node.resolvedCachePolicy, samplerDescriptor: .default,
                        sourceKind: try node.resolvedPrimarySource().kindName, filterCount: filters.count,
                        fingerprint: node.resolutionFingerprint(profile: profile, derivative: derivative)
                    ))
                    edges.append(ImageGraphEdge(from: previousID, to: id))
                    previousID = id
                }
                let graph = try node.makeImageGraph(profile: profile, derivative: derivative)
                XCTAssertEqual(graph.nodes, expected)
                XCTAssertEqual(graph.edges, edges)
                XCTAssertEqual(graph.rootNodeID, previousID)
            }
        }
    }

    func testFilterGraphReadsEachGroupOnceAndRefreshesMutableFiltersBetweenBuilds() throws {
        let source = ImageNode.texture(try makeTexture())
        let filter = GraphCountingFilter()
        _ = try source.applying(filter).makeImageGraph()
        let readsPerGroup = filter.factorReadCount
        XCTAssertGreaterThan(readsPerGroup, 0)
        filter.factorReadCount = 0
        let count = 64
        let node = (0..<count).reduce(source) { node, _ in node.applying(filter) }
        let first = try node.makeImageGraph()
        XCTAssertEqual(filter.factorReadCount, readsPerGroup * count)
        XCTAssertEqual(first.nodes.count, count + 1)
        filter.brightness = 0.25
        filter.factorReadCount = 0
        let changed = try node.makeImageGraph()
        XCTAssertEqual(filter.factorReadCount, readsPerGroup * count)
        XCTAssertNotEqual(first.fingerprint, changed.fingerprint)
    }

    func testGroupedFilterFingerprintPreservesPrefixesEmptyGroupsAndBoundaries() throws {
        let first: [C7FilterProtocol] = [C7Brightness(brightness: 0.1), C7Contrast(contrast: 1.2)]
        let last: [C7FilterProtocol] = [C7Gamma(gamma: 0.9)]
        for base in try makeBoundaryNodes() {
            let node = ImageNode.filters(input: ImageNode.filters(
                input: ImageNode.filters(input: base, filters: first), filters: []
            ), filters: last)
            let expected = "filters|filters|filters|\(base.nodeFingerprint)|\(first.chainRecipe.fingerprint)||\(last.chainRecipe.fingerprint)"
            XCTAssertEqual(node.nodeFingerprint, expected)
        }
    }

    func testGroupedFilterRecipeMatchesArrayAcrossAllNonFilterBoundaries() throws {
        let groups: [[C7FilterProtocol]] = [[C7Brightness(brightness: 0.1)], [],
                                          [C7Contrast(contrast: 1.2), C7Opacity(opacity: 0.8)]]
        for base in try makeBoundaryNodes() {
            let chained = groups.reduce(base) { ImageNode.filters(input: $0, filters: $1) }
            let array = base.applying(filters: groups.flatMap { $0 })
            for profile in [RenderProfile.stablePreview, .exportQuality] {
                let derivative = ImageDerivativeSpec(
                    name: "recipe-thumbnail", renderIntent: .delivery, sourceTier: .thumbnail,
                    semantic: profile.defaultImageSemantic, outputSizePolicy: .maxPixelSize(3)
                )
                XCTAssertEqual(try chained.makeRenderRecipe(profile: profile, derivative: derivative),
                               try array.makeRenderRecipe(profile: profile, derivative: derivative))
            }
        }
    }

    func testGroupedDescriptionsRefreshMutableFilterParameters() throws {
        let filter = GraphCountingFilter()
        let node = ImageNode.texture(try makeTexture()).applying(filter).applying(C7Contrast(contrast: 1.1))
        let fingerprint = node.nodeFingerprint
        let recipe = try node.makeRenderRecipe()
        filter.brightness = 0.25
        XCTAssertNotEqual(node.nodeFingerprint, fingerprint)
        XCTAssertNotEqual(try node.makeRenderRecipe().filters, recipe.filters)
    }

    func testLongFilterRecipePreservesDescriptorOrderWithoutRecursiveStackGrowth() throws {
        let source = ImageNode.source(.ciImage(CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))))
        let filters = (0..<256).map { C7Brightness(brightness: Float($0) / 1000) }
        let node = filters.reduce(source) { $0.applying($1) }
        let recipe = try node.makeRenderRecipe()
        XCTAssertEqual(recipe.filters, filters.map(\.recipeDescriptor))
        XCTAssertEqual(recipe.source, try source.makeRenderRecipe().source)
    }

    func testDebugSnapshotMatchesSeparatePlanningAndRecipeAcrossBoundaries() throws {
        let bases = try makeBoundaryNodes()
        let nodes = bases + [bases[0].applying(C7Brightness(brightness: 0.1)),
                             bases[3].withSamplerDescriptor(.nearest).withCachePolicy(.persistent)]
        for node in nodes {
            for profile in [RenderProfile.stablePreview, .exportQuality] {
                let derivative = ImageDerivativeSpec(
                    name: "snapshot-parity", renderIntent: .delivery, sourceTier: .thumbnail,
                    semantic: profile.defaultImageSemantic, outputSizePolicy: .maxPixelSize(3)
                )
                HarbethContext.shared.removeAllRenderPlans()
                let plan = try node.makeRenderPlan(profile: profile, derivative: derivative)
                let graph = try plan.imageGraph ?? node.makeImageGraph(profile: profile, derivative: derivative)
                let recipe = try node.makeRenderRecipe(profile: profile, derivative: derivative)
                let expected = RenderGraphDebugSnapshot(
                    graph: graph, diagnostics: plan.diagnostics,
                    optimizationDecisions: plan.diagnostics.graphOptimizationDecisions, renderRecipe: recipe
                )
                HarbethContext.shared.removeAllRenderPlans()
                XCTAssertEqual(try node.makeDebugSnapshot(profile: profile, derivative: derivative), expected)
                XCTAssertEqual(try node.makeDebugSnapshot(profile: profile, derivative: derivative), expected)
            }
        }
    }

    func testDebugSnapshotPreservesSourcePlanningFailure() {
        let node = ImageNode.source(.data(Data([0, 1, 2])))
        var expected: String?
        XCTAssertThrowsError(try node.makeRenderPlan()) { expected = String(describing: $0) }
        XCTAssertThrowsError(try node.makeDebugSnapshot()) { XCTAssertEqual(String(describing: $0), expected) }
    }

    func testDebugSnapshotReusesPreparedRootPlanWithoutAnotherFingerprintPass() throws {
        let filter = GraphCountingFilter()
        let node = ImageNode.texture(try makeTexture()).applying(filter).editing(EditRecipe())
        _ = try node.makeRenderPlan()
        filter.factorReadCount = 0
        let plan = try node.makeRenderPlan()
        _ = try node.makeRenderRecipe(preparedPlan: plan)
        let expectedReads = filter.factorReadCount
        filter.factorReadCount = 0
        _ = try node.makeDebugSnapshot()
        XCTAssertGreaterThan(expectedReads, 0)
        XCTAssertEqual(filter.factorReadCount, expectedReads)
        filter.brightness = 0.25
        filter.lastReadBrightness = nil
        _ = try node.makeDebugSnapshot()
        XCTAssertEqual(filter.lastReadBrightness, 0.25)
    }

    private func makeBoundaryNodes() throws -> [ImageNode] {
        let source = ImageSource.texture(try makeTexture())
        let node = ImageNode.source(source)
        return [
            node, node.withCachePolicy(.persistent), node.withSamplerDescriptor(.nearest),
            node.editing(EditRecipe()), node.applyingWithContract(C7Contrast(contrast: 1.1)),
            .transition(TransitionRecipe(from: source, to: source, kernel: .dissolve, progress: 0.3)),
            .layerComposite(LayerCompositeRecipe(background: source, layers: []))
        ]
    }

    func testAsyncEditFrameEncodesUpstreamOnce() async throws {
        let recorder = PreparationEncodingRecorder()
        let node = try makeNode(recorder).editing(EditRecipe())
        HarbethContext.shared.resetCaches()
        let frame = try await node.makeFrameAsync()
        XCTAssertEqual(recorder.encodingCount, 1)
        XCTAssertEqual(Array(try XCTUnwrap(frame.texture.c7.bytes()).prefix(4)), [64, 96, 128, 255])
    }

    func testSourceMaterializationIsSharedOnlyWithinOnePreparation() throws {
        let source = ImageSource.ciImage(CIImage(color: CIColor(red: 1, green: 0, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4)))
        let preparation = ImageNodeSourcePreparation()
        let first = try preparation.texture(for: source)
        XCTAssertTrue(first === (try preparation.texture(for: source)))
        XCTAssertFalse(first === (try ImageNodeSourcePreparation().texture(for: source)))
    }

    func testLocalEffectMaskIsNotResolvedDuringPlanningAndExecutesOnce() throws {
        let recorder = PreparationEncodingRecorder()
        let mask = try MaskDescriptor(texture: makeTexture())
        let maskCalls = MaskResolutionCounter()
        let effect = try LocalEffectRecipe(filters: [C7Brightness(brightness: 0.1)],
                                          mask: PreparationMaskRecipe(mask: mask, calls: maskCalls))
        let node = try makeNode(recorder).editing(EditRecipe(localEffects: [effect]))
        maskCalls.count = 0
        let request = try node.makeRenderRequest()
        XCTAssertEqual(maskCalls.count, 0)
        XCTAssertEqual(recorder.encodingCount, 0)
        _ = try request.renderFrame()
        XCTAssertEqual(maskCalls.count, 1)
        XCTAssertEqual(recorder.encodingCount, 1)
    }

    private func makeNode(_ recorder: PreparationEncodingRecorder) throws -> ImageNode {
        ImageNode.texture(try makeTexture()).applying(PreparationCountingFilter(recorder: recorder))
    }

    private func makeTexture() throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "验收需要可用的 Metal 设备。")
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let bytes = Array(repeating: [UInt8](arrayLiteral: 64, 96, 128, 255), count: 16).flatMap { $0 }
        texture.replace(region: MTLRegionMake2D(0, 0, 4, 4), mipmapLevel: 0, withBytes: bytes, bytesPerRow: 16)
        return texture
    }
}

private final class MaskResolutionCounter {
    var count = 0
}

private final class GraphCountingFilter: C7FilterProtocol {
    var brightness: Float = 0.1
    var factorReadCount = 0
    var lastReadBrightness: Float?
    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
    var factors: [Float] {
        factorReadCount += 1
        lastReadBrightness = brightness
        return [brightness]
    }
}

private struct PreparationMaskRecipe: MaskRecipe {
    let mask: MaskDescriptor
    let calls: MaskResolutionCounter
    var profile: RenderProfile { .stablePreview }
    var fingerprint: String { "preparation-mask" }
    var graphDescriptor: MaskGraphDescriptor { mask.graphDescriptor }

    func graphDescriptor(component: MaskComponent, blendMode: MaskBlendMode, invert: Bool, featherPolicy: MaskFeatherPolicy, opacity: Float) -> MaskGraphDescriptor {
        mask.graphDescriptor
    }

    func makeMaskDescriptor(component: MaskComponent, blendMode: MaskBlendMode, invert: Bool, featherPolicy: MaskFeatherPolicy, opacity: Float) throws -> MaskDescriptor {
        calls.count += 1
        return mask
    }
}

private struct PreparationCountingFilter: C7FilterProtocol {
    let recorder: PreparationEncodingRecorder
    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
    var factors: [Float] { [0] }

    func combinationBegin(for buffer: MTLCommandBuffer, source texture: MTLTexture, dest texture2: MTLTexture) throws -> MTLTexture {
        recorder.record(buffer)
        return texture
    }
}

private final class PreparationEncodingRecorder: @unchecked Sendable {
    private let lock = NSLock()
    // 保持强引用直到本次计数结束，避免对象地址复用影响 command buffer 去重。
    private var buffers: [MTLCommandBuffer] = []
    var encodingCount: Int { lock.withLock { buffers.count } }
    var commandBufferCount: Int { lock.withLock { Set(buffers.map(ObjectIdentifier.init)).count } }
    func record(_ buffer: MTLCommandBuffer) { lock.withLock { buffers.append(buffer) } }
    func reset() { lock.withLock { buffers.removeAll() } }
}
