//
//  PreviewDynamicRangeTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/8/2.
//

import Metal
import QuartzCore
import XCTest
@testable import Harbeth

final class PreviewDynamicRangeTests: XCTestCase {
    @MainActor
    func testAutomaticPolicyEnablesExtendedPresentationForExtendedFrame() {
        let state = RenderView.resolvePreviewDisplayState(
            policy: .automatic,
            frameDynamicRange: .extendedDynamicRange,
            outputColorSpace: .extendedLinearDisplayP3,
            supportsExtendedRange: true
        )

        XCTAssertEqual(state.requestedDynamicRange, .extendedDynamicRange)
        XCTAssertEqual(state.effectiveDynamicRange, .extendedDynamicRange)
        XCTAssertTrue(state.isExtendedRangePresentationEnabled)
        XCTAssertNil(state.fallbackReason)
    }

    @MainActor
    func testAutomaticPolicyReportsSDRFallbackWhenExtendedRangeIsUnavailable() {
        let state = RenderView.resolvePreviewDisplayState(
            policy: .automatic,
            frameDynamicRange: .extendedDynamicRange,
            outputColorSpace: .extendedLinearDisplayP3,
            supportsExtendedRange: false
        )

        XCTAssertEqual(state.requestedDynamicRange, .extendedDynamicRange)
        XCTAssertEqual(state.effectiveDynamicRange, .standardDynamicRange)
        XCTAssertFalse(state.isExtendedRangePresentationEnabled)
        XCTAssertEqual(state.fallbackReason, .extendedRangeUnavailable)
    }

    @MainActor
    func testStandardPolicyForcesSDRWithoutReportingCapabilityFallback() {
        let state = RenderView.resolvePreviewDisplayState(
            policy: .standard,
            frameDynamicRange: .highDynamicRange,
            outputColorSpace: .extendedLinearDisplayP3,
            supportsExtendedRange: true
        )

        XCTAssertEqual(state.requestedDynamicRange, .standardDynamicRange)
        XCTAssertEqual(state.effectiveDynamicRange, .standardDynamicRange)
        XCTAssertFalse(state.isExtendedRangePresentationEnabled)
        XCTAssertNil(state.fallbackReason)
    }

    @MainActor
    func testExtendedPolicyCanRequestEDRForRawTextureHost() {
        let state = RenderView.resolvePreviewDisplayState(
            policy: .extended,
            frameDynamicRange: .standardDynamicRange,
            outputColorSpace: .extendedLinearDisplayP3,
            supportsExtendedRange: true
        )

        XCTAssertEqual(state.requestedDynamicRange, .extendedDynamicRange)
        XCTAssertEqual(state.effectiveDynamicRange, .extendedDynamicRange)
        XCTAssertTrue(state.isExtendedRangePresentationEnabled)
    }

    func testRenderedFrameCarriesTypedOutputColorContract() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("当前环境没有 Metal device")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: 2,
            height: 2,
            mipmapped: false
        )
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return XCTFail("无法创建测试 texture")
        }

        let frame = RenderedFrame(
            texture: texture,
            outputColorSpaceContract: .extendedLinearDisplayP3,
            profile: .stablePreview,
            generation: 1,
            identifier: "typed-hdr-frame"
        )

        XCTAssertEqual(frame.outputColorSpaceContract, .extendedLinearDisplayP3)
        XCTAssertEqual(frame.outputDynamicRange, .extendedDynamicRange)
        XCTAssertEqual(frame.outputToneMappingPolicy, .preserveInput)
    }

    @MainActor
    func testRenderViewDisplayPublishesStateOnMainActorAndConfiguresHDRDrawable() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("当前环境没有 Metal device")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: 2,
            height: 2,
            mipmapped: false
        )
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return XCTFail("无法创建测试 texture")
        }
        let frame = RenderedFrame(
            texture: texture,
            outputColorSpaceContract: .extendedLinearDisplayP3,
            profile: .stablePreview,
            generation: 1,
            identifier: "render-view-hdr-display"
        )
        let view = RenderView(frame: .zero, device: device)
        view.dynamicRangePolicy = .standard
        var callbackState: PreviewDisplayState?
        var callbackWasMainThread = false
        view.onPreviewDisplayStateUpdated = { state in
            callbackState = state
            callbackWasMainThread = Thread.isMainThread
        }

        view.display(frame)

        XCTAssertTrue(view.currentRenderedFrame?.texture === texture)
        XCTAssertEqual(view.colorPixelFormat, .rgba16Float)
        XCTAssertEqual(callbackState, view.currentPreviewDisplayState)
        XCTAssertTrue(callbackWasMainThread)
        XCTAssertEqual(
            (view.layer as? CAMetalLayer)?.colorspace?.name,
            ImageColorSpaceContract.extendedLinearDisplayP3.cgColorSpace?.name
        )
    }
}
