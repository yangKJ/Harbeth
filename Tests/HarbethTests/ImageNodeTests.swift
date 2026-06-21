import XCTest
import Metal
import CoreVideo
@testable import Harbeth

final class ImageNodeTests: XCTestCase {

    func testNodeFilterPathMatchesDirectFilterPath() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [120, 20, 10, 255])
        let filters: [C7FilterProtocol] = [C7Resize(width: 2, height: 2)]
        let node = ImageNode.filters(input: .source(.texture(input)), filters: filters)

        let nodeOutput = try HarbethIO(element: input, filters: []).renderTexture(node: node)
        let directOutput: MTLTexture = try HarbethIO(element: input, filters: filters).output()
        let diagnostics = try HarbethIO(element: input, filters: []).renderDiagnostics(node: node)

        XCTAssertEqual(nodeOutput.width, directOutput.width)
        XCTAssertEqual(nodeOutput.height, directOutput.height)
        XCTAssertEqual(diagnostics.compilationSource, .nodeGraph)
        XCTAssertEqual(diagnostics.optimizationPlan.intermediateTextureCount, 0)
        XCTAssertTrue(diagnostics.summary.contains("source=nodeGraph"))
    }

    func testNodeCachePolicyIsVisibleInDiagnostics() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [10, 20, 30, 255])
        let sourceDiagnostics = try ImageNode.source(.texture(input)).makeDiagnostics()
        let persistentNode = ImageNode
            .filters(input: .source(.texture(input)), filters: [C7Brightness(brightness: 0.1)])
            .withCachePolicy(.persistent)
        let persistentDiagnostics = try persistentNode.makeDiagnostics()

        XCTAssertEqual(sourceDiagnostics.imageCachePolicy, .persistent)
        XCTAssertEqual(persistentDiagnostics.imageCachePolicy, .persistent)
        XCTAssertTrue(persistentDiagnostics.optimizationPlan.decisions.contains("preservePersistentImageNode"))
        XCTAssertTrue(persistentDiagnostics.summary.contains("cachePolicy=persistent"))
    }

    func testNodeSamplerDescriptorIsVisibleInDiagnostics() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [10, 20, 30, 255])
        let node = ImageNode
            .source(.texture(input))
            .withSamplerDescriptor(.nearest)
        let diagnostics = try node.makeDiagnostics()

        XCTAssertEqual(diagnostics.samplerDescriptor, .nearest)
        XCTAssertTrue(diagnostics.summary.contains("sampler=\(ImageSamplerDescriptor.nearest.fingerprint)"))
    }

    func testNodeWrappedPlanPreservesSourceConversionDiagnostics() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                4,
                4,
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create bi-planar pixel buffer.")
            return
        }

        let node = ImageNode
            .source(.pixelBuffer(pixelBuffer))
            .applying(C7Brightness(brightness: 0.1))
            .withCachePolicy(.persistent)
            .withSamplerDescriptor(.nearest)

        let diagnostics = try node.makeDiagnostics()

        XCTAssertEqual(diagnostics.sourceKind, "pixelBuffer")
        XCTAssertEqual(diagnostics.inputColorConversionCount, 1)
        XCTAssertEqual(diagnostics.inputPixelFormatConversionCount, 1)
        XCTAssertEqual(diagnostics.imageCachePolicy, .persistent)
        XCTAssertEqual(diagnostics.samplerDescriptor, .nearest)
        XCTAssertTrue(diagnostics.summary.contains("origin=pixelBuffer"))
        XCTAssertEqual(diagnostics.inputColorSpace.name, "preserveInput")
        XCTAssertEqual(diagnostics.inputPixelFormat.name, "r8Unorm")
    }

    func testPersistentNodeResolutionReusesCachedTexture() throws {
        let context = Shared.shared.defaultContext
        context.resetCaches()
        let input = try makeTexture(width: 2, height: 2, pixel: [10, 20, 30, 255])
        let node = ImageNode
            .filters(input: .source(.texture(input)), filters: [C7Brightness(brightness: 0.1)])
            .withCachePolicy(.persistent)

        let first = try node.makeTexture()
        let second = try node.makeTexture()
        let snapshot = context.debugCacheSnapshot()

        XCTAssertTrue(first === second)
        XCTAssertGreaterThanOrEqual(snapshot.imageResolutionCount, 1)
        XCTAssertTrue(node.resolutionFingerprint().contains("cache=persistent"))

        context.resetCaches()
        XCTAssertEqual(context.debugCacheSnapshot().imageResolutionCount, 0)
    }

    func testKernelDescriptorExposesStableFunctionAndContract() throws {
        let filter = C7Brightness(brightness: 0.2)
        let descriptor = filter.kernelDescriptor(inputSize: C7Size(width: 8, height: 6))

        XCTAssertEqual(descriptor.functionIdentity.kind, .compute)
        XCTAssertEqual(descriptor.functionIdentity.primaryName, "C7Brightness")
        XCTAssertEqual(descriptor.output.outputSize, C7Size(width: 8, height: 6))
        XCTAssertEqual(descriptor.resourceUsage, .singleInput)
        XCTAssertEqual(descriptor.resources.inputTextureCount, 1)
        XCTAssertEqual(descriptor.resources.memoryAccessPattern, "point")
        XCTAssertEqual(descriptor.alphaBehavior, .preserveInput)
        XCTAssertEqual(descriptor.outputContract.alpha, .preserveInput)
        XCTAssertTrue(descriptor.arguments.contains(where: { $0.name == "factors" && $0.dataType == .floatArray }))
        XCTAssertTrue(descriptor.arguments.contains(where: { $0.name == "memoryAccessPattern" && $0.role == .executionHint }))
        XCTAssertEqual(descriptor.passes.count, 1)
        XCTAssertEqual(descriptor.passes[0].functionIdentity.primaryName, "C7Brightness")
        XCTAssertTrue(descriptor.fingerprint.contains("filter=C7Brightness"))
        XCTAssertTrue(descriptor.fingerprint.contains("arguments=arg="))
        XCTAssertTrue(descriptor.fingerprint.contains("inputColor=color=preserveInput"))
        XCTAssertTrue(descriptor.fingerprint.contains("passes=pass=0"))
    }

    func testKernelDescriptorArgumentMetadataIsDeterministic() {
        let descriptor = C7Opacity(opacity: 0.4).kernelDescriptor(inputSize: C7Size(width: 2, height: 2))
        let names = descriptor.arguments.map(\.name)
        let sortedNames = names.sorted()

        XCTAssertEqual(names, sortedNames)
        XCTAssertEqual(descriptor.arguments.first?.index, 0)
        XCTAssertTrue(descriptor.arguments.contains(where: { argument in
            argument.name == "factors"
                && argument.role == .parameter
                && argument.dataType == .floatArray
                && argument.valueFingerprint == "floats:0.4000"
        }))
        XCTAssertTrue(descriptor.arguments.contains(where: { argument in
            argument.name == "otherInputTextures"
                && argument.role == .inputTexture
                && argument.dataType == .int
                && argument.required == false
        }))
    }

    func testKernelDescriptorFunctionConstantsAreSpecializationContracts() {
        let constants = [
            KernelFunctionConstantDescriptor(
                name: "harbeth::outputsPremultipliedAlpha",
                index: 3,
                value: .bool(true)
            ),
            KernelFunctionConstantDescriptor(
                name: "harbeth::blendMode",
                index: 1,
                value: .int(8)
            )
        ]
        let reversedConstants = Array(constants.reversed())
        let firstIdentity = KernelFunctionIdentity(
            kind: .render,
            primaryName: "C7VertexPassthrough",
            secondaryName: "C7LayerComposite",
            functionConstants: constants
        )
        let secondIdentity = KernelFunctionIdentity(
            kind: .render,
            primaryName: "C7VertexPassthrough",
            secondaryName: "C7LayerComposite",
            functionConstants: reversedConstants
        )
        let descriptor = KernelDescriptor(
            filterName: "C7LayerComposite",
            functionIdentity: firstIdentity,
            parameters: ["opacity": .float(0.5)],
            resourceUsage: .multiInput
        )

        XCTAssertEqual(firstIdentity.fingerprint, secondIdentity.fingerprint)
        XCTAssertEqual(descriptor.functionIdentity.functionConstants.count, 2)
        XCTAssertEqual(descriptor.passes[0].functionIdentity.functionConstants.count, 2)
        XCTAssertTrue(descriptor.fingerprint.contains("constants=constant=harbeth::blendMode"))
        XCTAssertTrue(descriptor.arguments.contains(where: { argument in
            argument.name == "harbeth::blendMode"
                && argument.role == .functionConstant
                && argument.dataType == .int
                && argument.valueFingerprint == "int:8"
        }))
        XCTAssertTrue(descriptor.arguments.contains(where: { argument in
            argument.name == "harbeth::outputsPremultipliedAlpha"
                && argument.role == .functionConstant
                && argument.dataType == .bool
                && argument.valueFingerprint == "bool:1"
        }))
    }

    func testKernelFunctionIdentityIncludesLibrarySource() {
        let defaultIdentity = KernelFunctionIdentity(
            kind: .compute,
            primaryName: "customKernel",
            librarySource: .defaultLibrary
        )
        let externalIdentity = KernelFunctionIdentity(
            kind: .compute,
            primaryName: "customKernel",
            librarySource: .externalProvider("tests.external.library")
        )
        let metallibIdentity = KernelFunctionIdentity(
            kind: .compute,
            primaryName: "customKernel",
            librarySource: .metallibURL("file:///tmp/custom.metallib"),
            functionConstants: [
                KernelFunctionConstantDescriptor(
                    name: "harbeth::usesLinearSampling",
                    value: .bool(true)
                )
            ]
        )
        let descriptor = KernelDescriptor(
            filterName: "customKernel",
            functionIdentity: metallibIdentity
        )

        XCTAssertNotEqual(defaultIdentity.fingerprint, externalIdentity.fingerprint)
        XCTAssertTrue(defaultIdentity.fingerprint.contains("library=default"))
        XCTAssertTrue(externalIdentity.fingerprint.contains("library=externalProvider:tests.external.library"))
        XCTAssertTrue(metallibIdentity.fingerprint.contains("library=metallibURL:file:///tmp/custom.metallib"))
        XCTAssertEqual(descriptor.functionIdentity.librarySource, .metallibURL("file:///tmp/custom.metallib"))
        XCTAssertTrue(descriptor.fingerprint.contains("library=metallibURL:file:///tmp/custom.metallib"))
        XCTAssertTrue(descriptor.passes[0].fingerprint.contains("library=metallibURL:file:///tmp/custom.metallib"))
    }

    func testKernelFunctionIdentityBuildsMetalFunctionConstantValues() {
        let identity = KernelFunctionIdentity(
            kind: .compute,
            primaryName: "customKernel",
            functionConstants: [
                KernelFunctionConstantDescriptor(
                    name: "harbeth::flag",
                    value: .bool(true)
                ),
                KernelFunctionConstantDescriptor(
                    name: "harbeth::mode",
                    index: 1,
                    value: .int(2)
                ),
                KernelFunctionConstantDescriptor(
                    name: "harbeth::amount",
                    index: 2,
                    value: .float(0.75)
                )
            ]
        )
        let metadataOnlyIdentity = KernelFunctionIdentity(
            kind: .compute,
            primaryName: "customKernel",
            functionConstants: [
                KernelFunctionConstantDescriptor(
                    name: "harbeth::debugLabel",
                    value: .string("metadata-only")
                )
            ]
        )

        XCTAssertNotNil(identity.makeMetalFunctionConstantValues())
        XCTAssertNil(metadataOnlyIdentity.makeMetalFunctionConstantValues())
    }

    func testKernelDescriptorTracksAlphaAndResourceContracts() {
        let premultiply = C7PremultiplyAlpha().kernelDescriptor(inputSize: C7Size(width: 2, height: 2))
        let unpremultiply = C7UnpremultiplyAlpha().kernelDescriptor(inputSize: C7Size(width: 2, height: 2))
        let opacity = C7Opacity(opacity: 0.4).kernelDescriptor(inputSize: C7Size(width: 2, height: 2))

        XCTAssertEqual(premultiply.alphaBehavior, .outputsPremultiplied)
        XCTAssertEqual(premultiply.outputContract.alpha, .premultiplied)
        XCTAssertEqual(unpremultiply.alphaBehavior, .outputsNonPremultiplied)
        XCTAssertEqual(unpremultiply.outputContract.alpha, .nonPremultiplied)
        XCTAssertEqual(opacity.alphaBehavior, .modifiesAlpha)
        XCTAssertEqual(opacity.parameters["factors"]?.fingerprint, "floats:0.4000")
        XCTAssertTrue(opacity.fingerprint.contains("memory=auto"))
        XCTAssertNil(opacity.passes.first?.renderPass)
    }

    func testKernelDescriptorCanBuildCompatibleInvocation() {
        let filter = C7Brightness(brightness: 0.2)
        let descriptor = filter.kernelDescriptor(inputSize: C7Size(width: 4, height: 4))
        let invocation = descriptor.makeInvocation(filter: filter, inputSize: C7Size(width: 4, height: 4))

        XCTAssertTrue(invocation.isCompatible)
        XCTAssertEqual(invocation.compatibilitySummary, "compatible")
        XCTAssertTrue(invocation.fingerprint.contains("filter=C7Brightness"))
        XCTAssertTrue(descriptor.matches(filter, inputSize: C7Size(width: 4, height: 4)))
    }

    func testKernelDescriptorDetectsIncompatibleInvocation() {
        let descriptor = C7Brightness(brightness: 0.2).kernelDescriptor(inputSize: C7Size(width: 4, height: 4))
        let incompatibleFilter = C7Contrast(contrast: 1.1)
        let invocation = descriptor.makeInvocation(filter: incompatibleFilter, inputSize: C7Size(width: 4, height: 4))

        XCTAssertFalse(invocation.isCompatible)
        XCTAssertEqual(invocation.compatibilitySummary, "functionIdentityMismatch")
        XCTAssertFalse(descriptor.matches(incompatibleFilter, inputSize: C7Size(width: 4, height: 4)))
    }

    func testKernelNodeFailsFastWhenDescriptorDoesNotMatchFilterDuringTextureExecution() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [120, 80, 40, 255])
        let descriptor = C7Brightness(brightness: 0.2).kernelDescriptor(inputSize: C7Size(width: 2, height: 2))
        let incompatibleFilter = C7Contrast(contrast: 1.1)
        let node = ImageNode.kernel(input: .source(.texture(input)), descriptor: descriptor, filter: incompatibleFilter)

        XCTAssertThrowsError(try node.makeTexture()) { error in
            guard case .kernelInvocationIncompatible(let summary)? = error.asHarbethError else {
                return XCTFail("Expected kernelInvocationIncompatible, got \(error)")
            }
            XCTAssertEqual(summary, "functionIdentityMismatch")
        }
    }

    func testKernelNodeFailsFastWhenDescriptorDoesNotMatchFilterDuringPlanCompilation() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [120, 80, 40, 255])
        let descriptor = C7Brightness(brightness: 0.2).kernelDescriptor(inputSize: C7Size(width: 2, height: 2))
        let incompatibleFilter = C7Contrast(contrast: 1.1)
        let node = ImageNode.kernel(input: .source(.texture(input)), descriptor: descriptor, filter: incompatibleFilter)

        XCTAssertThrowsError(try node.makeRenderPlan()) { error in
            guard case .kernelInvocationIncompatible(let summary)? = error.asHarbethError else {
                return XCTFail("Expected kernelInvocationIncompatible, got \(error)")
            }
            XCTAssertEqual(summary, "functionIdentityMismatch")
        }
    }

    func testRenderKernelDescriptorExposesRenderPassContract() {
        let basicDescriptor = RenderBasicFilter().kernelDescriptor(inputSize: C7Size(width: 2, height: 2))
        let projectiveDescriptor = RenderTransform3D().kernelDescriptor(inputSize: C7Size(width: 2, height: 2))

        XCTAssertEqual(basicDescriptor.functionIdentity.kind, .render)
        XCTAssertEqual(basicDescriptor.passes.first?.renderPass?.sampleCount, 1)
        XCTAssertEqual(basicDescriptor.passes.first?.renderPass?.colorAttachments.count, 1)
        XCTAssertEqual(basicDescriptor.passes.first?.renderPass?.usesCustomVertexLayout, false)
        XCTAssertEqual(projectiveDescriptor.passes.first?.renderPass?.usesCustomVertexLayout, true)
        XCTAssertTrue(projectiveDescriptor.fingerprint.contains("renderPass=attachments="))
    }

    func testKernelNodeExecutesAlphaOutputContract() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [200, 100, 50, 128])
        let filter = C7Brightness(brightness: 0)
        let descriptor = KernelDescriptor(
            filterName: "identityPremultiply",
            functionIdentity: KernelFunctionIdentity(kind: .compute, primaryName: "C7Brightness"),
            outputContract: RenderOutputContract(alpha: .forcePremultiply)
        )
        let node = ImageNode.kernel(input: .source(.texture(input)), descriptor: descriptor, filter: filter)

        let output = try node.makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertLessThan(outputPixel.red, 200)
        XCTAssertLessThan(outputPixel.green, 100)
        XCTAssertEqual(outputPixel.alpha, 128)
    }

    func testConservativeOptimizationPlanRecordsResourceDecisions() {
        let contract = RenderOutputContract(
            alpha: .forcePremultiply,
            pixelFormat: PixelFormatContract(pixelFormat: .rgba8Unorm, preservesInput: false)
        )
        let plan = GraphCompiler.compile(
            filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.1)
            ],
            inputSize: C7Size(width: 4, height: 4),
            profile: .readbackQuality,
            derivative: ImageDerivativeSpec(
                name: "testDerivative",
                renderIntent: .readback,
                sourceTier: .fullResolutionReusable,
                semantic: RenderProfile.readbackQuality.defaultImageSemantic,
                outputSizePolicy: .exact(C7Size(width: 2, height: 2))
            ),
            outputContract: contract
        )

        XCTAssertEqual(plan.diagnostics.outputContract.alpha, .forcePremultiply)
        XCTAssertEqual(plan.diagnostics.alphaConversionCount, 1)
        XCTAssertEqual(plan.diagnostics.pixelFormatConversionCount, 1)
        XCTAssertGreaterThanOrEqual(plan.diagnostics.optimizationPlan.intermediateTextureCount, 2)
        XCTAssertGreaterThan(plan.diagnostics.optimizationPlan.estimatedTransientByteCount, 0)
        XCTAssertGreaterThan(plan.diagnostics.optimizationPlan.estimatedPersistentByteCount, 0)
        XCTAssertGreaterThanOrEqual(plan.diagnostics.optimizationPlan.readbackBoundaryCount, 1)
        XCTAssertEqual(plan.diagnostics.optimizationPlan.lifecycleDecisions.last?.action, .preserveForReadback)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.decisions.contains("keepDerivativeResizeAtTerminalStage"))
        XCTAssertTrue(plan.diagnostics.summary.contains("transientBytes="))
    }

    func testOptimizerExposesTransientReuseLifecyclePlan() {
        let plan = GraphCompiler.compile(
            filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.1),
                C7Saturation(saturation: 0.8)
            ],
            inputSize: C7Size(width: 4, height: 4),
            profile: .stablePreview
        )

        XCTAssertEqual(plan.diagnostics.optimizationPlan.lifecycleDecisions.count, plan.diagnostics.stageCount)
        XCTAssertTrue(plan.diagnostics.optimizationPlan.lifecycleDecisions.contains(where: { $0.action == .allocatePersistentOutput }))
        XCTAssertTrue(plan.diagnostics.summary.contains("lifecycle="))
    }

    func testLayerCompositeRendersNormalizedFrameAndDiagnostics() throws {
        let background = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 255, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1),
                    opacity: 1,
                    blendMode: .sourceOver
                )
            ]
        )
        let node = ImageNode.layerComposite(recipe)

        let output = try HarbethIO(element: background, filters: []).renderTexture(node: node)
        let diagnostics = try HarbethIO(element: background, filters: []).renderDiagnostics(node: node)

        XCTAssertEqual(output.width, 2)
        XCTAssertEqual(output.height, 2)
        XCTAssertEqual(try pixel(in: output, x: 0, y: 0).green, 255)
        XCTAssertEqual(try pixel(in: output, x: 1, y: 0).red, 255)
        XCTAssertEqual(diagnostics.compilationSource, .layerComposite)
        XCTAssertEqual(diagnostics.nodes.first?.name.contains("C7LayerComposite"), true)
        XCTAssertEqual(diagnostics.optimizationPlan.destinationTextureCreationCount, 1)
    }

    func testNodeDebugSnapshotExposesGraphAndOptimizationDecisions() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [32, 64, 96, 255])
        let node = ImageNode
            .texture(input)
            .applying(filters: [
                C7Brightness(brightness: 0.1),
                C7Contrast(contrast: 1.1)
            ])
            .withCachePolicy(.persistent)

        let snapshot = try node.makeDebugSnapshot()

        XCTAssertFalse(snapshot.nodes.isEmpty)
        XCTAssertFalse(snapshot.edges.isEmpty)
        XCTAssertFalse(snapshot.dotGraph.isEmpty)
        XCTAssertTrue(snapshot.dotGraph.contains("digraph ImageGraph"))
        XCTAssertGreaterThanOrEqual(snapshot.diagnostics.graphNodeCount, 2)
        XCTAssertTrue(snapshot.diagnostics.persistentBoundaryCount >= 1)
        XCTAssertFalse(snapshot.optimizationDecisions.isEmpty)
    }

    func testNodeDebugSnapshotExposesDirectPlaneBridgeDiagnostics() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                4,
                4,
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create bi-planar pixel buffer.")
            return
        }
        let node = ImageNode
            .pixelBuffer(pixelBuffer)
            .applying(C7Brightness(brightness: 0.1))

        let snapshot = try node.makeDebugSnapshot()

        XCTAssertEqual(snapshot.diagnostics.inputDirectPlaneBridgeCount, 2)
        XCTAssertTrue(snapshot.summary.contains("inputDirectPlanes=2"))
    }

    func testLayerCompositeFingerprintTracksExtendedLayerContracts() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    contentRegion: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.5),
                    opacity: 0.8,
                    blendMode: .softLight,
                    flipOptions: LayerFlipOptions(horizontal: true),
                    rotation: 90,
                    tintColor: SIMD4<Float>(1, 0.5, 0.25, 0.75),
                    cornerCurve: .continuous,
                    rasterSampleCount: 2
                )
            ]
        )

        XCTAssertTrue(recipe.fingerprint.contains("contentRegion="))
        XCTAssertTrue(recipe.fingerprint.contains("layout=normalized"))
        XCTAssertTrue(recipe.fingerprint.contains("flip=h=1|v=0"))
        XCTAssertTrue(recipe.fingerprint.contains("rotation=90.0000"))
        XCTAssertTrue(recipe.fingerprint.contains("cornerCurve=continuous"))
        XCTAssertTrue(recipe.fingerprint.contains("samples=2"))
        XCTAssertTrue(recipe.fingerprint.contains("blend=12"))
    }

    func testNodeRenderPlanAndRenderRecipeExposeStableContracts() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [80, 40, 20, 255])
        let node = ImageNode
            .texture(input)
            .applying(C7Brightness(brightness: 0.1))
            .withCachePolicy(.persistent)
            .withSamplerDescriptor(.nearest)

        let plan = try node.makeRenderPlan(
            profile: .responseLatency,
            derivative: ImageDerivativeSpec(
                name: "nodeThumb",
                renderIntent: .responsive,
                sourceTier: .stableReusable,
                semantic: RenderProfile.responseLatency.defaultImageSemantic,
                outputSizePolicy: .maxPixelSize(2)
            )
        )
        let recipe = try node.makeRenderRecipe(
            profile: .responseLatency,
            derivative: ImageDerivativeSpec(
                name: "nodeThumb",
                renderIntent: .responsive,
                sourceTier: .stableReusable,
                semantic: RenderProfile.responseLatency.defaultImageSemantic,
                outputSizePolicy: .maxPixelSize(2)
            )
        )

        XCTAssertEqual(plan.diagnostics.compilationSource, .nodeGraph)
        XCTAssertEqual(plan.diagnostics.imageCachePolicy, .persistent)
        XCTAssertEqual(plan.diagnostics.samplerDescriptor, .nearest)
        XCTAssertEqual(plan.diagnostics.derivative.name, "nodeThumb")
        XCTAssertFalse(plan.diagnostics.graphFingerprint.isEmpty)
        XCTAssertTrue(plan.diagnostics.summary.contains("graph="))
        XCTAssertEqual(recipe.outputDerivative.name, "nodeThumb")
        XCTAssertEqual(recipe.outputCachePolicy, .persistent)
        XCTAssertEqual(recipe.source.kind, "texture")
        XCTAssertEqual(recipe.filters.count, 1)
        XCTAssertTrue(recipe.filters.first?.stableTypeID.contains("C7Brightness") == true)
    }

    func testNodeRenderRequestCarriesDeferredExecutionContract() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [40, 80, 120, 255])
        let node = ImageNode
            .texture(input)
            .applying(C7Brightness(brightness: 0.1))

        let request = try node.makeRenderRequest(profile: .stablePreview)
        let texture = try request.renderTexture()
        let frame = try request.renderFrame(metadata: ["node": "request"])

        XCTAssertEqual(request.compilationSource, .nodeGraph)
        XCTAssertEqual(request.profile, .stablePreview)
        XCTAssertEqual(request.source.kind, "texture")
        XCTAssertEqual(request.renderRecipe?.renderIntent, .stable)
        XCTAssertEqual(texture.width, 2)
        XCTAssertEqual(frame.metadata["node"], "request")
        XCTAssertEqual(frame.profile, .stablePreview)
    }

    func testLayerCompositeSupportsDifferenceBlendAndClampsFrame() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [255, 0, 0, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 255, 0, 255])
        let imageLayer = ImageLayer(
            content: .texture(layer),
            normalizedFrame: CGRect(x: -0.25, y: -0.25, width: 2, height: 2),
            opacity: 1,
            blendMode: .difference
        )
        let recipe = LayerCompositeRecipe(background: .texture(background), layers: [imageLayer])

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(imageLayer.normalizedFrame, CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertEqual(outputPixel.red, 255)
        XCTAssertEqual(outputPixel.green, 255)
        XCTAssertEqual(outputPixel.blue, 0)
        XCTAssertTrue(recipe.fingerprint.contains("blend=8"))
    }

    func testLayerCompositeExecutesLayerLocalTransform() throws {
        let background = try makeTexture(width: 2, height: 1, pixel: [255, 0, 0, 255])
        let layer = try makeTexture(
            width: 2,
            height: 1,
            pixels: [
                [0, 255, 0, 255],
                [0, 0, 255, 255]
            ]
        )
        let transformedLayer = ImageLayer(
            content: .texture(layer),
            normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 1),
            transform: ImageTransformRecipe(
                mirrorsHorizontally: true
            )
        )
        let recipe = LayerCompositeRecipe(background: .texture(background), layers: [transformedLayer])

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertLessThan(outputPixel.green, 64)
        XCTAssertGreaterThan(outputPixel.blue, 180)
        XCTAssertTrue(recipe.fingerprint.contains("transform=crop=none"))
        XCTAssertTrue(recipe.fingerprint.contains("mirror=1"))
    }

    func testLayerCompositeFingerprintTracksLayerTransformAndFilterParameters() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let identityLayer = ImageLayer(content: .texture(layer))
        let transformedLayer = ImageLayer(
            content: .texture(layer),
            transform: ImageTransformRecipe(rotationDegrees: 90)
        )
        let filteredLayer = ImageLayer(
            content: .texture(layer),
            filters: [C7Brightness(brightness: 0.2)]
        )

        let identityRecipe = LayerCompositeRecipe(background: .texture(background), layers: [identityLayer])
        let transformedRecipe = LayerCompositeRecipe(background: .texture(background), layers: [transformedLayer])
        let filteredRecipe = LayerCompositeRecipe(background: .texture(background), layers: [filteredLayer])

        XCTAssertNotEqual(identityRecipe.fingerprint, transformedRecipe.fingerprint)
        XCTAssertNotEqual(identityRecipe.fingerprint, filteredRecipe.fingerprint)
        XCTAssertTrue(transformedRecipe.fingerprint.contains("rotation=90.000000"))
        XCTAssertTrue(filteredRecipe.fingerprint.contains("C7Brightness"))
    }

    func testNodeRecipeAndTransitionDiagnosticsKeepOriginalSources() throws {
        let from = try makeTexture(width: 2, height: 2, pixel: [255, 0, 0, 255])
        let to = try makeTexture(width: 2, height: 2, pixel: [0, 0, 255, 255])
        let recipeNode = ImageNode.recipe(
            source: .texture(from),
            recipe: EditRecipe(filters: [C7Brightness(brightness: 0.1)]),
            mode: .preview
        )
        let transitionNode = ImageNode.transition(
            TransitionRecipe(from: .texture(from), to: .texture(to), kernel: .dissolve, progress: 0.5)
        )

        let recipeDiagnostics = try HarbethIO(element: from, filters: []).renderDiagnostics(node: recipeNode)
        let transitionDiagnostics = try HarbethIO(element: from, filters: []).renderDiagnostics(node: transitionNode)

        XCTAssertEqual(recipeDiagnostics.compilationSource, .editRecipe)
        XCTAssertEqual(transitionDiagnostics.compilationSource, .transition)
        XCTAssertTrue(transitionDiagnostics.containsTransitionKernel)
    }

    func testNodeDiagnosticsTracksPixelBufferInputConversions() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                4,
                4,
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            XCTFail("Failed to create bi-planar pixel buffer.")
            return
        }

        let node = ImageNode.source(.pixelBuffer(pixelBuffer))
            .applying(C7Brightness(brightness: 0.1))

        let diagnostics = try node.makeDiagnostics()

        XCTAssertEqual(diagnostics.compilationSource, .nodeGraph)
        XCTAssertEqual(diagnostics.inputColorConversionCount, 1)
        XCTAssertEqual(diagnostics.inputPixelFormatConversionCount, 1)
        XCTAssertEqual(diagnostics.inputAlphaConversionCount, 0)
    }

    func testRenderOutputContractFingerprintAndAlphaExpectation() {
        let contract = RenderOutputContract(alpha: .forceUnpremultiply)

        XCTAssertEqual(contract.alpha.expectedAlphaType, .nonPremultiplied)
        XCTAssertTrue(contract.fingerprint.contains("alpha=forceUnpremultiply"))
        XCTAssertEqual(RenderOutputContract.preserveInput.alpha, .preserveInput)
    }

    func testRenderOutputContractTracksWideGamutAndHighPrecisionOutput() {
        let displayP3 = RenderOutputContract.displayP3Texture
        let highPrecision = RenderOutputContract.highPrecisionLinearTexture

        XCTAssertTrue(displayP3.isWideGamutOutput)
        XCTAssertFalse(displayP3.isHighPrecisionOutput)
        XCTAssertTrue(displayP3.isHDRFriendlyOutput)
        XCTAssertEqual(displayP3.colorSpace.gamut, .displayP3)
        XCTAssertEqual(displayP3.colorSpace.transferFunction, .sRGB)
        XCTAssertEqual(displayP3.pixelFormat.precision, .unorm8)

        XCTAssertTrue(highPrecision.isWideGamutOutput)
        XCTAssertTrue(highPrecision.isHighPrecisionOutput)
        XCTAssertTrue(highPrecision.isHDRFriendlyOutput)
        XCTAssertEqual(highPrecision.colorSpace.transferFunction, .linear)
        XCTAssertEqual(highPrecision.pixelFormat.precision, .float16)
        XCTAssertTrue(highPrecision.fingerprint.contains("gamut=extendedLinearSRGB"))
        XCTAssertTrue(highPrecision.fingerprint.contains("precision=float16"))
    }

    func testRenderDiagnosticsExposeOutputQualityContract() {
        let plan = GraphCompiler.compile(
            filters: [C7Brightness(brightness: 0.1)],
            inputSize: C7Size(width: 2, height: 2),
            outputContract: .highPrecisionLinearTexture
        )

        XCTAssertEqual(plan.diagnostics.colorConversionCount, 1)
        XCTAssertEqual(plan.diagnostics.pixelFormatConversionCount, 1)
        XCTAssertTrue(plan.diagnostics.summary.contains("colorGamut=extendedLinearSRGB"))
        XCTAssertTrue(plan.diagnostics.summary.contains("transfer=linear"))
        XCTAssertTrue(plan.diagnostics.summary.contains("pixelPrecision=float16"))
        XCTAssertTrue(plan.diagnostics.summary.contains("hdrFriendly=1"))
        XCTAssertEqual(plan.diagnostics.outputColorSpace, .extendedLinearSRGB)
        XCTAssertEqual(plan.diagnostics.outputPixelFormat, .rgba16Float)
    }

    func testKernelNodeMaterializesPixelFormatOutputContract() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [120, 80, 40, 255])
        let descriptor = KernelDescriptor(
            filterName: "identityHighPrecision",
            functionIdentity: KernelFunctionIdentity(kind: .compute, primaryName: "C7Brightness"),
            outputContract: .highPrecisionLinearTexture
        )
        let node = ImageNode.kernel(
            input: .source(.texture(input)),
            descriptor: descriptor,
            filter: C7Brightness(brightness: 0)
        )

        let output = try node.makeTexture(profile: .interactiveLatency)

        XCTAssertEqual(output.width, input.width)
        XCTAssertEqual(output.height, input.height)
        XCTAssertEqual(output.pixelFormat, .rgba16Float)
    }

    func testRGBTransferConversionRunsOnlyForExplicitCompatibleContracts() throws {
        XCTAssertEqual(
            ImageColorSpaceContract.extendedLinearSRGB.transferConversionMode(from: .sRGB),
            .sRGBToLinear
        )
        XCTAssertEqual(
            ImageColorSpaceContract.sRGB.transferConversionMode(from: .extendedLinearSRGB),
            .linearToSRGB
        )
        XCTAssertNil(ImageColorSpaceContract.displayP3.transferConversionMode(from: .sRGB))
        XCTAssertNil(ImageColorSpaceContract.extendedLinearSRGB.transferConversionMode(from: .preserveInput))

        let input = try makeTexture(width: 1, height: 1, pixel: [128, 128, 128, 255])
        let output = try HarbethIO(
            element: input,
            filter: C7RGBTransferConversion(mode: .sRGBToLinear)
        ).output()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertLessThan(outputPixel.red, 80)
        XCTAssertGreaterThan(outputPixel.red, 40)
        XCTAssertEqual(outputPixel.red, outputPixel.green)
        XCTAssertEqual(outputPixel.green, outputPixel.blue)
        XCTAssertEqual(outputPixel.alpha, 255)
    }

    func testKernelNodeExecutesExplicitColorTransferOutputContract() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [128, 128, 128, 255])
        let descriptor = KernelDescriptor(
            filterName: "identityLinearOutput",
            functionIdentity: KernelFunctionIdentity(kind: .compute, primaryName: "C7Brightness"),
            inputColorSpace: .sRGB,
            outputContract: RenderOutputContract(colorSpace: .extendedLinearSRGB)
        )
        let node = ImageNode.kernel(
            input: .source(.texture(input)),
            descriptor: descriptor,
            filter: C7Brightness(brightness: 0)
        )

        let output = try node.makeTexture(profile: .stablePreview)
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertTrue(descriptor.fingerprint.contains("inputColor=color=sRGB"))
        XCTAssertLessThan(outputPixel.red, 80)
        XCTAssertGreaterThan(outputPixel.red, 40)
        XCTAssertEqual(outputPixel.alpha, 255)
    }

    func testRenderOutputContractDecodesOlderColorAndPixelFormatPayloads() throws {
        let colorData = Data("""
        {"name":"sRGB","preservesInput":false}
        """.utf8)
        let pixelData = Data("""
        {"name":"rgba8Unorm","preservesInput":false}
        """.utf8)

        let color = try JSONDecoder().decode(ImageColorSpaceContract.self, from: colorData)
        let pixel = try JSONDecoder().decode(PixelFormatContract.self, from: pixelData)

        XCTAssertEqual(color.name, "sRGB")
        XCTAssertEqual(color.gamut, .preserveInput)
        XCTAssertEqual(color.transferFunction, .preserveInput)
        XCTAssertEqual(pixel.name, "rgba8Unorm")
        XCTAssertEqual(pixel.precision, .custom)
    }

    func testRenderOutputContractCanDescribeMultipleAttachments() {
        let contract = RenderOutputContract(
            colorSpace: .extendedLinearSRGB,
            pixelFormat: .rgba16Float,
            additionalAttachments: [
                RenderOutputAttachmentContract.maskCoverage(index: 1, pixelFormat: .rgba8Unorm)
            ]
        )

        XCTAssertEqual(contract.attachmentCount, 2)
        XCTAssertTrue(contract.hasMultipleAttachments)
        XCTAssertEqual(contract.primaryAttachment.pixelFormat, .rgba16Float)
        XCTAssertEqual(contract.primaryAttachment.semantic, .primaryColor)
        XCTAssertEqual(contract.attachmentContract(at: 1)?.colorSpace.gamut, .sRGB)
        XCTAssertEqual(contract.attachmentContract(at: 1)?.semantic, .maskCoverage)
        XCTAssertEqual(contract.auxiliaryAttachmentCount, 1)
        XCTAssertTrue(contract.hasWideGamutAttachment)
        XCTAssertTrue(contract.hasHighPrecisionAttachment)
        XCTAssertTrue(contract.hasHDRFriendlyAttachment)
        XCTAssertTrue(contract.auxiliaryAttachments.allSatisfy(\.carriesAuxiliaryData))
        XCTAssertTrue(contract.fingerprint.contains("semantic=maskCoverage"))
        XCTAssertTrue(contract.fingerprint.contains("attachment=1"))
    }

    func testRenderOutputAttachmentSemanticHelpersExposeStableDefaults() {
        let auxiliary = RenderOutputAttachmentContract.auxiliaryColor(
            index: 1,
            colorSpace: .displayP3,
            pixelFormat: .rgba16Float
        )
        let mask = RenderOutputAttachmentContract.maskCoverage(index: 2)
        let luminance = RenderOutputAttachmentContract.luminance(index: 3)
        let analysis = RenderOutputAttachmentContract.analysis(index: 4)
        let histogram = RenderOutputAttachmentContract.histogram(index: 5)

        XCTAssertEqual(auxiliary.semantic, .auxiliaryColor)
        XCTAssertEqual(auxiliary.colorSpace.gamut, .displayP3)
        XCTAssertEqual(mask.semantic, .maskCoverage)
        XCTAssertEqual(mask.alpha, .opaque)
        XCTAssertEqual(luminance.semantic, .luminance)
        XCTAssertEqual(analysis.semantic, .analysis)
        XCTAssertEqual(histogram.semantic, .histogram)
        XCTAssertEqual(histogram.pixelFormat.precision, .float16)
        XCTAssertEqual(histogram.colorSpace.transferFunction, .linear)
    }

    func testRenderOutputAttachmentDebugPoliciesExposeStableReadbackHints() {
        let primary = RenderOutputAttachmentContract(
            index: 0,
            semantic: .primaryColor,
            alpha: .premultiplied,
            colorSpace: .extendedLinearSRGB,
            pixelFormat: .rgba16Float
        )
        let mask = RenderOutputAttachmentContract.maskCoverage(index: 1)
        let histogram = RenderOutputAttachmentContract.histogram(index: 2)

        XCTAssertEqual(primary.debugPolicy.label, "primaryColor")
        XCTAssertEqual(primary.debugPolicy.interpretation, .color)
        XCTAssertEqual(primary.debugPolicy.preferredReadbackPixelFormat, .rgba16Float)
        XCTAssertTrue(primary.debugPolicy.preservesDynamicRange)
        XCTAssertFalse(primary.debugPolicy.prefersMonochromePreview)

        XCTAssertEqual(mask.debugPolicy.label, "maskCoverage")
        XCTAssertEqual(mask.debugPolicy.interpretation, .monochrome)
        XCTAssertEqual(mask.debugPolicy.preferredReadbackPixelFormat, .rgba8Unorm)
        XCTAssertFalse(mask.debugPolicy.preservesDynamicRange)
        XCTAssertTrue(mask.debugPolicy.prefersMonochromePreview)

        XCTAssertEqual(histogram.debugPolicy.label, "histogram")
        XCTAssertEqual(histogram.debugPolicy.interpretation, .scalarField)
        XCTAssertEqual(histogram.debugPolicy.preferredReadbackPixelFormat, .rgba16Float)
        XCTAssertTrue(histogram.debugPolicy.preservesDynamicRange)
        XCTAssertTrue(histogram.debugPolicy.prefersMonochromePreview)
    }

    func testNodeAttachmentDebugPoliciesExposeAuxiliaryAttachmentHints() throws {
        let input = try makeTexture(pixel: [64, 128, 255, 255])
        let node = ImageNode.filters(input: .texture(input), filters: [RenderAuxiliaryLuminance()])

        let policies = try node.makeAttachmentDebugPolicies()

        XCTAssertEqual(policies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(policies.map(\.interpretation), [.color, .monochrome])
        XCTAssertEqual(policies.map { $0.preferredReadbackPixelFormat }, [.rgba8Unorm, .rgba8Unorm])
        XCTAssertEqual(policies.map(\.prefersMonochromePreview), [false, true])
    }

    func testRenderOutputContractDecodesAttachmentArrayPayload() throws {
        let data = Data("""
        {
          "inputAlphaExpectation":"preserveInput",
          "attachments":[
            {
              "index":0,
              "alpha":"preserveInput",
              "colorSpace":{
                "name":"extendedLinearSRGB",
                "preservesInput":false,
                "gamut":"extendedLinearSRGB",
                "transferFunction":"linear"
              },
              "pixelFormat":{
                "name":"rgba16Float",
                "preservesInput":false,
                "metalPixelFormatRawValue":112,
                "precision":"float16"
              }
            },
            {
              "index":1,
              "alpha":"opaque",
              "colorSpace":{
                "name":"DisplayP3",
                "preservesInput":false,
                "gamut":"displayP3",
                "transferFunction":"sRGB"
              },
              "pixelFormat":{
                "name":"rgba8Unorm",
                "preservesInput":false,
                "metalPixelFormatRawValue":70,
                "precision":"unorm8"
              }
            }
          ],
          "colorTransferPolicy":"automatic",
          "pixelFormatFallbackPolicy":"preserveInput",
          "allowsLossyConversion":false,
          "preservesOrientation":true
        }
        """.utf8)

        let contract = try JSONDecoder().decode(RenderOutputContract.self, from: data)

        XCTAssertEqual(contract.attachmentCount, 2)
        XCTAssertEqual(contract.colorSpace.transferFunction, .linear)
        XCTAssertEqual(contract.pixelFormat.precision, .float16)
        XCTAssertEqual(contract.attachmentContract(at: 1)?.alpha, .opaque)
        XCTAssertEqual(contract.attachmentContract(at: 1)?.pixelFormat.name, "rgba8Unorm")
    }

    private func makeTexture(width: Int = 1, height: Int = 1, pixel: [UInt8]) throws -> MTLTexture {
        let bytes = Array(repeating: pixel, count: width * height)
        return try makeTexture(width: width, height: height, pixels: bytes)
    }

    private func makeTexture(width: Int, height: Int, pixels: [[UInt8]]) throws -> MTLTexture {
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
        let bytes = pixels.flatMap { $0 }
        XCTAssertEqual(bytes.count, width * height * 4)
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: width * 4
        )
        return texture
    }

    private func pixel(in texture: MTLTexture, x: Int, y: Int) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        var bytes = [UInt8](repeating: 0, count: 4)
        texture.getBytes(
            &bytes,
            bytesPerRow: 4,
            from: MTLRegionMake2D(x, y, 1, 1),
            mipmapLevel: 0
        )
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }
}
