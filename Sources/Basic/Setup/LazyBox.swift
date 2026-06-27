//
//  LazyBox.swift
//  Harbeth
//
//  Created by Condy on 2026/6/27.
//

import Foundation
import MetalKit

/// NSCache value wrapper,因为 NSCache<NSString, ...> 要求 class。
final class BoxedTexture {
    let texture: MTLTexture
    init(texture: MTLTexture) { self.texture = texture }
}

/// 延迟求值包装。把构造期重操作延后到第一次访问。
///
/// 只用于同一闭包内部读一次的场景;`get()` 不是线程安全的(设计上
/// `makeRenderRequest` 返回的 `RenderRequest` 由调用方在单线程持有)。
final class LazyBox<T> {
    private var value: T?
    private var producer: () throws -> T
    private var computed = false

    init(_ producer: @escaping () throws -> T) {
        self.producer = producer
    }

    func get() throws -> T {
        if !computed {
            value = try producer()
            computed = true
        }
        return value!
    }
}
