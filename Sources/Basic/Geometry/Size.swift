//
//  Size.swift
//  Harbeth
//
//  Created by Condy on 2022/10/12.
//

import Foundation
import CoreGraphics
import CoreMedia
import CoreVideo
import MetalKit

public struct C7Size: Codable, Sendable {

    public static let zero = C7Size(width: 0, height: 0)

    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public init(size: CGSize) {
        self.init(width: Int(size.width), height: Int(size.height))
    }

    public init(cgSize: CGSize) {
        self.init(size: cgSize)
    }

    public init(texture: MTLTexture) {
        self.init(width: texture.width, height: texture.height)
    }

    public init(pixelBuffer: CVPixelBuffer) {
        self.init(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
    }

    public init(cgImage: CGImage) {
        self.init(width: cgImage.width, height: cgImage.height)
    }

    public init?(sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        self.init(pixelBuffer: imageBuffer)
    }

    private enum CodingKeys: String, CodingKey {
        case width
        case height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.width = try container.decode(Int.self, forKey: .width)
        self.height = try container.decode(Int.self, forKey: .height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}

extension C7Size {
    public func toFloatArray() -> [Float] {
        [Float(width), Float(height)]
    }
}

extension C7Size: Equatable {

    public static func == (lhs: C7Size, rhs: C7Size) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height
    }
}

extension C7Size: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}
