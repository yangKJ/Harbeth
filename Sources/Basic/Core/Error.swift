//
//  Error.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/20.
//

import Foundation

public enum C7CustomError: Swift.Error, CustomDebugStringConvertible {
    case unknown
    case image2Texture
    case readFunction(String)
}

extension C7CustomError {
    /// A textual representation of `self`, suitable for debugging.
    public var debugDescription: String {
        switch self {
        case .image2Texture:
            return "Input image transform texture failed."
        case .readFunction(let name):
            return "Read MTL Function failed with \(name)"
        default:
            return "Unknown error occurred."
        }
    }
}

internal func C7FailedErrorInDebug(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
    #if DEBUG
    fatalError(message(), file: file, line: line)
    #else
    print("\(file):\(line): \(message())")
    #endif
}
