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
            return filter.renderCoreImage(with: inTexture, name: name)
        }
        let commandBuffer = try filter.applyAtTexture(form: inTexture, to: outTexture)
        // Commit a command buffer so it can be executed as soon as possible.
        commandBuffer.commit()
        // Wait to make sure that output texture contains new data.
        commandBuffer.waitUntilCompleted()
        return outTexture
    }
    
    /// Whether to synchronously wait for the execution of the Metal command buffer to complete.
    /// - Parameters:
    ///   - intexture: Input texture
    ///   - outTexture: Output texture
    ///   - filter: It must be an object implementing C7FilterProtocol
    ///   - complete: Add a block to be called when this command buffer has completed execution.
    static func runAsynIO(inTexture: MTLTexture, outTexture: MTLTexture, filter: C7FilterProtocol, complete: @escaping (Result<MTLTexture, Error>) -> Void) {
        if case .coreimage(let name) = filter.modifier {
            let texture = filter.renderCoreImage(with: inTexture, name: name)
            complete(.success(texture))
            return
        }
        do {
            let commandBuffer = try filter.applyAtTexture(form: inTexture, to: outTexture)
            commandBuffer.addCompletedHandler { (buffer) in
                switch buffer.status {
                case .completed:
                    complete(.success(outTexture))
                default:
                    break
                }
            }
            commandBuffer.commit()
        } catch {
            complete(.failure(error))
        }
    }
}

extension C7FilterProtocol {
    
    /// Add the filter into the output texture.
    func applyAtTexture(form sourceTexture: MTLTexture, to destinationTexture: MTLTexture) throws -> MTLCommandBuffer {
        guard let commandBuffer = Device.commandQueue().makeCommandBuffer() else {
            throw CustomError.commandBuffer
        }
        if case .compute(let kernel) = self.modifier {
            guard let pipelineState = Compute.makeComputePipelineState(with: kernel) else {
                throw CustomError.computePipelineState(kernel)
            }
            var textures = [destinationTexture, sourceTexture]
            textures += self.otherInputTextures
            Compute.drawingProcess(pipelineState, commandBuffer: commandBuffer, textures: textures, filter: self)
        } else if case .render(let vertex, let fragment) = self.modifier {
            guard let pipelineState = Rendering.makeRenderPipelineState(with: vertex, fragment: fragment) else {
                throw CustomError.renderPipelineState(vertex, fragment)
            }
            Rendering.drawingProcess(pipelineState, commandBuffer: commandBuffer, texture: sourceTexture, filter: self)
        } else if case .mps(let performance) = self.modifier {
            performance.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: destinationTexture)
        }
        return commandBuffer
    }
    
    /// Metal texture compatibility uses CoreImage filter.
    func renderCoreImage(with texture: MTLTexture, name: String) -> MTLTexture {
        guard let filter = self as? CoreImageFiltering, let cgImage = texture.mt.toCGImage() else {
            return texture
        }
        var ciimage = CIImage.init(cgImage: cgImage)
        let cifiter = CIFilter.init(name: name)
        ciimage = filter.coreImageApply(filter: cifiter, input: ciimage)
        cifiter?.setValue(ciimage, forKeyPath: kCIInputImageKey)
        cifiter?.outputImage?.mt.renderImageToTexture(texture, colorSpace: Device.colorSpace())
        return texture
    }
}
