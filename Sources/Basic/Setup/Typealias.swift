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

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
public typealias C7View  = UIView
public typealias C7Color = UIColor
public typealias C7Image = UIImage
#elseif os(macOS)
import AppKit
public typealias C7View  = NSView
public typealias C7Color = NSColor
public typealias C7Image = NSImage
#endif

public typealias C7InputTextures = [MTLTexture]
public typealias C7FilterImageCallback = (_ image: C7Image) -> Void

typealias C7KernelFunction = String

// Make sure to run on the main thread.
@inline(__always) func make_run_on_main_thread() {
    assert(Thread.isMainThread)
}

// Wrong printing.
func C7FailedErrorInDebug(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
    #if DEBUG
    fatalError(message(), file: file, line: line)
    #else
    print("\(file):\(line): \(message())")
    #endif
}
