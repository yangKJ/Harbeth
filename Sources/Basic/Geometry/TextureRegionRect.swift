//
//  TextureRegionRect.swift
//  Harbeth
//
//  Created by Condy on 2026/7/10.
//

import CoreGraphics
import MetalKit

struct TextureRegionRect: Equatable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init?(rect: CGRect) {
        guard rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.width.isFinite, rect.height.isFinite,
              rect.origin.x.rounded() == rect.origin.x,
              rect.origin.y.rounded() == rect.origin.y,
              rect.width.rounded() == rect.width,
              rect.height.rounded() == rect.height,
              rect.origin.x >= CGFloat(Int.min), rect.origin.x <= CGFloat(Int.max),
              rect.origin.y >= CGFloat(Int.min), rect.origin.y <= CGFloat(Int.max),
              rect.width > 0, rect.height > 0,
              rect.width <= CGFloat(Int.max), rect.height <= CGFloat(Int.max) else {
            return nil
        }
        self.init(
            x: Int(rect.origin.x),
            y: Int(rect.origin.y),
            width: Int(rect.width),
            height: Int(rect.height)
        )
    }

    func fits(in texture: MTLTexture) -> Bool {
        guard x >= 0, y >= 0, x <= texture.width, y <= texture.height else {
            return false
        }
        return width <= texture.width - x && height <= texture.height - y
    }

    func fits(at origin: MTLOrigin, in texture: MTLTexture) -> Bool {
        guard origin.z == 0, origin.x >= 0, origin.y >= 0,
              origin.x <= texture.width, origin.y <= texture.height else {
            return false
        }
        return width <= texture.width - origin.x && height <= texture.height - origin.y
    }
}
