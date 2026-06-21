//
//  GuidedUpright.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//

import Foundation
import CoreGraphics

/// Guide-driven perspective correction foundation inspired by Lightroom's
/// Guided Upright workflow.
///
/// The first phase focuses on:
/// - validating official guide combinations,
/// - producing a usable rectification quad when enough line constraints exist,
/// - falling back to a deterministic straighten transform for 1H + 1V.
public struct GuidedUpright {

    public enum Axis: String, Codable {
        case horizontal
        case vertical
    }

    public struct Guide: Codable, Equatable {
        public var start: FreePoint2D
        public var end: FreePoint2D
        public var axis: Axis

        public init(start: FreePoint2D, end: FreePoint2D, axis: Axis) {
            self.start = start
            self.end = end
            self.axis = axis
        }
    }

    public enum Recommendation {
        case quadRectify(RenderQuadRectifyTransform)
        case perspective(PerspectiveTransform)
    }

    public var guides: [Guide]

    public init(guides: [Guide]) {
        self.guides = guides
    }

    public var isSupportedCombination: Bool {
        let verticalCount = guides.filter { $0.axis == .vertical }.count
        let horizontalCount = guides.filter { $0.axis == .horizontal }.count

        switch (verticalCount, horizontalCount) {
        case (2, 0), (0, 2), (2, 2), (2, 1), (1, 2), (1, 1):
            return guides.count == verticalCount + horizontalCount
        default:
            return false
        }
    }

    public func recommendTransform(inputSize: CGSize) -> Recommendation? {
        guard isSupportedCombination else { return nil }

        let verticalGuides = guides.filter { $0.axis == .vertical }
        let horizontalGuides = guides.filter { $0.axis == .horizontal }

        if verticalGuides.count == 1 && horizontalGuides.count == 1 {
            return .perspective(makeStraightenPerspective(vertical: verticalGuides[0], horizontal: horizontalGuides[0], inputSize: inputSize))
        }

        guard let quad = sourceQuad(inputSize: inputSize, verticalGuides: verticalGuides, horizontalGuides: horizontalGuides) else {
            return nil
        }

        return .quadRectify(RenderQuadRectifyTransform(sourceQuad: quad))
    }

    private func sourceQuad(inputSize: CGSize, verticalGuides: [Guide], horizontalGuides: [Guide]) -> RenderQuadTransform.Quad? {
        let imageRect = CGRect(x: 0, y: 0, width: inputSize.width, height: inputSize.height)
        let leftX = imageRect.minX
        let rightX = imageRect.maxX
        let topY = imageRect.minY
        let bottomY = imageRect.maxY

        let sortedVertical = verticalGuides.sorted { midpointX(of: $0, size: inputSize) < midpointX(of: $1, size: inputSize) }
        let sortedHorizontal = horizontalGuides.sorted { midpointY(of: $0, size: inputSize) < midpointY(of: $1, size: inputSize) }

        let topLine: C7Line2D?
        let bottomLine: C7Line2D?
        let leftLine: C7Line2D?
        let rightLine: C7Line2D?

        switch sortedHorizontal.count {
        case 2:
            topLine = line(for: sortedHorizontal[0], size: inputSize)
            bottomLine = line(for: sortedHorizontal[1], size: inputSize)
        case 1:
            let candidate = sortedHorizontal[0]
            if midpointY(of: candidate, size: inputSize) <= inputSize.height * 0.5 {
                topLine = line(for: candidate, size: inputSize)
                bottomLine = C7Line2D(yConstant: bottomY)
            } else {
                topLine = C7Line2D(yConstant: topY)
                bottomLine = line(for: candidate, size: inputSize)
            }
        default:
            topLine = C7Line2D(yConstant: topY)
            bottomLine = C7Line2D(yConstant: bottomY)
        }

        switch sortedVertical.count {
        case 2:
            leftLine = line(for: sortedVertical[0], size: inputSize)
            rightLine = line(for: sortedVertical[1], size: inputSize)
        case 1:
            let candidate = sortedVertical[0]
            if midpointX(of: candidate, size: inputSize) <= inputSize.width * 0.5 {
                leftLine = line(for: candidate, size: inputSize)
                rightLine = C7Line2D(xConstant: rightX)
            } else {
                leftLine = C7Line2D(xConstant: leftX)
                rightLine = line(for: candidate, size: inputSize)
            }
        default:
            leftLine = C7Line2D(xConstant: leftX)
            rightLine = C7Line2D(xConstant: rightX)
        }

        guard let leftLine, let rightLine, let topLine, let bottomLine,
              let topLeft = leftLine.intersection(with: topLine),
              let topRight = rightLine.intersection(with: topLine),
              let bottomLeft = leftLine.intersection(with: bottomLine),
              let bottomRight = rightLine.intersection(with: bottomLine) else {
            return nil
        }

        return RenderQuadTransform.Quad(
            topLeft: FreePoint2D(point: topLeft, size: inputSize),
            topRight: FreePoint2D(point: topRight, size: inputSize),
            bottomLeft: FreePoint2D(point: bottomLeft, size: inputSize),
            bottomRight: FreePoint2D(point: bottomRight, size: inputSize)
        )
    }

    private func makeStraightenPerspective(vertical: Guide, horizontal: Guide, inputSize: CGSize) -> PerspectiveTransform {
        let verticalAngle = lineAngleToVertical(vertical, size: inputSize)
        let horizontalAngle = lineAngleToHorizontal(horizontal, size: inputSize)
        let rotate = Float((verticalAngle + horizontalAngle) * 0.5)
        return PerspectiveTransform(rotate: rotate)
    }

    private func lineAngleToVertical(_ guide: Guide, size: CGSize) -> CGFloat {
        let start = point(for: guide.start, size: size)
        let end = point(for: guide.end, size: size)
        let dx = end.x - start.x
        let dy = end.y - start.y
        return atan2(dx, dy)
    }

    private func lineAngleToHorizontal(_ guide: Guide, size: CGSize) -> CGFloat {
        let start = point(for: guide.start, size: size)
        let end = point(for: guide.end, size: size)
        let dx = end.x - start.x
        let dy = end.y - start.y
        return atan2(dy, dx)
    }

    private func midpointX(of guide: Guide, size: CGSize) -> CGFloat {
        let start = point(for: guide.start, size: size)
        let end = point(for: guide.end, size: size)
        return (start.x + end.x) * 0.5
    }

    private func midpointY(of guide: Guide, size: CGSize) -> CGFloat {
        let start = point(for: guide.start, size: size)
        let end = point(for: guide.end, size: size)
        return (start.y + end.y) * 0.5
    }

    private func line(for guide: Guide, size: CGSize) -> C7Line2D? {
        C7Line2D(
            start: point(for: guide.start, size: size),
            end: point(for: guide.end, size: size)
        )
    }

    private func point(for normalizedPoint: FreePoint2D, size: CGSize) -> CGPoint {
        CGPoint(
            x: CGFloat(normalizedPoint.x) * size.width,
            y: CGFloat(normalizedPoint.y) * size.height
        )
    }
}

private struct C7Line2D {
    private let a: CGFloat
    private let b: CGFloat
    private let c: CGFloat

    init?(start: CGPoint, end: CGPoint) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        guard abs(dx) > 0.0001 || abs(dy) > 0.0001 else { return nil }
        self.a = start.y - end.y
        self.b = end.x - start.x
        self.c = start.x * end.y - end.x * start.y
    }

    init(xConstant: CGFloat) {
        self.a = 1
        self.b = 0
        self.c = -xConstant
    }

    init(yConstant: CGFloat) {
        self.a = 0
        self.b = 1
        self.c = -yConstant
    }

    func intersection(with other: C7Line2D) -> CGPoint? {
        let determinant = a * other.b - other.a * b
        guard abs(determinant) > 0.0001 else { return nil }
        let x = (b * other.c - other.b * c) / determinant
        let y = (c * other.a - other.c * a) / determinant
        return CGPoint(x: x, y: y)
    }
}
