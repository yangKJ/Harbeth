//
//  Shared.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/17.
//

import Foundation
import ObjectiveC
import Metal

public final class Shared {
    
    public static let shared = Shared()
    
    /// Enable performance monitoring
    public var enablePerformanceMonitor: Bool = false {
        didSet {
            if enablePerformanceMonitor {
                self.performanceMonitor?.setupEnablePerformanceMonitor(enablePerformanceMonitor)
            } else {
                if let _ = objc_getAssociatedObject(self, &C7ATSharedPerformanceMonitorContext) {
                    self.performanceMonitor = nil
                }
            }
        }
    }
    
    private init() { }
    
    /// Release the Device resource
    /// Considering that there are quite a lot of performance-consuming objects in `Device`, design a singleton for global use.
    /// Once Metal is no longer used, call this method to release it.
    public func deinitDevice() {
        device = nil
        texturePool = nil
        performanceMonitor = nil
    }
    
    public func advanceSetupDevice() {
        let _ = self.device
    }
    
    public var hasDevice: Bool {
        return synchronizedDevice {
            if let _ = objc_getAssociatedObject(self, &C7ATSharedDeviceContext) {
                return true
            }
            return false
        }
    }
}

private var C7ATSharedDeviceContext: UInt8 = 0
private var C7ATSharedTexturePoolContext: UInt8 = 0
private var C7ATSharedPerformanceMonitorContext: UInt8 = 0

extension Shared {
    
    /// Device instantiation
    public weak var device: Device? {
        get {
            return synchronizedDevice {
                if let object = objc_getAssociatedObject(self, &C7ATSharedDeviceContext) {
                    return object as? Device
                } else {
                    let object = Device()
                    objc_setAssociatedObject(self, &C7ATSharedDeviceContext, object, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    return object
                }
            }
        }
        set {
            synchronizedDevice {
                objc_setAssociatedObject(self, &C7ATSharedDeviceContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    public weak var texturePool: TexturePool? {
        get {
            return synchronizedDevice {
                if let object = objc_getAssociatedObject(self, &C7ATSharedTexturePoolContext) {
                    return object as? TexturePool
                } else {
                    let object = TexturePool()
                    objc_setAssociatedObject(self, &C7ATSharedTexturePoolContext, object, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    return object
                }
            }
        }
        set {
            synchronizedDevice {
                objc_setAssociatedObject(self, &C7ATSharedTexturePoolContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    public var performanceMonitor: PerformanceMonitor? {
        get {
            if !enablePerformanceMonitor {
                return nil
            }
            return synchronizedDevice {
                if let object = objc_getAssociatedObject(self, &C7ATSharedPerformanceMonitorContext) {
                    return object as? PerformanceMonitor
                } else {
                    let object = PerformanceMonitor(enabled: enablePerformanceMonitor)
                    objc_setAssociatedObject(self, &C7ATSharedPerformanceMonitorContext, object, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    return object
                }
            }
        }
        set {
            synchronizedDevice {
                objc_setAssociatedObject(self, &C7ATSharedPerformanceMonitorContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    private func synchronizedDevice<T>( _ action: () -> T) -> T {
        objc_sync_enter(self)
        let result = action()
        objc_sync_exit(self)
        return result
    }
}

extension Shared {
    /// Preheat the texture pool
    /// - Parameters:
    ///   - resolutions: List of commonly used resolutions [(width, height, pixelFormat)]
    ///   - count: The number of pre-created textures for each resolution.
    public func prewarmTexturePool(resolutions: [(width: Int, height: Int, pixelFormat: MTLPixelFormat)], count: Int = 2) {
        texturePool?.prewarm(resolutions: resolutions, count: count)
    }
    
    /// Get the statistics of the texture pool
    public var texturePoolStatistics: TexturePool.Statistics? {
        return texturePool?.statistics
    }
    
    /// Reset the statistics of the texture pool
    public func resetTexturePoolStatistics() {
        texturePool?.resetStatisticsSync()
    }
}
