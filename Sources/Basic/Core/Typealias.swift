//
//  Typealias.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation
import MetalKit
import class UIKit.UIImage

public typealias C7Image = UIImage
public typealias C7InputTextures = [MTLTexture]
public typealias C7Size = (width: Int, height: Int)
public typealias C7Point2D = (x: Float, y: Float)

/// 对于 2D 纹理，采用归一化之后的纹理坐标, 在 x 轴和 y 轴方向上都是从 0.0 到 1.0
/// 2D textures, normalized texture coordinates are used, from 0.0 to 1.0 in both x and y directions
public let C7Point2DMaximum = C7Point2D(x: 1.0, y: 1.0)
public let C7Point2DCenter  = C7Point2D(x: 0.5, y: 0.5)
public let C7Point2DZero    = C7Point2D(x: 0.0, y: 0.0)
