//
//  HarbethViewInput.swift
//  Harbeth
//
//  Created by Condy on 2025/1/1.
//

import Foundation

public struct HarbethViewInput {
    
    public let texture: MTLTexture?
    /// A filters add into a data source.
    public var filters: [C7FilterProtocol] = []
    /// Whether to use asynchronous processing, the UI will not be updated in real time.
    public var asynchronousProcessing: Bool = false
    /// Placeholder image, without source data.
    public var placeholder: C7Image?
    
    public init(texture: MTLTexture?) {
        self.texture = texture
    }
    
    public init(image: C7Image) {
        self.init(texture: image.c7.toTexture())
    }
}
