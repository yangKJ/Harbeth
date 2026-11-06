//
//  RenderedAnalysisBundleHelperTests.swift
//  Harbeth
//
//  覆盖 RenderedAnalysisBundle.makeRegionBundle / makeScopeBundle 两个
//  internal factory method 的行为契约。这是 plan Task D「RenderRequest
//  重复闭包收口」最小落地的 dual-path 验证。
//
// 关注点：
//  - analysisScopeFingerprint 在 region / scope 两条路径下的不同处理方式
//    （region 用 TextureAnalysisScope(region:) 包装；scope 直接用 scope.fingerprint）
//  - helper 不会因 RenderRequest 路径替换而改变 attachmentDebugPolicies 透传
//

import XCTest
import Metal
@testable import Harbeth

final class RenderedAnalysisBundleHelperTests: XCTestCase {

    // MARK: - analysisScopeFingerprint 契约

    /// region 路径：`analysisScopeFingerprint` 必须等于 `TextureAnalysisScope(region: region).fingerprint`
    /// 这与原 ImageNode / EditRecipe / LayerCompositeRecipe 内联实现完全一致。
    func testMakeRegionBundleAnalysisScopeFingerprintMatchesInlinedLogic() throws {
        let frame = try makeSimpleFrame()

        let region = MTLRegionMake2D(0, 0, 2, 2)
        let expected = TextureAnalysisScope(region: region).fingerprint
        XCTAssertFalse(expected.isEmpty, "TextureAnalysisScope(region:).fingerprint should be non-empty")

        let bundle = RenderedAnalysisBundle.makeRegionBundle(
            frame: frame,
            channel: .luminance,
            bins: 256,
            histogramHeight: 64,
            region: region,
            preferredMethod: .cpuReadback,
            attachmentDebugPolicies: []
        )

        XCTAssertEqual(bundle.analysisScopeFingerprint, expected)
    }

    /// scope 路径：`analysisScopeFingerprint` 必须直接等于 `scope.fingerprint`
    func testMakeScopeBundleAnalysisScopeFingerprintMatchesScopeFingerprint() throws {
        let frame = try makeSimpleFrame()

        let scope = TextureAnalysisScope()
        let expected = scope.fingerprint
        XCTAssertFalse(expected.isEmpty, "TextureAnalysisScope().fingerprint should be non-empty")

        let bundle = RenderedAnalysisBundle.makeScopeBundle(
            frame: frame,
            channel: .luminance,
            bins: 256,
            histogramHeight: 64,
            scope: scope,
            preferredMethod: .cpuReadback,
            attachmentDebugPolicies: []
        )

        XCTAssertEqual(bundle.analysisScopeFingerprint, expected)
    }

    /// region = nil 时：`TextureAnalysisScope(region: nil).fingerprint` 仍应可用，helper 不应崩溃。
    func testMakeRegionBundleHandlesNilRegion() throws {
        let frame = try makeSimpleFrame()

        let bundle = RenderedAnalysisBundle.makeRegionBundle(
            frame: frame,
            channel: .luminance,
            bins: 256,
            histogramHeight: 64,
            region: nil,
            preferredMethod: .cpuReadback,
            attachmentDebugPolicies: []
        )

        XCTAssertNotNil(bundle.analysisScopeFingerprint)
        XCTAssertEqual(bundle.analysisScopeFingerprint, TextureAnalysisScope(region: nil).fingerprint)
    }

    // MARK: - attachmentDebugPolicies 透传

    /// attachmentDebugPolicies 必须原样透传，不被 helper 修改或过滤。
    func testHelperPreservesAttachmentDebugPolicies() throws {
        let frame = try makeSimpleFrame()
        // helper 应当原样透传空数组（不隐式填充）
        let regionBundle = RenderedAnalysisBundle.makeRegionBundle(
            frame: frame,
            channel: .luminance,
            bins: 256,
            histogramHeight: 64,
            region: MTLRegionMake2D(0, 0, 2, 2),
            preferredMethod: .cpuReadback,
            attachmentDebugPolicies: []
        )
        let scopeBundle = RenderedAnalysisBundle.makeScopeBundle(
            frame: frame,
            channel: .luminance,
            bins: 256,
            histogramHeight: 64,
            scope: TextureAnalysisScope(),
            preferredMethod: .cpuReadback,
            attachmentDebugPolicies: []
        )

        XCTAssertTrue(regionBundle.attachmentDebugPolicies.isEmpty)
        XCTAssertTrue(scopeBundle.attachmentDebugPolicies.isEmpty)
    }

    // MARK: - helper 输出字段非空（不会因 RenderRequest 路径替换而退化为空）

    /// helper 必须保留 frame 引用（不重新构造 frame）
    /// RenderedFrame 是 struct 用 `==` 比较（依赖 Equatable，依赖纹理内容相等）
    func testHelperPreservesFrameTextureAndProfile() throws {
        let frame = try makeSimpleFrame()

        let regionBundle = RenderedAnalysisBundle.makeRegionBundle(
            frame: frame,
            channel: .luminance,
            bins: 256,
            histogramHeight: 64,
            region: MTLRegionMake2D(0, 0, 2, 2),
            preferredMethod: .cpuReadback,
            attachmentDebugPolicies: []
        )

        // texture / profile 必须与原 frame 一致（helper 不应该重新构造）
        XCTAssertEqual(regionBundle.frame.texture.width, frame.texture.width)
        XCTAssertEqual(regionBundle.frame.texture.height, frame.texture.height)
        XCTAssertEqual(regionBundle.frame.profile, frame.profile)
        XCTAssertEqual(regionBundle.frame.token.identifier, frame.token.identifier)
    }

    // MARK: - helper（3 caller 行为契约一致性）

    /// 同一 frame 通过 helper 输出的 `analysisScopeFingerprint` 必须与
    /// 通过 ImageNode.makeRenderRequest().renderAnalysisBundle() 输出的相同（dual-path 验证）。
    ///
    /// 这是 plan 要求的"如果确实改代码，必须附 dual-path 验证"。
    func testHelperOutputMatchesImageNodeRenderRequestPath() throws {
        let frame = try makeSimpleFrame()
        let region = MTLRegionMake2D(0, 0, 2, 2)

        // Path 1: 直接走 helper
        let helperBundle = RenderedAnalysisBundle.makeRegionBundle(
            frame: frame,
            channel: .luminance,
            bins: 256,
            histogramHeight: 64,
            region: region,
            preferredMethod: .cpuReadback,
            attachmentDebugPolicies: []
        )

        // Path 2: 走 ImageNode.makeRenderRequest().renderAnalysisBundle() 端到端路径
        let node = ImageNode.texture(frame.texture)
        let request = try node.makeRenderRequest()
        let requestBundle = try XCTUnwrap(
            request.renderAnalysisBundle(channel: .luminance, bins: 256, histogramHeight: 64, region: region, preferredMethod: .cpuReadback),
            "RenderRequest.renderAnalysisBundle must return a bundle"
        )

        // 两个路径输出的 analysisScopeFingerprint 必须完全一致
        XCTAssertEqual(helperBundle.analysisScopeFingerprint, requestBundle.analysisScopeFingerprint)
    }

    // MARK: - 测试 helper

    func testCPUHistogramPreviewMatchesDirectFrameAndAttachmentPaths() throws {
        let texture = try makeSolidTexture(width: 3, height: 2, pixel: [64, 128, 192, 255])
        let frame = RenderedFrame(texture: texture, profile: .readbackQuality, generation: 7, identifier: "preview-parity")
        let primary = RenderedAttachment(
            index: 0, semantic: .primaryColor, texture: texture,
            debugPolicy: RenderOutputAttachmentContract(index: 0, pixelFormat: .rgba8Unorm).debugPolicy
        )
        let attachments = RenderedAttachmentSet(outputContract: .preserveInput, attachments: [primary])
        let mask = try MaskDescriptor(texture: makeSolidTexture(width: 1, height: 1, pixel: [128, 0, 0, 255]), component: .red)
        let scopes: [(TextureAnalysisScope, Int)] = [
            (.init(), 6),
            (.init(region: MTLRegionMake2D(1, 0, 2, 1)), 2),
            (.init(mask: mask, luminanceRange: .init(minimum: 0, maximum: 1),
                   colorRange: .init(saturation: .init(minimum: 0, maximum: 1)), coverageThreshold: 0.5), 6),
            (.init(mask: mask, coverageThreshold: 0.75), 0),
            (.init(region: MTLRegionMake2D(99, 0, 1, 1)), 0)
        ]
        for (scope, count) in scopes {
            let direct = try XCTUnwrap(texture.c7.renderHistogramAttachment(channel: .red, bins: 8, height: 0,
                                                                           scope: scope, preferredMethod: .cpuReadback))
            let bundle = RenderedAnalysisBundle.makeScopeBundle(
                frame: frame, channel: .red, bins: 8, histogramHeight: 0, scope: scope,
                preferredMethod: .cpuReadback, attachmentDebugPolicies: [primary.debugPolicy]
            )
            let analysis = try XCTUnwrap(attachments.makeAnalysis(for: .primaryColor, channel: .red, bins: 8,
                                                                  histogramHeight: 0, scope: scope, preferredMethod: .cpuReadback))
            XCTAssertEqual(bundle.histogram, direct.histogram)
            XCTAssertEqual(analysis.histogram, direct.histogram)
            XCTAssertEqual(direct.histogram.totalSampleCount, count)
            XCTAssertEqual(bundle.statistics?.sampleCount, count)
            XCTAssertEqual(analysis.statistics, bundle.statistics)
            XCTAssertEqual(bundle.frame.token.identifier, frame.token.identifier)
            XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
            for preview in [direct, try XCTUnwrap(bundle.histogramAttachment), try XCTUnwrap(analysis.histogramAttachment)] {
                XCTAssertEqual(preview.attachment.index, 1)
                XCTAssertEqual(preview.attachment.semantic, .histogram)
                XCTAssertEqual(preview.attachment.debugPolicy, RenderOutputAttachmentContract.histogram(index: 1, pixelFormat: .rgba8Unorm).debugPolicy)
                XCTAssertEqual(preview.attachment.texture.height, 1)
                XCTAssertEqual(preview.attachment.texture.c7.bytes(), direct.attachment.texture.c7.bytes())
            }
        }
    }

    func testAttachmentAnalysisKeepsIndependentPixelsAndDefaultChannels() throws {
        let primary = RenderedAttachment(
            index: 0, semantic: .primaryColor,
            texture: try makeSolidTexture(width: 2, height: 2, pixel: [255, 0, 0, 255]),
            debugPolicy: RenderOutputAttachmentContract(index: 0, pixelFormat: .rgba8Unorm).debugPolicy
        )
        let auxiliary = RenderedAttachment(
            index: 3, semantic: .analysis,
            texture: try makeSolidTexture(width: 2, height: 2, pixel: [0, 255, 0, 255]),
            debugPolicy: .init(label: "scalar", interpretation: .scalarField, preferredReadbackPixelFormat: .rgba8Unorm,
                               preservesDynamicRange: false, prefersMonochromePreview: false)
        )
        let set = RenderedAttachmentSet(outputContract: .preserveInput, attachments: [auxiliary, primary])
        let bundle = set.makeAnalysisBundle(bins: 4, histogramHeight: 4, preferredMethod: .cpuReadback)
        XCTAssertEqual(bundle.analyses.map { $0.attachment.index }, [0, 3])
        XCTAssertEqual(bundle.analyses[0].histogram?.channel, .luminance)
        XCTAssertEqual(bundle.analyses[0].histogram?.bins, [0, 4, 0, 0])
        XCTAssertEqual(bundle.analyses[1].histogram?.channel, .red)
        XCTAssertEqual(bundle.analyses[1].histogram?.bins, [4, 0, 0, 0])
        XCTAssertEqual(bundle.analyses[0].statistics?.meanRed, 1)
        XCTAssertEqual(bundle.analyses[1].statistics?.meanRed, 0)
    }

    func testUnsupportedCPUReadbackKeepsFrameAndAttachmentWrappersWithoutMeasurements() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Uint, width: 2, height: 2, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let frame = RenderedFrame(texture: texture, profile: .readbackQuality, generation: 8, identifier: "unsupported-readback")
        let primary = RenderedAttachment(
            index: 0, semantic: .primaryColor, texture: texture,
            debugPolicy: RenderOutputAttachmentContract(index: 0).debugPolicy
        )
        let scope = TextureAnalysisScope()
        let bundle = RenderedAnalysisBundle.makeScopeBundle(
            frame: frame, channel: .red, bins: 8, histogramHeight: 4, scope: scope,
            preferredMethod: .cpuReadback, attachmentDebugPolicies: [primary.debugPolicy]
        )
        let set = RenderedAttachmentSet(outputContract: .preserveInput, attachments: [primary])
        let analysis = try XCTUnwrap(set.makeAnalysis(for: .primaryColor, scope: scope, preferredMethod: .cpuReadback))
        XCTAssertNil(texture.c7.renderHistogramAttachment(preferredMethod: .cpuReadback))
        XCTAssertNil(bundle.histogram)
        XCTAssertNil(bundle.statistics)
        XCTAssertNil(bundle.colorProbe)
        XCTAssertNil(bundle.histogramAttachment)
        XCTAssertEqual(bundle.frame.token.identifier, frame.token.identifier)
        XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
        XCTAssertNil(analysis.histogram)
        XCTAssertNil(analysis.statistics)
        XCTAssertNil(analysis.histogramAttachment)
        XCTAssertTrue(analysis.attachment.texture === texture)
    }

    private func makeSimpleFrame() throws -> RenderedFrame {
        let input = try makeSolidTexture(width: 4, height: 4, pixel: [200, 120, 80, 255])
        let node = ImageNode.texture(input).applying(C7Brightness(brightness: 0.0))
        return try node.makeFrame()
    }

    private func makeSolidTexture(width: Int, height: Int, pixel: [UInt8]) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "Metal device is unavailable.")
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor), "Failed to create texture.")
        let region = MTLRegionMake2D(0, 0, width, height)
        let bytesPerRow = 4 * width
        var pixels = [UInt8]()
        for _ in 0..<(width * height) {
            pixels.append(contentsOf: pixel)
        }
        pixels.withUnsafeBytes { ptr in
            texture.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }
        return texture
    }
}
