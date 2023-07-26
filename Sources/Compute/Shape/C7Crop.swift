//
//  C7Crop.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/15.
//

import Foundation

public struct C7Crop: C7FilterProtocol {
    
    /// The adjusted contrast, from 0 to 1.0, with a default of 0.0
    public var origin: C7Point2D = C7Point2D.zero
    
    public var modifier: Modifier {
        return .compute(kernel: "C7Crop")
    }
    
    public var factors: [Float] {
        return origin.toXY()
    }
    
    public func resize(input size: C7Size) -> C7Size {
        return crop(size: size)
    }
    
    private var cropType: CropType = CropType.size(0, 0)
    
    /// Specifies the border area clipping initialization.
    /// - Parameter space: Cutting dimension around, Unit of pixel.
    public init(space: Float) {
        self.cropType = CropType.space(space)
    }
    
    public init(rect: CGRect) {
        self.cropType = CropType.rect(rect)
    }
    
    public init(origin: C7Point2D = .zero, width: Float, height: Float) {
        self.origin = origin
        self.cropType = CropType.size(width, height)
    }
}

extension C7Crop: Mutatingable {
    enum CropType {
        case size(Float, Float)
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
            self.mutating(type: C7Crop.self) {
                $0.origin = C7Point2D(x: space/Float(size.width), y: space/Float(size.height))
            }
            return C7Size(width: size.width-2*Int(space), height: size.height-2*Int(space))
        case .rect(let rect):
            self.mutating(type: C7Crop.self) {
                $0.origin = C7Point2D(x: Float(rect.origin.x)/Float(size.width), y: Float(rect.origin.y)/Float(size.height))
            }
            return rect.size.mt.toC7Size()
        }
    }
}
