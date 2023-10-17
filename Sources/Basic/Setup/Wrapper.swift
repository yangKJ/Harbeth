//
//  Wrapper.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation

/// Add the `c7` prefix namespace
public struct HarbethWrapper<Base> {
    public let base: Base
}

/// Protocol describing the `c7` extension points for Alamofire extended types.
public protocol HarbethCompatible { }

extension HarbethCompatible {
    
    public var c7: HarbethWrapper<Self> {
        get { return HarbethWrapper(base: self) }
        set { }
    }
    
    public static var c7: HarbethWrapper<Self>.Type {
        HarbethWrapper<Self>.self
    }
}
