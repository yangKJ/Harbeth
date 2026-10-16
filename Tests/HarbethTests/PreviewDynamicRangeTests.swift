//
//  PreviewDynamicRangeTests.swift
//  HarbethTests
//
//  Created by Condy on 2026/8/2.
//

import Metal
import QuartzCore
import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
@testable import Harbeth

final class PreviewDynamicRangeTests: XCTestCase {
    #if targetEnvironment(macCatalyst) || canImport(AppKit)
    @MainActor
    func testDesktopActivationRequestsRedrawWithoutReplacingRetainedFrame() async throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: 2,
            height: 2,
            mipmapped: false
        )
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let frame = RenderedFrame(
            texture: texture,
            outputColorSpaceContract: .extendedLinearDisplayP3,
            profile: .stablePreview,
            generation: 1,
            identifier: "desktop-retained-frame"
        )
        let view = RedrawTrackingRenderView(frame: .zero, device: device)
        view.display(frame)
        let displayState = view.currentPreviewDisplayState
        let baseline = view.invalidationCount
        for (index, notification) in desktopPresentationNotifications.enumerated() {
            NotificationCenter.default.post(name: notification.name, object: notification.sender)
            XCTAssertEqual(view.invalidationCount, baseline + index)
            await waitForMainQueue()

            XCTAssertEqual(view.invalidationCount, baseline + index + 1)
            XCTAssertEqual(view.currentRenderedFrame?.token, frame.token)
            XCTAssertTrue(view.currentRenderedFrame?.texture === texture)
            XCTAssertEqual(view.currentPreviewDisplayState, displayState)
            XCTAssertTrue(view.isPaused)
            XCTAssertTrue(view.enableSetNeedsDisplay)
        }
    }

    @MainActor
    func testDesktopActivationDoesNotInvalidateEmptyPreview() async throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = RedrawTrackingRenderView(frame: .zero, device: device)
        let baseline = view.invalidationCount

        for notification in desktopPresentationNotifications {
            NotificationCenter.default.post(name: notification.name, object: notification.sender)
        }

        await waitForMainQueue()
        XCTAssertEqual(view.invalidationCount, baseline)
        XCTAssertNil(view.currentRenderedFrame)
    }

    @MainActor
    private func waitForMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    @MainActor
    private var desktopPresentationNotifications: [(name: Notification.Name, sender: AnyObject)] {
        #if canImport(UIKit)
        // Catalyst 不能构造 NSWindow；主窗口和遮挡通知由 AppKit 回归与消费者真实窗口验收覆盖。
        return [(Notification.Name("NSApplicationDidBecomeActiveNotification"), UIApplication.shared)]
        #else
        let window = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
        return [
            (NSApplication.didBecomeActiveNotification, NSApplication.shared),
            (NSWindow.didBecomeKeyNotification, window),
            (NSWindow.didChangeOcclusionStateNotification, window),
        ]
        #endif
    }
    #endif

    @MainActor
    func testRenderViewCanDeallocateInsideTaskLocalScope() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        RenderViewDeinitTaskLocal.$marker.withValue(1) {
            for _ in 0..<4 {
                weak var releasedView: RenderView?
                autoreleasepool {
                    let view = RenderView(frame: .zero, device: device)
                    releasedView = view
                    XCTAssertEqual(RenderViewDeinitTaskLocal.marker, 1)
                }
                XCTAssertNil(releasedView)
            }
        }
    }

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

private enum RenderViewDeinitTaskLocal {
    @TaskLocal static var marker = 0
}

#if targetEnvironment(macCatalyst) || canImport(AppKit)
@MainActor
private final class RedrawTrackingRenderView: RenderView {
    private(set) var invalidationCount = 0

    #if canImport(UIKit)
    override func setNeedsDisplay() {
        invalidationCount += 1
        super.setNeedsDisplay()
    }
    #else
    override func setNeedsDisplay(_ rect: CGRect) {
        invalidationCount += 1
        super.setNeedsDisplay(rect)
    }
    #endif
}
#endif
