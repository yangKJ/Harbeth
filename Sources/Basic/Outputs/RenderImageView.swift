//
//  RenderView.swift
//  Harbeth
//
//  Created by Condy on 2024/3/20.
//

import Foundation
import MetalKit

public final class RenderImageView: C7ImageView, Renderable {
    
    public typealias Element = C7Image
    
    public override var image: C7Image? {
        didSet {
            if lockedSource {
                return
            }
            self.setupInputSource()
            self.filtering()
        }
    }
}

extension Renderable where Self: C7ImageView {
    
    public func setupInputSource() {
        if lockedSource {
            return
        }
        if let image = self.image {
            self.inputSource = try? TextureLoader(with: image).texture
        }
    }
    
    public func setupOutputDest(_ dest: MTLTexture) {
        DispatchQueue.main.async {
            if let image = self.image {
                self.lockedSource = true
                self.image = try? dest.c7.fixImageOrientation(refImage: image)
                self.lockedSource = false
            }
        }
    }
}
