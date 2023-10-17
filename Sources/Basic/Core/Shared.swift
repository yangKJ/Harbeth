//
//  Shared.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/17.
//

import Foundation
import ObjectiveC

public final class Shared {
    
    public static let shared = Shared()
    
    /// 释放`Device`资源
    /// 考虑到`Device`当中存在蛮多比较消耗性能的对象，所以设计单例全局使用
    /// 一旦不再使用Metal之后，就调此方法将之释放掉
    ///
    /// Release the Device resource
    /// Considering that there are quite a lot of performance-consuming objects in `Device`, design a singleton for global use.
    /// Once Metal is no longer used, call this method to release it.
    public func deinitDevice() {
        device = nil
    }
    
    /// 是否已经初始化`Device`资源
    /// Whether the Device resource has been initialized.
    public var hasDevice: Bool {
        return synchronizedDevice {
            if let _ = objc_getAssociatedObject(self, &C7ATSharedContext) {
                return true
            }
            return false
        }
    }
    
    /// 提前加载`Device`资源
    public func advanceSetupDevice() {
        let _ = self.device
    }
    
    private init() { }
}

fileprivate var C7ATSharedContext: UInt8 = 0

extension Shared {
    
    /// Device instantiation
    weak var device: Device? {
        get {
            return synchronizedDevice {
                if let object = objc_getAssociatedObject(self, &C7ATSharedContext) {
                    return object as? Device
                } else {
                    let object = Device()
                    objc_setAssociatedObject(self, &C7ATSharedContext, object, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    return object
                }
            }
        }
        set {
            synchronizedDevice {
                objc_setAssociatedObject(self, &C7ATSharedContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    func synchronizedDevice<T>( _ action: () -> T) -> T {
        objc_sync_enter(self)
        let result = action()
        objc_sync_exit(self)
        return result
    }
}
