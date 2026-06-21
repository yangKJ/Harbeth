//
//  FilterRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation

public struct FilterRecipeDescriptor: Sendable, Hashable, Codable {
    public let stableTypeID: String
    public let modifier: String
    public let parameterValues: [String]
    public let otherInputTextureCount: Int
    public let hasCount: Bool

    public init(stableTypeID: String,
                modifier: String,
                parameterValues: [String],
                otherInputTextureCount: Int,
                hasCount: Bool) {
        self.stableTypeID = stableTypeID
        self.modifier = modifier
        self.parameterValues = parameterValues
        self.otherInputTextureCount = otherInputTextureCount
        self.hasCount = hasCount
    }

    public var fingerprint: String {
        [
            stableTypeID,
            modifier,
            parameterValues.joined(separator: ","),
            "inputs=\(otherInputTextureCount)",
            "count=\(hasCount ? 1 : 0)"
        ].joined(separator: "|")
    }
}

public struct FilterChainRecipe: Sendable, Hashable, Codable {
    public let filters: [FilterRecipeDescriptor]

    public init(filters: [FilterRecipeDescriptor]) {
        self.filters = filters
    }

    public var fingerprint: String {
        filters.map(\.fingerprint).joined(separator: " -> ")
    }
}

public struct RenderRecipe: Sendable, Hashable, Codable {
    public let renderProfile: String
    public let renderIntent: RenderIntent
    public let source: ImageSourceDescriptor
    public let outputDerivative: ImageDerivativeSpec
    public let outputCachePolicy: ImageCachePolicy
    public let outputSemantic: ImageSemanticDescriptor
    public let alphaType: AlphaType
    public let orientation: FrameOrientation
    public let filters: [FilterRecipeDescriptor]

    public init(renderProfile: String,
                renderIntent: RenderIntent,
                source: ImageSourceDescriptor,
                outputDerivative: ImageDerivativeSpec,
                outputCachePolicy: ImageCachePolicy,
                outputSemantic: ImageSemanticDescriptor,
                alphaType: AlphaType,
                orientation: FrameOrientation,
                filters: [FilterRecipeDescriptor]) {
        self.renderProfile = renderProfile
        self.renderIntent = renderIntent
        self.source = source
        self.outputDerivative = outputDerivative
        self.outputCachePolicy = outputCachePolicy
        self.outputSemantic = outputSemantic
        self.alphaType = alphaType
        self.orientation = orientation
        self.filters = filters
    }

    public var fingerprint: String {
        [
            "profile=\(renderProfile)",
            "intent=\(renderIntent.rawValue)",
            source.fingerprint,
            outputDerivative.fingerprint,
            "outputCache=\(outputCachePolicy.rawValue)",
            outputSemantic.fingerprint,
            "alpha=\(alphaType.rawValue)",
            "orientation=\(orientation.rawValue)",
            filters.map(\.fingerprint).joined(separator: " -> ")
        ].joined(separator: " || ")
    }
}

extension C7FilterProtocol {
    public var recipeDescriptor: FilterRecipeDescriptor {
        FilterRecipeDescriptor(
            stableTypeID: stableTypeID,
            modifier: modifier.recipeName,
            parameterValues: factors.map { Self.stableFloatDescription($0) },
            otherInputTextureCount: otherInputTextures.count,
            hasCount: hasCount
        )
    }

    public static func stableFloatDescription(_ value: Float) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

extension Array where Element == C7FilterProtocol {
    public var chainRecipe: FilterChainRecipe {
        FilterChainRecipe(filters: map(\.recipeDescriptor))
    }
}
