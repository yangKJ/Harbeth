//
//  Error.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/20.
//

import Foundation

public enum HarbethError: Swift.Error {
    case unknown
    case error(Error)
    case image2Texture
    case image2CGImage
    case readFunction(String)
    case commandBuffer
    case computePipelineState(String)
    case renderPipelineState(String, String)
    case source2Texture
    case texture2Image
    case texture2CGImage
    case texture2CIImage
    case CVPixelBufferToCMSampleBuffer
    case CMSampleBufferToCVPixelBuffer
    case outputCIImage(String)
    case cubeResource
    case createCIFilter(String)
    case makeComputeCommandEncoder
    case makeTexture
    case textureLoader
    case bitmapDataNotFound
}

extension HarbethError: CustomStringConvertible, LocalizedError {
    
    /// For each error type return the appropriate description.
    public var description: String {
        localizedDescription
    }
    
    public var errorDescription: String? {
        localizedDescription
    }
    
    /// A textual representation of `self`, suitable for debugging.
    public var localizedDescription: String {
        switch self {
        case .error(let error):
            return error.localizedDescription
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
        case .texture2CGImage:
            return "MTLTexture transform to CGImage failed."
        case .texture2CIImage:
            return "MTLTexture transform to CIImage failed."
        case .CVPixelBufferToCMSampleBuffer:
            return "CVPixelBuffer transform to CMSampleBuffer failed."
        case .CMSampleBufferToCVPixelBuffer:
            return "CMSampleBuffer transform to CVPixelBuffer failed."
        case .outputCIImage(let name):
            return "CoreImage \(name) filter bring into being output image failed."
        case .cubeResource:
            return "Read the contents of the cube file failed."
        case .createCIFilter(let name):
            return "Create the filter \(name) is failed."
        case .makeComputeCommandEncoder:
            return "Create a compute command encoder to encode into this command buffer failed."
        case .makeTexture:
            return "Create a new metal texture is failed."
        case .textureLoader:
            return "Using metal texture loader is nil."
        case .bitmapDataNotFound:
            return "Bitmap Data Not Found."
        case .image2CGImage:
            return "Input image transform CGImage failed."
        default:
            return "Unknown error occurred."
        }
    }
    
    /// Depending on error type, returns an underlying `Error`.
    internal var underlyingError: Swift.Error? {
        switch self {
        case .unknown:
            return nil
        case .error(let error):
            return error
        case .image2Texture:
            return nil
        case .readFunction:
            return nil
        case .commandBuffer:
            return nil
        case .computePipelineState:
            return nil
        case .renderPipelineState:
            return nil
        case .source2Texture:
            return nil
        case .texture2Image:
            return nil
        case .texture2CGImage:
            return nil
        case .texture2CIImage:
            return nil
        case .CVPixelBufferToCMSampleBuffer:
            return nil
        case .CMSampleBufferToCVPixelBuffer:
            return nil
        case .outputCIImage:
            return nil
        case .cubeResource:
            return nil
        case .createCIFilter:
            return nil
        case .makeComputeCommandEncoder:
            return nil
        case .makeTexture:
            return nil
        case .textureLoader:
            return nil
        case .bitmapDataNotFound:
            return nil
        case .image2CGImage:
            return nil
        }
    }
}

extension HarbethError: CustomNSError {
    public var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [:]
        userInfo[NSLocalizedDescriptionKey] = errorDescription
        userInfo[NSUnderlyingErrorKey] = underlyingError
        return userInfo
    }
}

extension HarbethError {
    public static func toHarbethError(_ error: Error) -> HarbethError {
        if let error = error.asHarbethError {
            return error
        } else {
            return .error(error)
        }
    }
}

extension Error {
    /// Returns the instance cast as an `HarbethError`.
    public var asHarbethError: HarbethError? {
        self as? HarbethError
    }
}
