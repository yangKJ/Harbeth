import XCTest
import Metal
@testable import Harbeth

final class RenderTaskTests: XCTestCase {

    func testTextureRenderTaskExposesCommandBufferStatusAndOutput() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [100, 80, 60, 255])
        let task = try HarbethIO(
            element: input,
            filter: C7Brightness(brightness: 0.1)
        ).startRenderTextureTask()

        let output = try task.output()

        XCTAssertEqual(task.commandBufferStatus, .completed)
        XCTAssertNil(task.error)
        XCTAssertTrue(task.isCompleted)
        XCTAssertEqual(output.width, 2)
        XCTAssertEqual(output.height, 2)
        XCTAssertEqual(task.diagnostics?.compilationSource, .filtersPrimitive)
        XCTAssertEqual(task.diagnostics?.stageCount, 1)
    }

    func testRenderTaskCompletionObserverRunsAfterGPUCompletion() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [20, 40, 80, 255])
        let expectation = expectation(description: "render task completion")
        let task = try HarbethIO(
            element: input,
            filter: C7Contrast(contrast: 1.1)
        ).startRenderTextureTask()

        task.observeCompletion { completedTask in
            XCTAssertTrue(completedTask.isCompleted)
            XCTAssertEqual(completedTask.commandBufferStatus, .completed)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        _ = try task.output()
    }

    func testGenericRenderTextureTaskCarriesDerivativeDiagnostics() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [200, 20, 20, 255])
        let derivative = ImageDerivativeSpec(
            name: "taskDerivative",
            renderIntent: .stable,
            sourceTier: .stableReusable,
            semantic: RenderProfile.stablePreview.defaultImageSemantic,
            outputSizePolicy: .exact(C7Size(width: 2, height: 2))
        )

        let task = try HarbethIO<MTLTexture>(
            element: input,
            filters: []
        ).startRenderTextureTask(profile: .stablePreview, derivative: derivative)
        let output = try task.output()

        XCTAssertEqual(output.width, 2)
        XCTAssertEqual(output.height, 2)
        XCTAssertEqual(task.diagnostics?.derivative.name, "taskDerivative")
        XCTAssertTrue(task.diagnostics?.containsDerivativeResize == true)
    }

    private func makeTexture(width: Int, height: Int, pixel: [UInt8]) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = Shared.shared.defaultDevice.device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        var pixels = Array(repeating: UInt8(0), count: width * height * 4)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            pixels[index] = pixel[0]
            pixels[index + 1] = pixel[1]
            pixels[index + 2] = pixel[2]
            pixels[index + 3] = pixel[3]
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )
        return texture
    }
}
