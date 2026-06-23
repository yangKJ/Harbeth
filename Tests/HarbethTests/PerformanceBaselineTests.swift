import XCTest
import Metal
import CoreVideo
@testable import Harbeth

final class PerformanceBaselineTests: XCTestCase {

    func testHarbethIOFilterChainClockBaseline() throws {
        let input = try makeTexture(width: 256, height: 256, pixel: [96, 128, 160, 255])
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.08),
            C7Contrast(contrast: 1.05),
            C7Saturation(saturation: 1.1)
        ]

        measure(metrics: [XCTClockMetric()]) {
            autoreleasepool {
                do {
                    _ = try HarbethIO(element: input, filters: filters)
                        .configured(for: .stablePreview)
                        .renderTexture()
                } catch {
                    XCTFail("Expected HarbethIO baseline render to succeed: \(error)")
                }
            }
        }
    }

    func testImageNodeFilterChainClockBaseline() throws {
        let input = try makeTexture(width: 256, height: 256, pixel: [96, 128, 160, 255])
        let node = ImageNode
            .texture(input)
            .applying(C7Brightness(brightness: 0.08))
            .applying(C7Contrast(contrast: 1.05))
            .applying(C7Saturation(saturation: 1.1))

        measure(metrics: [XCTClockMetric()]) {
            autoreleasepool {
                do {
                    _ = try node.makeTexture(profile: .stablePreview)
                } catch {
                    XCTFail("Expected ImageNode baseline render to succeed: \(error)")
                }
            }
        }
    }

    func testImageNodeGeometrySamplerClockBaseline() throws {
        let input = try makeTexture(width: 256, height: 256, pixel: [255, 64, 32, 255])
        let filter = RenderQuadTransform(
            quad: .init(
                topLeft: .init(x: 0.08, y: 0.02),
                topRight: .init(x: 0.94, y: 0.1),
                bottomLeft: .init(x: 0.04, y: 0.92),
                bottomRight: .init(x: 0.98, y: 0.88)
            )
        )
        let node = ImageNode
            .texture(input)
            .applying(filter)
            .withSamplerDescriptor(.nearest)

        measure(metrics: [XCTClockMetric()]) {
            autoreleasepool {
                do {
                    _ = try node.makeTexture(profile: .stablePreview)
                } catch {
                    XCTFail("Expected geometry sampler baseline render to succeed: \(error)")
                }
            }
        }
    }

    func testImageNodeEditRouteClockBaseline() throws {
        let input = try makeTexture(width: 256, height: 256, pixel: [180, 96, 48, 255])
        let node = ImageNode
            .texture(input)
            .editing(
                EditRecipe(
                    geometry: ImageTransformRecipe(
                        targetSize: CGSize(width: 220, height: 220),
                        aspectPolicy: .fit
                    )
                )
            )
            .applying(C7Brightness(brightness: 0.06))

        measure(metrics: [XCTClockMetric()]) {
            autoreleasepool {
                do {
                    _ = try node.makeTexture(profile: .stablePreview)
                } catch {
                    XCTFail("Expected edit route baseline render to succeed: \(error)")
                }
            }
        }
    }

    func testImageNodeLayerCompositeRouteClockBaseline() throws {
        let background = try makeTexture(width: 256, height: 256, pixel: [48, 48, 48, 255])
        let layer = try makeTexture(width: 128, height: 128, pixel: [220, 128, 64, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    normalizedFrame: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                    opacity: 0.9
                )
            ]
        )
        let node = ImageNode.layerComposite(recipe)

        measure(metrics: [XCTClockMetric()]) {
            autoreleasepool {
                do {
                    _ = try node.makeTexture(profile: recipe.profile, derivative: recipe.derivative)
                } catch {
                    XCTFail("Expected layer composite route baseline render to succeed: \(error)")
                }
            }
        }
    }

    func testImageNodeTransitionRouteClockBaseline() throws {
        let from = try makeTexture(width: 256, height: 256, pixel: [255, 64, 64, 255])
        let to = try makeTexture(width: 256, height: 256, pixel: [64, 64, 255, 255])
        let recipe = TransitionRecipe(
            from: .texture(from),
            to: .texture(to),
            kernel: .dissolve,
            progress: 0.5
        )
        let node = ImageNode.transition(recipe)

        measure(metrics: [XCTClockMetric()]) {
            autoreleasepool {
                do {
                    _ = try node.makeTexture(profile: recipe.profile, derivative: recipe.derivative)
                } catch {
                    XCTFail("Expected transition route baseline render to succeed: \(error)")
                }
            }
        }
    }

    func testPixelBufferYCbCrBridgeClockBaseline() throws {
        let pixelBuffer = try makeBiPlanarPixelBuffer(width: 320, height: 180)
        let io = HarbethIO(
            element: pixelBuffer,
            filters: [C7Brightness(brightness: 0.05)]
        ).configured(for: .stablePreview)

        measure(metrics: [XCTClockMetric()]) {
            autoreleasepool {
                do {
                    _ = try io.renderTexture()
                } catch {
                    XCTFail("Expected pixel buffer baseline render to succeed: \(error)")
                }
            }
        }
    }

    private func makeTexture(width: Int, height: Int, pixel: [UInt8]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw XCTSkip("Could not create Metal texture.")
        }
        let bytes = Array(repeating: pixel, count: width * height).flatMap { $0 }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func makeBiPlanarPixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw XCTSkip("Could not create bi-planar pixel buffer.")
        }
        return pixelBuffer
    }
}
