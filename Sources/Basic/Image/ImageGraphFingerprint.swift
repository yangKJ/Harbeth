//
//  ImageGraphFingerprint.swift
//  Harbeth
//
//  Created by Condy on 2026/11/8.
//

import Foundation

/// 不可变文本 DAG 共享上游前缀；只在读取诊断文本时展开，保留原有逐字合同。
/// 结构共享不以散列代替内容相等，也不跨请求保存可变滤镜。
final class ImageGraphFingerprint: Sendable, Hashable {
    private let text: String
    private let parts: [ImageGraphFingerprint]

    init(_ text: String) {
        self.text = text
        self.parts = []
    }

    init(parts: [ImageGraphFingerprint]) {
        self.text = ""
        self.parts = parts
    }

    var value: String {
        var pending = [self]
        var result = ""
        while let part = pending.popLast() {
            if part.parts.isEmpty {
                result.append(part.text)
            } else {
                pending.append(contentsOf: part.parts.reversed())
            }
        }
        return result
    }

    static func == (lhs: ImageGraphFingerprint, rhs: ImageGraphFingerprint) -> Bool {
        lhs === rhs || lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        // 不同分段必须与相同完整文本遵守一致的相等和哈希语义。
        hasher.combine(value)
    }
}
