//
//  Res.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/7/29.
//

import Foundation
import Harbeth

struct Res {
    
    public static func rgUVB1Gradient(_ size: CGSize = .onePixel) throws -> MTLTexture {
        let texture = MTLTextureCompatible_.destTexture(width: Int(size.width), height: Int(size.height))
        let filter = C7ColorGradient(with: .rgUVB1)
        var dest = BoxxIO(element: texture, filter: filter)
        dest.createDestTexture = false
        return try dest.output()
    }
}
