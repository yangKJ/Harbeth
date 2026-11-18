//
//  PluginBoundaryContractTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/11/18.
//

import CoreGraphics
import CoreImage
import Metal
import XCTest
@testable import Harbeth

final class PluginBoundaryContractTests: XCTestCase {
    func testUnsupportedLatencyFailsBeforeMaterializingInput() {
        let plugin = PluginProbe(capability: .cpu)
        let source = ImageNode.ciImage(CIImage(color: CIColor(red: 1, green: 0, blue: 0)))
        XCTAssertThrowsError(try source.applying(plugin: plugin, profile: .interactiveLatency)) { error in
            XCTAssertTrue(String(describing: error).contains("低延迟"))
        }
        XCTAssertEqual(plugin.outputCalls, 0)
    }

    func testEmptyIdentifierFailsBeforeMaterializingInput() {
        let plugin = PluginProbe(identifier: "  ", capability: .nativeMetal)
        let source = ImageNode.ciImage(CIImage(color: CIColor(red: 1, green: 0, blue: 0)))
        XCTAssertThrowsError(try source.applying(plugin: plugin)) { error in
            XCTAssertTrue(String(describing: error).contains("标识"))
        }
        XCTAssertEqual(plugin.outputCalls, 0)
    }

    func testPreparedOutputDoesNotRequireAnAnalysisFrame() throws {
        let source = ImageNode.ciImage(CIImage(color: CIColor(red: 1, green: 0, blue: 0)))
        // 无界输入不能物化；固定配方的接入仍应保持惰性。
        _ = try source.applying(pluginOutput: .filters([C7Brightness(brightness: 0.1)]))
    }

    func testReadbackAndReportUseTheSameAnalysisFrame() throws {
        let plugin = PluginProbe(capability: .cpu, output: .filters([]))
        var report: PluginExecutionReport?
        let node = try ImageNode.texture(makeTexture())
            .withCachePolicy(.persistent)
            .applying(plugin: plugin, profile: .stablePreview, report: { report = $0 })
        XCTAssertEqual(plugin.inputProfile, .readbackQuality)
        XCTAssertEqual(plugin.contextProfile, .stablePreview)
        XCTAssertEqual(plugin.outputCalls, 1)
        XCTAssertEqual(plugin.diagnosticsCalls, 1)
        XCTAssertEqual(report?.inputToken, plugin.inputToken)
        XCTAssertEqual(report?.diagnostics?["analysis"], "same-frame")
        XCTAssertEqual(report?.capability, .cpu)
        XCTAssertEqual(node.resolvedCachePolicy, .persistent)
    }

    func testNonCacheableOutputIsTransientAndDiagnosticsAreOptIn() throws {
        let plugin = PluginProbe(capability: .ai)
        let node = try ImageNode.texture(makeTexture())
            .withCachePolicy(.persistent)
            .applying(plugin: plugin)
        XCTAssertEqual(node.resolvedCachePolicy, .transient)
        XCTAssertEqual(plugin.diagnosticsCalls, 0)
    }

    func testRequestedDiagnosticFailurePropagatesWithoutReportingSuccess() throws {
        let plugin = PluginProbe(capability: .nativeMetal, failsDiagnostics: true)
        var reported = false
        XCTAssertThrowsError(try ImageNode.texture(makeTexture()).applying(plugin: plugin, report: { _ in reported = true }))
        XCTAssertFalse(reported)
        XCTAssertEqual(plugin.diagnosticsCalls, 1)
    }

    func testAnalysisDerivativeDoesNotReplaceOriginalRecipeInput() throws {
        let plugin = PluginProbe(capability: .nativeMetal, output: .filters([C7Brightness(brightness: 0.1)]))
        let derivative = ImageDerivativeSpec(name: "analysis", renderIntent: .stable,
            sourceTier: .thumbnail, semantic: .sourceOriginal, outputSizePolicy: .fit(C7Size(width: 2, height: 2)))
        let node = try ImageNode.texture(makeTexture(width: 4, height: 4)).applying(plugin: plugin, derivative: derivative)
        XCTAssertEqual(plugin.inputSize, C7Size(width: 2, height: 2))
        let output = try node.makeTexture()
        XCTAssertEqual(output.width, 4)
        XCTAssertEqual(output.height, 4)
    }

    func testFrameOutputPreservesPixelContractAndMetadata() throws {
        let texture = try makeTexture()
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let frame = RenderedFrame(texture: texture, colorSpace: colorSpace, sourceTier: .thumbnail,
            alphaType: .nonPremultiplied, orientation: .rightMirrored, profile: .stablePreview,
            generation: 7, identifier: "plugin-frame", metadata: ["source": "preserved"])
        let output = PluginOutput.frame(frame)
        XCTAssertTrue(output.isSourceLike)
        XCTAssertEqual(try output.makePreviewFrame().token, frame.token)
        let descriptor = try output.sourceDescriptor()
        XCTAssertEqual(descriptor.alphaType, .nonPremultiplied)
        XCTAssertEqual(descriptor.orientation, .rightMirrored)
        XCTAssertEqual(descriptor.sourceTier, .thumbnail)
        let delivered = try ImageNode.texture(texture).applying(pluginOutput: output).makeFrame(metadata: ["request": "added"])
        XCTAssertTrue(delivered.texture === texture)
        XCTAssertEqual(delivered.alphaType, frame.alphaType)
        XCTAssertEqual(delivered.orientation, frame.orientation)
        XCTAssertEqual(delivered.outputColorSpaceContract, frame.outputColorSpaceContract)
        XCTAssertEqual(delivered.metadata["source"], "preserved")
        XCTAssertEqual(delivered.metadata["request"], "added")
    }

    func testFrameNodeAndDeliveredFrameKeepLeaseUntilLastOwner() throws {
        let texture = try makeTexture()
        let recorder = PluginLeaseRecorder()
        var lease: TextureLease? = TextureLease(texture: texture, releaseHandler: { recorder.record() })
        weak var retainedLease = lease
        var frame: RenderedFrame? = RenderedFrame(texture: texture, profile: .stablePreview,
            generation: 1, identifier: "owned-frame", lease: lease)
        var node: ImageNode? = try ImageNode.texture(texture).applying(pluginOutput: .frame(frame!))
        lease = nil
        frame = nil
        XCTAssertNotNil(retainedLease)
        XCTAssertEqual(recorder.count, 0)
        var delivered: RenderedFrame? = try node!.makeFrame()
        XCTAssertTrue(delivered?.lease === retainedLease)
        node = nil
        XCTAssertEqual(recorder.count, 0)
        delivered = nil
        XCTAssertNil(retainedLease)
        XCTAssertEqual(recorder.count, 1)
    }

    func testRawTextureOutputIsIndependentOfFrameLeaseAndLaterWrites() throws {
        let texture = try makeTexture()
        let recorder = PluginLeaseRecorder()
        var frame: RenderedFrame? = RenderedFrame(texture: texture, profile: .stablePreview,
            generation: 1, identifier: "raw-snapshot", lease: TextureLease(texture: texture, releaseHandler: { recorder.record() }))
        var node: ImageNode? = ImageNode.source(.renderedFrame(frame!))
        frame = nil
        let output = try node!.makeTexture()
        XCTAssertFalse(output === texture)
        node = nil
        XCTAssertEqual(recorder.count, 1)
        var replacement: [UInt8] = [0, 0, 0, 255]
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &replacement, bytesPerRow: 4)
        var actual = [UInt8](repeating: 0, count: 4)
        output.getBytes(&actual, bytesPerRow: 4, from: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0)
        XCTAssertEqual(actual, [100, 80, 60, 255])
    }

    func testTexturePassThroughRetainsTheInputManagedLease() throws {
        let plugin = PluginProbe(capability: .nativeMetal)
        var node: ImageNode? = try ImageNode.texture(makeTexture())
            .applying(C7Brightness(brightness: 0.1))
            .applying(plugin: plugin)
        XCTAssertNotNil(plugin.inputLease)
        var output: RenderedFrame? = try node!.makeFrame()
        XCTAssertTrue(output?.lease === plugin.inputLease)
        node = nil
        XCTAssertNotNil(plugin.inputLease)
        output = nil
        XCTAssertNil(plugin.inputLease)
    }

    func testAliasedFrameKeepsBackingOwnersWithoutAnIndependentLease() throws {
        let texture = try makeTexture()
        var owner: NSObject? = NSObject()
        weak var retainedOwner = owner
        var payload: RenderedFramePreviewHostPayload? = RenderedFramePreviewHostPayload(sampleBufferFactory: { [owner] in
            withExtendedLifetime(owner) { nil }
        })
        var frame: RenderedFrame? = RenderedFrame(texture: texture, profile: .stablePreview,
            token: FrameRenderToken(identifier: "backing-owner", generation: 1), previewHostPayload: payload)
        var node: ImageNode? = ImageNode.source(.renderedFrame(frame!))
        owner = nil
        payload = nil
        frame = nil
        var output: RenderedFrame? = try node!.makeFrame()
        XCTAssertNil(output?.lease)
        node = nil
        XCTAssertNotNil(retainedOwner)
        output = nil
        XCTAssertNil(retainedOwner)
    }

    func testExternalEncodingRetainsFrameOwnerAfterCommandCompletion() throws {
        let texture = try makeTexture()
        let released = expectation(description: "输出释放后归还输入资源")
        let recorder = PluginLeaseRecorder()
        var source: RenderedFrame? = RenderedFrame(texture: texture, alphaType: .alphaIsOne, profile: .stablePreview,
            generation: 1, identifier: "encoded-source", lease: TextureLease(texture: texture, releaseHandler: {
                recorder.record()
                released.fulfill()
            }))
        var node: ImageNode? = ImageNode.source(.renderedFrame(source!))
        var command = HarbethContext.shared.makeCommandBuffer()
        var output: RenderedFrame? = try node!.encodeFrame(into: XCTUnwrap(command), inputColorSpace: .sRGB,
            workingColorSpace: .sRGB, pixelFormat: .rgba8Unorm)
        XCTAssertTrue(output?.texture === texture)
        source = nil
        node = nil
        try command!.commitAndWaitUntilCompleted(identifier: "plugin-encoded-source")
        command = nil
        XCTAssertEqual(recorder.count, 0)
        output = nil
        wait(for: [released], timeout: 2)
        XCTAssertEqual(recorder.count, 1)
    }

    func testWrappedInputFrameKeepsLeaseAndExplicitOutputMetadata() throws {
        let plugin = PluginProbe(capability: .nativeMetal)
        plugin.wrapsFrame = true
        var node: ImageNode? = try ImageNode.texture(makeTexture()).applying(C7Brightness(brightness: 0.1))
            .applying(plugin: plugin)
        var output: RenderedFrame? = try node!.makeFrame()
        XCTAssertEqual(output?.orientation, .left)
        XCTAssertEqual(output?.metadata["custom"], "wrapped")
        XCTAssertTrue(output?.lease === plugin.inputLease)
        node = nil
        XCTAssertNotNil(plugin.inputLease)
        output = nil
        XCTAssertNil(plugin.inputLease)
    }

    func testFrameSourceHonorsLogicalExtentInsteadOfPoolPadding() throws {
        let texture = try makeTexture(width: 4, height: 4)
        let frame = RenderedFrame(texture: texture, resolvedOutputSize: C7Size(width: 2, height: 3),
            profile: .stablePreview, generation: 1, identifier: "logical-extent")
        let source = ImageNode.source(.renderedFrame(frame))
        let output = try source.makeFrame()
        XCTAssertEqual(output.texture.width, 2)
        XCTAssertEqual(output.texture.height, 3)
        let raw = try source.makeTexture()
        XCTAssertEqual(raw.width, 2)
        XCTAssertEqual(raw.height, 3)
    }

    private func makeTexture(width: Int = 1, height: Int = 1) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("Metal 设备不可用。") }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let pixel: [UInt8] = [100, 80, 60, 255]
        let bytes = Array(repeating: pixel, count: width * height).flatMap { $0 }
        bytes.withUnsafeBytes { buffer in
            texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                withBytes: buffer.baseAddress!, bytesPerRow: width * 4)
        }
        return texture
    }
}

private final class PluginProbe: Plugin {
    let pluginIdentifier: String
    let capability: PluginCapability
    let output: PluginOutput?
    let failsDiagnostics: Bool
    var wrapsFrame = false
    private(set) var outputCalls = 0
    private(set) var diagnosticsCalls = 0
    private(set) var inputProfile: RenderProfile?
    private(set) var contextProfile: RenderProfile?
    private(set) var inputToken: FrameRenderToken?
    private(set) var inputSize: C7Size?
    private(set) weak var inputLease: TextureLease?

    init(identifier: String = "plugin.probe", capability: PluginCapability, output: PluginOutput? = nil, failsDiagnostics: Bool = false) {
        pluginIdentifier = identifier
        self.capability = capability
        self.output = output
        self.failsDiagnostics = failsDiagnostics
    }

    func makeOutput(frame: RenderedFrame) throws -> PluginOutput {
        outputCalls += 1
        inputProfile = frame.profile
        inputToken = frame.token
        inputSize = C7Size(texture: frame.texture)
        inputLease = frame.lease
        if wrapsFrame {
            return .frame(RenderedFrame(texture: frame.texture, alphaType: frame.alphaType, orientation: .left,
                profile: frame.profile, token: frame.token, metadata: ["custom": "wrapped"]))
        }
        return output ?? .texture(frame.texture)
    }

    func makeOutput(frame: RenderedFrame, context: PluginContext) throws -> PluginOutput {
        contextProfile = context.profile
        return try makeOutput(frame: frame)
    }

    func makeDiagnostics(frame: RenderedFrame) throws -> PluginDiagnostics? {
        diagnosticsCalls += 1
        if failsDiagnostics { throw HarbethError.configurationInvalid("诊断失败。") }
        XCTAssertEqual(frame.token, inputToken)
        return ["analysis": "same-frame"]
    }
}

private final class PluginLeaseRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int { lock.withLock { value } }
    func record() { lock.withLock { value += 1 } }
}
