//
//  ImagePrintResolution.swift
//  Harbeth
//
//  Created by Condy on 2026/11/1.
//

import Foundation

public struct ImagePrintResolution: Codable, Hashable, Sendable {
    public let horizontalDPI: Double
    public let verticalDPI: Double

    public init?(horizontalDPI: Double, verticalDPI: Double) {
        guard horizontalDPI.isFinite, verticalDPI.isFinite,
              horizontalDPI > 0, verticalDPI > 0 else { return nil }
        self.horizontalDPI = horizontalDPI
        self.verticalDPI = verticalDPI
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let horizontalDPI = try? container.decode(Double.self, forKey: .horizontalDPI),
              let verticalDPI = try? container.decode(Double.self, forKey: .verticalDPI),
              let value = Self(horizontalDPI: horizontalDPI, verticalDPI: verticalDPI) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "打印分辨率必须是有限正数"))
        }
        self = value
    }

    private enum CodingKeys: String, CodingKey {
        case horizontalDPI
        case verticalDPI
    }
}
