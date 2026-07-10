//
//  ImageTransformRecipe.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import CoreGraphics

public enum CoordinateSpace: String, Sendable, Codable, Equatable, Hashable {
    case pixel
    case normalized
}

public enum AspectPolicy: String, Sendable, Codable, Equatable, Hashable {
    case none
    case fit
    case fill
}

public enum ImageCanvasMode: String, Sendable, Codable, Equatable, Hashable {
    case minimumEnclosing
    case preserveInput
}

public enum ImageCropAnchor: String, Sendable, Codable, Equatable, Hashable {
    case center
    case top
    case bottom
    case leading
    case trailing
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    func resolvedOffset(fillSize: CGSize, targetSize: CGSize) -> CGPoint {
        let overflowX = max(fillSize.width - targetSize.width, 0)
        let overflowY = max(fillSize.height - targetSize.height, 0)
        let x: CGFloat
        let y: CGFloat
        switch self {
        case .center:
            x = overflowX * 0.5
            y = overflowY * 0.5
        case .top:
            x = overflowX * 0.5
            y = 0
        case .bottom:
            x = overflowX * 0.5
            y = overflowY
        case .leading:
            x = 0
            y = overflowY * 0.5
        case .trailing:
            x = overflowX
            y = overflowY * 0.5
        case .topLeading:
            x = 0
            y = 0
        case .topTrailing:
            x = overflowX
            y = 0
        case .bottomLeading:
            x = 0
            y = overflowY
        case .bottomTrailing:
            x = overflowX
            y = overflowY
        }
        return CGPoint(x: x, y: y)
    }
}

public struct ImageCropRegion: Sendable, Codable, Equatable, Hashable {
    public let rect: CGRect
    public let coordinateSpace: CoordinateSpace

    public init(rect: CGRect, coordinateSpace: CoordinateSpace = .pixel) {
        self.rect = rect.standardized
        self.coordinateSpace = coordinateSpace
    }

    public func resolvedRect(in size: CGSize) -> CGRect {
        let baseRect: CGRect
        switch coordinateSpace {
        case .pixel:
            baseRect = rect
        case .normalized:
            baseRect = CGRect(
                x: rect.origin.x * size.width,
                y: rect.origin.y * size.height,
                width: rect.size.width * size.width,
                height: rect.size.height * size.height
            )
        }

        let clampedOriginX = min(max(baseRect.origin.x, 0), size.width)
        let clampedOriginY = min(max(baseRect.origin.y, 0), size.height)
        let maxWidth = max(size.width - clampedOriginX, 0)
        let maxHeight = max(size.height - clampedOriginY, 0)
        let width = min(max(baseRect.size.width, 0), maxWidth)
        let height = min(max(baseRect.size.height, 0), maxHeight)
        return CGRect(x: clampedOriginX, y: clampedOriginY, width: width, height: height).integral
    }

    public func normalizedRect(in size: CGSize) -> CGRect {
        let pixelRect = resolvedRect(in: size)
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGRect(
            x: pixelRect.origin.x / size.width,
            y: pixelRect.origin.y / size.height,
            width: pixelRect.size.width / size.width,
            height: pixelRect.size.height / size.height
        )
    }

    public func resolvedOutputSize(in size: CGSize) -> C7Size {
        let resolved = resolvedRect(in: size)
        return C7Size(
            width: max(Int(resolved.width.rounded(.toNearestOrAwayFromZero)), 1),
            height: max(Int(resolved.height.rounded(.toNearestOrAwayFromZero)), 1)
        )
    }

    public var fingerprint: String {
        [
            "rect=\(ImageTransformRecipe.stableRectDescription(rect))",
            "space=\(coordinateSpace.rawValue)"
        ].joined(separator: "|")
    }
}

public struct ImageTransformRecipe {
    public var cropRegion: ImageCropRegion?
    public var targetSize: CGSize?
    public var aspectPolicy: AspectPolicy
    public var canvasMode: ImageCanvasMode
    public var cropAnchor: ImageCropAnchor
    public var quadTransform: RenderQuadTransform.Quad?
    public var perspectiveTransform: PerspectiveTransform?
    public var guidedUpright: GuidedUpright?
    public var projectiveViewportMode: Transform3DViewportMode
    public var rotationDegrees: Float
    public var mirrorsHorizontally: Bool
    public var flipsVertically: Bool

    public init(cropRegion: ImageCropRegion? = nil,
                targetSize: CGSize? = nil,
                aspectPolicy: AspectPolicy = .none,
                canvasMode: ImageCanvasMode = .minimumEnclosing,
                cropAnchor: ImageCropAnchor = .center,
                quadTransform: RenderQuadTransform.Quad? = nil,
                perspectiveTransform: PerspectiveTransform? = nil,
                guidedUpright: GuidedUpright? = nil,
                projectiveViewportMode: Transform3DViewportMode = .minimumEnclosing,
                rotationDegrees: Float = 0,
                mirrorsHorizontally: Bool = false,
                flipsVertically: Bool = false) {
        self.cropRegion = cropRegion
        self.targetSize = targetSize
        self.aspectPolicy = aspectPolicy
        self.canvasMode = canvasMode
        self.cropAnchor = cropAnchor
        self.quadTransform = quadTransform
        self.perspectiveTransform = perspectiveTransform
        self.guidedUpright = guidedUpright
        self.projectiveViewportMode = projectiveViewportMode
        self.rotationDegrees = rotationDegrees
        self.mirrorsHorizontally = mirrorsHorizontally
        self.flipsVertically = flipsVertically
    }

    public var isIdentity: Bool {
        cropRegion == nil &&
        targetSize == nil &&
        quadTransform == nil &&
        perspectiveTransform == nil &&
        guidedUpright == nil &&
        rotationDegrees.truncatingRemainder(dividingBy: 360) == 0 &&
        mirrorsHorizontally == false &&
        flipsVertically == false
    }

    public var fingerprint: String {
        [
            "crop=\(cropRegion?.fingerprint ?? "none")",
            "target=\(targetSize.map { ImageTransformRecipe.stableSizeDescription($0) } ?? "none")",
            "aspect=\(aspectPolicy.rawValue)",
            "canvas=\(canvasMode.rawValue)",
            "anchor=\(cropAnchor.rawValue)",
            "quad=\(quadTransform.map { ImageTransformRecipe.stableQuadDescription($0) } ?? "none")",
            "perspective=\(perspectiveTransform?.fingerprint ?? "none")",
            "upright=\(guidedUpright?.fingerprint ?? "none")",
            "projectiveViewport=\(projectiveViewportMode.rawValue)",
            "rotation=\(ImageTransformRecipe.stableFloatDescription(rotationDegrees.truncatingRemainder(dividingBy: 360)))",
            "mirror=\(mirrorsHorizontally ? 1 : 0)",
            "flip=\(flipsVertically ? 1 : 0)"
        ].joined(separator: "|")
    }

    public func makeFilters(inputSize: C7Size, prefersQualityResize: Bool = true) -> [C7FilterProtocol] {
        var filters: [C7FilterProtocol] = []
        var workingSize = inputSize

        if let cropRegion {
            let cropRect = cropRegion.resolvedRect(
                in: CGSize(width: inputSize.width, height: inputSize.height)
            )
            if cropRect.width > 0, cropRect.height > 0 {
                let crop = C7Crop(rect: cropRect, samplingMode: .adaptive, edgeMode: .transparent)
                filters.append(crop)
                workingSize = crop.resize(input: workingSize)
            }
        }

        let resolvedProjectiveViewportMode: Transform3DViewportMode = canvasMode == .preserveInput ? .original : projectiveViewportMode

        if let quadTransform {
            let quad = RenderQuadTransform(quad: quadTransform, viewportMode: resolvedProjectiveViewportMode)
            filters.append(quad)
            workingSize = quad.resize(input: workingSize)
        }

        if let projectiveFilter = makeProjectiveFilter(inputSize: workingSize, viewportMode: resolvedProjectiveViewportMode) {
            filters.append(projectiveFilter)
            workingSize = projectiveFilter.resize(input: workingSize)
        }

        let normalizedRotation = rotationDegrees.truncatingRemainder(dividingBy: 360)
        if normalizedRotation != 0 {
            let rotate = C7Rotate(mode: canvasMode == .preserveInput ? .fixed : .fit, angle: normalizedRotation)
            filters.append(rotate)
            workingSize = rotate.resize(input: workingSize)
        }

        if mirrorsHorizontally {
            filters.append(C7Mirror())
        }

        if flipsVertically {
            filters.append(C7Flip(vertical: true))
        }

        if let targetSize, targetSize.width > 0, targetSize.height > 0 {
            let exactTarget = C7Size(
                width: max(Int(targetSize.width.rounded(.toNearestOrAwayFromZero)), 1),
                height: max(Int(targetSize.height.rounded(.toNearestOrAwayFromZero)), 1)
            )
            switch aspectPolicy {
            case .none:
                filters.append(makeResize(width: exactTarget.width, height: exactTarget.height, quality: prefersQualityResize))
            case .fit:
                let fitted = Placement.fit.resize(
                    width: Float(exactTarget.width),
                    height: Float(exactTarget.height),
                    size: workingSize
                )
                filters.append(makeResize(width: fitted.width, height: fitted.height, quality: prefersQualityResize))
            case .fill:
                let scale = max(
                    CGFloat(exactTarget.width) / CGFloat(max(workingSize.width, 1)),
                    CGFloat(exactTarget.height) / CGFloat(max(workingSize.height, 1))
                )
                let filledWidth = max(Int((CGFloat(workingSize.width) * scale).rounded(.up)), exactTarget.width)
                let filledHeight = max(Int((CGFloat(workingSize.height) * scale).rounded(.up)), exactTarget.height)
                filters.append(makeResize(width: filledWidth, height: filledHeight, quality: prefersQualityResize))
                let exactTargetSize = CGSize(width: exactTarget.width, height: exactTarget.height)
                let cropOrigin = cropAnchor.resolvedOffset(
                    fillSize: CGSize(width: filledWidth, height: filledHeight),
                    targetSize: exactTargetSize
                )
                let rect_ = CGRect(origin: cropOrigin, size: exactTargetSize).integral
                filters.append(C7Crop(rect: rect_, samplingMode: .adaptive, edgeMode: .transparent))
            }
        }

        return filters
    }

    private func makeProjectiveFilter(inputSize: C7Size, viewportMode: Transform3DViewportMode) -> C7FilterProtocol? {
        let resolvedSize = CGSize(width: inputSize.width, height: inputSize.height)
        if let guidedUpright {
            return guidedUpright.makeFilter(inputSize: resolvedSize, viewportMode: viewportMode)
        }
        if let perspectiveTransform {
            return perspectiveTransform.makeFilter(viewportMode: viewportMode)
        }
        return nil
    }

    private func makeResize(width: Int, height: Int, quality: Bool) -> C7FilterProtocol {
        if quality {
            return C7LanczosResize(width: Float(width), height: Float(height))
        } else {
            return C7Resize(width: Float(width), height: Float(height))
        }
    }

    fileprivate static func stableFloatDescription(_ value: Float) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    fileprivate static func stableRectDescription(_ rect: CGRect) -> String {
        [
            stableFloatDescription(Float(rect.origin.x)),
            stableFloatDescription(Float(rect.origin.y)),
            stableFloatDescription(Float(rect.width)),
            stableFloatDescription(Float(rect.height))
        ].joined(separator: ",")
    }

    fileprivate static func stableSizeDescription(_ size: CGSize) -> String {
        [
            stableFloatDescription(Float(size.width)),
            stableFloatDescription(Float(size.height))
        ].joined(separator: "x")
    }

    fileprivate static func stableQuadDescription(_ quad: RenderQuadTransform.Quad) -> String {
        [
            stablePointDescription(quad.topLeft),
            stablePointDescription(quad.topRight),
            stablePointDescription(quad.bottomLeft),
            stablePointDescription(quad.bottomRight)
        ].joined(separator: "|")
    }

    fileprivate static func stablePointDescription(_ point: FreePoint2D) -> String {
        [
            stableFloatDescription(point.x),
            stableFloatDescription(point.y)
        ].joined(separator: ",")
    }
}

public extension ImageTransformRecipe {
    static func crop(_ region: ImageCropRegion) -> ImageTransformRecipe {
        ImageTransformRecipe(cropRegion: region)
    }

    static func fit(targetSize: CGSize,
                    canvasMode: ImageCanvasMode = .minimumEnclosing,
                    cropAnchor: ImageCropAnchor = .center) -> ImageTransformRecipe {
        return ImageTransformRecipe(targetSize: targetSize, aspectPolicy: .fit, canvasMode: canvasMode, cropAnchor: cropAnchor)
    }

    static func fill(targetSize: CGSize,
                     canvasMode: ImageCanvasMode = .minimumEnclosing,
                     cropAnchor: ImageCropAnchor = .center) -> ImageTransformRecipe {
        return ImageTransformRecipe(targetSize: targetSize, aspectPolicy: .fill, canvasMode: canvasMode, cropAnchor: cropAnchor)
    }

    static func quad(topLeft: FreePoint2D,
                     topRight: FreePoint2D,
                     bottomLeft: FreePoint2D,
                     bottomRight: FreePoint2D,
                     targetSize: CGSize? = nil,
                     aspectPolicy: AspectPolicy = .none,
                     canvasMode: ImageCanvasMode = .minimumEnclosing,
                     cropAnchor: ImageCropAnchor = .center,
                     projectiveViewportMode: Transform3DViewportMode = .minimumEnclosing) -> ImageTransformRecipe {
        ImageTransformRecipe(
            targetSize: targetSize,
            aspectPolicy: aspectPolicy,
            canvasMode: canvasMode,
            cropAnchor: cropAnchor,
            quadTransform: RenderQuadTransform.Quad(
                topLeft: topLeft,
                topRight: topRight,
                bottomLeft: bottomLeft,
                bottomRight: bottomRight
            ),
            projectiveViewportMode: projectiveViewportMode
        )
    }

    static func perspective(_ transform: PerspectiveTransform,
                            targetSize: CGSize? = nil,
                            aspectPolicy: AspectPolicy = .none,
                            canvasMode: ImageCanvasMode = .minimumEnclosing,
                            cropAnchor: ImageCropAnchor = .center,
                            projectiveViewportMode: Transform3DViewportMode = .minimumEnclosing) -> ImageTransformRecipe {
        ImageTransformRecipe(
            targetSize: targetSize,
            aspectPolicy: aspectPolicy,
            canvasMode: canvasMode,
            cropAnchor: cropAnchor,
            perspectiveTransform: transform,
            projectiveViewportMode: projectiveViewportMode
        )
    }

    static func upright(_ upright: GuidedUpright,
                        targetSize: CGSize? = nil,
                        aspectPolicy: AspectPolicy = .none,
                        canvasMode: ImageCanvasMode = .minimumEnclosing,
                        cropAnchor: ImageCropAnchor = .center,
                        projectiveViewportMode: Transform3DViewportMode = .minimumEnclosing) -> ImageTransformRecipe {
        ImageTransformRecipe(
            targetSize: targetSize,
            aspectPolicy: aspectPolicy,
            canvasMode: canvasMode,
            cropAnchor: cropAnchor,
            guidedUpright: upright,
            projectiveViewportMode: projectiveViewportMode
        )
    }
}
