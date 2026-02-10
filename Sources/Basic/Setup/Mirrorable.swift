//
//  Mirrorable.swift
//  Harbeth
//
//  Created by Condy on 2022/12/8.
//

import Foundation

public protocol Mirrorable/*: Hashable*/ {
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

extension Mirrorable where Self: Hashable {
    /// Default Hashable implementation using reflection
    public func hash(into hasher: inout Hasher) {
        let properties = parameterDescription
        for (key, value) in properties.sorted(by: { $0.key < $1.key }) {
            hasher.combine(key)
            if let hashableValue = value as? AnyHashable {
                hasher.combine(hashableValue)
            } else if let texture = value as? MTLTexture {
                // Special handling for MTLTexture
                hasher.combine(ObjectIdentifier(texture))
            } else if let textures = value as? [MTLTexture] {
                // Special handling for MTLTexture arrays
                for (index, texture) in textures.enumerated() {
                    hasher.combine(index)
                    hasher.combine(ObjectIdentifier(texture))
                }
            } else {
                // For non-Hashable values, use string representation
                hasher.combine(String(describing: value))
            }
        }
    }
}

extension Mirrorable where Self: Equatable {
    /// Default Equatable implementation using reflection
    public static func == (lhs: Self, rhs: Self) -> Bool {
        let leftProperties = lhs.parameterDescription
        let rightProperties = rhs.parameterDescription
        
        // Check if both have the same keys
        let leftKeys = Set(leftProperties.keys)
        let rightKeys = Set(rightProperties.keys)
        if leftKeys != rightKeys {
            return false
        }
        
        // Check each property value
        for key in leftKeys {
            let leftValue = leftProperties[key]
            let rightValue = rightProperties[key]
            
            // Special handling for MTLTexture
            if let leftTexture = leftValue as? MTLTexture, let rightTexture = rightValue as? MTLTexture {
                if ObjectIdentifier(leftTexture) != ObjectIdentifier(rightTexture) {
                    return false
                }
                continue
            }
            
            // Special handling for MTLTexture arrays
            if let leftTextures = leftValue as? [MTLTexture], let rightTextures = rightValue as? [MTLTexture] {
                if leftTextures.count != rightTextures.count {
                    return false
                }
                for (leftTexture, rightTexture) in zip(leftTextures, rightTextures) {
                    if ObjectIdentifier(leftTexture) != ObjectIdentifier(rightTexture) {
                        return false
                    }
                }
                continue
            }
            
            // For Hashable values
            if let leftHashable = leftValue as? AnyHashable, let rightHashable = rightValue as? AnyHashable {
                if leftHashable != rightHashable {
                    return false
                }
                continue
            }
            
            // For other values, use string representation
            if String(describing: leftValue) != String(describing: rightValue) {
                return false
            }
        }
        
        return true
    }
}
