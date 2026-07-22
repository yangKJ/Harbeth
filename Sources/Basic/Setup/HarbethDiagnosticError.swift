import Foundation

public protocol HarbethDiagnosticError: Error {
    var harbethDiagnosticCode: String { get }
    var harbethDiagnosticMetadata: [String: String] { get }
}

public extension HarbethDiagnosticError {
    var harbethDiagnosticMetadata: [String: String] { [:] }
}

extension HarbethError: HarbethDiagnosticError {
    public var harbethDiagnosticCode: String {
        switch self {
        case .unknown: return "harbeth.unknown"
        case .error: return "harbeth.underlying_error"
        case .commandBuffer: return "harbeth.command_buffer.create_failed"
        case .makeBlitCommandEncoder: return "harbeth.command_encoder.blit_create_failed"
        case .makeComputeCommandEncoder: return "harbeth.command_encoder.compute_create_failed"
        case .makeTexture: return "harbeth.texture.create_failed"
        case .textureLoader: return "harbeth.texture.loader_failed"
        case .bitmapDataNotFound: return "harbeth.bitmap.data_missing"
        case .commandBufferAsyncCommit: return "harbeth.command_buffer.async_commit_failed"
        case .image2Texture: return "harbeth.image.to_texture_failed"
        case .image2CGImage: return "harbeth.image.to_cgimage_failed"
        case .imageCropFailed: return "harbeth.image.crop_failed"
        case .imageRotationFailed: return "harbeth.image.rotation_failed"
        case .imageFlipFailed: return "harbeth.image.flip_failed"
        case .imageResizeFailed: return "harbeth.image.resize_failed"
        case .imageOrientationFailed: return "harbeth.image.orientation_failed"
        case .source2Texture: return "harbeth.source.to_texture_failed"
        case .texture2Image: return "harbeth.texture.to_image_failed"
        case .texture2CGImage: return "harbeth.texture.to_cgimage_failed"
        case .textureCropFailed: return "harbeth.texture.crop_failed"
        case .textureCreateFailed: return "harbeth.texture.allocate_failed"
        case .textureCopyPixelBufferFailed: return "harbeth.texture.copy_pixel_buffer_failed"
        case .textureFormatNotSupported: return "harbeth.texture.format_unsupported"
        case .textureSizeMismatch: return "harbeth.texture.size_mismatch"
        case .textureNotMipmapped: return "harbeth.texture.mipmaps_missing"
        case .readFunction: return "harbeth.metal.function_not_found"
        case .computePipelineState: return "harbeth.metal.compute_pipeline_create_failed"
        case .renderPipelineState: return "harbeth.metal.render_pipeline_create_failed"
        case .pipelineStateCreationFailed: return "harbeth.metal.pipeline_create_failed"
        case .cubeResource: return "harbeth.resource.cube_read_failed"
        case .contextCreationFailed: return "harbeth.context.create_failed"
        case .CVPixelBufferToCMSampleBuffer: return "harbeth.pixel_buffer.to_sample_buffer_failed"
        case .CMSampleBufferToCVPixelBuffer: return "harbeth.sample_buffer.to_pixel_buffer_failed"
        case .pixelBufferLockFailed: return "harbeth.pixel_buffer.lock_failed"
        case .pixelBufferUnlockFailed: return "harbeth.pixel_buffer.unlock_failed"
        case .pixelBufferCreationFailed: return "harbeth.pixel_buffer.create_failed"
        case .pixelBufferCopyFailed: return "harbeth.pixel_buffer.copy_failed"
        case .sampleBufferCreationFailed: return "harbeth.sample_buffer.create_failed"
        case .renderableNoInputSource: return "harbeth.renderable.input_missing"
        case .renderableUnsupportedInputType: return "harbeth.renderable.input_unsupported"
        case .renderableInvalidOutputType: return "harbeth.renderable.output_invalid"
        case .renderableAlreadyProcessing: return "harbeth.renderable.already_processing"
        case .renderableTaskCancelled: return "harbeth.renderable.cancelled"
        case .renderableTextureLocked: return "harbeth.renderable.texture_locked"
        case .renderableViewSetupFailed: return "harbeth.renderable.view_setup_failed"
        case .renderableDelegateNotSet: return "harbeth.renderable.delegate_missing"
        case .filterInitializationFailed: return "harbeth.filter.initialization_failed"
        case .filterParameterInvalid: return "harbeth.filter.parameter_invalid"
        case .filterChainEmpty: return "harbeth.filter.chain_empty"
        case .kernelInvocationIncompatible: return "harbeth.kernel.invocation_incompatible"
        case .filterProcessingFailed: return "harbeth.filter.processing_failed"
        case .memoryAllocationFailed: return "harbeth.memory.allocation_failed"
        case .deviceNotAvailable: return "harbeth.metal.device_unavailable"
        case .commandQueueCreationFailed: return "harbeth.metal.command_queue_create_failed"
        case .textureCacheCreationFailed: return "harbeth.texture.cache_create_failed"
        case .libraryCreationFailed: return "harbeth.metal.library_create_failed"
        case .bufferCreationFailed: return "harbeth.metal.buffer_create_failed"
        case .fileNotFound: return "harbeth.file.not_found"
        case .fileReadFailed: return "harbeth.file.read_failed"
        case .fileWriteFailed: return "harbeth.file.write_failed"
        case .resourceNotFound: return "harbeth.resource.not_found"
        case .configurationInvalid: return "harbeth.configuration.invalid"
        case .parameterMissing: return "harbeth.parameter.missing"
        case .parameterOutOfRange: return "harbeth.parameter.out_of_range"
        }
    }

    public var harbethDiagnosticMetadata: [String: String] {
        var metadata = ["numericCode": String(code)]
        switch self {
        case .commandBufferAsyncCommit(let status): metadata["commandBufferStatus"] = String(status.rawValue)
        case .readFunction(let name): metadata["function"] = name
        case .computePipelineState(let name): metadata["function"] = name
        case .renderPipelineState(let vertex, let fragment):
            metadata["vertexFunction"] = vertex
            metadata["fragmentFunction"] = fragment
        case .filterInitializationFailed(let name): metadata["filter"] = name
        case .filterParameterInvalid(let parameter), .parameterMissing(let parameter): metadata["parameter"] = parameter
        case .parameterOutOfRange(let parameter, let range):
            metadata["parameter"] = parameter
            metadata["range"] = "\(range.lowerBound)...\(range.upperBound)"
        default: break
        }
        return metadata
    }
}

extension TextureMultiPassError: HarbethDiagnosticError {
    public var harbethDiagnosticCode: String { "harbeth.texture_multi_pass.cancelled" }
}

extension TextureRegionContextError: HarbethDiagnosticError {
    public var harbethDiagnosticCode: String {
        switch self {
        case .invalidLogicalExtent: return "harbeth.texture_region.logical_extent_invalid"
        case .invalidReadRegion: return "harbeth.texture_region.read_region_invalid"
        case .invalidWriteRegion: return "harbeth.texture_region.write_region_invalid"
        case .invalidFootprint: return "harbeth.texture_region.footprint_invalid"
        case .unsupportedFootprint: return "harbeth.texture_region.footprint_unsupported"
        }
    }
}

public extension Error {
    var harbethDiagnosticCode: String {
        (self as? HarbethDiagnosticError)?.harbethDiagnosticCode ?? "harbeth.underlying_error"
    }

    var harbethDiagnosticMetadata: [String: String] {
        (self as? HarbethDiagnosticError)?.harbethDiagnosticMetadata ?? [
            "errorDomain": (self as NSError).domain,
            "errorCode": String((self as NSError).code)
        ]
    }
}
