//
//  Processed.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import MetalKit
import MetalPerformanceShaders
import CoreImage

internal struct Processed {

    /// Create a new texture based on the filter content.
    /// Synchronously wait for the execution of the Metal command buffer to complete.
    /// - Parameters:
    ///   - intexture: Input texture
    ///   - outTexture: Output texture
    ///   - filter: It must be an object implementing C7FilterProtocol
    /// - Returns: Output texture after processing
    @inlinable @discardableResult static func IO(inTexture: MTLTexture, outTexture: MTLTexture, filter: C7FilterProtocol) throws -> MTLTexture {
        guard let commandBuffer = Device.commandQueue().makeCommandBuffer() else {
            throw CustomError.commandBuffer
        }
        var finalTexture = inTexture
        switch filter.modifier {
        case .coreimage(let name):
            let outputImage = try filter.outputCIImage(with: inTexture, name: name)
            finalTexture = try outputImage.c7.renderCIImageToTexture(inTexture, commandBuffer: commandBuffer)
        case .compute, .mps, .render:
            finalTexture = try filter.combinationIO(in: inTexture, to: outTexture, commandBuffer: commandBuffer)
            commandBuffer.commitAndWaitUntilCompleted()
        default:
            break
        }
        return finalTexture
    }
    
    /// Whether to synchronously wait for the execution of the Metal command buffer to complete.
    /// - Parameters:
    ///   - intexture: Input texture
    ///   - outTexture: Output texture
    ///   - filter: It must be an object implementing C7FilterProtocol
    ///   - complete: Add a block to be called when this command buffer has completed execution.
    static func runAsyncIO(intexture: MTLTexture, outTexture: MTLTexture, filter: C7FilterProtocol, complete: @escaping (Result<MTLTexture, CustomError>) -> Void) {
        guard let commandBuffer = Device.commandQueue().makeCommandBuffer() else {
            complete(.failure(CustomError.commandBuffer))
            return
        }
        do {
            switch filter.modifier {
            case .coreimage(let name):
                let outputImage = try filter.outputCIImage(with: intexture, name: name)
                outputImage.c7.asyncRenderCIImageToTexture(intexture, commandBuffer: commandBuffer, complete: complete)
            case .compute, .mps, .render:
                let finaTexture = try filter.combinationIO(in: intexture, to: outTexture, commandBuffer: commandBuffer)
                commandBuffer.asyncCommit(texture: finaTexture, complete: complete)
            default:
                break
            }
        } catch {
            complete(.failure(CustomError.toCustomError(error)))
        }
    }
}

// MARK: - filter processed

extension C7FilterProtocol {
    /// Add the filter into the output texture.
    @discardableResult
    public func applyAtTexture(form texture: MTLTexture, to destTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws -> MTLTexture {
        switch self.modifier {
        case .compute(let kernel):
            var textures = [destTexture, texture]
            textures += self.otherInputTextures
            return try self.drawing(with: kernel, commandBuffer: commandBuffer, textures: textures)
        case .render(let vertex, let fragment):
            let pipelineState = try Rendering.makeRenderPipelineState(with: vertex, fragment: fragment)
            Rendering.drawingProcess(pipelineState, commandBuffer: commandBuffer, texture: texture, filter: self)
            return destTexture
        case .mps:
            var textures = [destTexture, texture]
            textures += self.otherInputTextures
            return try (self as! MPSKernelProtocol).encode(commandBuffer: commandBuffer, textures: textures)
        default:
            return destTexture
        }
    }
}

// MARK: - combination fitlers processed
extension C7FilterProtocol {
    
    /// Process combination filters.
    func combinationIO(in texture: MTLTexture, to texture2: MTLTexture, commandBuffer: MTLCommandBuffer) throws -> MTLTexture {
        guard let filter = self as? CombinationProtocol else {
            return try applyAtTexture(form: texture, to: texture2, commandBuffer: commandBuffer)
        }
        let beiginTexture = try filter.combinationBegin(for: commandBuffer, source: texture, dest: texture2)
        let outputTexture = try applyAtTexture(form: beiginTexture, to: texture2, commandBuffer: commandBuffer)
        return try filter.combinationAfter(for: commandBuffer, input: outputTexture, source: texture)
    }
}

// MARK: - core image filter processed
extension C7FilterProtocol {
    
    func outputCIImage(with texture: MTLTexture, name: String) throws -> CIImage {
        guard let cgImage = texture.c7.toCGImage() else {
            throw CustomError.texture2CGImage
        }
        guard let ciFiter = CIFilter.init(name: name) else {
            throw CustomError.createCIFilter(name)
        }
        let inputCIImage = CIImage.init(cgImage: cgImage)
        let ciImage = try (self as! CoreImageProtocol).coreImageApply(filter: ciFiter, input: inputCIImage)
        ciFiter.setValue(ciImage, forKeyPath: kCIInputImageKey)
        guard let outputImage = ciFiter.outputImage else {
            throw CustomError.outputCIImage(name)
        }
        // Return a new image cropped to a rectangle.
        return outputImage.cropped(to: inputCIImage.extent)
    }
}
