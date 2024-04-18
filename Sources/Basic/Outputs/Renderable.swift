//
//  Renderable.swift
//  Harbeth
//
//  Created by Condy on 2024/3/20.
//

import Foundation
import ObjectiveC
import MetalKit

public protocol Renderable: AnyObject {
    associatedtype Element
    
    var filters: [C7FilterProtocol] { get set }
    
    var keepAroundForSynchronousRender: Bool { get set }
    
    /// Frequent changes require this to be set to true.
    var transmitOutputRealTimeCommit: Bool { get set }
    
    var inputSource: MTLTexture? { get set }
    
    func setupInputSource()
    
    func filtering()
    
    func setupOutputDest(_ dest: MTLTexture)
}

fileprivate var C7ATRenderableSetFiltersContext: UInt8 = 0
fileprivate var C7ATRenderableInputSourceContext: UInt8 = 0
fileprivate var C7ATRenderableTransmitOutputRealTimeCommitContext: UInt8 = 0
fileprivate var C7ATRenderableKeepAroundForSynchronousRenderContext: UInt8 = 0

extension Renderable {
    public var filters: [C7FilterProtocol] {
        get {
            return synchronizedRenderable {
                if let object = objc_getAssociatedObject(self, &C7ATRenderableSetFiltersContext) as? [C7FilterProtocol] {
                    return object
                } else {
                    let object = [C7FilterProtocol]()
                    objc_setAssociatedObject(self, &C7ATRenderableSetFiltersContext, object, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    return object
                }
            }
        }
        set {
            synchronizedRenderable {
                setupInputSource()
                objc_setAssociatedObject(self, &C7ATRenderableSetFiltersContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                filtering()
            }
        }
    }
    
    public var keepAroundForSynchronousRender: Bool {
        get {
            return synchronizedRenderable {
                if let object = objc_getAssociatedObject(self, &C7ATRenderableKeepAroundForSynchronousRenderContext) as? Bool {
                    return object
                } else {
                    objc_setAssociatedObject(self, &C7ATRenderableKeepAroundForSynchronousRenderContext, true, .OBJC_ASSOCIATION_ASSIGN)
                    return true
                }
            }
        }
        set {
            synchronizedRenderable {
                objc_setAssociatedObject(self, &C7ATRenderableKeepAroundForSynchronousRenderContext, newValue, .OBJC_ASSOCIATION_ASSIGN)
            }
        }
    }
    
    public var transmitOutputRealTimeCommit: Bool {
        get {
            return synchronizedRenderable {
                if let object = objc_getAssociatedObject(self, &C7ATRenderableTransmitOutputRealTimeCommitContext) as? Bool {
                    return object
                } else {
                    objc_setAssociatedObject(self, &C7ATRenderableTransmitOutputRealTimeCommitContext, false, .OBJC_ASSOCIATION_ASSIGN)
                    return false
                }
            }
        }
        set {
            synchronizedRenderable {
                objc_setAssociatedObject(self, &C7ATRenderableTransmitOutputRealTimeCommitContext, newValue, .OBJC_ASSOCIATION_ASSIGN)
            }
        }
    }
    
    public weak var inputSource: MTLTexture? {
        get {
            synchronizedRenderable {
                objc_getAssociatedObject(self, &C7ATRenderableInputSourceContext) as? MTLTexture
            }
        }
        set {
            synchronizedRenderable {
                objc_setAssociatedObject(self, &C7ATRenderableInputSourceContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    public func filtering() {
        guard let texture = inputSource, filters.count > 0 else {
            return
        }
        var dest = HarbethIO(element: texture, filters: filters)
        dest.transmitOutputRealTimeCommit = transmitOutputRealTimeCommit
        if self.keepAroundForSynchronousRender {
            do {
                self.lockedSource = true
                let result = try dest.output()
                self.setupOutputDest(result)
                self.lockedSource = false
            } catch { 
                return
            }
        } else {
            dest.transmitOutput(success: { [weak self] result in
                self?.lockedSource = true
                self?.setupOutputDest(result)
                self?.lockedSource = false
            })
        }
    }
}

fileprivate var C7ATRenderableLockedSourceContext: UInt8 = 0

extension Renderable {
    var lockedSource: Bool {
        get {
            return synchronizedRenderable {
                if let locked = objc_getAssociatedObject(self, &C7ATRenderableLockedSourceContext) as? Bool {
                    return locked
                } else {
                    objc_setAssociatedObject(self, &C7ATRenderableLockedSourceContext, false, .OBJC_ASSOCIATION_ASSIGN)
                    return false
                }
            }
        }
        set {
            synchronizedRenderable {
                objc_setAssociatedObject(self, &C7ATRenderableLockedSourceContext, newValue, .OBJC_ASSOCIATION_ASSIGN)
            }
        }
    }
    
    private func synchronizedRenderable<T>( _ action: () -> T) -> T {
        objc_sync_enter(self)
        let result = action()
        objc_sync_exit(self)
        return result
    }
}
