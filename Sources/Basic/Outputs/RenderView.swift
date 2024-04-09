//
//  RenderView.swift
//  Harbeth
//
//  Created by Condy on 2024/3/20.
//

import Foundation
import MetalKit

public final class RenderView: C7ImageView, Renderable {
    
    public typealias Element = C7Image
    
    public override var image: C7Image? {
        didSet {
            setupInputSource()
        }
    }
}

extension Renderable where Self: C7ImageView {
    
    public func setupInputSource() {
        if lockedSource {
            return
        }
        if inputSource == nil, let image = self.image {
            self.inputSource = try? TextureLoader(with: image).texture
        }
        self.filtering()
    }
    
    public func setupOutputDest(_ dest: MTLTexture) {
        DispatchQueue.main.async {
            if let image = self.image {
                self.image = try? dest.c7.fixImageOrientation(refImage: image)
            }
        }
    }
}
