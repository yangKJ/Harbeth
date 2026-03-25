//
//  Size.swift
//  Harbeth
//
//  Created by Condy on 2022/10/12.
//

import Foundation

public struct C7Size: Codable {
    
    public static let zero = C7Size(width: 0, height: 0)
    
    public var width: Int
    public var height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    
    public init(cgSize: CGSize) {
        self.init(width: Int(cgSize.width), height: Int(cgSize.height))
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
