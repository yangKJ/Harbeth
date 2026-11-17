//
//  C7Crop.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// For use class.
/// See: https://stackoverflow.com/questions/49253299/cannot-assign-to-property-self-is-immutable-i-know-how-to-fix-but-needs-unde
public final class C7Crop: C7FilterProtocol, SamplerAdaptableFilter, GeometryParameterValidating {

    /// The adjusted contrast, from 0 to 1.0, with a default of 0.0
    public var origin: C7Point2D = C7Point2D.zero
    public var samplingMode: SpatialSamplingMode = .adaptive
    public var edgeMode: SpatialEdgeMode = .transparent

    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Crop")
    }

    public var factors: [Float] {
        return origin.toXY() + [Float(samplingMode.rawValue), Float(edgeMode.rawValue)]
    }

    public var memoryAccessPattern: MemoryAccessPattern { .neighborhood }
    public var samplingFootprint: SamplingFootprint { .global }
    public var kernelOutputContract: RenderOutputContract { .premultipliedColorOutput }
    public var kernelPixelContract: KernelPixelContract {
        .init(inputAlphaExpectation: .premultiplied, outputAlpha: .premultiplied,
              precision: .float32, dynamicRangeBehavior: .preservesExtendedRange,
              samplingFootprint: .global, coordinateDependency: .absoluteInput, globalDependency: .imageDimensions)
    }
    public var kernelConfigurationIdentity: String? {
        switch cropType {
        case .size(let width, let height): return "size=\(width.bitPattern),\(height.bitPattern)"
        case .space(let space): return "space=\(space.bitPattern)"
        case .rect(let rect):
            return "rect=" + [rect.origin.x, rect.origin.y, rect.width, rect.height].map { String(Double($0).bitPattern) }.joined(separator: ",")
        }
    }
    public var kernelParameterBindings: [KernelParameterBinding] { kernelParameterBindings(inputSize: nil) }

    public func kernelParameterBindings(inputSize: C7Size?) -> [KernelParameterBinding] {
        let resolvedOrigin: C7Point2D
        switch cropType {
        case .size: resolvedOrigin = origin
        case .space(let space):
            resolvedOrigin = inputSize.map { C7Point2D(x: space / Float(max($0.width, 1)), y: space / Float(max($0.height, 1))) } ?? .zero
        case .rect(let rect):
            resolvedOrigin = inputSize.map { C7Point2D(x: Float(rect.origin.x) / Float(max($0.width, 1)), y: Float(rect.origin.y) / Float(max($0.height, 1))) } ?? .zero
        }
        return [
            .init(name: "originX", index: 0, stage: .compute, value: .float(resolvedOrigin.x)),
            .init(name: "originY", index: 1, stage: .compute, value: .float(resolvedOrigin.y)),
            .init(name: "samplingMode", index: 2, stage: .compute, value: .float(Float(samplingMode.rawValue))),
            .init(name: "edgeMode", index: 3, stage: .compute, value: .float(Float(edgeMode.rawValue)))
        ]
    }

    func validateGeometryParameters() throws {
        switch cropType {
        case .size(let width, let height):
            try validateResizeDimensions(width, height)
            guard origin.x.isFinite, origin.y.isFinite else { throw HarbethError.configurationInvalid("裁切原点必须是有限值。") }
        case .space(let space):
            guard space.isFinite, Double(space) > Double(Int.min), Double(space) < Double(Int.max) else {
                throw HarbethError.configurationInvalid("裁切边距必须可表示为整数。")
            }
        case .rect(let rect):
            guard rect.origin.x.isFinite, rect.origin.y.isFinite, Float(rect.origin.x).isFinite, Float(rect.origin.y).isFinite,
                  Placement.validDimension(Double(rect.width)), Placement.validDimension(Double(rect.height)) else {
                throw HarbethError.configurationInvalid("裁切矩形无效。")
            }
        }
    }
    func validateGeometryParameters(inputSize: C7Size) throws {
        try validateGeometryParameters()
        if case .space(let space) = cropType {
            let inset = Double(Int(space)) * 2
            guard Placement.validDimension(Double(inputSize.width) - inset), Placement.validDimension(Double(inputSize.height) - inset) else {
                throw HarbethError.configurationInvalid("裁切边距没有留下有效画布。")
            }
        }
    }

    public func resize(input size: C7Size) -> C7Size {
        return crop(size: size)
    }

    public func samplerAdaptation(for descriptor: ImageSamplerDescriptor) -> SamplerAdaptation {
        guard descriptor != .default else {
            return .notApplicable
        }
        let samplingMode = descriptor.compatibleSpatialSamplingMode
        let edgeMode = descriptor.compatibleSpatialEdgeMode
        guard samplingMode != nil || edgeMode != nil else {
            return .metadataOnly
        }
        let resolved = resolved(samplingMode: samplingMode, edgeMode: edgeMode)
        if samplingMode != nil, edgeMode != nil, descriptor.mipFilter == .notMipmapped {
            return .covered(resolved)
        }
        return .partial(resolved)
    }

    private var cropType: CropType = CropType.size(width: 0, height: 0)

    /// Specifies the border area clipping initialization.
    /// - Parameters:
    ///   - space: Cutting dimension around, in pixels.
    ///   - samplingMode: Sampling mode used by the crop operation.
    ///   - edgeMode: Behavior used when sampling outside the source extent.
    public required init(space: Float, samplingMode: SpatialSamplingMode = .adaptive, edgeMode: SpatialEdgeMode = .transparent) {
        self.samplingMode = samplingMode
        self.edgeMode = edgeMode
        self.cropType = CropType.space(space)
    }

    public required init(rect: CGRect, samplingMode: SpatialSamplingMode = .adaptive, edgeMode: SpatialEdgeMode = .transparent) {
        self.samplingMode = samplingMode
        self.edgeMode = edgeMode
        self.cropType = CropType.rect(rect)
    }

    public required init(origin: C7Point2D = .zero,
                         width: Float, height: Float,
                         samplingMode: SpatialSamplingMode = .adaptive,
                         edgeMode: SpatialEdgeMode = .transparent) {
        self.origin = origin
        self.samplingMode = samplingMode
        self.edgeMode = edgeMode
        self.cropType = CropType.size(width: width, height: height)
    }
}

extension C7Crop {
    enum CropType {
        case size(width: Float, height: Float)
        case space(Float)
        case rect(CGRect)
    }

    func crop(size: C7Size) -> C7Size {
        switch cropType {
        case .size(let width, let height): return Placement.fit.resize(width: width, height: height, size: size)
        case .space(let space):
            guard space.isFinite, Double(space) > Double(Int.min), Double(space) < Double(Int.max) else { return size }
            let inset = Double(Int(space)) * 2
            return C7Size(width: Placement.safeDimension(Double(size.width) - inset, fallback: size.width),
                          height: Placement.safeDimension(Double(size.height) - inset, fallback: size.height))
        case .rect(let rect):
            return C7Size(width: Placement.safeDimension(Double(rect.width), fallback: size.width),
                          height: Placement.safeDimension(Double(rect.height), fallback: size.height))
        }
    }

    func resolved(samplingMode: SpatialSamplingMode?,
                  edgeMode: SpatialEdgeMode?) -> C7Crop {
        let nextSamplingMode = samplingMode ?? self.samplingMode
        let nextEdgeMode = edgeMode ?? self.edgeMode
        switch cropType {
        case .size(let width, let height):
            return C7Crop(
                origin: origin,
                width: width,
                height: height,
                samplingMode: nextSamplingMode,
                edgeMode: nextEdgeMode
            )
        case .space(let space):
            return C7Crop(
                space: space,
                samplingMode: nextSamplingMode,
                edgeMode: nextEdgeMode
            )
        case .rect(let rect):
            return C7Crop(
                rect: rect,
                samplingMode: nextSamplingMode,
                edgeMode: nextEdgeMode
            )
        }
    }
}
