// 由 Condy 创建于 2026/11/17。遮罩资源、版本与执行参数必须完整进入图身份。
import XCTest
import Metal
@testable import Harbeth

final class MaskSemanticIdentityTests: XCTestCase {
    func testRawAndCompositeMasksSeparateDifferentResourcesInPersistentEffects() throws {
        let source = try image([0.2, 0.1, 0, 1]), black = try image([0, 0, 0, 1]), white = try image([1, 1, 1, 1])
        let a = MaskDescriptor(texture: black, component: .red), b = MaskDescriptor(texture: white, component: .red)
        XCTAssertNotEqual(a.graphDescriptor.fingerprint, b.graphDescriptor.fingerprint)
        let base = ImageNode.texture(source)
        try assertCache(base.applying(mask: a, filter: C7Brightness(brightness: 1)), base.applying(mask: b, filter: C7Brightness(brightness: 1)))
        try assertRecipes(MaskCompositeRecipe(baseMask: a), MaskCompositeRecipe(baseMask: b), source)
        let ca = MaskCompositeRecipe(baseMask: a, steps: [.add(a)]), cb = MaskCompositeRecipe(baseMask: a, steps: [.add(b)])
        XCTAssertNotEqual(ca.fingerprint, cb.fingerprint)
        try assertRecipes(ca, cb, source)
    }

    func testRangeAndBrushSmallChangesRemainVisibleToCache() throws {
        let source = try image([0.2, 0.1, 0, 1]), gray = try image([0.5, 0.5, 0.5, 1])
        let a = MaskRangeRecipe(sourceTexture: gray, sourceIdentifier: "range", kind: .highlights(threshold: 0.499999, softness: 0.000001), storageFormat: .rgba16Float)
        let b = MaskRangeRecipe(sourceTexture: gray, sourceIdentifier: "range", kind: .highlights(threshold: 0.500001, softness: 0.000001), storageFormat: .rgba16Float)
        XCTAssertEqual(try NeighborhoodTestImage.read(a.makeTexture())[0], 1)
        XCTAssertEqual(try NeighborhoodTestImage.read(b.makeTexture())[0], 0)
        try assertRecipes(a, b, source)
        let brushSource = try NeighborhoodTestImage.make(width: 257, height: 257,
            values: Array(repeating: [Float](arrayLiteral: 0.2, 0.1, 0, 1), count: 257 * 257).flatMap { $0 })
        let points = [MaskBrushPoint(point: .init(x: 0.5, y: 0.5))]
        let ba = MaskBrushRecipe(size: C7Size(width: 257, height: 257), preparedPoints: points, settings: .init(width: 0.08001), storageFormat: .rgba16Float)
        let bb = MaskBrushRecipe(size: C7Size(width: 257, height: 257), preparedPoints: points, settings: .init(width: 0.08002), storageFormat: .rgba16Float)
        XCTAssertNotEqual(try NeighborhoodTestImage.read(ba.makeTexture()), try NeighborhoodTestImage.read(bb.makeTexture()))
        try assertRecipes(ba, bb, brushSource)
    }

    func testGraphIdentityIncludesSelectionFieldsAndPlaneVersion() throws {
        let texture = try image([1, 0, 0, 1])
        let a = MaskDescriptor(plane: MaskPlane(texture: texture, resourceIdentity: .init(identifier: "same", revision: 1)), component: .red)
        let b = MaskDescriptor(plane: MaskPlane(texture: texture, resourceIdentity: .init(identifier: "same", revision: 2)), component: .red)
        XCTAssertNotEqual(a.graphDescriptor.fingerprint, b.graphDescriptor.fingerprint)
        let range = MaskRangeRecipe(sourceTexture: texture, sourceIdentifier: "components", kind: .highlights(threshold: 0.6, softness: 0.1))
        let other = try image([0, 0, 0, 1])
        XCTAssertNotEqual(range.fingerprint, MaskRangeRecipe(sourceTexture: other, sourceIdentifier: "components", kind: range.kind).fingerprint)
        XCTAssertNotEqual(range.graphDescriptor(component: .red).fingerprint, range.graphDescriptor(component: .alpha).fingerprint)
        XCTAssertNotEqual(range.graphDescriptor(opacity: 0.50001).fingerprint, range.graphDescriptor(opacity: 0.50002).fingerprint)
        let descriptor = range.graphDescriptor(component: .blue, invert: true, opacity: 0.50001)
        XCTAssertEqual(try JSONDecoder().decode(MaskGraphDescriptor.self, from: JSONEncoder().encode(descriptor)), descriptor)
        let source = try image([0.2, 0.1, 0, 1]), base = ImageNode.texture(source)
        let red = try LocalEffectRecipe(filters: [C7Brightness(brightness: 1)], mask: range, component: .red)
        let alpha = try LocalEffectRecipe(filters: [C7Brightness(brightness: 1)], mask: range, component: .alpha)
        try assertCache(base.applying(localEffect: red), base.applying(localEffect: alpha))
    }

    func testEveryProceduralFingerprintPreservesAdjacentParameters() {
        let v = Float(0.1), next = v.nextUp
        XCTAssertNotEqual(MaskRangeKind.highlights(threshold: v, softness: 0.1).fingerprint, MaskRangeKind.highlights(threshold: next, softness: 0.1).fingerprint)
        XCTAssertNotEqual(MaskGradientKind.radial(center: .zero, startRadius: v, endRadius: 1).fingerprint,
                          MaskGradientKind.radial(center: .zero, startRadius: next, endRadius: 1).fingerprint)
        XCTAssertNotEqual(MaskShapeKind.ellipse(rect: .init(x: 0, y: 0, width: 1, height: 1), feather: v).fingerprint,
                          MaskShapeKind.ellipse(rect: .init(x: 0, y: 0, width: 1, height: 1), feather: next).fingerprint)
        XCTAssertNotEqual(MaskPathCommand.move(to: .init(x: 0.1, y: 0)).fingerprint,
                          MaskPathCommand.move(to: .init(x: Double(0.1).nextUp, y: 0)).fingerprint)
        XCTAssertNotEqual(MaskDerivedOperation.threshold(v).fingerprint, MaskDerivedOperation.threshold(next).fingerprint)
    }

    func testImmutableInitialMaskIsReusedOnceAndExposureInvalidatesReuse() throws {
        let size = C7Size(width: 8, height: 6)
        let gradient = MaskGradientRecipe(size: size, kind: .linear(startPoint: .zero, endPoint: .init(x: 1, y: 0)))
        let shape = MaskShapeRecipe(size: size, kind: .rectangle(rect: .init(x: 0.2, y: 0.2, width: 0.5, height: 0.5)))
        let path = MaskPathRecipe.regularPolygon(size: size, rect: .init(x: 0.2, y: 0.2, width: 0.5, height: 0.5), sides: 3)
        let brush = MaskBrushRecipe(size: size, points: [.init(point: .init(x: 0.5, y: 0.5))])
        for recipe in [AnyMaskRecipe(gradient), AnyMaskRecipe(shape), AnyMaskRecipe(path), AnyMaskRecipe(brush)] {
            let effect = try LocalEffectRecipe(filters: [], mask: recipe)
            let first = try effect.resolvedMaskDescriptor(), original = effect.mask
            XCTAssertTrue(first.texture === original.texture)
            let next = try effect.resolvedMaskDescriptor()
            XCTAssertFalse(next.texture === original.texture)
            XCTAssertEqual(try NeighborhoodTestImage.read(first.texture), try NeighborhoodTestImage.read(next.texture))
            let exposedEffect = try LocalEffectRecipe(filters: [], mask: recipe)
            let exposed = exposedEffect.mask
            XCTAssertFalse(try exposedEffect.resolvedMaskDescriptor().texture === exposed.texture)
        }
    }

    func testMutableRangeAndCustomRecipeRefreshBetweenConstructionAndExecution() throws {
        let gray = try image([0.5, 0.5, 0.5, 1])
        let recipe = MaskRangeRecipe(sourceTexture: gray, sourceIdentifier: "mutable", kind: .highlights(threshold: 0.4, softness: 0.01), storageFormat: .rgba16Float)
        let effect = try LocalEffectRecipe(filters: [], mask: recipe)
        let replacement: [Float16] = [0.1, 0.1, 0.1, 1]
        replacement.withUnsafeBytes { gray.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 8) }
        XCTAssertEqual(try NeighborhoodTestImage.read(effect.resolvedMaskDescriptor().texture)[0], 0)
        let counter = MaskCallCounter(), custom = CountedMask(texture: gray, counter: counter)
        let customEffect = try LocalEffectRecipe(filters: [], mask: custom)
        XCTAssertEqual(counter.value, 1)
        _ = try customEffect.resolvedMaskDescriptor(); XCTAssertEqual(counter.value, 2)
        _ = try customEffect.resolvedMaskDescriptor(); XCTAssertEqual(counter.value, 3)
    }

    private func image(_ value: [Float]) throws -> MTLTexture { try NeighborhoodTestImage.make(width: 1, height: 1, values: value) }
    private func assertRecipes<R: MaskRecipe>(_ a: R, _ b: R, _ source: MTLTexture) throws {
        XCTAssertNotEqual(a.fingerprint, b.fingerprint)
        let input = ImageNode.texture(source)
        try assertCache(input.applying(localEffect: LocalEffectRecipe(filters: [C7Brightness(brightness: 1)], mask: a)),
                        input.applying(localEffect: LocalEffectRecipe(filters: [C7Brightness(brightness: 1)], mask: b)))
    }
    private func assertCache(_ a: ImageNode, _ b: ImageNode) throws {
        _ = try a.withCachePolicy(.persistent).makeTexture()
        let cached = try b.withCachePolicy(.persistent).makeTexture(), direct = try b.withCachePolicy(.transient).makeTexture()
        XCTAssertEqual(try NeighborhoodTestImage.read(cached), try NeighborhoodTestImage.read(direct))
    }
}

private final class MaskCallCounter { var value = 0 }
private struct CountedMask: MaskRecipe {
    let texture: MTLTexture
    let counter: MaskCallCounter
    var profile: RenderProfile { .stablePreview }
    var fingerprint: String { "counted" }
    var graphDescriptor: MaskGraphDescriptor { MaskDescriptor(texture: texture).graphDescriptor }
    func graphDescriptor(component: MaskComponent, blendMode: MaskBlendMode, invert: Bool, featherPolicy: MaskFeatherPolicy, opacity: Float) -> MaskGraphDescriptor { graphDescriptor }
    func makeMaskDescriptor(component: MaskComponent, blendMode: MaskBlendMode, invert: Bool, featherPolicy: MaskFeatherPolicy, opacity: Float) throws -> MaskDescriptor {
        counter.value += 1
        return MaskDescriptor(texture: texture, component: component, blendMode: blendMode, invert: invert, featherPolicy: featherPolicy, opacity: opacity)
    }
}
