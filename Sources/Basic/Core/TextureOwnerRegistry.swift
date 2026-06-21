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

    private final class OwnerBox: NSObject {
        let owners: [AnyObject]

        init(owners: [AnyObject]) {
            self.owners = owners
        }
    }

    private static var ownerKey: UInt8 = 0

    static func attach(_ owner: AnyObject, to texture: MTLTexture) {
        objc_setAssociatedObject(texture, &ownerKey, owner, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func attach(_ owners: [AnyObject], to texture: MTLTexture) {
        guard owners.isEmpty == false else { return }
        if owners.count == 1, let owner = owners.first {
            attach(owner, to: texture)
            return
        }
        objc_setAssociatedObject(texture, &ownerKey, OwnerBox(owners: owners), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func owner(for texture: MTLTexture) -> AnyObject? {
        objc_getAssociatedObject(texture, &ownerKey) as AnyObject?
    }
}
