//
//  CIResizedSmooth.swift
//  Harbeth
//
//  Created by Condy on 2024/4/8.
//

import Foundation
import CoreImage

public struct CIResizedSmooth: CIImageDisplaying {
    
    public var modifier: Modifier {
        return .coreimage(CIName: "CILanczosScaleTransform")
    }
    
    public var ciFilter: CIFilter?
    
    public var postProcessing: (CIImage) -> CIImage = { $0 }
    
    public func coreImageApply(filter: CIFilter, input ciImage: CIImage) throws -> CIImage {
        let scale = targetSize.height / ciImage.extent.height
        let aspectRatio = targetSize.width / (ciImage.extent.width) * scale
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
        return ciImage
    }
    
    public var targetSize: CGSize
    
    public init(targetSize: CGSize) {
        self.targetSize = targetSize
        self.ciFilter = CIFilter(name: "CILanczosScaleTransform")
    }
}
