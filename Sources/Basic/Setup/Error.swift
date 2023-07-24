//
//  Error.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/20.
//

import Foundation

public enum CustomError: Swift.Error {
    case unknown
    case image2Texture
    case readFunction(String)
    case commandBuffer
    case computePipelineState(String)
    case renderPipelineState(String, String)
    case source2Texture
    case texture2Image
    case CVPixelBufferToCMSampleBuffer
}

extension CustomError: CustomStringConvertible {
    
    /// For each error type return the appropriate description.
    public var description: String {
        localizedDescription
    }
    
    /// A textual representation of `self`, suitable for debugging.
    public var localizedDescription: String {
        switch self {
        case .image2Texture:
            return "Input image transform texture failed."
        case .readFunction(let name):
            return "Read MTL Function failed with \(name)."
        case .commandBuffer:
            return "Make command buffer failed."
        case .computePipelineState(let name):
            return "Make compute pipeline state failed with \(name)."
        case .renderPipelineState(let vertex, let fragment):
            return "Make rendering pipeline state failed with \(vertex) and \(fragment)."
        case .source2Texture:
            return "Transform to texture failed."
        case .texture2Image:
            return "MTLTexture transform to image failed."
        case .CVPixelBufferToCMSampleBuffer:
            return "CVPixelBuffer transform to CMSampleBuffer failed."
        default:
            return "Unknown error occurred."
        }
    }
}
