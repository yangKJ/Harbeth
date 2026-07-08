//
//  MaskMicrotestHelper.swift
//  Harbeth
//

import XCTest
import Metal
import simd
@testable import Harbeth

enum MaskMicrotestHelper {

    struct KernelRun {
        let input: MTLTexture
        let output: MTLTexture
        let commandBuffer: MTLCommandBuffer
    }

    static func prepareKernelMicrotest(size: Int = 8, filter: C7FilterProtocol, customInput: MTLTexture? = nil) throws -> KernelRun {
        guard size > 0 else {
            throw HarbethError.filterParameterInvalid(
                "MaskMicrotestHelper: size must be > 0, got \(size)"
            )
        }
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command queue / buffer.")
            throw HarbethError.commandBuffer
        }

        let input: MTLTexture
        if let custom = customInput {
            input = custom
        } else {
            let inputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: size,
                height: size,
                mipmapped: false
            )
            inputDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            guard let built = device.makeTexture(descriptor: inputDescriptor) else {
                XCTFail("Failed to create input texture (\(size)x\(size)).")
                throw HarbethError.makeTexture
            }
            input = built
        }

        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        outputDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        guard let output = device.makeTexture(descriptor: outputDescriptor) else {
            XCTFail("Failed to create output texture (\(size)x\(size)).")
            throw HarbethError.makeTexture
        }

        _ = try filter.apply(form: input, to: output, for: commandBuffer, complete: nil)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return KernelRun(input: input, output: output, commandBuffer: commandBuffer)
    }

    static func assertMatchesMaskMath(
        gpuPixel: SIMD4<Float>,
        mathValue: Float,
        tolerance: Float = 0.005,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let diff = abs(gpuPixel.x - mathValue)
        if diff > tolerance {
            XCTFail(
                "GPU mask coverage (\(gpuPixel.x)) 与 MaskMath 参考值 (\(mathValue)) 差 \(diff),超过 tolerance \(tolerance)",
                file: file,
                line: line
            )
        } else {
            XCTAssertTrue(
                diff <= tolerance,
                "diff \(diff) 应该 ≤ tolerance \(tolerance)",
                file: file,
                line: line
            )
        }
    }

    static func sampleGrid(in texture: MTLTexture, gridSize: Int = 4) throws -> [[SIMD4<Float>]] {
        let width = texture.width
        let height = texture.height
        guard gridSize > 0 else {
            throw HarbethError.filterParameterInvalid(
                "MaskMicrotestHelper.sampleGrid: gridSize must be > 0, got \(gridSize)"
            )
        }
        guard let bytes = texture.c7.bytes(), bytes.count >= width * height * 4 else {
            XCTFail("Expected readable RGBA bytes from \(width)x\(height) texture.")
            throw HarbethError.texture2Image
        }
        // 构造采样点:xSample / ySample 在像素索引空间均匀分布
        let xs: [Int] = (0..<gridSize).map { i in
            // (i * 2 + 1) / (2 * gridSize) * width,然后四舍五入到最接近的像素索引
            let normalized = (Float(i) + 0.5) / Float(gridSize)
            return min(max(Int(normalized * Float(width)), 0), width - 1)
        }
        let ys: [Int] = (0..<gridSize).map { i in
            let normalized = (Float(i) + 0.5) / Float(gridSize)
            return min(max(Int(normalized * Float(height)), 0), height - 1)
        }
        var grid: [[SIMD4<Float>]] = []
        for y in ys {
            var row: [SIMD4<Float>] = []
            for x in xs {
                let offset = (y * width + x) * 4
                let r = Float(bytes[offset + 0]) / 255.0
                let g = Float(bytes[offset + 1]) / 255.0
                let b = Float(bytes[offset + 2]) / 255.0
                let a = Float(bytes[offset + 3]) / 255.0
                row.append(SIMD4<Float>(r, g, b, a))
            }
            grid.append(row)
        }
        return grid
    }

    static func samplePixel(in texture: MTLTexture, x: Int, y: Int) throws -> SIMD4<Float> {
        var raw = [UInt8](repeating: 0, count: 4)
        texture.getBytes(
            &raw,
            bytesPerRow: 4,
            from: MTLRegionMake2D(x, y, 1, 1),
            mipmapLevel: 0
        )
        return SIMD4<Float>(
            Float(raw[0]) / 255.0,
            Float(raw[1]) / 255.0,
            Float(raw[2]) / 255.0,
            Float(raw[3]) / 255.0
        )
    }
}
