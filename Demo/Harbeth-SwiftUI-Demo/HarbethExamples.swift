//
//  HarbethExamples.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/3/21.
//

import SwiftUI

@main
struct HarbethExamples: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(width: 888, height: 600)
                #endif
        }
    }
}

@_exported import Harbeth

extension Matrix4x4.Color {
    // 灰度图转换矩阵（加权平均法，符合人眼感知）
    public static let luminance = Matrix4x4(values: [
        0.2126, 0.7152, 0.0722, 0.0,  // R通道权重（人眼最敏感）
        0.2126, 0.7152, 0.0722, 0.0,  // G通道权重
        0.2126, 0.7152, 0.0722, 0.0,  // B通道权重
        0.0000, 0.0000, 0.0000, 1.0   // Alpha通道（保持不变）
    ])
}

extension HarbethIO {
    
    public func transmitOutput() async throws -> Dest {
        return try await withCheckedThrowingContinuation { continuation in
            self.transmitOutput(complete: { result in
                switch result {
                case .success(let output):
                    continuation.resume(returning: output)
                case .failure(let underlyingError):
                    let harbethError = HarbethError.toHarbethError(underlyingError)
                    continuation.resume(throwing: harbethError)
                }
            })
        }
    }
}

extension HarbethWrapper where Base: C7Image {
    
    public func resized(to size: CGSize) -> C7Image? {
        if size == base.size {
            return base
        }
        return base.preparingThumbnail(of: size)
    }
    
    public func resized(maxWidth: CGFloat) -> C7Image? {
        guard base.size.width > maxWidth else {
            return base
        }
        let ratio = maxWidth / base.size.width
        return resized(to: CGSize(width: maxWidth, height: base.size.height * ratio))
    }
}
