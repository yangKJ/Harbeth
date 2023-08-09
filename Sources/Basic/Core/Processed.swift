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
        if case .coreimage(let name) = filter.modifier {
            return try filter.renderCoreImage(with: inTexture, name: name)
        }
        guard let commandBuffer = Device.commandQueue().makeCommandBuffer() else {
            throw CustomError.commandBuffer
        }
        let finalTexture = try textureIO(in: inTexture, to: outTexture, commandBuffer: commandBuffer, filter: filter)
        // Commit a command buffer so it can be executed as soon as possible.
        commandBuffer.commit()
        // Wait to make sure that output texture contains new data.
        commandBuffer.waitUntilCompleted()
        return finalTexture
    }
    
    /// Whether to synchronously wait for the execution of the Metal command buffer to complete.
    /// - Parameters:
    ///   - intexture: Input texture
    ///   - outTexture: Output texture
    ///   - filter: It must be an object implementing C7FilterProtocol
    ///   - complete: Add a block to be called when this command buffer has completed execution.
    static func runAsynIO(inTexture: MTLTexture, outTexture: MTLTexture, filter: C7FilterProtocol, complete: @escaping (Result<MTLTexture, CustomError>) -> Void) {
        if case .coreimage(let name) = filter.modifier {
            filter.renderCoreImage(with: inTexture, name: name, complete: complete)
            return
        }
        guard let commandBuffer = Device.commandQueue().makeCommandBuffer() else {
            complete(.failure(CustomError.commandBuffer))
            return
        }
        do {
            let finalTexture = try textureIO(in: inTexture, to: outTexture, commandBuffer: commandBuffer, filter: filter)
            commandBuffer.addCompletedHandler { (buffer) in
                switch buffer.status {
                case .completed:
                    complete(.success(finalTexture))
                case .error where buffer.error != nil:
                    complete(.failure(.error(buffer.error!)))
                default:
                    break
                }
            }
            commandBuffer.commit()
        } catch {
            complete(.failure(CustomError.toCustomError(error)))
        }
    }
    
    private static func textureIO(in texture: MTLTexture,
                                  to texture2: MTLTexture,
                                  commandBuffer: MTLCommandBuffer,
                                  filter: C7FilterProtocol) throws -> MTLTexture {
        guard let cFilter = filter as? CombinationProtocol else {
            let finalTexture = try filter.applyAtTexture(form: texture, to: texture2, commandBuffer: commandBuffer)
            return finalTexture
        }
        let beiginTexture = try cFilter.combinationBegin(for: commandBuffer, source: texture, dest: texture2)
        let destTexture = try filter.applyAtTexture(form: beiginTexture, to: texture2, commandBuffer: commandBuffer)
        let finalTexture = try cFilter.combinationAfter(for: commandBuffer, input: destTexture, source: texture)
        return finalTexture
    }
}

// MARK: - filter processed

extension C7FilterProtocol {

    /// Add the filter into the output texture.
    @discardableResult public func applyAtTexture(form sourceTexture: MTLTexture,
                                                  to destTexture: MTLTexture,
                                                  commandBuffer: MTLCommandBuffer) throws -> MTLTexture {
        switch self.modifier {
        case .compute(let kernel):
            var textures = [destTexture, sourceTexture]
            textures += self.otherInputTextures
            try self.drawing(with: kernel, commandBuffer: commandBuffer, textures: textures)
            return destTexture
        case .render(let vertex, let fragment):
            let pipelineState = try Rendering.makeRenderPipelineState(with: vertex, fragment: fragment)
            Rendering.drawingProcess(pipelineState, commandBuffer: commandBuffer, texture: sourceTexture, filter: self)
            return destTexture
        case .mps:
            var textures = [destTexture, sourceTexture]
            textures += self.otherInputTextures
            let destTexture = try (self as! MPSKernelProtocol).encode(commandBuffer: commandBuffer, textures: textures)
            return destTexture
        default:
            return destTexture
        }
    }
}

// MARK: - core image filter processed

extension C7FilterProtocol {
    /// Metal texture compatibility uses CoreImage filter.
    func renderCoreImage(with texture: MTLTexture, name: String) throws -> MTLTexture {
        let outputImage = try outputCIImage(with: texture, name: name)
        try outputImage.mt.renderImageToTexture(texture, colorSpace: Device.colorSpace())
        return texture
    }
    
    func renderCoreImage(with texture: MTLTexture, name: String, complete: @escaping (Result<MTLTexture, CustomError>) -> Void) {
        do {
            let outputImage = try outputCIImage(with: texture, name: name)
            outputImage.mt.writeCIImageAtTexture(texture, complete: complete, colorSpace: Device.colorSpace())
        } catch {
            complete(.failure(CustomError.toCustomError(error)))
        }
    }
    
    private func outputCIImage(with texture: MTLTexture, name: String) throws -> CIImage {
        guard let cgImage = texture.mt.toCGImage() else {
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
