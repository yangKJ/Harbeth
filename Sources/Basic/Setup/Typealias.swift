//
//  Typealias.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation
import MetalKit
import class UIKit.UIImage
import class UIKit.UIColor
import class UIKit.UIView

public typealias C7View  = UIView
public typealias C7Color = UIColor
public typealias C7Image = UIImage
public typealias C7InputTextures = [MTLTexture]
public typealias C7Size = (width: Int, height: Int)
public typealias C7Point2D = (x: Float, y: Float)
public typealias C7RGBAColor = (red: Float, green: Float, blue: Float, alpha: Float)
public typealias C7FilterImageCallback = (_ image: C7Image) -> Void

internal typealias C7KernelFunction = String

/// 对于 2D 纹理，采用归一化之后的纹理坐标, 在 x 轴和 y 轴方向上都是从 0.0 到 1.0
/// 2D textures, normalized texture coordinates are used, from 0.0 to 1.0 in both x and y directions
public let C7Point2DMaximum = C7Point2D(x: 1.0, y: 1.0)
public let C7Point2DCenter  = C7Point2D(x: 0.5, y: 0.5)
public let C7Point2DZero    = C7Point2D(x: 0.0, y: 0.0)

public let C7ColorBlack = C7RGBAColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
public let C7ColorWhite = C7RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
public let C7ColorRed   = C7RGBAColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
public let C7ColorGreen = C7RGBAColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
public let C7ColorBlue  = C7RGBAColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)

// For simulator compile
#if targetEnvironment(simulator)
public typealias CVMetalTexture = AnyClass
public typealias CVMetalTextureCache = AnyClass
#endif
