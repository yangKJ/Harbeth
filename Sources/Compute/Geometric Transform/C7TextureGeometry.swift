//
//  C7TextureGeometry.swift
//  Harbeth
//
//  Created by Condy on 2026/11/13.
//

import Foundation
import simd

/// 在一次采样中完成归一化裁切、镜像、缩放及画布适配；坐标以纹理左上角为原点。
public struct C7TextureGeometry: C7FilterProtocol {
    public let width: Int
    public let height: Int
    public let sourceRect: CGRect
    public let destinationRect: CGRect
    public let mirrorsHorizontally: Bool
    public let flipsVertically: Bool
    /// 裁切后的归一化坐标映射到实际输入纹理，越界像素使用background。
    public let sampleTransform: CGAffineTransform
    public let background: SIMD4<Float>

    public init(width: Int, height: Int,
                sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
                destinationRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
                mirrorsHorizontally: Bool = false, flipsVertically: Bool = false,
                background: SIMD4<Float> = SIMD4(0, 0, 0, 1),
                sampleTransform: CGAffineTransform = .identity) throws {
        func valid(_ rect: CGRect) -> Bool {
            let finite = rect.origin.x.isFinite && rect.origin.y.isFinite && rect.width.isFinite && rect.height.isFinite
            let positive = rect.minX >= 0 && rect.minY >= 0 && rect.width > 0 && rect.height > 0
            return finite && positive && rect.maxX <= 1 && rect.maxY <= 1
        }
        guard (1...16384).contains(width), (1...16384).contains(height),
              valid(sourceRect), valid(destinationRect), (0..<4).allSatisfy({ background[$0].isFinite }),
              [sampleTransform.a, sampleTransform.b, sampleTransform.c, sampleTransform.d,
               sampleTransform.tx, sampleTransform.ty].allSatisfy({ $0.isFinite && Float($0).isFinite }) else {
            throw HarbethError.configurationInvalid("无效的纹理采样几何。")
        }
        self.width = width
        self.height = height
        self.sourceRect = sourceRect
        self.destinationRect = destinationRect
        self.mirrorsHorizontally = mirrorsHorizontally
        self.flipsVertically = flipsVertically
        self.sampleTransform = sampleTransform
        self.background = background
    }

    public var modifier: ModifierEnum { .compute(kernel: "HarbethTextureGeometry") }
    public var memoryAccessPattern: MemoryAccessPattern { .point }
    public func resize(input size: C7Size) -> C7Size { C7Size(width: width, height: height) }
    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            .init(name: "sourceRect", index: 0, stage: .compute, value: .float4(vector(sourceRect))),
            .init(name: "destinationRect", index: 1, stage: .compute, value: .float4(vector(destinationRect))),
            .init(name: "flips", index: 2, stage: .compute, value: .float2(SIMD2(mirrorsHorizontally ? 1 : 0, flipsVertically ? 1 : 0))),
            .init(name: "background", index: 3, stage: .compute, value: .float4(background)),
            .init(name: "sampleRowX", index: 4, stage: .compute,
                value: .float4(SIMD4(Float(sampleTransform.a), Float(sampleTransform.c), Float(sampleTransform.tx), 0))),
            .init(name: "sampleRowY", index: 5, stage: .compute,
                value: .float4(SIMD4(Float(sampleTransform.b), Float(sampleTransform.d), Float(sampleTransform.ty), 0)))
        ]
    }
    private func vector(_ rect: CGRect) -> SIMD4<Float> {
        SIMD4(Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height))
    }
}
