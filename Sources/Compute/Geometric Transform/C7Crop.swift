//
//  C7Crop.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

/// For use class.
/// See: https://stackoverflow.com/questions/49253299/cannot-assign-to-property-self-is-immutable-i-know-how-to-fix-but-needs-unde
public final class C7Crop: C7FilterProtocol, SamplerAdaptableFilter {

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

    public var memoryAccessPattern: MemoryAccessPattern {
        .point
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
        return .covered(resolved(samplingMode: samplingMode, edgeMode: edgeMode))
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
        case .size(let width, let height):
            let w = width > 0 ? Int(width) : size.width
            let h = height > 0 ? Int(height) : size.height
            return C7Size(width: w, height: h)
        case .space(let space):
            self.origin = C7Point2D(x: space/Float(size.width), y: space/Float(size.height))
            return C7Size(width: size.width-2*Int(space), height: size.height-2*Int(space))
        case .rect(let rect):
            self.origin = C7Point2D(x: Float(rect.origin.x) / Float(size.width),
                                    y: Float(rect.origin.y) / Float(size.height))
            return C7Size(width: Int(rect.size.width), height: Int(rect.size.height))
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
