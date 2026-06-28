import XCTest
import Metal
@testable import Harbeth

/// Regression gate for the eager-source-fallback fix in `Device.readMTLFunction(identity)`.
///
/// Contract: identity-based function resolution must try the precompiled / registered libraries
/// FIRST, and only walk the app bundle for `.metal` sources as a genuine last resort. The original
/// bug built that bundle scan eagerly while assembling the candidate list — a recursive walk that
/// measured ~0.9–3s per kernel on device — even when the kernel was already in a library. Across a
/// filter chain that summed to the ~9s first-frame main-thread hang.
///
/// This test registers a library containing a known kernel and asserts that resolving that kernel
/// does NOT advance `Device.sourceFallbackScanCount`. If a future refactor makes the fallback eager
/// again (e.g. by collecting all candidate libraries up front), the counter moves and this fails.
final class SourceFallbackGateTests: XCTestCase {

    func testKernelResolvableFromLibraryDoesNotTriggerSourceFallbackScan() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        // Unique name so no earlier lookup in this process has cached the function or its miss.
        let kernelName = "harbeth_gate_kernel_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        let provider = SourceKernelLibraryProvider(kernelName: kernelName)
        XCTAssertTrue(
            Device.registerExternalLibraryProvider(provider),
            "Provider should register; its identifier is unique per kernel."
        )

        let scansBefore = Device.sourceFallbackScanCount
        // `.render` kind is arbitrary here: resolution keys off primaryName + librarySource(.automatic);
        // the only kind that is rejected outright is `.blit`.
        let identity = KernelFunctionIdentity(kind: .render, primaryName: kernelName)
        let function = try Device.readMTLFunction(identity)
        let scansAfter = Device.sourceFallbackScanCount

        XCTAssertEqual(function.name, kernelName)
        XCTAssertEqual(
            scansAfter, scansBefore,
            "A kernel resolvable from a registered library must NOT trigger the source-fallback bundle scan — the fallback regressed to eager."
        )
    }
}

/// Provides a freshly compiled library containing a single trivial kernel, so the gate test does
/// not depend on which shaders the test bundle happened to package.
private final class SourceKernelLibraryProvider: ExternalMTLLibraryProvider {
    let providerIdentifier: String
    private let kernelName: String

    init(kernelName: String) {
        self.kernelName = kernelName
        self.providerIdentifier = "harbeth.gate.provider.\(kernelName)"
    }

    func provideLibrary(for device: MTLDevice) -> MTLLibrary? {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        kernel void \(kernelName)(texture2d<half, access::write> outTexture [[texture(0)]],
                                  uint2 gid [[thread_position_in_grid]]) {
            outTexture.write(half4(1.0h), gid);
        }
        """
        return try? device.makeLibrary(source: source, options: nil)
    }
}
