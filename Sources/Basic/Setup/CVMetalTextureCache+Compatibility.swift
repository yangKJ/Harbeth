//
//  CVMetalTextureCache+Compatibility.swift
//  Harbeth
//
//  Created by Condy on 2026/8/1.
//

import CoreVideo

// Core Video does not expose these concrete types to simulator builds.
#if targetEnvironment(simulator)
public typealias CVMetalTexture = AnyClass
public typealias CVMetalTextureCache = AnyClass
#endif
