import XCTest
import MetalKit
@testable import Harbeth

final class MetalCommandEncodingTests: XCTestCase {
    func testMetalCommandContractDeclaresResourcesAndOutput() {
        let descriptor = FallbackOnlyMetalCommandFilter().kernelDescriptor(inputSize: C7Size(width: 4, height: 4))

        XCTAssertEqual(descriptor.functionIdentity.kind, .metalCommand)
        XCTAssertEqual(descriptor.functionIdentity.primaryName, "fallback-only")
        XCTAssertTrue(descriptor.resources.requiresDestinationTexture)
        XCTAssertEqual(descriptor.parameters["destinationTextureAliasingPolicy"], .string("requiredDistinct"))
        XCTAssertEqual(descriptor.parameters["metalCommandRequiredCapabilities"], .stringArray([]))
    }

    func testOrdinaryComputeDeclaresDestinationWithoutMetalCommandProtocol() throws {
        let input = try makeSolidTexture(red: 40, green: 80, blue: 120, alpha: 255)
        let filter = DeclaredDestinationComputeFilter()
        let descriptor = filter.kernelDescriptor(inputSize: C7Size(width: input.width, height: input.height))

        XCTAssertEqual(descriptor.functionIdentity.kind, .compute)
        XCTAssertEqual(descriptor.output.pixelFormat, String(describing: MTLPixelFormat.rgba8Unorm))
        XCTAssertEqual(descriptor.parameters["destinationTextureStorageMode"], .int(Int(MTLStorageMode.shared.rawValue)))
        XCTAssertFalse(filter is any C7MetalCommandEncodingProtocol)

        let output = try HarbethIO(element: input, filter: filter).renderTexture(profile: .stablePreview)
        XCTAssertEqual(output.pixelFormat, .rgba8Unorm)
        XCTAssertEqual(output.storageMode, .shared)
    }

    func testCLAHEUsesMetalCommandRouteForItsBufferResourceGraph() {
        let filter = C7CLAHE()
        let descriptor = filter.kernelDescriptor(inputSize: C7Size(width: 4, height: 4))

        XCTAssertEqual(filter.modifier, .metalCommand(label: "C7CLAHE"))
        XCTAssertEqual(descriptor.functionIdentity.kind, .metalCommand)
        XCTAssertNil(descriptor.parameters["metalCommandEncoderKinds"])
    }

    func testMetalCommandFallbackRouteIsLoggedAtExecution() throws {
        let (commandBuffer, output, input) = try makeTexturePair()
        let events = LogEventBox()
        let previousLevel = HarbethLogger.minimumLevel
        let previousHandler = HarbethLogger.handler
        HarbethLogger.minimumLevel = .info
        HarbethLogger.handler = { event in events.append(event) }
        defer {
            HarbethLogger.minimumLevel = previousLevel
            HarbethLogger.handler = previousHandler
        }

        let filter = FallbackOnlyMetalCommandFilter()
        let result = try filter.encodeMetalCommands(commandBuffer: commandBuffer, textures: [output, input])

        XCTAssertTrue(result === output)
        XCTAssertTrue(events.values.contains(where: {
            $0.code == "harbeth.metal_command.route"
                && $0.outcome == .fallback
                && $0.metadata["route"] == "fallback"
        }))
    }

    func testMetalCommandModifierRoutesThroughApply() throws {
        let (commandBuffer, output, input) = try makeTexturePair()

        let filter = FallbackOnlyMetalCommandFilter()
        let result = try filter.apply(form: input, to: output, for: commandBuffer, complete: nil)

        XCTAssertTrue(result === output)
    }

    func testExplicitDestinationOrOutputContractDisablesDoubleBuffering() throws {
        let input = try makeSolidTexture(red: 10, green: 20, blue: 30, alpha: 255)
        let destinationContractFilters: [C7FilterProtocol] = [
            ExplicitDestinationContractFilter(),
            C7Brightness(brightness: 0.1)
        ]
        let outputContractFilters: [C7FilterProtocol] = [
            ExplicitOutputContractFilter(),
            C7Brightness(brightness: 0.1)
        ]

        let destinationProgram = RenderExecutionCompiler.compile(
            filters: destinationContractFilters,
            inputSize: C7Size(texture: input)
        )
        let outputProgram = RenderExecutionCompiler.compile(
            filters: outputContractFilters,
            inputSize: C7Size(texture: input)
        )
        let destinationIO = HarbethIO(element: input, filters: destinationContractFilters)
        let outputIO = HarbethIO(element: input, filters: outputContractFilters)

        XCTAssertFalse(destinationIO.shouldUseDoubleBuffer(input: input, program: destinationProgram, minimumFilterCount: 1))
        XCTAssertFalse(outputIO.shouldUseDoubleBuffer(input: input, program: outputProgram, minimumFilterCount: 1))
    }

    func testInteractiveLatencyHonorsRequiredDistinctDestinationContract() throws {
        let input = try makeSolidTexture(red: 10, green: 20, blue: 30, alpha: 255)

        let frame = try ImageNode
            .texture(input)
            .applying(C7Brightness(brightness: 0.1))
            .makeFrame(profile: .interactiveLatency)

        XCTAssertFalse(frame.texture === input)
    }

    func testExecutionContractVariantsUseDistinctRenderPlans() throws {
        let input = try makeSolidTexture(red: 10, green: 20, blue: 30, alpha: 255)
        let firstIO = HarbethIO(element: input, filter: PlanVariantComputeFilter(enabled: false))
        let secondIO = HarbethIO(element: input, filter: PlanVariantComputeFilter(enabled: true))

        let first = firstIO.makeRenderProgram(input: input)
        let second = secondIO.makeRenderProgram(input: input)
        let repeatedSecond = secondIO.makeRenderProgram(input: input)

        XCTAssertNotEqual(first.sourceFilterFingerprint, second.sourceFilterFingerprint)
        XCTAssertFalse(second.reusedCachedPlan)
        XCTAssertTrue(repeatedSecond.reusedCachedPlan)
    }

    func testNonterminalOutputContractSurvivesPreservingFilter() {
        let filters: [C7FilterProtocol] = [
            ExplicitOutputContractFilter(),
            C7Brightness(brightness: 0.1)
        ]

        let plan = GraphCompiler.compile(
            filters: filters,
            inputSize: C7Size(width: 4, height: 4)
        )

        XCTAssertEqual(plan.diagnostics.outputContract.alpha, .premultiplied)
        XCTAssertEqual(plan.diagnostics.outputContract.pixelFormat, .rgba16Float)
    }

    func testMetalCommandDistinctDestinationPolicyRejectsAliasing() throws {
        let (commandBuffer, _, input) = try makeTexturePair()

        XCTAssertThrowsError(
            try FallbackOnlyMetalCommandFilter().encodeMetalCommands(
                commandBuffer: commandBuffer,
                textures: [input, input]
            )
        ) { error in
            guard case HarbethError.configurationInvalid = error else {
                return XCTFail("Expected configurationInvalid, got \(error).")
            }
        }
    }

    func testProgrammableBlendDescriptorCarriesLibrarySourceAndFunctionConstants() {
        let constants = [
            KernelFunctionConstantDescriptor(name: "harbeth::usesWideMix", index: 0, value: .bool(true)),
            KernelFunctionConstantDescriptor(name: "harbeth::blendVariant", index: 1, value: .int(2))
        ]
        let filter = C7ProgrammableBlend(
            functionName: "C7BlendColorAdd",
            blendTexture: nil,
            intensity: 0.4,
            librarySource: .sourceFallback("programmable-blend-test"),
            functionConstants: constants
        )
        let descriptor = filter.kernelDescriptor(inputSize: C7Size(width: 4, height: 4))

        XCTAssertEqual(descriptor.functionIdentity.kind, .compute)
        XCTAssertEqual(descriptor.functionIdentity.primaryName, "C7BlendColorAdd")
        XCTAssertEqual(descriptor.functionIdentity.librarySource, .sourceFallback("programmable-blend-test"))
        XCTAssertEqual(descriptor.functionIdentity.functionConstants, constants)
        XCTAssertTrue(descriptor.fingerprint.contains("library=sourceFallback:programmable-blend-test"))
        XCTAssertTrue(descriptor.fingerprint.contains("constant=harbeth::blendVariant"))
        XCTAssertTrue(descriptor.arguments.contains(where: { argument in
            argument.name == "harbeth::usesWideMix"
                && argument.role == .functionConstant
                && argument.dataType == .bool
        }))
    }

    func testUnsupportedStringFunctionConstantFailsBeforeFunctionResolution() {
        let identity = KernelFunctionIdentity(
            kind: .compute,
            primaryName: "C7BlendColorAdd",
            functionConstants: [
                KernelFunctionConstantDescriptor(name: "unsupported", value: .string("metadata-only"))
            ]
        )

        XCTAssertThrowsError(try Device.readMTLFunction(identity)) { error in
            guard case HarbethError.configurationInvalid = error else {
                return XCTFail("Expected configurationInvalid, got \(error).")
            }
        }
    }

    func testProgrammableBlendMatchesBuiltInSourceOverBlend() throws {
        let input = try makeSolidTexture(red: 40, green: 80, blue: 120, alpha: 255)
        let overlay = try makeSolidTexture(red: 220, green: 30, blue: 10, alpha: 128)

        let expected = try HarbethIO(
            element: input,
            filter: C7Blend(with: .sourceOver, blendTexture: overlay, intensity: 1.0)
        ).output()
        let programmable = try HarbethIO(
            element: input,
            filter: C7ProgrammableBlend(
                functionName: "C7BlendSourceOver",
                blendTexture: overlay,
                intensity: 1.0,
                librarySource: .sourceFallback("programmable-source-over")
            )
        ).output()

        XCTAssertEqual(try firstPixel(in: programmable), try firstPixel(in: expected))
    }

    func testProgrammableBlendSupportsCustomSamplingCoordinatesViaFunctionConstants() throws {
        let input = try makeSolidTexture(red: 10, green: 20, blue: 30, alpha: 255)
        let overlay = try makeHorizontalTexture(
            left: [0, 0, 0, 255],
            right: [255, 0, 0, 255]
        )

        let leftSample = try HarbethIO(
            element: input,
            filter: C7ProgrammableBlend(
                functionName: "C7ProgrammableBlendCoordinateProbe",
                blendTexture: overlay,
                intensity: 1.0,
                librarySource: .sourceFallback("programmable-coordinate-probe"),
                functionConstants: [
                    KernelFunctionConstantDescriptor(name: "useRightSample", index: 0, value: .bool(false))
                ]
            )
        ).output()
        let rightSample = try HarbethIO(
            element: input,
            filter: C7ProgrammableBlend(
                functionName: "C7ProgrammableBlendCoordinateProbe",
                blendTexture: overlay,
                intensity: 1.0,
                librarySource: .sourceFallback("programmable-coordinate-probe"),
                functionConstants: [
                    KernelFunctionConstantDescriptor(name: "useRightSample", index: 0, value: .bool(true))
                ]
            )
        ).output()

        XCTAssertEqual(try firstPixel(in: leftSample), [0, 0, 0, 255])
        XCTAssertEqual(try firstPixel(in: rightSample), [255, 0, 0, 255])
    }

    private func makeTexturePair() throws -> (MTLCommandBuffer, MTLTexture, MTLTexture) {
        let device = HarbethContext.shared.device
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw XCTSkip("Metal device is not available.")
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let output = device.makeTexture(descriptor: descriptor),
              let input = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create test textures.")
            throw HarbethError.filterParameterInvalid("Failed to create test textures.")
        }

        return (commandBuffer, output, input)
    }

    private func makeSolidTexture(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 2,
            height: 2,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create solid texture.")
            throw HarbethError.textureLoader
        }

        let bytes = Array(repeating: [red, green, blue, alpha], count: 4).flatMap { $0 }
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 2),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 8
        )
        return texture
    }

    private func makeHorizontalTexture(left: [UInt8], right: [UInt8]) throws -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        guard left.count == 4, right.count == 4 else {
            throw HarbethError.filterParameterInvalid("Expected RGBA pixels.")
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 2,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            XCTFail("Failed to create horizontal texture.")
            throw HarbethError.textureLoader
        }

        let bytes = left + right
        texture.replace(
            region: MTLRegionMake2D(0, 0, 2, 1),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: 8
        )
        return texture
    }

    private func firstPixel(in texture: MTLTexture) throws -> [UInt8] {
        guard let bytes = texture.c7.bytes(), bytes.count >= 4 else {
            XCTFail("Expected readable RGBA bytes.")
            throw HarbethError.texture2Image
        }
        return Array(bytes[0..<4])
    }
}

private struct FallbackOnlyMetalCommandFilter: C7MetalCommandEncodingProtocol {
    var modifier: ModifierEnum {
        .metalCommand(label: "fallback-only")
    }

    var destinationTextureContract: FilterDestinationTextureContract {
        FilterDestinationTextureContract(aliasingPolicy: .requiredDistinct)
    }

    func metalCommandExecutionRoute(
        in environment: MetalCommandEnvironment
    ) -> MetalCommandExecutionRoute {
        .fallback
    }

    func encodeMetalCommands(
        context: MetalCommandEncodingContext,
        route: MetalCommandExecutionRoute
    ) throws -> MTLTexture {
        context.destinationTexture
    }
}

private struct DeclaredDestinationComputeFilter: C7FilterProtocol {
    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
    var factors: [Float] { [0] }

    var destinationTextureContract: FilterDestinationTextureContract {
        FilterDestinationTextureContract(storageMode: .shared)
    }

    var kernelOutputContract: RenderOutputContract {
        RenderOutputContract(pixelFormat: .rgba8Unorm)
    }
}

private struct ExplicitDestinationContractFilter: C7FilterProtocol {
    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
    var factors: [Float] { [0.1] }
    var destinationTextureContract: FilterDestinationTextureContract {
        FilterDestinationTextureContract(storageMode: .private)
    }
}

private struct ExplicitOutputContractFilter: C7FilterProtocol {
    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
    var factors: [Float] { [0.1] }
    var kernelOutputContract: RenderOutputContract {
        RenderOutputContract(alpha: .premultiplied, pixelFormat: .rgba16Float)
    }
}

private struct PlanVariantComputeFilter: C7FilterProtocol {
    let enabled: Bool

    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
    var factors: [Float] { [0.1] }
    var computeKernelFunctionConstants: [KernelFunctionConstantDescriptor] {
        [
            KernelFunctionConstantDescriptor(
                name: "harbeth::planVariant",
                index: 0,
                value: .bool(enabled)
            )
        ]
    }
}

private final class LogEventBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [HarbethLogEvent] = []

    var values: [HarbethLogEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ event: HarbethLogEvent) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }
}
