//
//  ImageNode+Editing.swift
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

import Foundation

extension ImageNode {

    public func applying(localEffect: LocalEffectRecipe, mode: EditRecipeMode = .preview) -> ImageNode {
        editing(EditRecipe(localEffects: [localEffect]), mode: mode)
    }

    public func applying(optics recipe: OpticsRecipe, mode: EditRecipeMode = .preview) -> ImageNode {
        recipe.isIdentity ? self : editing(EditRecipe(optics: recipe), mode: mode)
    }

    public func editing(_ recipe: EditRecipe, mode: EditRecipeMode = .preview) -> ImageNode {
        ImageNode(storage: .edit(input: self, recipe: recipe, mode: mode))
    }

    public func transforming(_ geometry: ImageTransformRecipe, mode: EditRecipeMode = .preview) -> ImageNode {
        editing(EditRecipe(geometry: geometry), mode: mode)
    }

    public func applying(transition recipe: TransitionRecipe) -> ImageNode {
        ImageNode.transition(recipe)
    }

    public func applying(layerComposite recipe: LayerCompositeRecipe) -> ImageNode {
        ImageNode.layerComposite(recipe)
    }
}
