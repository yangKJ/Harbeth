import XCTest
import Metal
@testable import Harbeth

final class PipelineBinaryArchiveTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try HarbethContext.shared.configurePipelineBinaryArchive(.disabled)
        HarbethContext.shared.resetCaches()
    }

    override func tearDownWithError() throws {
        try HarbethContext.shared.configurePipelineBinaryArchive(.disabled)
        HarbethContext.shared.resetCaches()
        try super.tearDownWithError()
    }

    private func makeTexture() throws -> MTLTexture {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal device is unavailable.")
        }
        return try TextureLoader.makeTexture(
            width: 4,
            height: 4,
            options: [.texturePixelFormat: MTLPixelFormat.rgba8Unorm],
            identifier: "PipelineBinaryArchiveTests"
        )
    }

    func testMemoryArchiveRegistersComputeAndRenderPipelines() throws {
        let texture = try makeTexture()
        try HarbethContext.shared.configurePipelineBinaryArchive(.memoryOnly)

        _ = try HarbethIO(element: texture, filters: [C7Brightness(brightness: 0.1)]).output()
        _ = try HarbethIO(element: texture, filters: [RenderGrayscale()]).output()

        let snapshot = HarbethContext.shared.pipelineBinaryArchiveSnapshot
        XCTAssertEqual(snapshot.mode, .memoryOnly)
        XCTAssertGreaterThanOrEqual(snapshot.registeredComputePipelineCount, 1)
        XCTAssertGreaterThanOrEqual(snapshot.registeredRenderPipelineCount, 1)
        XCTAssertGreaterThanOrEqual(snapshot.registeredPipelineCount, 2)
    }

    func testPersistentArchiveCanSerializeAndReload() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HarbethBinaryArchiveTests-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("pipelines.metalarc")
        defer { try? FileManager.default.removeItem(at: directory) }

        try HarbethContext.shared.configurePipelineBinaryArchive(.persistent(at: url))
        _ = try HarbethIO(element: try makeTexture(), filters: [C7Contrast(contrast: 1.1)]).output()
        try HarbethContext.shared.serializePipelineBinaryArchive()

        let serialized = HarbethContext.shared.pipelineBinaryArchiveSnapshot
        XCTAssertEqual(serialized.serializationCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertGreaterThan((try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0, 0)

        try HarbethContext.shared.configurePipelineBinaryArchive(.persistent(at: url))
        let reloaded = HarbethContext.shared.pipelineBinaryArchiveSnapshot
        XCTAssertTrue(reloaded.loadedFromDisk)
        XCTAssertEqual(reloaded.persistentPath, url.path)
    }

    func testInvalidPersistentConfigurationFailsWithoutChangingPipelineExecution() throws {
        try HarbethContext.shared.configurePipelineBinaryArchive(.memoryOnly)

        XCTAssertThrowsError(
            try HarbethContext.shared.configurePipelineBinaryArchive(
                PipelineBinaryArchiveConfiguration(mode: .persistent, persistentURL: URL(string: "https://example.com/archive"))
            )
        )

        XCTAssertEqual(HarbethContext.shared.pipelineBinaryArchiveSnapshot.mode, .memoryOnly)
        let output = try HarbethIO(element: try makeTexture(), filters: [C7Brightness(brightness: 0.1)]).output()
        XCTAssertEqual(output.width, 4)
        XCTAssertEqual(HarbethContext.shared.pipelineBinaryArchiveSnapshot.mode, .memoryOnly)
    }
}
