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
public typealias C7FilterImageCallback = (_ image: C7Image) -> Void

typealias C7KernelFunction = String

// Make sure to run on the main thread.
@inline(__always) func make_run_on_main_thread() {
    assert(Thread.isMainThread)
}
