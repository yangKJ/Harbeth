//
//  RenderView.swift
//  Harbeth
//
//  Created by Condy on 2024/3/20.
//

import Foundation
import MetalKit

public final class RenderView: C7ImageView, Renderable {
    
    public override var image: C7Image? {
        didSet {
            changedInputSource()
        }
    }
}
