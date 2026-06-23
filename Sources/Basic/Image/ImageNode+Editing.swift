//
//  ImageNode+Editing.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

import Foundation

extension ImageNode {
    /// 高级局部编辑 primitive 入口。
    ///
    /// 普通调用方默认优先使用 `.applying(mask: ...)`；
    /// 只有在调用方已经持有结构化 `LocalEffectRecipe` 时，才直接走这个入口。
    public func applying(localEffect: LocalEffectRecipe, mode: EditRecipeMode = .preview) -> ImageNode {
        editing(EditRecipe(localEffects: [localEffect]), mode: mode)
    }

    public func editing(_ recipe: EditRecipe, mode: EditRecipeMode = .preview) -> ImageNode {
        ImageNode(storage: .edit(input: self, recipe: recipe, mode: mode))
    }

    public func transforming(_ geometry: ImageTransformRecipe, mode: EditRecipeMode = .preview) -> ImageNode {
        editing(EditRecipe(geometry: geometry), mode: mode)
    }
}
