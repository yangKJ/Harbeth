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
        func appendField(_ raw: String, into result: inout [(String, String)]) {
            // 先把占位符还原回 `||`，保持 value 字符串与原 fingerprint 等价
            let restored = raw.replacingOccurrences(of: "\u{1F}", with: "||")
            let segment = restored.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !segment.isEmpty, let eqIndex = segment.firstIndex(of: "=") else { return }
            let key = String(segment[..<eqIndex])
            let value = String(segment[segment.index(after: eqIndex)...])
            result.append((key, value))
        }
        // 用 ASCII 控制字符 \u{1F} 作为 `||` 的占位符;`{...}` 内不做替换。
        let placeholder: Character = "\u{1F}"
        var masked = ""
        var depth = 0
        var i = fingerprint.startIndex
        while i < fingerprint.endIndex {
            let ch = fingerprint[i]
            if ch == "{" {
                depth += 1
                masked.append(ch)
                i = fingerprint.index(after: i)
                continue
            }
            if ch == "}" {
                depth = max(depth - 1, 0)
                masked.append(ch)
                i = fingerprint.index(after: i)
                continue
            }
            if depth == 0, ch == "|",
               let next = fingerprint.index(i, offsetBy: 1, limitedBy: fingerprint.endIndex),
               next < fingerprint.endIndex, fingerprint[next] == "|" {
                masked.append(placeholder)
                i = fingerprint.index(after: next)
                continue
            }
            masked.append(ch)
            i = fingerprint.index(after: i)
        }

        var result: [(String, String)] = []
        var current = ""
        for ch in masked {
            if ch == "|" {
                appendField(current, into: &result)
                current.removeAll(keepingCapacity: true)
                continue
            }
            current.append(ch)
        }
        appendField(current, into: &result)
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
