//
//  Error.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/20.
//

import Foundation

public enum C7CustomError: Swift.Error {
    case unknown
    case image2Texture
    case readFunction(String)
    case commandBuffer
    case computePipelineState(String)
    case renderPipelineState(String, String)
    case source2Texture
    case texture2Image
}

extension C7CustomError {
    /// A textual representation of `self`, suitable for debugging.
    public var localizedDescription: String {
        switch self {
        case .image2Texture:
            return "Input image transform texture failed."
        case .readFunction(let name):
            return "Read MTL Function failed with \(name)"
        case .commandBuffer:
            return "Make Command buffer failed."
        case .computePipelineState(let name):
            return "Make Compute Pipeline State failed with \(name)"
        case .renderPipelineState(let vertex, let fragment):
            return "Make Rendering Pipeline State failed with \(vertex) and \(fragment)"
        case .source2Texture:
            return "Transform to texture failed."
        case .texture2Image:
            return "MTLTexture transform to image failed."
        default:
            return "Unknown error occurred."
        }
    }
}

internal func C7FailedErrorInDebug(_ message: @autoclosure () -> String,
                                   file: StaticString = #file,
                                   line: UInt = #line) {
    #if DEBUG
    fatalError(message(), file: file, line: line)
    #else
    print("\(file):\(line): \(message())")
    #endif
}
