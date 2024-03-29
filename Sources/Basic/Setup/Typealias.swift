//
//  Typealias.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/16.
//

import Foundation
@_exported import MetalKit
@_exported import CoreVideo
@_exported import CoreImage
@_exported import CoreMedia
@_exported import AVFoundation
import ImageIO

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
public typealias C7View  = UIView
public typealias C7Color = UIColor
public typealias C7Image = UIImage
public typealias C7EdgeInsets = UIEdgeInsets
public typealias C7ImageView = UIImageView
public typealias C7ImageOrientation = UIImage.Orientation
#elseif os(macOS)
import AppKit
public typealias C7View  = NSView
public typealias C7Color = NSColor
public typealias C7Image = NSImage
public typealias C7EdgeInsets = NSEdgeInsets
public typealias C7ImageView = NSImageView
public typealias C7ImageOrientation = CGImagePropertyOrientation
#endif

public typealias C7InputTextures = [MTLTexture]
public typealias C7FilterImageCallback = (_ image: C7Image) -> Void

typealias C7KernelFunction = String

// Make sure to run on the main thread.
//@inline(__always) func make_run_on_main_thread() {
//    assert(Thread.isMainThread)
//}
