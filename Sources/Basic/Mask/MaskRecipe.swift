//
//  MaskRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/7/2.
//

import Foundation
import CoreGraphics

public protocol MaskRecipe {
    var profile: RenderProfile { get }
    var fingerprint: String { get }
    var graphDescriptor: MaskGraphDescriptor { get }

    func graphDescriptor(component: MaskComponent, blendMode: MaskBlendMode, invert: Bool, featherPolicy: MaskFeatherPolicy, opacity: Float) -> MaskGraphDescriptor
    func makeMaskDescriptor(component: MaskComponent, blendMode: MaskBlendMode, invert: Bool, featherPolicy: MaskFeatherPolicy, opacity: Float) throws -> MaskDescriptor
}

protocol MaskRebasableRecipe: MaskRecipe {
    func rebasedRecipe(sourceRect: CGRect, logicalSize: C7Size, tileInputSize: C7Size) throws -> AnyMaskRecipe?
}

public extension MaskRecipe {
    /// 把当前 recipe 的 `fingerprint` 拆成 `(key, value)` 列表，按出现顺序保留。
    var fingerprintFields: [(String, String)] {
        var result: [(String, String)] = [], field = "", depth = 0
        func append() {
            guard let equal = field.firstIndex(of: "=") else { return }
            result.append((String(field[..<equal]), String(field[field.index(after: equal)...])))
        }
        var index = fingerprint.startIndex
        while index < fingerprint.endIndex {
            let character = fingerprint[index]
            if character == "{" { depth += 1 }
            if character == "}" { depth = max(depth - 1, 0) }
            let next = fingerprint.index(after: index)
            if character == "|", depth == 0 {
                if next < fingerprint.endIndex, fingerprint[next] == "|" {
                    field += "||"; index = fingerprint.index(after: next); continue
                }
                append(); field = ""
            } else { field.append(character) }
            index = next
        }
        append()
        return result
    }

}

extension AnyMaskRecipe: MaskRebasableRecipe {
    func rebasedRecipe(sourceRect: CGRect, logicalSize: C7Size, tileInputSize: C7Size) throws -> AnyMaskRecipe? {
        try rebased(sourceRect: sourceRect, logicalSize: logicalSize, tileInputSize: tileInputSize)
    }
}

extension MaskGradientRecipe: MaskRecipe { }
extension MaskShapeRecipe: MaskRecipe { }
extension MaskPathRecipe: MaskRecipe { }
extension MaskCompositeRecipe: MaskRecipe { }
extension MaskBrushRecipe: MaskRecipe { }
extension MaskRangeRecipe: MaskRecipe { }
extension MaskTextureRecipe: MaskRecipe { }
extension MaskDerivedRecipe: MaskRecipe { }
