//
//  C7FilterManager.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/9.
//

import Foundation
import MetalKit
import UIKit

public struct C7FilterManager {
    public struct compute { }
}

/// 以下模式均只支持基于并行计算编码器`compute(kernel: String)`
/// The following modes support only the encoder based on parallel computing
extension C7FilterManager.compute {
    
    /// 获取滤镜图片
    public static func makeImage(input image: MTQImage, filter: C7FilterProtocol) -> MTQImage {
        guard let inTexture = image.mt.toTexture() else {
            return image
        }
        let otherInpuTextures = filter.otherInputTextures
        let outTexture = C7FilterManager.makeMTLTexture(inTexture, otherInputTextures: otherInpuTextures, filter: filter)
        return outTexture.toImage() ?? image
    }
    
    /// 多种滤镜组合
    public static func makeGroup(input image: MTQImage, filters: [C7FilterProtocol]) -> MTQImage {
        guard let inTexture = image.mt.toTexture() else {
            return image
        }
        var outTexture: MTLTexture = inTexture
        for filter in filters {
            let otherInputTextures = filter.otherInputTextures
            outTexture = C7FilterManager.makeMTLTexture(outTexture, otherInputTextures: otherInputTextures, filter: filter)
        }
        return outTexture.toImage() ?? image
    }
}

extension C7FilterManager {
    static func makeMTLTexture(_ inTexture: MTLTexture,
                               otherInputTextures: MTQInputTextures? = nil,
                               filter: C7FilterProtocol) -> MTLTexture {
        guard let commandBuffer = C7FilterUtil.makeCommandBuffer() else {
            return inTexture
        }
        
        let outTexture = C7FilterUtil.dstTexture(width: inTexture.width, height: inTexture.height)
        if case .compute(let kernel) = filter.modifier {
            var textures = [outTexture, inTexture]
            if let inTexture2 = otherInputTextures { textures += inTexture2 }
            let pipelineState = C7FilterUtil.Compute.makeComputePipelineState(with: kernel)
            C7FilterUtil.Compute.process(pipelineState: pipelineState,
                                         commandBuffer: commandBuffer,
                                         textures: textures,
                                         factors: filter.factors)
        } else if case .render(let vertex, let fragment) = filter.modifier {
            var textures = [inTexture]
            if let inTexture2 = otherInputTextures { textures += inTexture2 }
            let pipelineState = C7FilterUtil.Render.makeRenderPipelineState(with: vertex, fragment: fragment)
            C7FilterUtil.Render.process(pipelineState: pipelineState,
                                        commandBuffer: commandBuffer,
                                        inputTextures: textures,
                                        outputTexture: outTexture,
                                        factors: filter.factors)
        }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return outTexture
    }
}
