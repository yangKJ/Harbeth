//
//  ColorCubeReplacement.swift
//  Harbeth
//
//  Created by Condy on 2026/10/23.
//

import Foundation
import Metal

/// 命名 CUBE 的确定性替代入口；具体风格和是否准入由资源 owner 决定。
public protocol ColorCubeReplacementProvider: Sendable {
    var providerIdentifier: String { get }
    func replacement(resourceName: String, resourceOwner: String) -> ColorCubeReplacement?
}

/// 单位 RGB 域中的逐像素颜色链，不持有 LUT、空间效果或产品状态。
public struct ColorCubeReplacement {
    public let identifier: String
    public let version: Int
    public let filters: [C7FilterProtocol]
    let fingerprint: String
    let fusedAtoms: ColorCubeFusedAtoms?

    public init?(identifier: String, version: Int, filters: [C7FilterProtocol]) {
        guard !identifier.isEmpty, version > 0, !filters.isEmpty,
              filters.allSatisfy({ !($0 is C7FilterPipelineProtocol) && !($0 is C7ColorCube)
                  && $0.memoryAccessPattern == .point && $0.otherInputTextures.isEmpty }) else { return nil }
        self.identifier = identifier
        self.version = version
        self.filters = filters
        self.fusedAtoms = ColorCubeFusedAtoms(filters: filters)
        fingerprint = "cube-replacement:\(identifier):v\(version):" + filters.map { $0.recipeDescriptor.fingerprint }.joined(separator: "->")
    }
}

final class ColorCubeReplacementRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var providers: [any ColorCubeReplacementProvider] = []

    func register(_ provider: any ColorCubeReplacementProvider) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !provider.providerIdentifier.isEmpty,
              !providers.contains(where: { $0.providerIdentifier == provider.providerIdentifier }) else { return false }
        providers.append(provider)
        return true
    }

    func replacement(resourceName: String, resourceOwner: String) -> ColorCubeReplacement? {
        lock.lock()
        let snapshot = providers
        lock.unlock()
        // 在锁外构建滤镜，避免创建原子时重入资源系统。
        for provider in snapshot {
            if let replacement = provider.replacement(resourceName: resourceName, resourceOwner: resourceOwner) {
                return replacement
            }
        }
        return nil
    }
}

struct ColorCubeReplacementPrepare: C7FilterProtocol {
    // 连续原子在同一半浮点工作域中运行，避免每段写回 8 位纹理累积量化误差。
    var kernelOutputContract: RenderOutputContract { .init(pixelFormat: .rgba16Float) }
    var modifier: ModifierEnum { .compute(kernel: "colorCubeReplacementPrepare") }
    var memoryAccessPattern: MemoryAccessPattern { .point }
}

struct ColorCubeReplacementMix: C7FilterProtocol {
    let intensity: Float
    let domainPolicy: C7ColorCube.DomainPolicy
    let inputs: C7InputTextures
    var modifier: ModifierEnum { .compute(kernel: "colorCubeReplacementMix") }
    var kernelParameterBindings: [KernelParameterBinding] {
        [.init(name: "intensity", index: 0, stage: .compute, value: .float(intensity)),
         .init(name: "domainPolicy", index: 1, stage: .compute, value: .float(domainPolicy.rawValue))]
    }
    var otherInputTextures: C7InputTextures { inputs }
    var memoryAccessPattern: MemoryAccessPattern { .dualTexture }
}

/// 原生 LUT 叶子保留单次执行，避免 CUBE 的管线外壳再次递归调度自身。
struct ColorCubeKernel: C7FilterProtocol {
    let bindings: [KernelParameterBinding]
    let inputs: C7InputTextures
    let identity: String?
    let pixelContract: KernelPixelContract
    var modifier: ModifierEnum { .compute(kernel: "C7ColorCube") }
    var kernelParameterBindings: [KernelParameterBinding] { bindings }
    var otherInputTextures: C7InputTextures { inputs }
    var kernelResourceIdentity: String? { identity }
    var kernelPixelContract: KernelPixelContract { pixelContract }
    var memoryAccessPattern: MemoryAccessPattern { .dualTexture }
}

/// 线性通道曲线、颜色矩阵、线性通道曲线的通用单次执行，参数仍来自原子本身。
struct ColorCubeFusedAtoms: C7FilterProtocol {
    let first: C7Curves
    let matrix: C7ColorMatrix4x5
    let last: C7Curves
    var intensity: Float = 1
    var domainPolicy: C7ColorCube.DomainPolicy = .clampToDomain

    init?(filters: [C7FilterProtocol]) {
        guard filters.count == 3,
              let first = filters[0] as? C7Curves,
              let matrix = filters[1] as? C7ColorMatrix4x5,
              let last = filters[2] as? C7Curves,
              Self.supports(first), Self.supports(last), matrix.intensity == 1 else { return nil }
        let values = matrix.matrix.matrix4x4.values
        guard [3, 7, 11, 12, 13, 14].allSatisfy({ values[$0] == 0 }),
              values[15] == 1, matrix.matrix.vector4.values[3] == 0 else { return nil }
        self.first = first
        self.matrix = matrix
        self.last = last
    }

    private static func supports(_ curve: C7Curves) -> Bool {
        curve.interpolation == .linear && curve.extrapolation == .clampToEndpoints
            && curve.compositionOrder == .channelsThenRGB
            && curve.rgbPoints.count == 2
            && curve.rgbPoints[0].x == 0 && curve.rgbPoints[0].y == 0
            && curve.rgbPoints[1].x == 1 && curve.rgbPoints[1].y == 1
            && [curve.redPoints, curve.greenPoints, curve.bluePoints].allSatisfy { points in
                (2...16).contains(points.count) && points.allSatisfy { $0.x.isFinite && $0.y.isFinite }
            }
    }

    var modifier: ModifierEnum { .compute(kernel: "colorCubeReplacementCurveMatrixCurve") }
    var memoryAccessPattern: MemoryAccessPattern { .point }
    var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(precision: .float16,
            dynamicRangeBehavior: domainPolicy == .preserveOutsideDomain ? .preservesExtendedRange : .unspecified,
            samplingFootprint: .point)
    }
    var kernelParameterBindings: [KernelParameterBinding] {
        let channels = [first.redPoints, first.greenPoints, first.bluePoints, last.redPoints, last.greenPoints, last.bluePoints]
        let counts = channels.map { Float($0.count) }
        let points = channels.flatMap { $0.flatMap { [$0.x, $0.y] } }
        return [
            .init(name: "intensity", index: 0, stage: .compute, value: .float(intensity)),
            .init(name: "domainPolicy", index: 1, stage: .compute, value: .float(domainPolicy.rawValue)),
            .init(name: "counts", index: 2, stage: .compute, value: .floatArray(counts)),
            .init(name: "points", index: 3, stage: .compute, value: .floatArray(points)),
            .init(name: "matrix", index: 4, stage: .compute, value: .matrix4x4(matrix.matrix.matrix4x4)),
            .init(name: "offset", index: 5, stage: .compute, value: .float4(matrix.matrix.vector4.to_factor()))
        ]
    }
}
