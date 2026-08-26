//
//  IncrementalMaskCanvasSession.swift
//  Harbeth
//
//  Created by Condy on 2026/8/26.
//

import Foundation

/// 将增量蒙版画布约束在一个显式的串行执行域中。
///
/// UIKit/SwiftUI 输入层只发送笔刷意图；此会话负责按调用顺序提交 GPU 工作，避免调用方
/// 在主线程上直接等待 `IncrementalMaskCanvas` 的同步 Metal 完成。画布纹理仍是派生表示，
/// 用户的笔迹、历史和持久化真相继续由消费者持有。
public actor IncrementalMaskCanvasSession {
    private let canvas: IncrementalMaskCanvas

    public init(
        size: C7Size,
        storageFormat: MaskStorageFormat = .coverage8,
        coordinateSpace: MaskCoordinateSpace = .sourceNormalized,
        identifier: String = UUID().uuidString
    ) throws {
        canvas = try IncrementalMaskCanvas(
            size: size,
            storageFormat: storageFormat,
            coordinateSpace: coordinateSpace,
            identifier: identifier
        )
    }

    @discardableResult
    public func apply(
        points: [MaskBrushPoint],
        settings: MaskBrushSettings = MaskBrushSettings(),
        generation: UInt64? = nil,
        cancellation: TextureMultiPassCancellationToken? = nil
    ) throws -> MaskCanvasUpdate {
        try canvas.apply(
            points: points,
            settings: settings,
            generation: generation,
            cancellation: cancellation
        )
    }

    @discardableResult
    public func reset(generation: UInt64? = nil) throws -> MaskCanvasUpdate {
        try canvas.reset(generation: generation)
    }

    public func snapshot(sampling: MaskSamplingContract = .softCoverage) -> MaskPlane {
        canvas.snapshot(sampling: sampling)
    }
}
