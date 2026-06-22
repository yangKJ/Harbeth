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
        synchronizedDevice {
            if let context = existingContext {
                context.resetCaches()
            }
            existingContext = nil
            existingDevice = nil
            existingTexturePool = nil
            existingTextureAllocator = nil
            performanceMonitor = nil
        }
    }
    
    public func advanceSetupDevice() {
        let _ = self.defaultDevice
    }
    
    public var hasDevice: Bool {
        return synchronizedDevice {
            existingDevice != nil
        }
    }

    public var hasContext: Bool {
        synchronizedDevice {
            existingContext != nil
        }
    }
}

private var C7ATSharedDeviceContext: UInt8 = 0
private var C7ATSharedTexturePoolContext: UInt8 = 0
private var C7ATSharedPerformanceMonitorContext: UInt8 = 0
private var C7ATSharedContext: UInt8 = 0
private var C7ATSharedTextureAllocatorContext: UInt8 = 0
private var C7ATSharedTextureAllocationStrategyContext: UInt8 = 0

extension Shared {

    fileprivate var existingDevice: Device? {
        get { objc_getAssociatedObject(self, &C7ATSharedDeviceContext) as? Device }
        set { objc_setAssociatedObject(self, &C7ATSharedDeviceContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    fileprivate var existingTexturePool: TexturePool? {
        get { objc_getAssociatedObject(self, &C7ATSharedTexturePoolContext) as? TexturePool }
        set { objc_setAssociatedObject(self, &C7ATSharedTexturePoolContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    fileprivate var existingContext: HarbethContext? {
        get { objc_getAssociatedObject(self, &C7ATSharedContext) as? HarbethContext }
        set { objc_setAssociatedObject(self, &C7ATSharedContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    fileprivate var existingTextureAllocator: TextureAllocator? {
        get { objc_getAssociatedObject(self, &C7ATSharedTextureAllocatorContext) as? TextureAllocator }
        set { objc_setAssociatedObject(self, &C7ATSharedTextureAllocatorContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    fileprivate var existingTextureAllocationStrategy: NSString? {
        get { objc_getAssociatedObject(self, &C7ATSharedTextureAllocationStrategyContext) as? NSString }
        set { objc_setAssociatedObject(self, &C7ATSharedTextureAllocationStrategyContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private func resolvedDefaultTextureAllocationStrategy() -> TextureAllocationStrategy {
        guard let rawValue = existingTextureAllocationStrategy as String?,
              let strategy = TextureAllocationStrategy(rawValue: rawValue) else {
            return .exact
        }
        return strategy
    }

    private func makeDefaultTextureAllocatorLocked() -> TextureAllocator {
        resolvedDefaultTextureAllocationStrategy().makeAllocator(
            texturePool: defaultTexturePool,
            on: existingDevice?.device
        )
    }
    
    public var defaultDevice: Device {
        synchronizedDevice {
            if let device = existingDevice {
                return device
            }
            let device = Device()
            existingDevice = device
            return device
        }
    }

    public var defaultContext: HarbethContext {
        synchronizedDevice {
            if let context = existingContext {
                return context
            }
            let device: Device
            if let existingDevice {
                device = existingDevice
            } else {
                let created = Device()
                existingDevice = created
                device = created
            }
            let context = HarbethContext(device: device)
            existingContext = context
            return context
        }
    }

    public var metalDevice: MTLDevice {
        defaultDevice.device
    }

    public var commandQueue: MTLCommandQueue {
        defaultDevice.commandQueue
    }

    public var sharedTextureCache: CVMetalTextureCache? {
        defaultDevice.textureCache
    }

    public var currentMetalDevice: MTLDevice? {
        synchronizedDevice {
            existingDevice?.device
        }
    }

    public var renderOperationQueue: OperationQueue {
        defaultDevice.sharedRenderOperationQueue
    }

    public var memoryLimitMB: Int {
        get { defaultDevice.sharedMemoryLimitMB }
        set { defaultDevice.sharedMemoryLimitMB = newValue }
    }

    public func getCommandBuffer() -> MTLCommandBuffer? {
        defaultDevice.dequeueCommandBuffer()
    }

    public func returnCommandBuffer(_ buffer: MTLCommandBuffer) {
        defaultDevice.enqueueCommandBuffer(buffer)
    }

    public var defaultTexturePool: TexturePool {
        synchronizedDevice {
            if let pool = existingTexturePool {
                return pool
            }
            let pool = TexturePool()
            existingTexturePool = pool
            return pool
        }
    }

    public var defaultTextureAllocationStrategy: TextureAllocationStrategy {
        get {
            synchronizedDevice {
                resolvedDefaultTextureAllocationStrategy()
            }
        }
        set {
            synchronizedDevice {
                existingTextureAllocationStrategy = newValue.rawValue as NSString
                existingTextureAllocator = nil
            }
        }
    }

    var defaultTextureAllocator: TextureAllocator {
        get {
            synchronizedDevice {
                if let allocator = existingTextureAllocator {
                    return allocator
                }
                let allocator = makeDefaultTextureAllocatorLocked()
                existingTextureAllocator = allocator
                return allocator
            }
        }
        set {
            synchronizedDevice {
                existingTextureAllocator = newValue
            }
        }
    }

    /// Compatibility surface. Use `defaultDevice` for the default runtime owner.
    @available(*, deprecated, message: "Use Shared.shared.defaultDevice instead.")
    public weak var device: Device? {
        get {
            synchronizedDevice {
                if let device = existingDevice {
                    return device
                }
                let device = Device()
                existingDevice = device
                return device
            }
        }
        set {
            synchronizedDevice {
                existingDevice = newValue
                existingContext = nil
            }
        }
    }
    
    /// Compatibility surface. Use `defaultTexturePool` for the default runtime owner.
    @available(*, deprecated, message: "Use Shared.shared.defaultTexturePool instead.")
    public weak var texturePool: TexturePool? {
        get {
            synchronizedDevice {
                if let pool = existingTexturePool {
                    return pool
                }
                let pool = TexturePool()
                existingTexturePool = pool
                return pool
            }
        }
        set {
            synchronizedDevice {
                existingTexturePool = newValue
            }
        }
    }

    /// Compatibility surface. Use `defaultContext` for the default execution context.
    @available(*, deprecated, message: "Use Shared.shared.defaultContext instead.")
    public var context: HarbethContext? {
        get {
            synchronizedDevice {
                if let context = existingContext {
                    return context
                }
                let device: Device
                if let existingDevice {
                    device = existingDevice
                } else {
                    let created = Device()
                    existingDevice = created
                    device = created
                }
                let context = HarbethContext(device: device)
                existingContext = context
                return context
            }
        }
        set {
            synchronizedDevice {
                existingContext = newValue
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
        defaultTexturePool.prewarm(resolutions: resolutions, count: count)
    }

    public func prewarmTexturePool(reservations: [RenderTextureReservation],
                                   fallbackPixelFormat: MTLPixelFormat,
                                   defaultCount: Int = 1) {
        defaultTexturePool.prewarm(
            requests: makePrewarmRequests(
                from: reservations,
                fallbackPixelFormat: fallbackPixelFormat,
                defaultCount: defaultCount
            )
        )
    }

    public func prewarmTexturePoolSync(reservations: [RenderTextureReservation],
                                       fallbackPixelFormat: MTLPixelFormat,
                                       defaultCount: Int = 1) {
        defaultTexturePool.prewarmSync(
            requests: makePrewarmRequests(
                from: reservations,
                fallbackPixelFormat: fallbackPixelFormat,
                defaultCount: defaultCount
            )
        )
    }
    
    /// Get the statistics of the texture pool
    public var texturePoolStatistics: TexturePool.Statistics? {
        return defaultTexturePool.statistics
    }
    
    /// Reset the statistics of the texture pool
    public func resetTexturePoolStatistics() {
        defaultTexturePool.resetStatisticsSync()
    }

    private func makePrewarmRequests(from reservations: [RenderTextureReservation],
                                     fallbackPixelFormat: MTLPixelFormat,
                                     defaultCount: Int) -> [TexturePool.PrewarmRequest] {
        reservations.map { reservation in
            TexturePool.PrewarmRequest(
                width: reservation.size.width,
                height: reservation.size.height,
                pixelFormat: reservation.pixelFormat.metalPixelFormat ?? fallbackPixelFormat,
                count: max(defaultCount, reservation.count)
            )
        }
    }
}
