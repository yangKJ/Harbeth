import XCTest
import Metal
@testable import Harbeth

final class RenderPassContractTests: XCTestCase {

    func testRenderPassContractBindsMultipleDestinationTextures() throws {
        let first = try makeTexture(width: 8, height: 8, pixelFormat: .rgba8Unorm, sampleCount: 1)
        let second = try makeTexture(width: 8, height: 8, pixelFormat: .rgba8Unorm, sampleCount: 1)
        let contract = RenderPassContract(
            colorAttachments: [
                ColorAttachmentContract(index: 0, pixelFormat: .rgba8Unorm, loadBehavior: .clear, storeBehavior: .store),
                ColorAttachmentContract(index: 1, pixelFormat: .rgba8Unorm, loadBehavior: .load, storeBehavior: .store)
            ],
            sampleCount: 1
        )

        let descriptor = try contract.makeDescriptor(
            destinationTexturesByAttachmentIndex: [
                0: first,
                1: second
            ]
        )

        XCTAssertTrue(descriptor.colorAttachments[0]?.texture === first)
        XCTAssertTrue(descriptor.colorAttachments[1]?.texture === second)
        XCTAssertEqual(descriptor.colorAttachments[0]?.loadAction, .clear)
        XCTAssertEqual(descriptor.colorAttachments[1]?.loadAction, .load)
    }

    func testRenderPassContractRejectsMissingAttachmentTexture() throws {
        let first = try makeTexture(width: 8, height: 8, pixelFormat: .rgba8Unorm, sampleCount: 1)
        let contract = RenderPassContract(
            colorAttachments: [
                ColorAttachmentContract(index: 0, pixelFormat: .rgba8Unorm),
                ColorAttachmentContract(index: 1, pixelFormat: .rgba8Unorm)
            ],
            sampleCount: 1
        )

        XCTAssertThrowsError(
            try contract.makeDescriptor(destinationTexturesByAttachmentIndex: [0: first])
        ) { error in
            guard case .configurationInvalid(let message)? = error.asHarbethError else {
                return XCTFail("Expected configurationInvalid, got \(error)")
            }
            XCTAssertTrue(message.contains("Missing destination texture"))
            XCTAssertTrue(message.contains("1"))
        }
    }

    func testRenderPassContractRejectsMismatchedAttachmentSize() throws {
        let first = try makeTexture(width: 8, height: 8, pixelFormat: .rgba8Unorm, sampleCount: 1)
        let second = try makeTexture(width: 4, height: 8, pixelFormat: .rgba8Unorm, sampleCount: 1)
        let contract = RenderPassContract(
            colorAttachments: [
                ColorAttachmentContract(index: 0, pixelFormat: .rgba8Unorm),
                ColorAttachmentContract(index: 1, pixelFormat: .rgba8Unorm)
            ],
            sampleCount: 1
        )

        XCTAssertThrowsError(
            try contract.makeDescriptor(destinationTexturesByAttachmentIndex: [0: first, 1: second])
        ) { error in
            guard case .configurationInvalid(let message)? = error.asHarbethError else {
                return XCTFail("Expected configurationInvalid, got \(error)")
            }
            XCTAssertTrue(message.contains("share the same size"))
        }
    }

    func testRenderPassContractRejectsMismatchedAttachmentSampleCount() throws {
        let first = try makeTexture(width: 8, height: 8, pixelFormat: .rgba8Unorm, sampleCount: 1)
        let second = try makeTexture(width: 8, height: 8, pixelFormat: .rgba8Unorm, sampleCount: 2)
        let contract = RenderPassContract(
            colorAttachments: [
                ColorAttachmentContract(index: 0, pixelFormat: .rgba8Unorm),
                ColorAttachmentContract(index: 1, pixelFormat: .rgba8Unorm)
            ],
            sampleCount: 1
        )

        XCTAssertThrowsError(
            try contract.makeDescriptor(destinationTexturesByAttachmentIndex: [0: first, 1: second])
        ) { error in
            guard case .configurationInvalid(let message)? = error.asHarbethError else {
                return XCTFail("Expected configurationInvalid, got \(error)")
            }
            XCTAssertTrue(message.contains("sample count mismatch"))
        }
    }

    private func makeTexture(width: Int,
                             height: Int,
                             pixelFormat: MTLPixelFormat,
                             sampleCount: Int) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = pixelFormat
        descriptor.width = width
        descriptor.height = height
        descriptor.sampleCount = sampleCount
        descriptor.textureType = sampleCount > 1 ? .type2DMultisample : .type2D
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        guard let texture = HarbethContext.shared.device.makeTexture(descriptor: descriptor) else {
            throw HarbethError.makeTexture
        }
        return texture
    }
}
