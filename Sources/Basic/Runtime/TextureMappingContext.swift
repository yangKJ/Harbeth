//
//  TextureMappingContext.swift
//  Harbeth
//
//  Created by Condy on 2026/7/15.
//

import CoreGraphics
import Foundation

/// 描述输出 tile 到输入 ROI 的通用映射上下文。
///
/// compute、render 与 mesh kernel 共用相同的 buffer(30) ABI：
/// input origin/size/logical size + output origin/size/logical size。
public struct TextureMappingContext: Sendable, Equatable {
    public let inputLogicalExtent: CGRect
    public let inputRegion: CGRect
    public let outputLogicalExtent: CGRect
    public let outputRegion: CGRect

    public init(
        inputLogicalExtent: CGRect,
        inputRegion: CGRect,
        outputLogicalExtent: CGRect,
        outputRegion: CGRect
    ) throws {
        guard Self.isValid(inputLogicalExtent),
              Self.isValid(outputLogicalExtent),
              Self.isValid(inputRegion),
              Self.isValid(outputRegion),
              inputLogicalExtent.contains(inputRegion),
              outputLogicalExtent.contains(outputRegion) else {
            throw HarbethError.textureRegionInvalidReadRegion
        }
        self.inputLogicalExtent = inputLogicalExtent
        self.inputRegion = inputRegion
        self.outputLogicalExtent = outputLogicalExtent
        self.outputRegion = outputRegion
    }

    public var kernelValues: [Float] {
        [
            Float(inputRegion.minX), Float(inputRegion.minY),
            Float(inputLogicalExtent.width), Float(inputLogicalExtent.height),
            Float(outputRegion.minX), Float(outputRegion.minY),
            Float(outputLogicalExtent.width), Float(outputLogicalExtent.height)
        ]
    }

    private static func isValid(_ rect: CGRect) -> Bool {
        rect.minX.isFinite && rect.minY.isFinite &&
        rect.width.isFinite && rect.height.isFinite &&
        rect.width > 0 && rect.height > 0
    }
}
