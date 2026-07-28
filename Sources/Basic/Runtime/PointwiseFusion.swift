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
        }

        let kind: Kind
        let value: Float
    }

    let operations: [Operation]

    var modifier: ModifierEnum {
        .compute(kernel: "C7FusedPointOperations")
    }

    var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(
                name: "operations",
                index: 0,
                stage: .compute,
                value: .floatArray(operations.flatMap { [$0.kind.rawValue, $0.value] })
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
            dynamicRangeBehavior: .unspecified,
            samplingFootprint: .point,
            fusionPolicy: .pointwise
        )
    }

    var fusedOperationCount: Int { operations.count }
}

enum PointwiseFusionPlanner {
    static let maximumOperationCount = 16

    static func makeExecutionFilters(_ filters: [C7FilterProtocol]) -> [C7FilterProtocol] {
        guard filters.count > 1 else { return filters }
        var result: [C7FilterProtocol] = []
        var pending: [C7FusedPointOperations.Operation] = []

        func flushPending() {
            guard pending.isEmpty == false else { return }
            if pending.count == 1, let operation = pending.first {
                result.append(makeOriginalFilter(operation))
            } else {
                result.append(C7FusedPointOperations(operations: pending))
            }
            pending.removeAll(keepingCapacity: true)
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
            return .init(kind: .brightness, value: filter.brightness)
        case let filter as C7Contrast:
            return .init(kind: .contrast, value: filter.contrast)
        case let filter as C7Saturation:
            return .init(kind: .saturation, value: filter.saturation)
        case let filter as C7Exposure:
            return .init(kind: .exposure, value: filter.exposure)
        case let filter as C7Gamma:
            return .init(kind: .gamma, value: filter.gamma)
        case let filter as C7Opacity:
            return .init(kind: .opacity, value: filter.opacity)
        default:
            return nil
        }
    }

    private static func makeOriginalFilter(_ operation: C7FusedPointOperations.Operation) -> C7FilterProtocol {
        switch operation.kind {
        case .brightness: return C7Brightness(brightness: operation.value)
        case .contrast: return C7Contrast(contrast: operation.value)
        case .saturation: return C7Saturation(saturation: operation.value)
        case .exposure: return C7Exposure(exposure: operation.value)
        case .gamma: return C7Gamma(gamma: operation.value)
        case .opacity: return C7Opacity(opacity: operation.value)
        }
    }
}
