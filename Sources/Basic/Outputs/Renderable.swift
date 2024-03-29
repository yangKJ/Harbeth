//
//  Renderable.swift
//  Harbeth
//
//  Created by Condy on 2024/3/20.
//

import Foundation
import ObjectiveC

public protocol Renderable: AnyObject {
    associatedtype Element
    
    var filters: [C7FilterProtocol] { get set }
    
    var keepAroundForSynchronousRender: Bool { get set }
    
    var inputSource: Element? { get set }
    
    func setupInputSource()
    
    func changedInputSource()
    
    func filtering()
    
    func setupOutputDest(_ dest: Element)
}

fileprivate var C7ATRenderableSetFiltersContext: UInt8 = 0
fileprivate var C7ATRenderableInputSourceContext: UInt8 = 0
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
    
    public var inputSource: Element? {
        get {
            synchronizedRenderable {
                objc_getAssociatedObject(self, &C7ATRenderableInputSourceContext) as? Element
            }
        }
        set {
            synchronizedRenderable {
                objc_setAssociatedObject(self, &C7ATRenderableInputSourceContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    public func filtering() {
        guard let image = inputSource, filters.count > 0 else {
            return
        }
        let dest = BoxxIO(element: image, filters: filters)
        if self.keepAroundForSynchronousRender {
            if let image_ = try? dest.output() {
                self.lockedSource = true
                self.setupOutputDest(image_)
                self.lockedSource = false
            }
        } else {
            dest.transmitOutput { [weak self] image_ in
                DispatchQueue.main.async {
                    self?.lockedSource = true
                    self?.setupOutputDest(image_)
                    self?.lockedSource = false
                }
            }
        }
    }
    
    public func changedInputSource() {
        if lockedSource {
            return
        }
        self.setupInputSource()
        self.filtering()
    }
}

fileprivate var C7ATRenderableLockedSourceContext: UInt8 = 0

extension Renderable {
    private var lockedSource: Bool {
        get {
            return synchronizedRenderable {
                if let object = objc_getAssociatedObject(self, &C7ATRenderableLockedSourceContext) as? Bool {
                    return object
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

// MARK: - image view
extension Renderable where Self: C7ImageView, Element == C7Image {
    
    public func setupInputSource() {
        if inputSource == nil {
            self.inputSource = image
        }
    }
    
    public func setupOutputDest(_ dest: C7Image) {
        self.image = dest
    }
}
