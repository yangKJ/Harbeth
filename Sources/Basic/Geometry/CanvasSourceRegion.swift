//
//  CanvasSourceRegion.swift
//  Harbeth
//
//  Created by Condy on 2026/10/27.
//

import CoreGraphics
import Foundation

/// Shared rounding rules for normalized source requests and their pixel coverage.
public enum CanvasSourceRegion {
    public static func pixelBounds(for normalizedRect: CGRect, sourceSize: CGSize) -> CGRect? {
        guard !normalizedRect.isInfinite, !normalizedRect.isNull,
              [sourceSize.width, sourceSize.height].allSatisfy({
            $0.isFinite && $0 >= 1 && $0 <= CGFloat(Int32.max) && $0.rounded() == $0
        }), [normalizedRect.origin.x, normalizedRect.origin.y, normalizedRect.width, normalizedRect.height,
             normalizedRect.minX, normalizedRect.minY, normalizedRect.maxX, normalizedRect.maxY].allSatisfy(\.isFinite) else {
            return nil
        }
        let region = normalizedRect.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !region.isNull, !region.isEmpty else { return nil }

        // Normalized round-trips may turn 15 into 14.999999999999998; snap only a few ULPs.
        let left = min(max(snapped(region.minX * sourceSize.width).rounded(.down), 0), sourceSize.width - 1)
        let top = min(max(snapped(region.minY * sourceSize.height).rounded(.down), 0), sourceSize.height - 1)
        let right = min(max(snapped(region.maxX * sourceSize.width).rounded(.up), left + 1), sourceSize.width)
        let bottom = min(max(snapped(region.maxY * sourceSize.height).rounded(.up), top + 1), sourceSize.height)

        // Cover both endpoints: ceil(width) is not equivalent to ceil(maxX) - floor(minX).
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    private static func snapped(_ value: CGFloat) -> CGFloat {
        let integer = value.rounded()
        let tolerance = max(1, abs(value)) * CGFloat.ulpOfOne * 8
        return abs(value - integer) <= tolerance ? integer : value
    }
}
