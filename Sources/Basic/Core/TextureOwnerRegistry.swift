//
//  TextureOwnerRegistry.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal
import ObjectiveC

enum TextureOwnerRegistry {

    private static var ownerKey: UInt8 = 0

    static func attach(_ owner: AnyObject, to texture: MTLTexture) {
        objc_setAssociatedObject(texture, &ownerKey, owner, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func owner(for texture: MTLTexture) -> AnyObject? {
        objc_getAssociatedObject(texture, &ownerKey) as AnyObject?
    }
}
