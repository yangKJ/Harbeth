//
//  FilterMetadata.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation

public enum FilterParameterValueType: String, Sendable, Codable {
    case scalar
    case integer
    case boolean
    case color
    case point
    case size
    case lookupResource
    case cubeResource
    case custom
}

public struct FilterParameterDescriptor: Sendable, Hashable, Codable {
    public let name: String
    public let valueType: FilterParameterValueType
    public let defaultValueDescription: String?
    public let rangeDescription: String?

    public init(name: String, valueType: FilterParameterValueType, defaultValueDescription: String? = nil, rangeDescription: String? = nil) {
        self.name = name
        self.valueType = valueType
        self.defaultValueDescription = defaultValueDescription
        self.rangeDescription = rangeDescription
    }
}

public struct FilterIntensityHint: Sendable, Hashable, Codable {
    public let parameterName: String
    public let uiRange: ClosedRange<Float>
    public let semanticRange: ClosedRange<Float>?

    public init(parameterName: String = "intensity", uiRange: ClosedRange<Float> = 0...1, semanticRange: ClosedRange<Float>? = nil) {
        self.parameterName = parameterName
        self.uiRange = uiRange
        self.semanticRange = semanticRange
    }
}

public protocol FilterMetadataProviding {
    var stableTypeID: String { get }
    var parameterDescriptors: [FilterParameterDescriptor] { get }
    var intensityHint: FilterIntensityHint? { get }
}

extension C7FilterProtocol where Self: FilterMetadataProviding {
    public var stableTypeID: String {
        String(describing: Self.self)
    }

    public var parameterDescriptors: [FilterParameterDescriptor] {
        []
    }

    public var intensityHint: FilterIntensityHint? {
        nil
    }
}

extension C7FilterProtocol {
    public var stableTypeID: String {
        String(describing: type(of: self))
    }

    public var parameterDescriptors: [FilterParameterDescriptor] {
        []
    }

    public var intensityHint: FilterIntensityHint? {
        nil
    }
}
