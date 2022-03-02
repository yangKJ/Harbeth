//
//  C7CollectorProtocol.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import UIKit

public protocol C7CollectorProtocol {
    
    /// Multiple filter combinations.
    var filters: [C7FilterProtocol] { get set }
    
    /// Initialization method
    /// This mode directly generates images for external use.
    ///
    /// - Parameter callback: Collect generated filter image callback. You can display it directly using ImageView.
    init(callback: @escaping C7FilterImageCallback)
    
    /// Initialization method, TODO:
    /// This mode internally generates MTKView for rendering.
    ///
    /// - Parameter view: Host the render control view.
    init(view: UIView)
}
