//
//  TextureCacheable.swift
//  Harbeth
//
//  Created by Condy on 2022/10/28.
//

import Foundation
import ObjectiveC
import CoreVideo

// For simulator compile
#if targetEnvironment(simulator)
public typealias CVMetalTexture = AnyClass
public typealias CVMetalTextureCache = AnyClass
#endif

public protocol Cacheable {
    var textureCache: CVMetalTextureCache? { get set }
    
    /// Release the CVMetalTextureCache resource
    func deferTextureCache()
}

fileprivate var C7ATCacheContext: UInt8 = 0

extension Cacheable {
    public var textureCache: CVMetalTextureCache? {
        get {
            return synchronizedCacheable {
                if let object = objc_getAssociatedObject(self, &C7ATCacheContext) {
                    return (object as! CVMetalTextureCache)
                } else {
                    var textureCache: CVMetalTextureCache?
                    #if !targetEnvironment(simulator)
                    CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, Device.device(), nil, &textureCache)
                    #endif
                    objc_setAssociatedObject(self, &C7ATCacheContext, textureCache, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    return textureCache
                }
            }
        }
        set {
            synchronizedCacheable {
                objc_setAssociatedObject(self, &C7ATCacheContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    public func deferTextureCache() {
        #if !targetEnvironment(simulator)
        if let textureCache = textureCache {
            CVMetalTextureCacheFlush(textureCache, 0)
        }
        #endif
    }
    
    private func synchronizedCacheable<T>( _ action: () -> T) -> T {
        objc_sync_enter(self)
        let result = action()
        objc_sync_exit(self)
        return result
    }
}
