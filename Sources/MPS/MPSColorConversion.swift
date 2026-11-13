//
//  MPSColorConversion.swift
//  Harbeth
//
//  Created by Condy on 2026/11/13.
//

import CoreGraphics
import MetalPerformanceShaders

/// 在现有提交内兑现RGB ICC转换，避免纹理回到位图或独立同步提交。
public struct MPSColorConversion: MPSKernelProtocol {
    private let conversion: MPSImageConversion
    private let identity: String

    public init(from source: CGColorSpace, to destination: CGColorSpace, alphaType: AlphaType = .premultiplied) throws {
        guard source.model == .rgb, destination.model == .rgb,
              let info = CGColorConversionInfo(src: source, dst: destination) else {
            throw HarbethError.configurationInvalid("GPU ICC转换需要有效RGB配置文件。")
        }
        let alpha: MPSAlphaType
        switch alphaType {
        case .premultiplied: alpha = .premultiplied
        case .nonPremultiplied: alpha = .nonPremultiplied
        case .alphaIsOne: alpha = .alphaIsOne
        }
        conversion = MPSImageConversion(device: HarbethContext.shared.device,
            srcAlpha: alpha, destAlpha: alpha, backgroundColor: nil, conversionInfo: info)
        identity = ImageColorProfileDescriptor(colorSpace: source).fingerprint
            + ":" + ImageColorProfileDescriptor(colorSpace: destination).fingerprint + ":" + alphaType.rawValue
    }

    public var modifier: ModifierEnum { .mps(performance: conversion) }
    public var identifier: String { "MPSColorConversion:" + identity }
    public var memoryAccessPattern: MemoryAccessPattern { .point }

    public func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        let (destination, source) = try mpsTexturePair(from: textures)
        conversion.encode(commandBuffer: commandBuffer, sourceTexture: source, destinationTexture: destination)
        return destination
    }
}
