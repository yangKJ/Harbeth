//
//  MaskAdvancedProcessing.swift
//  Harbeth
//
//  Created by Condy on 2026/7/28.
//

import Foundation
import Metal

public struct MaskTopologyComponent: Sendable, Equatable, Hashable {
    public let label: Int
    public let area: Int
    public let bounds: MaskCoverageBounds
    public let centroid: CGPoint
    public let touchesCanvasEdge: Bool
}

public struct MaskTopologyAnalysis: Sendable, Equatable {
    public let components: [MaskTopologyComponent]
    public let holeCount: Int
    public let isolatedPixelCount: Int

    public var componentCount: Int { components.count }
    public var largestComponent: MaskTopologyComponent? { components.max { $0.area < $1.area } }
}

/// 拓扑分析属于按需 inspection；不会进入默认实时渲染路径。
public struct MaskTopologyRecipe {
    public let threshold: Float
    public let connectivity: Int

    public init(threshold: Float = 0.5, connectivity: Int = 8) {
        self.threshold = min(max(threshold.isFinite ? threshold : 0.5, 0), 1)
        self.connectivity = connectivity == 4 ? 4 : 8
    }

    public func analyze(_ mask: MaskDescriptor) throws -> MaskTopologyAnalysis {
        let raster = try rasterize(mask)
        let foreground = Self.label(binary: raster.binary, width: raster.width, height: raster.height, connectivity: connectivity)
        let inverted = raster.binary.map { !$0 }
        let background = Self.label(binary: inverted, width: raster.width, height: raster.height, connectivity: 4)
        let holeCount = background.components.filter { !$0.touchesCanvasEdge }.count
        return MaskTopologyAnalysis(
            components: foreground.components,
            holeCount: holeCount,
            isolatedPixelCount: foreground.components.filter { $0.area == 1 }.count
        )
    }

    public func removingComponents(smallerThan minimumArea: Int, from mask: MaskDescriptor) throws -> MaskPlane {
        let raster = try rasterize(mask)
        let labeled = Self.label(binary: raster.binary, width: raster.width, height: raster.height, connectivity: connectivity)
        let keep = Set(labeled.components.filter { $0.area >= max(minimumArea, 1) }.map(\.label))
        return try makePlane(
            raster: raster,
            coverage: raster.coverage.enumerated().map { keep.contains(labeled.labels[$0.offset]) ? $0.element : 0 },
            basedOn: mask
        )
    }

    public func fillingHoles(in mask: MaskDescriptor) throws -> MaskPlane {
        let raster = try rasterize(mask)
        let background = Self.label(
            binary: raster.binary.map { !$0 },
            width: raster.width,
            height: raster.height,
            connectivity: 4
        )
        let holes = Set(background.components.filter { !$0.touchesCanvasEdge }.map(\.label))
        return try makePlane(
            raster: raster,
            coverage: raster.coverage.enumerated().map { holes.contains(background.labels[$0.offset]) ? 1 : $0.element },
            basedOn: mask
        )
    }
}

public enum MaskAuxiliaryPlaneSemantic: Sendable, Codable, Equatable, Hashable {
    case depth
    case disparity
    case saliency
    case confidence
    case semantic(String)
    case custom(String)
}

public enum MaskAuxiliaryPlaneComponent: Int, Sendable, Codable, Equatable, Hashable {
    case red = 0
    case green = 1
    case blue = 2
    case alpha = 3
}

public struct MaskAuxiliaryPlane: @unchecked Sendable {
    public let texture: MTLTexture
    public let semantic: MaskAuxiliaryPlaneSemantic
    public let component: MaskAuxiliaryPlaneComponent
    public let confidenceTexture: MTLTexture?
    public let coordinateSpace: MaskCoordinateSpace

    public init(texture: MTLTexture,
                semantic: MaskAuxiliaryPlaneSemantic,
                component: MaskAuxiliaryPlaneComponent = .red,
                confidenceTexture: MTLTexture? = nil,
                coordinateSpace: MaskCoordinateSpace = .sourceNormalized) throws {
        guard confidenceTexture.map({ $0.width == texture.width && $0.height == texture.height }) ?? true else {
            throw HarbethError.textureSizeMismatch
        }
        self.texture = texture
        self.semantic = semantic
        self.component = component
        self.confidenceTexture = confidenceTexture
        self.coordinateSpace = coordinateSpace
    }

    public func rangeMask(lowerBound: Float,
                          upperBound: Float,
                          softness: Float = 0.02,
                          invert: Bool = false,
                          storageFormat: MaskStorageFormat = .coverage16Float,
                          profile: RenderProfile = .stablePreview) throws -> MaskPlane {
        let confidence = confidenceTexture ?? texture
        var io = HarbethIO(
            element: texture,
            filter: MaskAuxiliaryRangeFilter(
                confidenceTexture: confidence,
                component: component.rawValue,
                lowerBound: lowerBound,
                upperBound: upperBound,
                softness: softness,
                invert: invert,
                usesConfidence: confidenceTexture != nil
            )
        ).configured(for: profile)
        io.bufferPixelFormat = storageFormat.pixelFormat
        return MaskPlane(
            texture: try io.output(),
            coordinateSpace: coordinateSpace,
            sampling: .softCoverage,
            coverageSemantics: .continuous,
            storageFormat: storageFormat,
            resourceIdentity: MaskResourceIdentity(identifier: "auxiliary:\(semantic):\(ObjectIdentifier(texture as AnyObject))")
        )
    }
}

public enum MaskFlowUnit: String, Sendable, Codable, Equatable, Hashable {
    case pixels
    case normalized
}

/// 只执行单帧 displacement；光流生成、跨帧调度和媒体生命周期不属于 Harbeth。
public struct MaskWarpRecipe: @unchecked Sendable {
    public let flowTexture: MTLTexture
    public let confidenceTexture: MTLTexture?
    public let scale: Float
    public let unit: MaskFlowUnit
    public let edgeMode: MaskSamplingEdgeMode
    public let profile: RenderProfile

    public init(flowTexture: MTLTexture,
                confidenceTexture: MTLTexture? = nil,
                scale: Float = 1,
                unit: MaskFlowUnit = .pixels,
                edgeMode: MaskSamplingEdgeMode = .zero,
                profile: RenderProfile = .stablePreview) {
        self.flowTexture = flowTexture
        self.confidenceTexture = confidenceTexture
        self.scale = scale.isFinite ? scale : 1
        self.unit = unit
        self.edgeMode = edgeMode
        self.profile = profile
    }

    public func makePlane(from mask: MaskDescriptor, storageFormat: MaskStorageFormat = .coverage16Float) throws -> MaskPlane {
        let coverage = try MaskProcessingRecipe(mask: mask).makeCoverageTexture()
        guard flowTexture.width == coverage.width,
              flowTexture.height == coverage.height,
              confidenceTexture.map({ $0.width == coverage.width && $0.height == coverage.height }) ?? true else {
            throw HarbethError.textureSizeMismatch
        }
        let confidence = confidenceTexture ?? flowTexture
        var io = HarbethIO(
            element: coverage,
            filter: MaskFlowWarp(
                flowTexture: flowTexture,
                confidenceTexture: confidence,
                scale: scale,
                flowIsNormalized: unit == .normalized,
                usesConfidence: confidenceTexture != nil,
                edgeMode: edgeMode
            )
        ).configured(for: profile)
        io.bufferPixelFormat = storageFormat.pixelFormat
        return MaskPlane(
            texture: try io.output(),
            coordinateSpace: mask.plane.descriptor.coordinateSpace,
            sourceToMaskTransform: mask.plane.descriptor.sourceToMaskTransform,
            sampling: .softCoverage,
            coverageSemantics: .continuous,
            storageFormat: storageFormat,
            resourceIdentity: mask.plane.descriptor.resourceIdentity.advanced(),
            lastModifiedBounds: mask.plane.descriptor.lastModifiedBounds
        )
    }
}

private extension MaskTopologyRecipe {
    struct Raster {
        let width: Int
        let height: Int
        let coverage: [Float]
        let binary: [Bool]
    }

    struct LabelResult {
        let labels: [Int]
        let components: [MaskTopologyComponent]
    }

    func rasterize(_ mask: MaskDescriptor) throws -> Raster {
        var io = HarbethIO(element: mask.texture, filter: MaskCoverageExtract(mask: mask))
            .configured(for: .readbackQuality)
        io.bufferPixelFormat = .rgba8Unorm
        let texture = try io.output()
        guard let data = texture.c7.bytes() else { throw HarbethError.texture2Image }
        let bytes = [UInt8](data)
        let coverage = stride(from: 0, to: bytes.count, by: 4).map { Float(bytes[$0]) / 255 }
        return Raster(
            width: texture.width,
            height: texture.height,
            coverage: coverage,
            binary: coverage.map { $0 >= threshold }
        )
    }

    static func label(binary: [Bool], width: Int, height: Int, connectivity: Int) -> LabelResult {
        var labels = [Int](repeating: 0, count: binary.count)
        var components: [MaskTopologyComponent] = []
        var nextLabel = 1
        let offsets = connectivity == 4
            ? [(-1, 0), (1, 0), (0, -1), (0, 1)]
            : [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]

        for index in binary.indices where binary[index] && labels[index] == 0 {
            var queue = [index]
            labels[index] = nextLabel
            var cursor = 0
            var area = 0
            var minX = width
            var minY = height
            var maxX = 0
            var maxY = 0
            var sumX = 0
            var sumY = 0
            var touchesEdge = false
            while cursor < queue.count {
                let current = queue[cursor]
                cursor += 1
                let x = current % width
                let y = current / width
                area += 1
                minX = min(minX, x); minY = min(minY, y)
                maxX = max(maxX, x); maxY = max(maxY, y)
                sumX += x; sumY += y
                touchesEdge = touchesEdge || x == 0 || y == 0 || x == width - 1 || y == height - 1
                for offset in offsets {
                    let nx = x + offset.0
                    let ny = y + offset.1
                    guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                    let neighbor = ny * width + nx
                    guard binary[neighbor], labels[neighbor] == 0 else { continue }
                    labels[neighbor] = nextLabel
                    queue.append(neighbor)
                }
            }
            components.append(MaskTopologyComponent(
                label: nextLabel,
                area: area,
                bounds: MaskCoverageBounds(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1),
                centroid: CGPoint(x: CGFloat(sumX) / CGFloat(area), y: CGFloat(sumY) / CGFloat(area)),
                touchesCanvasEdge: touchesEdge
            ))
            nextLabel += 1
        }
        return LabelResult(labels: labels, components: components)
    }

    func makePlane(raster: Raster, coverage: [Float], basedOn mask: MaskDescriptor) throws -> MaskPlane {
        let texture = try TextureLoader.makeTexture(
            width: raster.width,
            height: raster.height,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "MaskTopologyRecipe"
        )
        let bytes = coverage.reduce(into: [UInt8]()) { result, value in
            let byte = UInt8((min(max(value, 0), 1) * 255).rounded())
            result.append(contentsOf: [byte, byte, byte, 255])
        }
        TextureLoader.replaceTexture(
            texture,
            region: MTLRegionMake2D(0, 0, raster.width, raster.height),
            bytes: bytes,
            packedBytesPerRow: raster.width * 4
        )
        return MaskPlane(
            texture: texture,
            coordinateSpace: mask.plane.descriptor.coordinateSpace,
            sourceToMaskTransform: mask.plane.descriptor.sourceToMaskTransform,
            sampling: mask.plane.descriptor.sampling,
            coverageSemantics: .continuous,
            resourceIdentity: mask.plane.descriptor.resourceIdentity.advanced(),
            lastModifiedBounds: MaskCoverageBounds(x: 0, y: 0, width: raster.width, height: raster.height)
        )
    }
}
