//
//  Mirrorable.swift
//  Harbeth
//
//  Created by Condy on 2022/12/8.
//

import Foundation

public protocol Mirrorable {
    /// Parametric description.
    var parameterDescription: [String: Any] { get }
}

extension Mirrorable {
    public var parameterDescription: [String: Any] {
        mapDictionary(mirror: Mirror(reflecting: self))
    }
}

extension Mirrorable {
    private func mapDictionary(mirror: Mirror) -> [String: Any] {
        var dict: [String: Any] = [:]
        for child in mirror.children {
            // If there is no labe, it will be discarded.
            if let label = child.label {
                //_ = Mirror(reflecting: child.value)
                dict[label] = child.value
            }
        }
        if let superMirror = mirror.superclassMirror {
            let superDic = mapDictionary(mirror: superMirror)
            for x in superDic {
                dict[x.key] = x.value
            }
        }
        return dict
    }
}
