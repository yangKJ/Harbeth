//
//  UnitTestViewController.swift
//  MetalDemo
//
//  Created by Condy on 2022/11/3.
//

import Foundation
import Harbeth

class UnitTestViewController: UIViewController {
    
    let originImage = R.image("AX")
    
    lazy var renderView: RenderImageView = {
        let view = RenderImageView.init(image: originImage)
        view.keepAroundForSynchronousRender = false
        //imageView.contentMode = .scaleAspectFit
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.borderColor = UIColor.background2?.cgColor
        view.layer.borderWidth = 0.5
        return view
    }()
    
    lazy var leftBarButton: UIBarButtonItem = {
        let bar = UIBarButtonItem(title: "Mourning", style: .plain, target: self, action: #selector(mourningAction))
        if #available(iOS 15.0, *) {
            bar.isSelected = true
        } else {
            // Fallback on earlier versions
        }
        return bar
    }()
    
    lazy var overlay: UIView = {
        let overlay = UIView.init(frame: view.bounds)
        overlay.isUserInteractionEnabled = false
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .lightGray
        overlay.layer.compositingFilter = "saturationBlendMode"
        overlay.layer.zPosition = CGFloat(Float.greatestFiniteMagnitude)
        return overlay
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.unitTest()
    }
    
    func setupUI() {
        title = "Unit"
        navigationItem.rightBarButtonItem = leftBarButton
        view.backgroundColor = UIColor.background
        view.addSubview(renderView)
        NSLayoutConstraint.activate([
            renderView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            renderView.heightAnchor.constraint(equalTo: renderView.widthAnchor, multiplier: 1.0),
            //renderView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100),
            renderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            renderView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
        ])
    }
    
    private var mourning: Bool = false
    
    @objc func mourningAction() {
        if mourning {
            self.overlay.removeFromSuperview()
        } else {
            UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.addSubview(overlay)
        }
        self.mourning = !self.mourning
    }
}

extension UnitTestViewController {
    
    func unitTest() {
        let filter = C7Storyboard(ranks: 2)
        
        //let dest = HarbethIO.init(element: originImage, filters: [filter])
        //renderView.image = try? dest.output()
        renderView.filters = [filter]
    }
}

public final class RenderImageView: C7ImageView, Renderable {
    
    public typealias Element = C7Image
    
    public override var image: C7Image? {
        didSet {
            if lockedSource {
                return
            }
            self.setupInputSource()
            self.filtering()
        }
    }
}

extension Renderable where Self: C7ImageView {
    
    public func setupInputSource() {
        if lockedSource {
            return
        }
        if let image = self.image {
            self.inputSource = try? TextureLoader(with: image).texture
        }
    }
    
    public func setupOutputDest(_ dest: MTLTexture) {
        DispatchQueue.main.async {
            if let image = self.image {
                self.lockedSource = true
                self.image = try? dest.c7.fixImageOrientation(refImage: image)
                self.lockedSource = false
            }
        }
    }
}

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
