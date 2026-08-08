//
//  HarbethRenderView.swift
//  Harbeth
//
//  Created by Condy on 2023/12/5.
//

import SwiftUI
@preconcurrency import Metal

/// SwiftUI 中直接承载 Harbeth texture-first 输出的宿主视图。
///
/// 直接复用 `RenderView` 展示 `MTLTexture` 或 `RenderedFrame`，避免为了预览发生 CPU 读回。
@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct HarbethRenderView: View {
    private let texture: MTLTexture?
    private let frame: RenderedFrame?
    private let resizingMode: RenderView.ResizingMode
    private let preferredDrawableScale: CGFloat?
    private let dynamicRangePolicy: PreviewDynamicRangePolicy
    private let onExecutionReport: ((PreviewHostExecutionReport) -> Void)?
    private let onFleetSnapshot: ((PreviewHostFleetSnapshot) -> Void)?
    private let onPreviewDisplayState: ((PreviewDisplayState) -> Void)?

    public init(
        texture: MTLTexture?,
        resizingMode: RenderView.ResizingMode = .aspectFit,
        preferredDrawableScale: CGFloat? = nil,
        dynamicRangePolicy: PreviewDynamicRangePolicy = .automatic,
        onExecutionReport: ((PreviewHostExecutionReport) -> Void)? = nil,
        onFleetSnapshot: ((PreviewHostFleetSnapshot) -> Void)? = nil,
        onPreviewDisplayState: ((PreviewDisplayState) -> Void)? = nil
    ) {
        self.texture = texture
        self.frame = nil
        self.resizingMode = resizingMode
        self.preferredDrawableScale = preferredDrawableScale
        self.dynamicRangePolicy = dynamicRangePolicy
        self.onExecutionReport = onExecutionReport
        self.onFleetSnapshot = onFleetSnapshot
        self.onPreviewDisplayState = onPreviewDisplayState
    }

    public init(
        frame: RenderedFrame?,
        resizingMode: RenderView.ResizingMode = .aspectFit,
        preferredDrawableScale: CGFloat? = nil,
        dynamicRangePolicy: PreviewDynamicRangePolicy = .automatic,
        onExecutionReport: ((PreviewHostExecutionReport) -> Void)? = nil,
        onFleetSnapshot: ((PreviewHostFleetSnapshot) -> Void)? = nil,
        onPreviewDisplayState: ((PreviewDisplayState) -> Void)? = nil
    ) {
        self.texture = nil
        self.frame = frame
        self.resizingMode = resizingMode
        self.preferredDrawableScale = preferredDrawableScale
        self.dynamicRangePolicy = dynamicRangePolicy
        self.onExecutionReport = onExecutionReport
        self.onFleetSnapshot = onFleetSnapshot
        self.onPreviewDisplayState = onPreviewDisplayState
    }

    public var body: some View {
        HarbethRenderViewRepresentable(
            texture: texture,
            frame: frame,
            resizingMode: resizingMode,
            preferredDrawableScale: preferredDrawableScale,
            dynamicRangePolicy: dynamicRangePolicy,
            onExecutionReport: onExecutionReport,
            onFleetSnapshot: onFleetSnapshot,
            onPreviewDisplayState: onPreviewDisplayState
        )
    }
}

#if canImport(UIKit)
@available(iOS 15.0, tvOS 15.0, *)
private struct HarbethRenderViewRepresentable: UIViewRepresentable {
    let texture: MTLTexture?
    let frame: RenderedFrame?
    let resizingMode: RenderView.ResizingMode
    let preferredDrawableScale: CGFloat?
    let dynamicRangePolicy: PreviewDynamicRangePolicy
    let onExecutionReport: ((PreviewHostExecutionReport) -> Void)?
    let onFleetSnapshot: ((PreviewHostFleetSnapshot) -> Void)?
    let onPreviewDisplayState: ((PreviewDisplayState) -> Void)?

    func makeUIView(context: Context) -> RenderView {
        RenderView(frame: .zero, device: nil)
    }

    func updateUIView(_ view: RenderView, context: Context) {
        Self.update(
            view,
            texture: texture,
            frame: frame,
            resizingMode: resizingMode,
            preferredDrawableScale: preferredDrawableScale,
            dynamicRangePolicy: dynamicRangePolicy,
            onExecutionReport: onExecutionReport,
            onFleetSnapshot: onFleetSnapshot,
            onPreviewDisplayState: onPreviewDisplayState
        )
    }

    static func dismantleUIView(_ view: RenderView, coordinator: Void) { reset(view) }
}
#elseif canImport(AppKit)
@available(macOS 12.0, *)
private struct HarbethRenderViewRepresentable: NSViewRepresentable {
    let texture: MTLTexture?
    let frame: RenderedFrame?
    let resizingMode: RenderView.ResizingMode
    let preferredDrawableScale: CGFloat?
    let dynamicRangePolicy: PreviewDynamicRangePolicy
    let onExecutionReport: ((PreviewHostExecutionReport) -> Void)?
    let onFleetSnapshot: ((PreviewHostFleetSnapshot) -> Void)?
    let onPreviewDisplayState: ((PreviewDisplayState) -> Void)?

    func makeNSView(context: Context) -> RenderView {
        RenderView(frame: .zero, device: nil)
    }

    func updateNSView(_ view: RenderView, context: Context) {
        Self.update(
            view,
            texture: texture,
            frame: frame,
            resizingMode: resizingMode,
            preferredDrawableScale: preferredDrawableScale,
            dynamicRangePolicy: dynamicRangePolicy,
            onExecutionReport: onExecutionReport,
            onFleetSnapshot: onFleetSnapshot,
            onPreviewDisplayState: onPreviewDisplayState
        )
    }

    static func dismantleNSView(_ view: RenderView, coordinator: Void) { reset(view) }
}
#endif

#if canImport(UIKit) || canImport(AppKit)
@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
private extension HarbethRenderViewRepresentable {
    static func update(
        _ view: RenderView,
        texture: MTLTexture?,
        frame: RenderedFrame?,
        resizingMode: RenderView.ResizingMode,
        preferredDrawableScale: CGFloat?,
        dynamicRangePolicy: PreviewDynamicRangePolicy,
        onExecutionReport: ((PreviewHostExecutionReport) -> Void)?,
        onFleetSnapshot: ((PreviewHostFleetSnapshot) -> Void)?,
        onPreviewDisplayState: ((PreviewDisplayState) -> Void)?
    ) {
        view.resizingMode = resizingMode
        view.preferredDrawableScale = preferredDrawableScale
        view.dynamicRangePolicy = dynamicRangePolicy
        view.onPreviewHostExecutionReportUpdated = onExecutionReport
        view.onPreviewHostFleetSnapshotUpdated = onFleetSnapshot
        view.onPreviewDisplayStateUpdated = onPreviewDisplayState
        if let frame {
            view.display(frame)
        } else {
            view.display(nil)
            view.texture = texture
        }
    }

    static func reset(_ view: RenderView) {
        view.display(nil)
        view.texture = nil
        view.dynamicRangePolicy = .automatic
        view.onPreviewHostExecutionReportUpdated = nil
        view.onPreviewHostFleetSnapshotUpdated = nil
        view.onPreviewDisplayStateUpdated = nil
    }
}
#endif
