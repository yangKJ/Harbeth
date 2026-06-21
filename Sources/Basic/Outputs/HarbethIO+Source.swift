//
//  HarbethIO+Source.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import CoreMedia
import CoreVideo
import CoreGraphics
import MetalKit

extension HarbethIO {
    func filtering(pixelBuffer: CVPixelBuffer) throws -> CVPixelBuffer {
        let inTexture = try TextureLoader(with: pixelBuffer).texture
        let texture = try filtering(texture: inTexture)
        pixelBuffer.c7.copyToPixelBuffer(with: texture)
        return pixelBuffer
    }

    func filtering(sampleBuffer: CMSampleBuffer) throws -> CMSampleBuffer {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw HarbethError.CMSampleBufferToCVPixelBuffer
        }
        let outputPixelBuffer = try filtering(pixelBuffer: pixelBuffer)
        guard let buffer = outputPixelBuffer.c7.toCMSampleBuffer(reference: sampleBuffer) else {
            throw HarbethError.CVPixelBufferToCMSampleBuffer
        }
        return buffer
    }

    func filtering(cgImage: CGImage) throws -> CGImage {
        let inTexture = try TextureLoader(with: cgImage).texture
        let texture = try filtering(texture: inTexture)
        guard let cgImg = texture.c7.toCGImage() else {
            throw HarbethError.texture2Image
        }
        return cgImg
    }

    func filtering(image: C7Image) throws -> C7Image {
        let inTexture = try TextureLoader(with: image).texture
        let texture = try filtering(texture: inTexture)
        return try texture.c7.fixImageOrientation(refImage: image)
    }

    func filtering(pixelBuffer: CVPixelBuffer, complete: @escaping (Result<CVPixelBuffer, HarbethError>) -> Void) {
        do {
            let texture = try TextureLoader(with: pixelBuffer).texture
            filtering(texture: texture, complete: { result in
                let mapped = result.map {
                    pixelBuffer.c7.copyToPixelBuffer(with: $0)
                    return pixelBuffer
                }
                complete(mapped)
            })
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }

    func filtering(sampleBuffer: CMSampleBuffer, complete: @escaping (Result<CMSampleBuffer, HarbethError>) -> Void) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            complete(.failure(HarbethError.CMSampleBufferToCVPixelBuffer))
            return
        }
        filtering(pixelBuffer: pixelBuffer, complete: { result in
            switch result {
            case .success(let outputPixelBuffer):
                guard let buffer = outputPixelBuffer.c7.toCMSampleBuffer(reference: sampleBuffer) else {
                    complete(.failure(HarbethError.CVPixelBufferToCMSampleBuffer))
                    return
                }
                complete(.success(buffer))
            case .failure(let error):
                complete(.failure(HarbethError.toHarbethError(error)))
            }
        })
    }

    func filtering(cgImage: CGImage, complete: @escaping (Result<CGImage, HarbethError>) -> Void) {
        do {
            let texture = try TextureLoader(with: cgImage).texture
            filtering(texture: texture, complete: { result in
                switch result {
                case .success(let texture):
                    guard let outputImage = texture.c7.toCGImage() else {
                        complete(.failure(HarbethError.texture2Image))
                        return
                    }
                    complete(.success(outputImage))
                case .failure(let error):
                    complete(.failure(HarbethError.toHarbethError(error)))
                }
            })
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }

    func filtering(image: C7Image, complete: @escaping (Result<C7Image, HarbethError>) -> Void) {
        do {
            let texture = try TextureLoader(with: image).texture
            filtering(texture: texture, complete: { result in
                switch result {
                case .success(let texture):
                    do {
                        let outputImage = try texture.c7.fixImageOrientation(refImage: image)
                        complete(.success(outputImage))
                    } catch {
                        complete(.failure(HarbethError.toHarbethError(error)))
                    }
                case .failure(let error):
                    complete(.failure(HarbethError.toHarbethError(error)))
                }
            })
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }

    func makeImageSource() throws -> ImageSource {
        switch element {
        case let texture as MTLTexture:
            return .texture(texture)
        case let image as C7Image:
            return .image(image)
        case let data as Data:
            return .data(data)
        case let url as URL:
            return .asset(ImageAsset(storage: .url(url)))
        case let asset as ImageAsset:
            return .asset(asset)
        case let value where CFGetTypeID(value as CFTypeRef) == CGImage.typeID:
            return .cgImage(value as! CGImage)
        case let value where CFGetTypeID(value as CFTypeRef) == CVPixelBufferGetTypeID():
            return .pixelBuffer(value as! CVPixelBuffer)
        case let value where CFGetTypeID(value as CFTypeRef) == CMSampleBufferGetTypeID():
            return .sampleBuffer(value as! CMSampleBuffer)
        default:
            throw HarbethError.source2Texture
        }
    }
}
