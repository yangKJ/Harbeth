//
//  PointwiseFusion.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Foundation

protocol FusedKernelProtocol {
    var fusedOperationCount: Int { get }
}

struct C7FusedPointOperations: C7FilterProtocol, FusedKernelProtocol {
    struct Operation: Sendable, Equatable {
        enum Kind: Float, Sendable {
            case brightness = 0
            case contrast = 1
            case saturation = 2
            case exposure = 3
            case gamma = 4
            case opacity = 5
            case whiteBalance = 6
        }

        let kind: Kind
        let value: Float
        var secondaryValue: Float = 0
    }

    let operations: [Operation]

    var modifier: ModifierEnum {
        .compute(kernel: usesSpecializedKernel ? "C7FusedPointOperationsSpecialized" : "C7FusedPointOperations")
    }

    let kernelParameterBindings: [KernelParameterBinding]

    /// 仅专门化六种操作按固定顺序组成的子序列，最多 57 种；数值不进入变体键。
    /// 其余顺序和重复操作继续使用通用内核，避免管线变体随配方无界增长。
    var computeKernelFunctionConstants: [KernelFunctionConstantDescriptor] {
        guard usesSpecializedKernel else { return [] }
        let kinds = operations.enumerated().reduce(0) { $0 | (Int($1.element.kind.rawValue) << ($1.offset * 3)) }
        return [
            .init(name: "pointwiseKinds", index: 0, value: .int(kinds)),
            .init(name: "pointwiseCount", index: 1, value: .int(operations.count))
        ]
    }

    var usesSpecializedKernel: Bool {
        operations.count >= 2 && operations.count <= 6
            && zip(operations, operations.dropFirst()).allSatisfy { $0.kind.rawValue < $1.kind.rawValue }
    }

    init(operations: [Operation]) {
        self.operations = operations
        self.kernelParameterBindings = [
            KernelParameterBinding(
                name: "operations",
                index: 0,
                stage: .compute,
                value: .floatArray(operations.flatMap { [$0.kind.rawValue, $0.value, $0.secondaryValue] })
            ),
            KernelParameterBinding(
                name: "operationCount",
                index: 1,
                stage: .compute,
                value: .int(operations.count)
            )
        ]
    }

    var memoryAccessPattern: MemoryAccessPattern { .point }

    var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            workingColorSpace: operations.contains(where: { $0.kind == .brightness || $0.kind == .exposure }) ? .extendedLinearDisplayP3 : .preserveInput,
            inputAlphaExpectation: .premultiplied, outputAlpha: alphaOutput, precision: .float32,
            dynamicRangeBehavior: .unspecified,
            samplingFootprint: .point,
            fusionPolicy: .pointwise
        )
    }

    private var alphaOutput: ImageAlphaContract { operations.contains { $0.kind == .opacity } ? .premultiplied : .preserveInput }
    var kernelOutputContract: RenderOutputContract { .init(inputAlphaExpectation: .premultiplied, alpha: alphaOutput) }

    var fusedOperationCount: Int { operations.count }
}

enum PointwiseFusionPlanner {
    static let maximumOperationCount = 16

    static func canReuseSourceFingerprint(_ filters: [C7FilterProtocol]) -> Bool {
        // 仅内置纯点运算允许提前复用；其他滤镜可能在尺寸准备时更新参数。
        filters.allSatisfy { operation(for: $0) != nil }
    }

    static func makeExecutionFilters(_ filters: [C7FilterProtocol]) -> [C7FilterProtocol] {
        guard filters.count > 1 else { return filters }
        var result: [C7FilterProtocol] = []
        var pending: [C7FusedPointOperations.Operation] = []
        var originalPendingFilter: C7FilterProtocol?

        func flushPending() {
            guard pending.isEmpty == false else { return }
            if pending.count == 1, let originalPendingFilter {
                result.append(originalPendingFilter)
            } else {
                result.append(C7FusedPointOperations(operations: pending))
            }
            pending.removeAll(keepingCapacity: true)
            originalPendingFilter = nil
        }

        for filter in filters {
            guard let operation = operation(for: filter) else {
                flushPending()
                result.append(filter)
                continue
            }
            if pending.count == maximumOperationCount {
                flushPending()
            }
            if pending.isEmpty { originalPendingFilter = filter }
            pending.append(operation)
        }
        flushPending()
        return result
    }

    private static func operation(for filter: C7FilterProtocol) -> C7FusedPointOperations.Operation? {
        guard filter.otherInputTextures.isEmpty,
              filter.samplingFootprint == .point else { return nil }
        switch filter {
        case let filter as C7Brightness:
            return .init(kind: .brightness, value: filter.factors[0])
        case let filter as C7Contrast:
            return .init(kind: .contrast, value: filter.factors[0])
        case let filter as C7Saturation:
            return .init(kind: .saturation, value: filter.factors[0])
        case let filter as C7Exposure:
            return .init(kind: .exposure, value: filter.factors[0])
        case let filter as C7Gamma:
            return .init(kind: .gamma, value: filter.factors[0])
        case let filter as C7Opacity:
            return .init(kind: .opacity, value: filter.factors[0])
        case let filter as C7WhiteBalance:
            let parameters = filter.pointwiseParameters
            return .init(kind: .whiteBalance, value: parameters.x, secondaryValue: parameters.y)
        default:
            return nil
        }
    }
}
