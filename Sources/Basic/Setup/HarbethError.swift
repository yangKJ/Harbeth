//
//  HarbethError.swift
//  Harbeth
//
//  Created by Condy on 2022/2/20.
//

import Foundation
import Metal
import MetalKit
import CoreVideo
import CoreMedia

public enum HarbethError: Swift.Error {
    case unknown
    case error(Swift.Error)
    case commandBuffer
    case makeBlitCommandEncoder
    case makeComputeCommandEncoder
    case makeTexture
    case textureLoader
    case bitmapDataNotFound
    
    case image2Texture
    case image2CGImage
    case imageCropFailed
    case imageRotationFailed
    case imageFlipFailed
    case imageResizeFailed
    case imageOrientationFailed
    
    case source2Texture
    case texture2Image
    case texture2CGImage
    case texture2CIImage
    case textureCropFailed
    case textureCreateFailed
    case textureCopyPixelBufferFailed
    case textureFormatNotSupported
    case textureSizeMismatch
    
    case readFunction(String)
    case computePipelineState(String)
    case renderPipelineState(String, String)
    case pipelineStateCreationFailed(String)
    
    case cubeResource
    case createCIFilter(String)
    case outputCIImage(String)
    case ciContextCreationFailed
    case ciImageCreationFailed
    
    case CVPixelBufferToCMSampleBuffer
    case CMSampleBufferToCVPixelBuffer
    case pixelBufferLockFailed
    case pixelBufferUnlockFailed
    case pixelBufferCreationFailed
    case pixelBufferCopyFailed
    case sampleBufferCreationFailed
    
    case renderableNoInputSource
    case renderableUnsupportedInputType
    case renderableInvalidOutputType
    case renderableAlreadyProcessing
    case renderableTaskCancelled
    case renderableTextureLocked
    case renderableViewSetupFailed
    case renderableDelegateNotSet
    
    case filterInitializationFailed(String)
    case filterParameterInvalid(String)
    case filterChainEmpty
    case filterProcessingFailed(String)
    
    case memoryAllocationFailed
    case deviceNotAvailable
    case commandQueueCreationFailed
    case textureCacheCreationFailed
    case libraryCreationFailed
    case bufferCreationFailed
    
    case fileNotFound(String)
    case fileReadFailed(String)
    case fileWriteFailed(String)
    case resourceNotFound(String)
    
    case configurationInvalid(String)
    case parameterMissing(String)
    case parameterOutOfRange(String, ClosedRange<Double>)
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
        case .unknown: return "Unknown error occurred."
        case .error(let error): return error.localizedDescription
        case .commandBuffer: return "Make command buffer failed."
        case .makeBlitCommandEncoder:  return "Create a blit command encoder to encode into this command buffer failed."
        case .makeComputeCommandEncoder: return "Create a compute command encoder to encode into this command buffer failed."
        case .makeTexture: return "Create a new metal texture is failed."
        case .textureLoader: return "Using metal texture loader is nil."
        case .bitmapDataNotFound: return "Bitmap Data Not Found."
        case .image2Texture: return "Input image transform texture failed."
        case .image2CGImage: return "Input image transform CGImage failed."
        case .imageCropFailed: return "Image crop failed."
        case .imageRotationFailed: return "Image rotation failed."
        case .imageFlipFailed: return "Image flip failed."
        case .imageResizeFailed: return "Image resize failed."
        case .imageOrientationFailed: return "Image orientation correction failed."
        case .source2Texture: return "Transform to texture failed."
        case .texture2Image: return "MTLTexture transform to image failed."
        case .texture2CGImage: return "MTLTexture transform to CGImage failed."
        case .texture2CIImage: return "MTLTexture transform to CIImage failed."
        case .textureCropFailed: return "Texture crop failed."
        case .textureCreateFailed: return "Texture create failed."
        case .textureCopyPixelBufferFailed: return "Failed to copy pixel buffer."
        case .textureFormatNotSupported: return "Texture format not supported."
        case .textureSizeMismatch: return "Texture size mismatch."
        case .readFunction(let name): return "Read MTL Function failed with \(name)."
        case .computePipelineState(let name): return "Make compute pipeline state failed with \(name)."
        case .renderPipelineState(let vertex, let fragment): return "Make rendering pipeline state failed with \(vertex) and \(fragment)."
        case .pipelineStateCreationFailed(let description): return "Pipeline state creation failed: \(description)"
        case .cubeResource: return "Read the contents of the cube file failed."
        case .createCIFilter(let name): return "Create the filter \(name) is failed."
        case .outputCIImage(let name): return "CoreImage \(name) filter bring into being output image failed."
        case .ciContextCreationFailed: return "Core Image context creation failed."
        case .ciImageCreationFailed: return "Core Image creation failed."
        case .CVPixelBufferToCMSampleBuffer: return "CVPixelBuffer transform to CMSampleBuffer failed."
        case .CMSampleBufferToCVPixelBuffer: return "CMSampleBuffer transform to CVPixelBuffer failed."
        case .pixelBufferLockFailed: return "Failed to lock pixel buffer."
        case .pixelBufferUnlockFailed: return "Failed to unlock pixel buffer."
        case .pixelBufferCreationFailed: return "Failed to create pixel buffer."
        case .pixelBufferCopyFailed: return "Failed to copy pixel buffer data."
        case .sampleBufferCreationFailed: return "Failed to create sample buffer."
        case .renderableNoInputSource: return "No input source available for rendering."
        case .renderableUnsupportedInputType: return "Unsupported input type for rendering."
        case .renderableInvalidOutputType: return "Invalid output type from rendering."
        case .renderableAlreadyProcessing: return "Already processing, please wait for completion."
        case .renderableTaskCancelled: return "Rendering task was cancelled."
        case .renderableTextureLocked: return "Texture is currently locked for processing."
        case .renderableViewSetupFailed: return "Failed to setup render view."
        case .renderableDelegateNotSet: return "Renderable delegate is not set."
        case .filterInitializationFailed(let name): return "Failed to initialize filter: \(name)."
        case .filterParameterInvalid(let parameter): return "Invalid filter parameter: \(parameter)."
        case .filterChainEmpty: return "Filter chain is empty."
        case .filterProcessingFailed(let description): return "Filter processing failed: \(description)."
        case .memoryAllocationFailed: return "Memory allocation failed."
        case .deviceNotAvailable: return "Metal device is not available."
        case .commandQueueCreationFailed: return "Failed to create command queue."
        case .textureCacheCreationFailed: return "Failed to create texture cache."
        case .libraryCreationFailed: return "Failed to create Metal library."
        case .bufferCreationFailed: return "Failed to create Metal buffer."
        case .fileNotFound(let path): return "File not found at path: \(path)."
        case .fileReadFailed(let path): return "Failed to read file at path: \(path)."
        case .fileWriteFailed(let path): return "Failed to write file at path: \(path)."
        case .resourceNotFound(let name): return "Resource not found: \(name)."
        case .configurationInvalid(let description): return "Invalid configuration: \(description)."
        case .parameterMissing(let parameter): return "Required parameter missing: \(parameter)."
        case .parameterOutOfRange(let parameter, let range): return "Parameter \(parameter) out of range. Valid range is \(range.lowerBound) to \(range.upperBound)."
        }
    }
    
    internal var underlyingError: Swift.Error? {
        switch self {
        case .error(let error):
            return error
        default:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .deviceNotAvailable:
            return "Check if Metal is supported on this device."
        case .memoryAllocationFailed:
            return "Try reducing image size or closing other applications."
        case .filterChainEmpty:
            return "Add at least one filter to the filter chain."
        case .renderableNoInputSource:
            return "Set an input source before applying filters."
        case .parameterOutOfRange(_, let range):
            return "Please provide a value between \(range.lowerBound) and \(range.upperBound)."
        case .fileNotFound(let path):
            return "Check if the file exists at the specified path: \(path)"
        default:
            return nil
        }
    }
}

extension HarbethError: CustomNSError {
    public var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: errorDescription ?? "Unknown error",
        ]
        if let recovery = recoverySuggestion {
            userInfo[NSLocalizedRecoverySuggestionErrorKey] = recovery
        }
        if let underlyingError = underlyingError {
            userInfo[NSUnderlyingErrorKey] = underlyingError
        }
        return userInfo
    }
    
    public static var errorDomain: String {
        return "com.harbeth.error"
    }
    
    public static func toHarbethError(_ error: Error) -> HarbethError {
        if let error = error.asHarbethError {
            return error
        } else {
            return .error(error)
        }
    }
    
    public static func failed(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
        #if DEBUG
        fatalError(message(), file: file, line: line)
        #else
        print("\(file):\(line): \(message())")
        #endif
    }
    
    public static func check(_ condition: @autoclosure () -> Bool, error: HarbethError, file: StaticString = #file, line: UInt = #line) throws {
        guard condition() else {
            #if DEBUG
            print("Error at \(file):\(line): \(error.localizedDescription)")
            #endif
            throw error
        }
    }
    
    public static func filterError(name: String, reason: String) -> HarbethError {
        return .filterProcessingFailed("Filter '\(name)': \(reason)")
    }
}

extension Error {
    /// Returns the instance cast as an `HarbethError`.
    public var asHarbethError: HarbethError? {
        self as? HarbethError
    }
    
    /// Get the localization description.
    public var harbethLocalizedDescription: String {
        if let harbethError = self as? HarbethError {
            return harbethError.localizedDescription
        } else {
            return self.localizedDescription
        }
    }
}

extension HarbethError {
    public var code: Int {
        switch self {
        case .unknown: return 1000
        case .error: return 1001
        case .commandBuffer: return 1002
        case .makeBlitCommandEncoder: return 1003
        case .makeComputeCommandEncoder: return 1004
        case .makeTexture: return 1005
        case .textureLoader: return 1006
        case .bitmapDataNotFound: return 1007
        case .image2Texture: return 1100
        case .image2CGImage: return 1101
        case .imageCropFailed: return 1102
        case .imageRotationFailed: return 1103
        case .imageFlipFailed: return 1104
        case .imageResizeFailed: return 1105
        case .imageOrientationFailed: return 1106
        case .source2Texture: return 1200
        case .texture2Image: return 1201
        case .texture2CGImage: return 1202
        case .texture2CIImage: return 1203
        case .textureCropFailed: return 1204
        case .textureCreateFailed: return 1205
        case .textureCopyPixelBufferFailed: return 1206
        case .textureFormatNotSupported: return 1207
        case .textureSizeMismatch: return 1208
        case .readFunction: return 1300
        case .computePipelineState: return 1301
        case .renderPipelineState: return 1302
        case .pipelineStateCreationFailed: return 1303
        case .cubeResource: return 1400
        case .createCIFilter: return 1401
        case .outputCIImage: return 1402
        case .ciContextCreationFailed: return 1403
        case .ciImageCreationFailed: return 1404
        case .CVPixelBufferToCMSampleBuffer: return 1500
        case .CMSampleBufferToCVPixelBuffer: return 1501
        case .pixelBufferLockFailed: return 1502
        case .pixelBufferUnlockFailed: return 1503
        case .pixelBufferCreationFailed: return 1504
        case .pixelBufferCopyFailed: return 1505
        case .sampleBufferCreationFailed: return 1506
        case .renderableNoInputSource: return 1600
        case .renderableUnsupportedInputType: return 1601
        case .renderableInvalidOutputType: return 1602
        case .renderableAlreadyProcessing: return 1603
        case .renderableTaskCancelled: return 1604
        case .renderableTextureLocked: return 1605
        case .renderableViewSetupFailed: return 1606
        case .renderableDelegateNotSet: return 1607
        case .filterInitializationFailed: return 1700
        case .filterParameterInvalid: return 1701
        case .filterChainEmpty: return 1702
        case .filterProcessingFailed: return 1703
        case .memoryAllocationFailed: return 1800
        case .deviceNotAvailable: return 1801
        case .commandQueueCreationFailed: return 1802
        case .textureCacheCreationFailed: return 1803
        case .libraryCreationFailed: return 1804
        case .bufferCreationFailed: return 1805
        case .fileNotFound: return 1900
        case .fileReadFailed: return 1901
        case .fileWriteFailed: return 1902
        case .resourceNotFound: return 1903
        case .configurationInvalid: return 2000
        case .parameterMissing: return 2001
        case .parameterOutOfRange: return 2002
        }
    }
}
