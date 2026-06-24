//
//  SampleBufferPreviewHost.swift
//  Harbeth
//
//  Created by Condy on 2026/6/24.
//

import Foundation

#if canImport(AVFoundation) && !os(watchOS)
import AVFoundation
import QuartzCore
import CoreGraphics

private final class SampleBufferPreviewLayerNullAction: NSObject, CAAction {
    @objc func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

private final class SampleBufferPreviewLayerImpl: AVSampleBufferDisplayLayer {
    override func action(forKey event: String) -> CAAction? {
        SampleBufferPreviewLayerNullAction()
    }
}

final class SampleBufferPreviewLayerLease {
    let layer: AVSampleBufferDisplayLayer

    init(layer: AVSampleBufferDisplayLayer) {
        self.layer = layer
    }

    func prepare(frame: CGRect, contentsScale: CGFloat) {
        layer.frame = frame
        layer.contentsScale = max(contentsScale, 1)
        layer.videoGravity = .resizeAspect
        layer.isHidden = false
    }

    func resetForReuse() {
        layer.flushAndRemoveImage()
        layer.removeAllAnimations()
        layer.setAffineTransform(.identity)
        layer.videoGravity = .resizeAspect
        layer.isHidden = true
        layer.removeFromSuperlayer()
    }
}

enum SampleBufferPreviewLayerPool {
    private static let lock = NSLock()
    private static var layers: [AVSampleBufferDisplayLayer] = []

    static func take() -> SampleBufferPreviewLayerLease {
        lock.lock()
        let layer = layers.popLast() ?? SampleBufferPreviewLayerImpl()
        lock.unlock()
        return SampleBufferPreviewLayerLease(layer: layer)
    }

    static func `return`(_ lease: SampleBufferPreviewLayerLease?) {
        guard let lease else { return }
        lease.resetForReuse()
        lock.lock()
        layers.append(lease.layer)
        lock.unlock()
    }
}
#endif
