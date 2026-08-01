import XCTest
import Metal
import CoreVideo
#if canImport(UIKit)
import UIKit
#endif
@testable import Harbeth

final class ImageNodeTests: XCTestCase {

    func testNodeFilterPathMatchesDirectFilterPath() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [120, 20, 10, 255])
        let filters: [C7FilterProtocol] = [C7Resize(width: 2, height: 2)]
        let node = ImageNode.filters(input: .source(.texture(input)), filters: filters)

        let nodeOutput = try node.makeTexture()
        let directOutput: MTLTexture = try HarbethIO(element: input, filters: filters).output()
        let diagnostics = try node.makeDiagnostics()

        XCTAssertEqual(nodeOutput.width, directOutput.width)
        XCTAssertEqual(nodeOutput.height, directOutput.height)
        XCTAssertEqual(diagnostics.compilationSource, .nodeGraph)
        XCTAssertEqual(diagnostics.optimizationPlan.intermediateTextureCount, 0)
        XCTAssertTrue(diagnostics.summary.contains("source=nodeGraph"))
    }

    func testNodeCachePolicyIsVisibleInDiagnostics() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [10, 20, 30, 255])
        let sourceDiagnostics = try ImageNode.source(.texture(input)).makeDiagnostics()
        let persistentNode = ImageNode.filters(
            input: .source(.texture(input)),
            filters: [C7Brightness(brightness: 0.1)]
        ).withCachePolicy(.persistent)
        let persistentDiagnostics = try persistentNode.makeDiagnostics()

        XCTAssertEqual(sourceDiagnostics.imageCachePolicy, .transient)
        XCTAssertEqual(persistentDiagnostics.imageCachePolicy, .persistent)
        XCTAssertTrue(persistentDiagnostics.optimizationPlan.decisions.contains("preservePersistentImageNode"))
        XCTAssertTrue(persistentDiagnostics.summary.contains("cachePolicy=persistent"))
    }

    func testNodeSamplerDescriptorIsVisibleInDiagnostics() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [10, 20, 30, 255])
        let node = ImageNode.source(.texture(input)).withSamplerDescriptor(.nearest)
        let diagnostics = try node.makeDiagnostics()

        XCTAssertEqual(diagnostics.samplerDescriptor, .nearest)
        XCTAssertTrue(diagnostics.summary.contains("sampler=\(ImageSamplerDescriptor.nearest.fingerprint)"))
    }

    func testNodeSamplerDescriptorAffectsCoveredRenderExecutionPath() throws {
        let input = try makeTexture(width: 2, height: 1, pixels: [[255, 0, 0, 255], [0, 0, 255, 255]])

        let linearNode = ImageNode.texture(input).applying(SamplerProbeFilter())
        let nearestNode = linearNode.withSamplerDescriptor(.nearest)

        let linearPixel = try pixel(in: linearNode.makeTexture(), x: 0, y: 0)
        let nearestPixel = try pixel(in: nearestNode.makeTexture(), x: 0, y: 0)

        XCTAssertNotEqual(linearPixel.red, nearestPixel.red)
        XCTAssertNotEqual(linearPixel.blue, nearestPixel.blue)
        XCTAssertGreaterThan(linearPixel.red, 0)
        XCTAssertGreaterThan(linearPixel.blue, 0)
        XCTAssertTrue(nearestPixel.red == 255 || nearestPixel.blue == 255)
    }

    func testNodeSamplerDescriptorAffectsLegacyComputeCropExecutionPath() throws {
        let input = try makeTexture(width: 2, height: 1, pixels: [[255, 0, 0, 255], [0, 0, 255, 255]])

        let linearNode = ImageNode.texture(input).applying(
            C7Crop(
                origin: C7Point2D(x: 0.5, y: 0),
                width: 1,
                height: 1,
                samplingMode: .adaptive,
                edgeMode: .transparent
            )
        )
        let nearestNode = linearNode.withSamplerDescriptor(.nearest)

        let linearPixel = try pixel(in: linearNode.makeTexture(), x: 0, y: 0)
        let nearestPixel = try pixel(in: nearestNode.makeTexture(), x: 0, y: 0)
        let nearestDiagnostics = try nearestNode.makeDiagnostics()

        XCTAssertNotEqual(linearPixel.red, nearestPixel.red)
        XCTAssertNotEqual(linearPixel.blue, nearestPixel.blue)
        XCTAssertGreaterThan(linearPixel.red, 0)
        XCTAssertGreaterThan(linearPixel.blue, 0)
        XCTAssertTrue(nearestPixel.red == 255 || nearestPixel.blue == 255)
        XCTAssertEqual(nearestDiagnostics.samplerExecutionCoverage.mode, .covered)
        XCTAssertEqual(nearestDiagnostics.samplerExecutionCoverage.coveredFilterTypes, ["C7Crop"])
    }

    #if canImport(UIKit)
    func testUIImageSourceOrientationIsAppliedBeforeTextureCreation() throws {
        let rawTexture = try makeTexture(
            width: 2,
            height: 3,
            pixels: [
                [255, 0, 0, 255],
                [0, 255, 0, 255],
                [0, 0, 255, 255],
                [255, 255, 0, 255],
                [255, 0, 255, 255],
                [0, 255, 255, 255],
            ]
        )
        let cgImage = try XCTUnwrap(rawTexture.c7.toCGImage())
        let orientedImage = UIImage(cgImage: cgImage, scale: 1, orientation: .right)

        let frame = try ImageNode.image(orientedImage).makeFrame(profile: .exportQuality)
        let outputImage = try XCTUnwrap(frame.makeImage())

        XCTAssertEqual(frame.texture.width, 3)
        XCTAssertEqual(frame.texture.height, 2)
        XCTAssertEqual(frame.textureSize.width, 3)
        XCTAssertEqual(frame.textureSize.height, 2)
        XCTAssertEqual(frame.size.width, 2)
        XCTAssertEqual(frame.size.height, 3)
        XCTAssertEqual(frame.resolvedOutputSize.width, 2)
        XCTAssertEqual(frame.resolvedOutputSize.height, 3)
        XCTAssertEqual(frame.orientation, .right)
        XCTAssertEqual(frame.displaySize.width, 2)
        XCTAssertEqual(frame.displaySize.height, 3)
        XCTAssertEqual(frame.outputImageSize.width, 2)
        XCTAssertEqual(frame.outputImageSize.height, 3)
        XCTAssertEqual(outputImage.size.width, 2)
        XCTAssertEqual(outputImage.size.height, 3)
        XCTAssertEqual(outputImage.imageOrientation, .up)
    }
    #endif

    func testNodeWrappedPlanPreservesSourceConversionDiagnostics() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
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

    func testNodeEditingCanAttachRecipeToExistingNodeChain() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [120, 20, 10, 255])
        let node = ImageNode.texture(input)
            .applying(C7Brightness(brightness: 0.1))
            .editing(
                EditRecipe(
                    geometry: ImageTransformRecipe(
                        cropRegion: ImageCropRegion(rect: CGRect(x: 1, y: 0, width: 2, height: 3))
                    )
                )
            )

        let output = try node.makeTexture(profile: .stablePreview)
        let diagnostics = try node.makeDiagnostics(profile: .stablePreview)
        let graph = try node.makeImageGraph(profile: .stablePreview)

        XCTAssertEqual(output.width, 2)
        XCTAssertEqual(output.height, 3)
        XCTAssertEqual(diagnostics.compilationSource, .editRecipe)
        XCTAssertTrue(graph.nodes.contains(where: { $0.kind == .recipe }))
        XCTAssertTrue(graph.nodes.contains(where: { $0.kind == .filters }))
    }

    func testNodeTransformingConvenienceUsesEditRoute() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [120, 20, 10, 255])
        let node = ImageNode.texture(input).transforming(
            ImageTransformRecipe(targetSize: CGSize(width: 3, height: 2), aspectPolicy: .none)
        )

        let output = try node.makeTexture(profile: .stablePreview)
        let diagnostics = try node.makeDiagnostics(profile: .stablePreview)

        XCTAssertEqual(output.width, 3)
        XCTAssertEqual(output.height, 2)
        XCTAssertEqual(diagnostics.compilationSource, .editRecipe)
    }

    func testNodeApplyingLocalEffectConvenienceUsesEditRoute() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [120, 20, 10, 255])
        let mask = try makeTexture(width: 4, height: 3, pixel: [255, 0, 0, 255])
        let localEffect = LocalEffectRecipe(
            filters: [C7Brightness(brightness: 0.1)],
            mask: MaskDescriptor(texture: mask, opacity: 0.8)
        )
        let node = ImageNode.texture(input).applying(localEffect: localEffect)

        let diagnostics = try node.makeDiagnostics(profile: .stablePreview)
        let renderRecipe = try node.makeRenderRecipe(profile: .stablePreview)
        let effect = try XCTUnwrap(renderRecipe.localEffects?.first)

        XCTAssertEqual(diagnostics.compilationSource, .editRecipe)
        XCTAssertEqual(effect.mask.kind, "maskDescriptor")
        XCTAssertEqual(effect.mask.opacity, 0.8, accuracy: 0.0001)
    }

    func testNodeApplyingMaskDescriptorConvenienceMatchesExplicitEditRecipe() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [120, 20, 10, 255])
        let mask = MaskDescriptor(
            texture: try makeTexture(width: 4, height: 3, pixel: [255, 0, 0, 255]),
            component: .alpha,
            blendMode: .replace,
            invert: true,
            featherPolicy: .normalized(0.25),
            opacity: 0.6
        )
        let convenienceNode = ImageNode.texture(input)
            .applying(mask: mask, filters: [C7Brightness(brightness: 0.1)])
        let explicitNode = ImageNode.texture(input).editing(
            EditRecipe(localEffects: [LocalEffectRecipe(filters: [C7Brightness(brightness: 0.1)], mask: mask)])
        )

        let convenienceRecipe = try convenienceNode.makeRenderRecipe(profile: .stablePreview)
        let explicitRecipe = try explicitNode.makeRenderRecipe(profile: .stablePreview)
        XCTAssertEqual(convenienceRecipe.localEffects, explicitRecipe.localEffects)
        XCTAssertEqual(try convenienceNode.makeDiagnostics(profile: .stablePreview).compilationSource, .editRecipe)
    }

    func testNodeApplyingMaskDescriptorSingleFilterConvenienceMatchesArrayOverload() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [120, 20, 10, 255])
        let mask = MaskDescriptor(
            texture: try makeTexture(width: 4, height: 3, pixel: [255, 0, 0, 255]),
            component: .red,
            opacity: 1
        )
        let singleNode = ImageNode.texture(input)
            .applying(mask: mask, filter: C7Brightness(brightness: 0.1))
        let arrayNode = ImageNode.texture(input)
            .applying(mask: mask, filters: [C7Brightness(brightness: 0.1)])

        XCTAssertEqual(
            try singleNode.makeRenderRecipe(profile: .stablePreview).localEffects,
            try arrayNode.makeRenderRecipe(profile: .stablePreview).localEffects
        )
    }

    func testNodeApplyingGradientMaskConvenienceMatchesExplicitEditRecipe() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [120, 20, 10, 255])
        let mask = MaskGradientRecipe(
            size: C7Size(width: 4, height: 3),
            kind: .linear(startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5))
        )
        let convenienceNode = try ImageNode.texture(input)
            .applying(
                mask: mask,
                filters: [C7Brightness(brightness: 0.1)],
                component: .green,
                blendMode: .add,
                invert: true,
                featherPolicy: .normalized(0.2),
                opacity: 0.7
            )
        let explicitNode = ImageNode.texture(input)
            .editing(
                EditRecipe(localEffects: [
                    try LocalEffectRecipe(
                        filters: [C7Brightness(brightness: 0.1)],
                        mask: mask,
                        component: .green,
                        blendMode: .add,
                        invert: true,
                        featherPolicy: .normalized(0.2),
                        opacity: 0.7
                    )
                ])
            )
        let renderRecipe = try convenienceNode.makeRenderRecipe(profile: .stablePreview)
        let localEffect = try XCTUnwrap(renderRecipe.localEffects?.first)
        let explicitRecipe = try explicitNode.makeRenderRecipe(profile: .stablePreview)

        XCTAssertEqual(renderRecipe.localEffects, explicitRecipe.localEffects)
        XCTAssertEqual(localEffect.mask.kind, "maskGradientRecipe")
        XCTAssertEqual(localEffect.mask.component, .green)
        XCTAssertEqual(localEffect.mask.blendMode, .add)
        XCTAssertEqual(localEffect.mask.opacity, 0.7, accuracy: 0.0001)
    }

    func testNodeApplyingShapeMaskConvenienceMatchesExplicitEditRecipe() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [120, 20, 10, 255])
        let mask = MaskShapeRecipe(
            size: C7Size(width: 4, height: 3),
            kind: .ellipse(rect: CGRect(x: 0.25, y: 0, width: 0.5, height: 1), feather: 0.3)
        )
        let convenienceNode = try ImageNode.texture(input)
            .applying(
                mask: mask,
                filters: [C7Contrast(contrast: 1.1)],
                component: .blue,
                blendMode: .multiply,
                featherPolicy: .normalized(0.4),
                opacity: 0.65
            )
        let explicitNode = ImageNode.texture(input)
            .editing(
                EditRecipe(localEffects: [
                    try LocalEffectRecipe(
                        filters: [C7Contrast(contrast: 1.1)],
                        mask: mask,
                        component: .blue,
                        blendMode: .multiply,
                        featherPolicy: .normalized(0.4),
                        opacity: 0.65
                    )
                ])
            )
        let renderRecipe = try convenienceNode.makeRenderRecipe(profile: .stablePreview)
        let localEffect = try XCTUnwrap(renderRecipe.localEffects?.first)
        let explicitRecipe = try explicitNode.makeRenderRecipe(profile: .stablePreview)

        XCTAssertEqual(renderRecipe.localEffects, explicitRecipe.localEffects)
        XCTAssertEqual(localEffect.mask.kind, "maskShapeRecipe")
        XCTAssertEqual(localEffect.mask.component, .blue)
        XCTAssertEqual(localEffect.mask.blendMode, .multiply)
        XCTAssertEqual(localEffect.mask.opacity, 0.65, accuracy: 0.0001)
    }

    func testNodeApplyingCompositeMaskConvenienceMatchesExplicitEditRecipe() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [120, 20, 10, 255])
        let base = MaskGradientRecipe(
            size: C7Size(width: 4, height: 3),
            kind: .linear(startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5))
        )
        let subtract = MaskShapeRecipe(
            size: C7Size(width: 4, height: 3),
            kind: .rectangle(rect: CGRect(x: 0.25, y: 0, width: 0.25, height: 1))
        )
        let mask = try MaskCompositeRecipe(baseRecipe: base).subtracting(subtract, name: "subtract-center")
        let convenienceNode = ImageNode.texture(input)
            .applying(mask: mask, filters: [C7Saturation(saturation: 1.2)])
        let explicitNode = ImageNode.texture(input)
            .editing(
                EditRecipe(localEffects: [
                    LocalEffectRecipe(filters: [C7Saturation(saturation: 1.2)], maskRecipe: mask)
                ])
            )
        let renderRecipe = try convenienceNode.makeRenderRecipe(profile: .stablePreview)
        let localEffect = try XCTUnwrap(renderRecipe.localEffects?.first)
        let explicitRecipe = try explicitNode.makeRenderRecipe(profile: .stablePreview)

        XCTAssertEqual(renderRecipe.localEffects, explicitRecipe.localEffects)
        XCTAssertEqual(localEffect.mask.kind, "maskCompositeRecipe")
        XCTAssertEqual(localEffect.mask.steps.first?.name, "subtract-center")
    }

    func testPersistentNodeResolutionReusesCachedTexture() throws {
        let context = HarbethContext.shared
        context.resetCaches()
        let input = try makeTexture(width: 2, height: 2, pixel: [10, 20, 30, 255])
        let node = ImageNode.filters(input: .source(.texture(input)), filters: [C7Brightness(brightness: 0.1)])
            .withCachePolicy(.persistent)

        let first = try node.makeTexture()
        let second = try node.makeTexture()
        let snapshot = context.debugCacheSnapshot()

        XCTAssertTrue(first === second)
        XCTAssertGreaterThanOrEqual(snapshot.imageResolutionCount, 1)

        context.resetCaches()
        XCTAssertEqual(context.debugCacheSnapshot().imageResolutionCount, 0)
    }

    func testTransientNodeResolutionDoesNotReuseCachedTexture() throws {
        let context = HarbethContext.shared
        context.resetCaches()
        let input = try makeTexture(width: 4, height: 4, pixel: [80, 40, 20, 255])
        let node = ImageNode.filters(input: .source(.texture(input)), filters: [C7Brightness(brightness: 0.1)])

        let first = try node.makeTexture()
        let second = try node.makeTexture()

        XCTAssertFalse(first === second)
        XCTAssertEqual(context.debugCacheSnapshot().imageResolutionCount, 0)
    }

    func testResetCachesClearsOutputContractTextureCache() throws {
        let context = HarbethContext.shared
        context.resetCaches()
        let input = try makeTexture(width: 1, height: 1, pixel: [128, 64, 32, 128])
        let contract = RenderOutputContract(alpha: .premultiplied)

        let first = try ImageNode.applyOutputContractIfNeeded(
            contract,
            to: input,
            sourceAlphaType: .nonPremultiplied,
            profile: .stablePreview
        )
        let second = try ImageNode.applyOutputContractIfNeeded(
            contract,
            to: input,
            sourceAlphaType: .nonPremultiplied,
            profile: .stablePreview
        )

        XCTAssertTrue(first === second)

        context.resetCaches()

        let third = try ImageNode.applyOutputContractIfNeeded(
            contract,
            to: input,
            sourceAlphaType: .nonPremultiplied,
            profile: .stablePreview
        )

        XCTAssertFalse(first === third)
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
        XCTAssertTrue(
            descriptor.arguments.contains(where: { argument in
                argument.name == "factors" && argument.role == .parameter && argument.dataType == .floatArray
                    && argument.valueFingerprint == "floats:0.4000"
            })
        )
        XCTAssertTrue(
            descriptor.arguments.contains(where: { argument in
                argument.name == "otherInputTextures" && argument.role == .inputTexture && argument.dataType == .int
                    && argument.required == false
            })
        )
    }

    func testKernelDescriptorFunctionConstantsAreSpecializationContracts() {
        let constants = [
            KernelFunctionConstantDescriptor(name: "harbeth::outputsPremultipliedAlpha", index: 3, value: .bool(true)),
            KernelFunctionConstantDescriptor(name: "harbeth::blendMode", index: 1, value: .int(8)),
        ]
        let reversedConstants = Array(constants.reversed())
        let firstIdentity = KernelFunctionIdentity(
            kind: .render,
            primaryName: "C7VertexPassthrough",
            secondaryName: "LayerComposite",
            functionConstants: constants
        )
        let secondIdentity = KernelFunctionIdentity(
            kind: .render,
            primaryName: "C7VertexPassthrough",
            secondaryName: "LayerComposite",
            functionConstants: reversedConstants
        )
        let descriptor = KernelDescriptor(
            filterName: "LayerComposite",
            functionIdentity: firstIdentity,
            parameters: ["opacity": .float(0.5)],
            resourceUsage: .multiInput,
            pixelContract: .conservative(samplingFootprint: .dynamic)
        )

        XCTAssertEqual(firstIdentity.fingerprint, secondIdentity.fingerprint)
        XCTAssertEqual(descriptor.functionIdentity.functionConstants.count, 2)
        XCTAssertEqual(descriptor.passes[0].functionIdentity.functionConstants.count, 2)
        XCTAssertTrue(descriptor.fingerprint.contains("constants=constant=harbeth::blendMode"))
        XCTAssertTrue(
            descriptor.arguments.contains(where: { argument in
                argument.name == "harbeth::blendMode" && argument.role == .functionConstant && argument.dataType == .int
                    && argument.valueFingerprint == "int:8"
            })
        )
        XCTAssertTrue(
            descriptor.arguments.contains(where: { argument in
                argument.name == "harbeth::outputsPremultipliedAlpha" && argument.role == .functionConstant
                    && argument.dataType == .bool && argument.valueFingerprint == "bool:1"
            })
        )
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
                KernelFunctionConstantDescriptor(name: "harbeth::usesLinearSampling", value: .bool(true))
            ]
        )
        let descriptor = KernelDescriptor(
            filterName: "customKernel",
            functionIdentity: metallibIdentity,
            pixelContract: .conservative(samplingFootprint: .dynamic)
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
                KernelFunctionConstantDescriptor(name: "harbeth::flag", value: .bool(true)),
                KernelFunctionConstantDescriptor(name: "harbeth::mode", index: 1, value: .int(2)),
                KernelFunctionConstantDescriptor(name: "harbeth::amount", index: 2, value: .float(0.75)),
            ]
        )
        let metadataOnlyIdentity = KernelFunctionIdentity(
            kind: .compute,
            primaryName: "customKernel",
            functionConstants: [
                KernelFunctionConstantDescriptor(name: "harbeth::debugLabel", value: .string("metadata-only"))
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
        XCTAssertTrue(opacity.fingerprint.contains("memory=point"))
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

    func testPublicApplyingKernelMatchesDirectFilterPath() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [120, 20, 10, 255])
        let filter = C7Brightness(brightness: 0.2)

        let node = ImageNode.texture(input).applyingWithContract(filter, inputSize: C7Size(width: 4, height: 3))

        let nodeOutput = try node.makeTexture()
        let directOutput: MTLTexture = try HarbethIO(element: input, filter: filter).output()
        let diagnostics = try node.makeDiagnostics()
        let graph = try node.makeImageGraph()

        XCTAssertEqual(nodeOutput.width, directOutput.width)
        XCTAssertEqual(nodeOutput.height, directOutput.height)
        XCTAssertEqual(diagnostics.compilationSource, .nodeGraph)
        XCTAssertEqual(graph.nodeCount, 2)
        XCTAssertTrue(graph.nodes.contains(where: { $0.kind == .kernel }))
    }

    func testPublicApplyingKernelPreservesOutputContractEffects() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [200, 100, 50, 128])
        let node = ImageNode.texture(input)
            .applyingWithContract(C7Brightness(brightness: 0))
            .applyingWithContract(C7PremultiplyAlpha())

        let output = try node.makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertLessThan(outputPixel.red, 200)
        XCTAssertLessThan(outputPixel.green, 100)
        XCTAssertEqual(outputPixel.alpha, 128)
    }

    func testImageSourceResolvedSizeHintCoversTexturePixelBufferAndSampleBuffer() throws {
        let texture = try makeTexture(width: 4, height: 3, pixel: [12, 34, 56, 255])
        let pixelBuffer = try makePixelBuffer(width: 5, height: 2, pixel: [8, 16, 32, 255])
        let sampleBuffer = try makeSampleBuffer(width: 6, height: 4, pixel: [2, 4, 8, 255])

        XCTAssertEqual(ImageSource.texture(texture).resolvedSizeHint, C7Size(width: 4, height: 3))
        XCTAssertEqual(ImageSource.pixelBuffer(pixelBuffer).resolvedSizeHint, C7Size(width: 5, height: 2))
        XCTAssertEqual(ImageSource.sampleBuffer(sampleBuffer).resolvedSizeHint, C7Size(width: 6, height: 4))
        XCTAssertNil(ImageSource.data(Data([1, 2, 3])).resolvedSizeHint)
    }

    func testImageNodeResolvedPlanningOutputSizeHintTracksFilterAndKernelResize() throws {
        let input = try makeTexture(width: 4, height: 3, pixel: [120, 20, 10, 255])

        let filterNode = ImageNode.texture(input)
            .applying(C7Resize(width: 2, height: 1))
        let kernelNode = ImageNode.texture(input)
            .applyingWithContract(
                C7Resize(width: 2, height: 1),
                inputSize: C7Size(width: 4, height: 3)
            )

        XCTAssertEqual(
            ImageNode.texture(input).resolvedPlanningOutputSizeHint(profile: .stablePreview),
            C7Size(width: 4, height: 3)
        )
        XCTAssertEqual(filterNode.resolvedPlanningOutputSizeHint(profile: .stablePreview), C7Size(width: 2, height: 1))
        XCTAssertEqual(kernelNode.resolvedPlanningOutputSizeHint(profile: .stablePreview), C7Size(width: 2, height: 1))
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
            pixelContract: filter.kernelPixelContract,
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
            filters: [C7Brightness(brightness: 0.1), C7Contrast(contrast: 1.1)],
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
            filters: [C7Brightness(brightness: 0.1), C7Contrast(contrast: 1.1), C7Saturation(saturation: 0.8)],
            inputSize: C7Size(width: 4, height: 4),
            profile: .stablePreview
        )

        XCTAssertEqual(plan.diagnostics.optimizationPlan.lifecycleDecisions.count, plan.diagnostics.stageCount)
        XCTAssertTrue(
            plan.diagnostics.optimizationPlan.lifecycleDecisions.contains(where: {
                $0.action == .allocatePersistentOutput
            })
        )
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

        let output = try node.makeTexture()
        let diagnostics = try node.makeDiagnostics()

        XCTAssertEqual(output.width, 2)
        XCTAssertEqual(output.height, 2)
        XCTAssertEqual(try pixel(in: output, x: 0, y: 0).green, 255)
        XCTAssertEqual(try pixel(in: output, x: 1, y: 0).red, 255)
        XCTAssertEqual(diagnostics.compilationSource, .layerComposite)
        XCTAssertEqual(diagnostics.nodes.first?.name.contains("LayerComposite"), true)
        XCTAssertEqual(diagnostics.optimizationPlan.destinationTextureCreationCount, 1)
    }

    func testImageNodeAttachmentAnalysisBundleReturnsNilForNonRenderPath() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [32, 64, 96, 255])
        let node = ImageNode.texture(input).applying(C7Brightness(brightness: 0.1))

        let bundle = try node.makeAttachmentAnalysisBundle()

        XCTAssertNil(bundle)
    }

    func testImageNodeAttachmentSetReturnsNilForNonRenderPath() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [32, 64, 96, 255])
        let node = ImageNode.texture(input).applying(C7Brightness(brightness: 0.1))

        let attachmentSet = try node.makeAttachmentSet()

        XCTAssertNil(attachmentSet)
    }

    func testImageNodeAttachmentSetUsesFinalRenderPrimitiveThroughWrappers() throws {
        let input = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [255, 0, 0, 255]])
        let node = ImageNode.texture(input)
            .applying(filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()])
            .withCachePolicy(.persistent)
            .withSamplerDescriptor(.nearest)

        let attachmentSet = try XCTUnwrap(node.makeAttachmentSet())

        XCTAssertEqual(attachmentSet.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(attachmentSet.attachments.count, 2)
        XCTAssertEqual(attachmentSet.primary?.semantic, .primaryColor)
        XCTAssertEqual(attachmentSet.attachment(for: .luminance)?.semantic, .luminance)
        XCTAssertNotNil(attachmentSet.texture(for: .luminance))
    }

    func testImageNodeAttachmentAnalysisBundleUsesFinalRenderPrimitiveThroughWrappers() throws {
        let input = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [255, 0, 0, 255]])
        let node = ImageNode.texture(input)
            .applying(filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()])
            .withCachePolicy(.persistent)
            .withSamplerDescriptor(.nearest)

        let bundle = try XCTUnwrap(
            node.makeAttachmentAnalysisBundle(bins: 4, histogramHeight: 16, preferredMethod: .gpuMPS)
        )

        XCTAssertEqual(bundle.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(bundle.analyses.count, 2)
        XCTAssertEqual(bundle.primary?.attachment.semantic, .primaryColor)
        XCTAssertEqual(bundle.primary?.histogram?.totalSampleCount, 2)
        XCTAssertEqual(bundle.analysis(for: .luminance)?.attachment.semantic, .luminance)
        XCTAssertEqual(bundle.analysis(for: .luminance)?.histogram?.channel, .luminance)
    }

    func testImageNodeAttachmentAnalysisBundleCanRestrictHistogramRegion() throws {
        let input = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [255, 0, 0, 255]])
        let node = ImageNode.texture(input).applying(filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()])

        let bundle = try XCTUnwrap(
            node.makeAttachmentAnalysisBundle(
                bins: 4,
                histogramHeight: 16,
                region: MTLRegionMake2D(1, 0, 1, 1),
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(bundle.primary?.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.analysis(for: .luminance)?.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.primary?.histogram?.bins.reduce(0, +), 1)
        XCTAssertEqual(bundle.analysis(for: .luminance)?.histogram?.bins.reduce(0, +), 1)
        XCTAssertNotNil(bundle.primary?.histogramAttachment)
        XCTAssertNotNil(bundle.analysis(for: .luminance)?.histogramAttachment)
    }

    func testImageNodeAttachmentAnalysisBundleSupportsUnifiedAnalysisScope() throws {
        let input = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [255, 0, 0, 255]])
        let mask = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [255, 0, 0, 255]])
        let node = ImageNode.texture(input)
            .applying(filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()])

        let bundle = try XCTUnwrap(
            node.makeAttachmentAnalysisBundle(
                bins: 4,
                histogramHeight: 16,
                scope: TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red)),
                preferredMethod: .gpuMPS
            )
        )

        XCTAssertEqual(bundle.primary?.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.primary?.statistics?.sampleCount, 1)
        XCTAssertEqual(Double(try XCTUnwrap(bundle.primary?.statistics).meanRed), 1, accuracy: 0.0001)
        XCTAssertEqual(bundle.analysis(for: .luminance)?.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.analysisScopeFingerprint, TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red)).fingerprint)
    }

    func testNodeDebugSnapshotExposesGraphAndOptimizationDecisions() throws {
        let input = try makeTexture(width: 4, height: 4, pixel: [32, 64, 96, 255])
        let node = ImageNode.texture(input)
            .applying(filters: [C7Brightness(brightness: 0.1), C7Contrast(contrast: 1.1)])
            .withCachePolicy(.persistent)

        let snapshot = try node.makeDebugSnapshot()

        XCTAssertFalse(snapshot.nodes.isEmpty)
        XCTAssertFalse(snapshot.edges.isEmpty)
        XCTAssertFalse(snapshot.dotGraph.isEmpty)
        XCTAssertTrue(snapshot.dotGraph.contains("digraph ImageGraph"))
        XCTAssertGreaterThanOrEqual(snapshot.diagnostics.graphNodeCount, 2)
        XCTAssertTrue(snapshot.diagnostics.persistentBoundaryCount >= 1)
        XCTAssertFalse(snapshot.optimizationDecisions.isEmpty)
        XCTAssertEqual(snapshot.renderRecipe?.source.kind, "texture")
        XCTAssertTrue(snapshot.renderRecipe?.filters.contains(where: { $0.stableTypeID.contains("C7Brightness") }) == true)
    }

    func testNodeDebugSnapshotExposesDirectPlaneBridgeDiagnostics() throws {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey: 4,
            kCVPixelBufferHeightKey: 4,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
        ]
        let creationStatus = CVPixelBufferCreate(
            kCFAllocatorDefault,
            4,
            4,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard creationStatus == kCVReturnSuccess else {
            throw XCTSkip("Failed to create bi-planar pixel buffer.")
        }
        guard let pixelBuffer else {
            throw XCTSkip("Failed to create bi-planar pixel buffer.")
        }
        let node = ImageNode.pixelBuffer(pixelBuffer).applying(C7Brightness(brightness: 0.1))

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
        let node = ImageNode.texture(input)
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
        let node = ImageNode.texture(input).applying(C7Brightness(brightness: 0.1))

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

    func testNodeRenderRequestBridgesDeferredAttachmentOutputs() throws {
        let input = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [255, 0, 0, 255]])
        let mask = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [255, 0, 0, 255]])
        let node = ImageNode.texture(input).applying(filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()])
        let request = try node.makeRenderRequest(profile: .readbackQuality)
        let scope = TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red))

        let attachmentSet = try XCTUnwrap(request.renderAttachmentSet())
        let bundle = try XCTUnwrap(
            request.renderAttachmentAnalysisBundle(bins: 4, histogramHeight: 16, scope: scope, preferredMethod: .gpuMPS)
        )

        XCTAssertEqual(attachmentSet.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(bundle.debugPolicies.map(\.label), ["primaryColor", "luminance"])
        XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
    }

    func testNodeAnalysisConveniencesMatchResultObjectLayer() throws {
        let input = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [255, 0, 0, 255]])
        let node = ImageNode.texture(input).applying(C7Brightness(brightness: 0.0))
        let scope = TextureAnalysisScope.region(MTLRegionMake2D(1, 0, 1, 1))
        let frame = try node.makeFrame(profile: .readbackQuality)

        let histogram = try XCTUnwrap(
            node.makeHistogram(
                profile: .readbackQuality,
                channel: .red,
                bins: 4,
                scope: scope,
                preferredMethod: .cpuReadback
            )
        )
        let statistics = try XCTUnwrap(node.makeStatistics(profile: .readbackQuality, scope: scope))
        let probe = try XCTUnwrap(node.makeColorProbe(profile: .readbackQuality, scope: scope))
        let histogramAttachment = try XCTUnwrap(
            node.makeHistogramAttachment(
                profile: .readbackQuality,
                channel: .red,
                bins: 4,
                height: 16,
                scope: scope,
                preferredMethod: .gpuMPS
            )
        )
        let bundle = try node.makeAnalysisBundle(
            profile: .readbackQuality,
            channel: .red,
            bins: 4,
            histogramHeight: 16,
            scope: scope,
            preferredMethod: .cpuReadback
        )

        XCTAssertEqual(histogram, frame.makeHistogram(channel: .red, bins: 4, scope: scope, preferredMethod: .cpuReadback))
        XCTAssertEqual(statistics, frame.makeStatistics(scope: scope))
        XCTAssertEqual(probe.meanColor8, frame.makeColorProbe(scope: scope)?.meanColor8)
        XCTAssertEqual(histogramAttachment.histogram.channel, .red)
        XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
        XCTAssertEqual(bundle.statistics, statistics)
        XCTAssertEqual(bundle.colorProbe?.meanColor8, probe.meanColor8)
    }

    func testNodeScopedMaskConveniencesMatchResultObjectLayer() throws {
        let input = try makeTexture(width: 2, height: 1, pixels: [[255, 0, 0, 255], [0, 0, 255, 255]])
        let mask = try makeTexture(width: 2, height: 1, pixels: [[255, 0, 0, 255], [0, 0, 0, 255]])
        let scope = TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red))
        let node = ImageNode.texture(input)
        let frame = try node.makeFrame(profile: .readbackQuality)

        let scopedMaskTexture = try XCTUnwrap(node.makeMaskTexture(profile: .readbackQuality, scope: scope))
        let scopedMaskDescriptor = try XCTUnwrap(node.makeMaskDescriptor(profile: .readbackQuality, scope: scope))

        XCTAssertEqual(scopedMaskTexture.width, frame.texture.width)
        XCTAssertEqual(scopedMaskTexture.height, frame.texture.height)
        XCTAssertEqual(scopedMaskDescriptor.texture.width, frame.texture.width)
        XCTAssertEqual(scopedMaskDescriptor.texture.height, frame.texture.height)
        XCTAssertEqual(
            try pixel(in: scopedMaskDescriptor.texture, x: 0, y: 0).red,
            try pixel(in: try XCTUnwrap(frame.makeMaskDescriptor(scope: scope)?.texture), x: 0, y: 0).red
        )
    }

    func testNodeAttachmentConveniencesMatchAttachmentResultLayer() throws {
        let input = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [255, 0, 0, 255]])
        let mask = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [255, 0, 0, 255]])
        let scope = TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red))
        let node = ImageNode.texture(input).applying(filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()])
        let attachmentSet = try XCTUnwrap(node.makeAttachmentSet(profile: .readbackQuality))

        let attachment = try XCTUnwrap(node.makeAttachment(profile: .readbackQuality, semantic: .luminance))
        let histogram = try XCTUnwrap(
            node.makeAttachmentHistogram(
                profile: .readbackQuality,
                semantic: .luminance,
                bins: 4,
                scope: scope,
                preferredMethod: .cpuReadback
            )
        )
        let statistics = try XCTUnwrap(
            node.makeAttachmentStatistics(profile: .readbackQuality, semantic: .luminance, scope: scope)
        )
        let probe = try XCTUnwrap(
            node.makeAttachmentColorProbe(profile: .readbackQuality, semantic: .luminance, scope: scope)
        )
        let scopedMask = try XCTUnwrap(
            node.makeAttachmentMaskDescriptor(profile: .readbackQuality, semantic: .luminance, scope: scope)
        )
        let analysis = try XCTUnwrap(
            node.makeAttachmentAnalysis(
                profile: .readbackQuality,
                semantic: .luminance,
                bins: 4,
                histogramHeight: 16,
                scope: scope,
                preferredMethod: .cpuReadback
            )
        )

        XCTAssertEqual(attachment.semantic, attachmentSet.attachment(for: .luminance)?.semantic)
        XCTAssertEqual(
            histogram,
            attachmentSet.makeHistogram(for: .luminance, bins: 4, scope: scope, preferredMethod: .cpuReadback)
        )
        XCTAssertEqual(statistics, attachmentSet.makeStatistics(for: .luminance, scope: scope))
        XCTAssertEqual(probe.meanColor8, attachmentSet.makeColorProbe(for: .luminance, scope: scope)?.meanColor8)
        XCTAssertEqual(scopedMask.texture.width, attachment.texture.width)
        XCTAssertEqual(analysis.attachment.semantic, .luminance)
        XCTAssertEqual(analysis.histogram, histogram)
        XCTAssertEqual(analysis.statistics, statistics)
    }

    func testNodeRenderRequestKeepsAttachmentOutputsOptionalForNonRenderPath() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [32, 64, 96, 255])
        let node = ImageNode.texture(input).applying(C7Brightness(brightness: 0.1))

        let request = try node.makeRenderRequest(profile: .stablePreview)

        XCTAssertNil(try request.renderAttachmentSet())
        XCTAssertNil(try request.renderAttachmentAnalysisBundle(bins: 4, histogramHeight: 16, preferredMethod: .gpuMPS))
    }

    func testNodeRenderRequestBridgesDeferredAnalysisBundleAndColorProbe() throws {
        let input = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [255, 0, 0, 255]])
        let request = try ImageNode.texture(input)
            .applying(C7Brightness(brightness: 0.0))
            .makeRenderRequest(profile: .readbackQuality)
        let scope = TextureAnalysisScope.region(MTLRegionMake2D(1, 0, 1, 1))

        let bundle = try XCTUnwrap(
            request.renderAnalysisBundle(
                channel: .red,
                bins: 4,
                histogramHeight: 16,
                scope: scope,
                preferredMethod: .cpuReadback
            )
        )
        let probe = try XCTUnwrap(request.renderColorProbe(scope: scope))

        XCTAssertEqual(bundle.statistics?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.x, 255)
        XCTAssertEqual(probe.meanColor8.x, 255)
        XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
    }

    func testNodeRenderRequestBridgesDeferredColorRangeAnalysisScope() throws {
        let input = try makeTexture(
            width: 3,
            height: 1,
            pixels: [[255, 0, 0, 255], [0, 255, 0, 255], [255, 255, 255, 255]]
        )
        let request = try ImageNode.texture(input)
            .applying(C7Brightness(brightness: 0.0))
            .makeRenderRequest(profile: .readbackQuality)
        let scope = TextureAnalysisScope(
            colorRange: TextureColorRange(
                hue: TextureComponentRange(minimum: 0.95, maximum: 0.05, wrapsAroundUnit: true),
                saturation: TextureComponentRange(minimum: 0.8, maximum: 1.0)
            )
        )

        let bundle = try XCTUnwrap(
            request.renderAnalysisBundle(
                channel: .red,
                bins: 4,
                histogramHeight: 16,
                scope: scope,
                preferredMethod: .cpuReadback
            )
        )
        let probe = try XCTUnwrap(request.renderColorProbe(scope: scope))

        XCTAssertEqual(bundle.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.statistics?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.sampleCount, 1)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.x, 255)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.y, 0)
        XCTAssertEqual(bundle.colorProbe?.meanColor8.z, 0)
        XCTAssertEqual(probe.meanColor8.x, 255)
        XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
    }

    func testNodeRenderRequestBridgesDeferredAttachmentColorRangeAnalysisScope() throws {
        let input = try makeTexture(
            width: 3,
            height: 1,
            pixels: [[255, 0, 0, 255], [0, 255, 0, 255], [255, 255, 255, 255]]
        )
        let node = ImageNode.texture(input).applying(filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance()])
        let request = try node.makeRenderRequest(profile: .readbackQuality)
        let scope = TextureAnalysisScope(
            colorRange: TextureColorRange(
                hue: TextureComponentRange(minimum: 0.95, maximum: 0.05, wrapsAroundUnit: true),
                saturation: TextureComponentRange(minimum: 0.8, maximum: 1.0)
            )
        )

        let bundle = try XCTUnwrap(
            request.renderAttachmentAnalysisBundle(
                bins: 4,
                histogramHeight: 16,
                scope: scope,
                preferredMethod: .cpuReadback
            )
        )

        XCTAssertEqual(bundle.analysisScopeFingerprint, scope.fingerprint)
        XCTAssertEqual(bundle.analysis(for: .primaryColor)?.histogram?.totalSampleCount, 1)
        XCTAssertEqual(bundle.analysis(for: .primaryColor)?.statistics?.sampleCount, 1)
        XCTAssertEqual(bundle.analysis(for: .primaryColor)?.colorProbe?.sampleCount, 1)
        XCTAssertEqual(bundle.analysis(for: .primaryColor)?.colorProbe?.meanColor8.x, 255)
        XCTAssertEqual(bundle.analysis(for: .primaryColor)?.colorProbe?.meanColor8.y, 0)
        XCTAssertEqual(bundle.analysis(for: .primaryColor)?.colorProbe?.meanColor8.z, 0)
    }

    func testNodeRenderRequestConveniencesMatchAttachmentAndAnalysisPaths() throws {
        let input = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [255, 0, 0, 255]])
        let mask = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [255, 0, 0, 255]])
        let scope = TextureAnalysisScope(mask: MaskDescriptor(texture: mask, component: .red))
        let request = try ImageNode.texture(input)
            .applying(filters: [C7Brightness(brightness: 0), RenderAuxiliaryLuminance(),])
            .makeRenderRequest(profile: .readbackQuality)

        let histogram = try XCTUnwrap(
            request.renderHistogram(channel: .red, bins: 4, scope: scope, preferredMethod: .cpuReadback)
        )
        let statistics = try XCTUnwrap(request.renderStatistics(scope: scope))
        let attachment = try XCTUnwrap(request.renderAttachment(semantic: .luminance))
        let attachmentHistogram = try XCTUnwrap(
            request.renderAttachmentHistogram(
                semantic: .luminance,
                bins: 4,
                scope: scope,
                preferredMethod: .cpuReadback
            )
        )
        let attachmentStatistics = try XCTUnwrap(request.renderAttachmentStatistics(semantic: .luminance, scope: scope))
        let attachmentProbe = try XCTUnwrap(request.renderAttachmentColorProbe(semantic: .luminance, scope: scope))
        let attachmentMask = try XCTUnwrap(request.renderAttachmentMaskDescriptor(semantic: .luminance, scope: scope))
        let attachmentAnalysis = try XCTUnwrap(
            request.renderAttachmentAnalysis(
                semantic: .luminance,
                bins: 4,
                histogramHeight: 16,
                scope: scope,
                preferredMethod: .cpuReadback
            )
        )

        XCTAssertEqual(histogram.totalSampleCount, 1)
        XCTAssertEqual(statistics.sampleCount, 1)
        XCTAssertEqual(attachment.semantic, .luminance)
        XCTAssertEqual(attachmentHistogram.totalSampleCount, 1)
        XCTAssertEqual(attachmentStatistics.sampleCount, 1)
        XCTAssertEqual(attachmentProbe.sampleCount, 1)
        XCTAssertEqual(attachmentMask.texture.width, attachment.texture.width)
        XCTAssertEqual(attachmentAnalysis.attachment.semantic, .luminance)
        XCTAssertEqual(attachmentAnalysis.histogram, attachmentHistogram)
        XCTAssertEqual(attachmentAnalysis.statistics, attachmentStatistics)
    }

    func testLayerCompositeRenderRecipeExposesLayerMaskGraphDescriptors() throws {
        let background = try makeTexture(width: 2, height: 2, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let baseMask = try makeTexture(width: 1, height: 1, pixel: [255, 0, 0, 255])
        let subtractMask = try makeTexture(width: 1, height: 1, pixel: [128, 0, 0, 255])
        let addMask = try makeTexture(width: 1, height: 1, pixel: [64, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    maskRecipe: MaskCompositeRecipe(
                        baseMask: MaskDescriptor(texture: baseMask, component: .red),
                        steps: [
                            MaskCompositeStep(
                                name: "subject-subtract",
                                mask: MaskDescriptor(
                                    texture: subtractMask,
                                    component: .red,
                                    blendMode: .subtract,
                                    opacity: 1
                                )
                            )
                        ]
                    ),
                    compositingMaskRecipe: MaskCompositeRecipe(
                        baseMask: MaskDescriptor(texture: baseMask, component: .red),
                        steps: [
                            MaskCompositeStep(
                                name: "canvas-add",
                                mask: MaskDescriptor(texture: addMask, component: .red, blendMode: .add, opacity: 1)
                            )
                        ]
                    )
                )
            ]
        )

        let renderRecipe = try recipe.makeRenderRecipe()
        let layerMask = try XCTUnwrap(renderRecipe.layerMasks?.first)

        XCTAssertEqual(layerMask.layerIndex, 0)
        XCTAssertEqual(layerMask.mask?.kind, "maskCompositeRecipe")
        XCTAssertEqual(layerMask.mask?.steps.first?.name, "subject-subtract")
        XCTAssertEqual(layerMask.compositingMask?.kind, "maskCompositeRecipe")
        XCTAssertEqual(layerMask.compositingMask?.steps.first?.blendMode, .add)
    }

    func testLayerCompositeDebugSnapshotCarriesLayerMaskGraphDescriptor() throws {
        let background = try makeTexture(width: 2, height: 2, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let baseMask = try makeTexture(width: 1, height: 1, pixel: [255, 0, 0, 255])
        let subtractMask = try makeTexture(width: 1, height: 1, pixel: [128, 0, 0, 255])
        let node = ImageNode.layerComposite(
            LayerCompositeRecipe(
                background: .texture(background),
                layers: [
                    ImageLayer(
                        content: .texture(layer),
                        maskRecipe: MaskCompositeRecipe(
                            baseMask: MaskDescriptor(texture: baseMask, component: .red),
                            steps: [
                                MaskCompositeStep(
                                    name: "snapshot-mask-step",
                                    mask: MaskDescriptor(
                                        texture: subtractMask,
                                        component: .red,
                                        blendMode: .subtract,
                                        opacity: 1
                                    )
                                )
                            ]
                        )
                    )
                ]
            )
        )

        let snapshot = try node.makeDebugSnapshot()
        let layerMask = try XCTUnwrap(snapshot.renderRecipe?.layerMasks?.first)

        XCTAssertEqual(layerMask.mask?.kind, "maskCompositeRecipe")
        XCTAssertEqual(layerMask.mask?.steps.first?.name, "snapshot-mask-step")
    }

    func testLayerCompositeRenderRecipePreservesGradientMaskDescriptors() throws {
        let background = try makeTexture(width: 3, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 3, height: 1, pixel: [0, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskGradientRecipe(
                        size: C7Size(width: 3, height: 1),
                        kind: .linear(startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5))
                    ),
                    compositingMask: MaskGradientRecipe(
                        size: C7Size(width: 3, height: 1),
                        kind: .radial(center: CGPoint(x: 0.5, y: 0.5), startRadius: 0, endRadius: 0.75)
                    )
                )
            ]
        )

        let renderRecipe = try recipe.makeRenderRecipe()
        let layerMask = try XCTUnwrap(renderRecipe.layerMasks?.first)

        XCTAssertEqual(layerMask.mask?.kind, "maskGradientRecipe")
        XCTAssertEqual(layerMask.mask?.gradient?.kind, "linear")
        XCTAssertTrue(layerMask.mask?.gradient?.parameterValues.contains("size=3x1") == true)
        XCTAssertEqual(layerMask.compositingMask?.kind, "maskGradientRecipe")
        XCTAssertEqual(layerMask.compositingMask?.gradient?.kind, "radial")
    }

    func testLayerCompositeDebugSnapshotPreservesGradientMaskDescriptors() throws {
        let background = try makeTexture(width: 3, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 3, height: 1, pixel: [0, 0, 0, 255])
        let node = ImageNode.layerComposite(
            LayerCompositeRecipe(
                background: .texture(background),
                layers: [
                    ImageLayer(
                        content: .texture(layer),
                        mask: MaskGradientRecipe(
                            size: C7Size(width: 3, height: 1),
                            kind: .linear(startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5))
                        )
                    )
                ]
            )
        )

        let snapshot = try node.makeDebugSnapshot()
        let layerMask = try XCTUnwrap(snapshot.renderRecipe?.layerMasks?.first)

        XCTAssertEqual(layerMask.mask?.kind, "maskGradientRecipe")
        XCTAssertEqual(layerMask.mask?.gradient?.kind, "linear")
        XCTAssertTrue(layerMask.mask?.fingerprint.contains("kind=linear") == true)
    }

    func testLayerCompositeGradientMaskCanDrivePartialCoverage() throws {
        let background = try makeTexture(width: 3, height: 1, pixel: [255, 0, 0, 255])
        let layer = try makeTexture(width: 3, height: 1, pixel: [0, 0, 255, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskGradientRecipe(
                        size: C7Size(width: 3, height: 1),
                        kind: .linear(startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5))
                    )
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let left = try pixel(in: output, x: 0, y: 0)
        let center = try pixel(in: output, x: 1, y: 0)
        let right = try pixel(in: output, x: 2, y: 0)

        XCTAssertGreaterThan(left.red, center.red)
        XCTAssertGreaterThan(center.red, right.red)
        XCTAssertLessThan(left.blue, center.blue)
        XCTAssertLessThan(center.blue, right.blue)
    }

    func testLayerCompositeRenderRecipePreservesShapeMaskDescriptors() throws {
        let background = try makeTexture(width: 3, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 3, height: 1, pixel: [0, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskShapeRecipe(
                        size: C7Size(width: 3, height: 1),
                        kind: .rectangle(rect: CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1))
                    ),
                    compositingMask: MaskShapeRecipe(
                        size: C7Size(width: 3, height: 1),
                        kind: .ellipse(rect: CGRect(x: 0, y: 0, width: 1, height: 1))
                    )
                )
            ]
        )

        let renderRecipe = try recipe.makeRenderRecipe()
        let layerMask = try XCTUnwrap(renderRecipe.layerMasks?.first)

        XCTAssertEqual(layerMask.mask?.kind, "maskShapeRecipe")
        XCTAssertEqual(layerMask.mask?.shape?.kind, "rectangle")
        XCTAssertEqual(layerMask.compositingMask?.kind, "maskShapeRecipe")
        XCTAssertEqual(layerMask.compositingMask?.shape?.kind, "ellipse")
    }

    func testLayerCompositeDebugSnapshotPreservesShapeMaskDescriptors() throws {
        let background = try makeTexture(width: 3, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 3, height: 1, pixel: [0, 0, 0, 255])
        let node = ImageNode.layerComposite(
            LayerCompositeRecipe(
                background: .texture(background),
                layers: [
                    ImageLayer(
                        content: .texture(layer),
                        mask: MaskShapeRecipe(
                            size: C7Size(width: 3, height: 1),
                            kind: .rectangle(rect: CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1))
                        )
                    )
                ]
            )
        )

        let snapshot = try node.makeDebugSnapshot()
        let layerMask = try XCTUnwrap(snapshot.renderRecipe?.layerMasks?.first)

        XCTAssertEqual(layerMask.mask?.kind, "maskShapeRecipe")
        XCTAssertEqual(layerMask.mask?.shape?.kind, "rectangle")
    }

    func testLayerCompositePreservesParametricShapeMaskDescriptors() throws {
        let background = try makeTexture(width: 8, height: 8, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 8, height: 8, pixel: [0, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskShapeRecipe.star(
                        size: C7Size(width: 8, height: 8),
                        rect: CGRect(x: 0.15, y: 0.15, width: 0.7, height: 0.7),
                        points: 6,
                        innerRadiusRatio: 0.32,
                        feather: 0.18
                    )
                )
            ]
        )

        let renderRecipe = try recipe.makeRenderRecipe()
        let snapshot = try ImageNode.layerComposite(recipe).makeDebugSnapshot()
        let renderLayerMask = try XCTUnwrap(renderRecipe.layerMasks?.first?.mask)
        let snapshotLayerMask = try XCTUnwrap(snapshot.renderRecipe?.layerMasks?.first?.mask)

        XCTAssertEqual(renderLayerMask.kind, "maskShapeRecipe")
        XCTAssertEqual(renderLayerMask.shape?.kind, "star")
        XCTAssertTrue(renderLayerMask.shape?.parameterValues.contains("points=6") == true)
        XCTAssertTrue(renderLayerMask.shape?.parameterValues.contains("innerRadiusRatio=0.320000") == true)
        XCTAssertEqual(snapshotLayerMask.kind, "maskShapeRecipe")
        XCTAssertEqual(snapshotLayerMask.shape?.kind, "star")
    }

    func testLayerCompositeRenderRecipePreservesParametricCompositeMaskStepDescriptors() throws {
        let background = try makeTexture(width: 3, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 3, height: 1, pixel: [0, 0, 0, 255])
        let gradient = MaskGradientRecipe(
            size: C7Size(width: 3, height: 1),
            kind: .linear(startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5))
        )
        let shape = MaskShapeRecipe(
            size: C7Size(width: 3, height: 1),
            kind: .ellipse(rect: CGRect(x: 0, y: 0, width: 1, height: 1))
        )
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    maskRecipe: try MaskCompositeRecipe(baseRecipe: gradient).intersecting(
                        shape,
                        name: "subjectIntersect"
                    )
                )
            ]
        )

        let renderRecipe = try recipe.makeRenderRecipe()
        let layerMask = try XCTUnwrap(renderRecipe.layerMasks?.first)
        let step = try XCTUnwrap(layerMask.mask?.steps.first)

        XCTAssertEqual(layerMask.mask?.kind, "maskCompositeRecipe")
        XCTAssertEqual(layerMask.mask?.gradient?.kind, "linear")
        XCTAssertEqual(step.name, "subjectIntersect")
        XCTAssertEqual(step.blendMode, .multiply)
        XCTAssertEqual(step.shape?.kind, "ellipse")
    }

    func testLayerCompositeShapeMaskCanDrivePartialCoverage() throws {
        let background = try makeTexture(width: 3, height: 1, pixel: [255, 0, 0, 255])
        let layer = try makeTexture(width: 3, height: 1, pixel: [0, 0, 255, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskShapeRecipe(
                        size: C7Size(width: 3, height: 1),
                        kind: .rectangle(rect: CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1))
                    )
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let left = try pixel(in: output, x: 0, y: 0)
        let center = try pixel(in: output, x: 1, y: 0)
        let right = try pixel(in: output, x: 2, y: 0)

        XCTAssertGreaterThan(left.red, 240)
        XCTAssertLessThan(center.red, 20)
        XCTAssertGreaterThan(right.red, 240)
        XCTAssertGreaterThan(center.blue, 240)
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
        let layer = try makeTexture(width: 2, height: 1, pixels: [[0, 255, 0, 255], [0, 0, 255, 255]])
        let transformedLayer = ImageLayer(
            content: .texture(layer),
            normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 1),
            transform: ImageTransformRecipe(mirrorsHorizontally: true)
        )
        let recipe = LayerCompositeRecipe(background: .texture(background), layers: [transformedLayer])

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertLessThan(outputPixel.green, 64)
        XCTAssertGreaterThan(outputPixel.blue, 180)
        XCTAssertTrue(recipe.fingerprint.contains("transform=crop=none"))
        XCTAssertTrue(recipe.fingerprint.contains("mirror=1"))
    }

    func testLayerCompositeSourceOverAccumulatesAlphaOverTranslucentBackground() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 128])
        let layer = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 128])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer), opacity: 1, blendMode: .sourceOver)]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(outputPixel.red, 128, accuracy: 2)
        XCTAssertEqual(outputPixel.green, 128, accuracy: 2)
        XCTAssertEqual(outputPixel.blue, 128, accuracy: 2)
        XCTAssertEqual(outputPixel.alpha, 192, accuracy: 2)
    }

    func testLayerCompositeSourceOverKeepsOpaqueBackgroundAlpha() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [32, 64, 96, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 128])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer), opacity: 1, blendMode: .sourceOver)]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(outputPixel.alpha, 255)
    }

    func testLayerCompositeOutputContractCanForceOpaqueAlpha() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 255, 128])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 255, 128])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer), opacity: 1, blendMode: .sourceOver)],
            outputContract: RenderOutputContract(alpha: .opaque)
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(outputPixel.red, 0)
        XCTAssertEqual(outputPixel.green, 0)
        XCTAssertEqual(outputPixel.blue, 255)
        XCTAssertEqual(outputPixel.alpha, 255)
    }

    func testLayerCompositeOutputContractCanForcePremultipliedAlpha() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 255, 128])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 255, 128])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer), opacity: 1, blendMode: .sourceOver)],
            outputContract: RenderOutputContract(alpha: .forcePremultiply)
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(outputPixel.red, 0)
        XCTAssertEqual(outputPixel.green, 0)
        XCTAssertEqual(outputPixel.blue, 192, accuracy: 2)
        XCTAssertEqual(outputPixel.alpha, 192, accuracy: 2)
    }

    func testLayerCompositeOutputContractCanForceUnpremultipliedAlpha() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 128, 128])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 128, 128])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer), opacity: 1, blendMode: .sourceOver)],
            outputContract: RenderOutputContract(alpha: .forceUnpremultiply)
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(outputPixel.red, 0)
        XCTAssertEqual(outputPixel.green, 0)
        XCTAssertEqual(outputPixel.blue, 170, accuracy: 3)
        XCTAssertEqual(outputPixel.alpha, 192, accuracy: 2)
    }

    func testLayerCompositeMaskUsesLayerLocalCoordinates() throws {
        let background = try makeTexture(
            width: 5,
            height: 1,
            pixels: [
                [255, 255, 255, 255], [255, 255, 255, 255], [255, 255, 255, 255], [255, 255, 255, 255],
                [255, 255, 255, 255],
            ]
        )
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let mask = try makeTexture(width: 2, height: 1, pixels: [[255, 0, 0, 255], [0, 0, 0, 255]])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    normalizedFrame: CGRect(x: 0.25, y: 0, width: 0.25, height: 1),
                    opacity: 1,
                    blendMode: .sourceOver,
                    mask: MaskDescriptor(texture: mask, component: .red, opacity: 1),
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let first = try pixel(in: output, x: 0, y: 0)
        let second = try pixel(in: output, x: 1, y: 0)
        let third = try pixel(in: output, x: 2, y: 0)
        let fourth = try pixel(in: output, x: 3, y: 0)
        let fifth = try pixel(in: output, x: 4, y: 0)

        XCTAssertEqual(first.red, 255)
        XCTAssertEqual(first.green, 255)
        XCTAssertEqual(first.blue, 255)
        XCTAssertEqual(second.red, 0)
        XCTAssertEqual(second.green, 0)
        XCTAssertEqual(second.blue, 0)
        XCTAssertEqual(third.red, 255)
        XCTAssertEqual(third.green, 255)
        XCTAssertEqual(third.blue, 255)
        XCTAssertEqual(fourth.red, 255)
        XCTAssertEqual(fourth.green, 255)
        XCTAssertEqual(fourth.blue, 255)
        XCTAssertEqual(fifth.red, 255)
        XCTAssertEqual(fifth.green, 255)
        XCTAssertEqual(fifth.blue, 255)
    }

    func testLayerCompositeTintUsesTintColorAndTintAlphaAsLayerOpacity() throws {
        let background = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [0, 0, 0, 255]])
        let layer = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1),
                    opacity: 1,
                    blendMode: .sourceOver,
                    tintColor: SIMD4<Float>(1, 1, 0, 0.5)
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let first = try pixel(in: output, x: 0, y: 0)
        let second = try pixel(in: output, x: 1, y: 0)

        XCTAssertEqual(first.red, 128, accuracy: 2)
        XCTAssertEqual(first.green, 128, accuracy: 2)
        XCTAssertEqual(first.blue, 0, accuracy: 2)
        XCTAssertEqual(first.alpha, 255)
        XCTAssertEqual(second.red, 0)
        XCTAssertEqual(second.green, 0)
        XCTAssertEqual(second.blue, 0)
        XCTAssertEqual(second.alpha, 255)
    }

    func testLayerCompositeTintWithZeroAlphaKeepsOriginalLayerColor() throws {
        let background = try makeTexture(width: 2, height: 1, pixels: [[0, 0, 0, 255], [0, 0, 0, 255]])
        let layer = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1),
                    opacity: 1,
                    blendMode: .sourceOver,
                    tintColor: SIMD4<Float>(1, 1, 0, 0)
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let first = try pixel(in: output, x: 0, y: 0)
        let second = try pixel(in: output, x: 1, y: 0)

        XCTAssertEqual(first.red, 255)
        XCTAssertEqual(first.green, 255)
        XCTAssertEqual(first.blue, 255)
        XCTAssertEqual(first.alpha, 255)
        XCTAssertEqual(second.red, 0)
        XCTAssertEqual(second.green, 0)
        XCTAssertEqual(second.blue, 0)
        XCTAssertEqual(second.alpha, 255)
    }

    func testLayerCompositeMaskOpacityModulatesCoverage() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let mask = try makeTexture(width: 1, height: 1, pixel: [255, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    opacity: 1,
                    blendMode: .sourceOver,
                    mask: MaskDescriptor(texture: mask, component: .red, opacity: 0.5)
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(outputPixel.red, 128, accuracy: 2)
        XCTAssertEqual(outputPixel.green, 128, accuracy: 2)
        XCTAssertEqual(outputPixel.blue, 128, accuracy: 2)
        XCTAssertEqual(outputPixel.alpha, 255)
    }

    func testLayerCompositeMaskRecipeBuildsReusableCoverageForLayerMask() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let baseMask = try makeTexture(width: 1, height: 1, pixel: [255, 0, 0, 255])
        let subtractMask = try makeTexture(width: 1, height: 1, pixel: [128, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    opacity: 1,
                    blendMode: .sourceOver,
                    maskRecipe: MaskCompositeRecipe(
                        baseMask: MaskDescriptor(texture: baseMask, component: .red),
                        steps: [
                            MaskCompositeStep(
                                name: "soft-subtract",
                                mask: MaskDescriptor(
                                    texture: subtractMask,
                                    component: .red,
                                    blendMode: .subtract,
                                    opacity: 1
                                )
                            )
                        ]
                    )
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(outputPixel.red, 128, accuracy: 4)
        XCTAssertEqual(outputPixel.green, 128, accuracy: 4)
        XCTAssertEqual(outputPixel.blue, 128, accuracy: 4)
        XCTAssertEqual(outputPixel.alpha, 255)
    }

    func testLayerCompositeCompositingMaskOpacityModulatesCoverage() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let compositingMask = try makeTexture(width: 1, height: 1, pixel: [255, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    opacity: 1,
                    blendMode: .sourceOver,
                    compositingMask: MaskDescriptor(texture: compositingMask, component: .red, opacity: 0.5)
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(outputPixel.red, 128, accuracy: 2)
        XCTAssertEqual(outputPixel.green, 128, accuracy: 2)
        XCTAssertEqual(outputPixel.blue, 128, accuracy: 2)
        XCTAssertEqual(outputPixel.alpha, 255)
    }

    func testLayerCompositeCompositingMaskRecipeBuildsReusableCoverage() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let baseMask = try makeTexture(width: 1, height: 1, pixel: [255, 0, 0, 255])
        let subtractMask = try makeTexture(width: 1, height: 1, pixel: [128, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    opacity: 1,
                    blendMode: .sourceOver,
                    compositingMaskRecipe: MaskCompositeRecipe(
                        baseMask: MaskDescriptor(texture: baseMask, component: .red),
                        steps: [
                            MaskCompositeStep(
                                name: "soft-subtract",
                                mask: MaskDescriptor(
                                    texture: subtractMask,
                                    component: .red,
                                    blendMode: .subtract,
                                    opacity: 1
                                )
                            )
                        ]
                    )
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(outputPixel.red, 128, accuracy: 4)
        XCTAssertEqual(outputPixel.green, 128, accuracy: 4)
        XCTAssertEqual(outputPixel.blue, 128, accuracy: 4)
        XCTAssertEqual(outputPixel.alpha, 255)
    }

    func testLayerCompositeFingerprintTracksMaskOpacity() throws {
        let layer = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let mask = try makeTexture(width: 1, height: 1, pixel: [255, 0, 0, 255])
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let firstRecipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskDescriptor(texture: mask, component: .red, opacity: 0.25)
                )
            ]
        )
        let secondRecipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskDescriptor(texture: mask, component: .red, opacity: 0.75)
                )
            ]
        )

        XCTAssertNotEqual(firstRecipe.fingerprint, secondRecipe.fingerprint)
    }

    func testLayerCompositeFingerprintTracksMaskRecipe() throws {
        let layer = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let baseMask = try makeTexture(width: 1, height: 1, pixel: [255, 0, 0, 255])
        let overlayMask = try makeTexture(width: 1, height: 1, pixel: [128, 0, 0, 255])
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let firstRecipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    maskRecipe: MaskCompositeRecipe(
                        baseMask: MaskDescriptor(texture: baseMask, component: .red),
                        steps: [
                            MaskCompositeStep(
                                name: "multiply-soft",
                                mask: MaskDescriptor(
                                    texture: overlayMask,
                                    component: .red,
                                    blendMode: .multiply,
                                    opacity: 0.5
                                )
                            )
                        ]
                    )
                )
            ]
        )
        let secondRecipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    maskRecipe: MaskCompositeRecipe(
                        baseMask: MaskDescriptor(texture: baseMask, component: .red),
                        steps: [
                            MaskCompositeStep(
                                name: "multiply-hard",
                                mask: MaskDescriptor(
                                    texture: overlayMask,
                                    component: .red,
                                    blendMode: .multiply,
                                    opacity: 1
                                )
                            )
                        ]
                    )
                )
            ]
        )

        XCTAssertTrue(firstRecipe.fingerprint.contains("recipe{"))
        XCTAssertNotEqual(firstRecipe.fingerprint, secondRecipe.fingerprint)
    }

    func testLayerCompositeFingerprintTracksCompositingMaskRecipe() throws {
        let layer = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let baseMask = try makeTexture(width: 1, height: 1, pixel: [255, 0, 0, 255])
        let overlayMask = try makeTexture(width: 1, height: 1, pixel: [128, 0, 0, 255])
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let firstRecipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    compositingMaskRecipe: MaskCompositeRecipe(
                        baseMask: MaskDescriptor(texture: baseMask, component: .red),
                        steps: [
                            MaskCompositeStep(
                                name: "subtract-soft",
                                mask: MaskDescriptor(
                                    texture: overlayMask,
                                    component: .red,
                                    blendMode: .subtract,
                                    opacity: 0.5
                                )
                            )
                        ]
                    )
                )
            ]
        )
        let secondRecipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    compositingMaskRecipe: MaskCompositeRecipe(
                        baseMask: MaskDescriptor(texture: baseMask, component: .red),
                        steps: [
                            MaskCompositeStep(
                                name: "subtract-hard",
                                mask: MaskDescriptor(
                                    texture: overlayMask,
                                    component: .red,
                                    blendMode: .subtract,
                                    opacity: 1
                                )
                            )
                        ]
                    )
                )
            ]
        )

        XCTAssertTrue(firstRecipe.fingerprint.contains("compositingMask=recipe{"))
        XCTAssertNotEqual(firstRecipe.fingerprint, secondRecipe.fingerprint)
    }

    func testLayerCompositeMaskFeatherModulatesCoverageCurve() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let mask = try makeTexture(width: 1, height: 1, pixel: [64, 0, 0, 255])
        let hardRecipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskDescriptor(texture: mask, component: .red, featherPolicy: .none, opacity: 1)
                )
            ]
        )
        let softRecipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskDescriptor(texture: mask, component: .red, featherPolicy: .normalized(1), opacity: 1)
                )
            ]
        )

        let hardOutput = try ImageNode.layerComposite(hardRecipe).makeTexture()
        let softOutput = try ImageNode.layerComposite(softRecipe).makeTexture()
        let hardPixel = try pixel(in: hardOutput, x: 0, y: 0)
        let softPixel = try pixel(in: softOutput, x: 0, y: 0)

        XCTAssertEqual(hardPixel.red, 191, accuracy: 3)
        XCTAssertEqual(softPixel.red, 215, accuracy: 3)
        XCTAssertGreaterThan(softPixel.red, hardPixel.red)
    }

    func testLayerCompositeCompositingMaskFeatherModulatesCoverageCurve() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let mask = try makeTexture(width: 1, height: 1, pixel: [64, 0, 0, 255])
        let hardRecipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    compositingMask: MaskDescriptor(texture: mask, component: .red, featherPolicy: .none, opacity: 1)
                )
            ]
        )
        let softRecipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    compositingMask: MaskDescriptor(
                        texture: mask,
                        component: .red,
                        featherPolicy: .normalized(1),
                        opacity: 1
                    )
                )
            ]
        )

        let hardOutput = try ImageNode.layerComposite(hardRecipe).makeTexture()
        let softOutput = try ImageNode.layerComposite(softRecipe).makeTexture()
        let hardPixel = try pixel(in: hardOutput, x: 0, y: 0)
        let softPixel = try pixel(in: softOutput, x: 0, y: 0)

        XCTAssertEqual(hardPixel.red, 191, accuracy: 3)
        XCTAssertEqual(softPixel.red, 215, accuracy: 3)
        XCTAssertGreaterThan(softPixel.red, hardPixel.red)
    }

    func testLayerCompositeCompositingMaskReplaceOverridesExistingLayerMaskCoverage() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let mask = try makeTexture(width: 1, height: 1, pixel: [64, 0, 0, 255])
        let compositingMask = try makeTexture(width: 1, height: 1, pixel: [128, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskDescriptor(texture: mask, component: .red, blendMode: .mix, opacity: 1),
                    compositingMask: MaskDescriptor(
                        texture: compositingMask,
                        component: .red,
                        blendMode: .replace,
                        opacity: 1
                    )
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let pixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(pixel.red, 127, accuracy: 3)
        XCTAssertEqual(pixel.green, 127, accuracy: 3)
        XCTAssertEqual(pixel.blue, 127, accuracy: 3)
    }

    func testLayerCompositeCompositingMaskAddCombinesWithExistingLayerMaskCoverage() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let mask = try makeTexture(width: 1, height: 1, pixel: [64, 0, 0, 255])
        let compositingMask = try makeTexture(width: 1, height: 1, pixel: [128, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskDescriptor(texture: mask, component: .red, blendMode: .mix, opacity: 1),
                    compositingMask: MaskDescriptor(
                        texture: compositingMask,
                        component: .red,
                        blendMode: .add,
                        opacity: 1
                    )
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let pixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(pixel.red, 63, accuracy: 4)
        XCTAssertEqual(pixel.green, 63, accuracy: 4)
        XCTAssertEqual(pixel.blue, 63, accuracy: 4)
    }

    func testLayerCompositeCompositingMaskMultiplyCombinesWithExistingLayerMaskCoverage() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let mask = try makeTexture(width: 1, height: 1, pixel: [64, 0, 0, 255])
        let compositingMask = try makeTexture(width: 1, height: 1, pixel: [128, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskDescriptor(texture: mask, component: .red, blendMode: .mix, opacity: 1),
                    compositingMask: MaskDescriptor(
                        texture: compositingMask,
                        component: .red,
                        blendMode: .multiply,
                        opacity: 1
                    )
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let pixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(pixel.red, 223, accuracy: 4)
        XCTAssertEqual(pixel.green, 223, accuracy: 4)
        XCTAssertEqual(pixel.blue, 223, accuracy: 4)
    }

    func testLayerCompositeCompositingMaskSubtractRemovesCoverageFromExistingLayerMask() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let mask = try makeTexture(width: 1, height: 1, pixel: [192, 0, 0, 255])
        let compositingMask = try makeTexture(width: 1, height: 1, pixel: [128, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskDescriptor(texture: mask, component: .red, blendMode: .mix, opacity: 1),
                    compositingMask: MaskDescriptor(
                        texture: compositingMask,
                        component: .red,
                        blendMode: .subtract,
                        opacity: 1
                    )
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let pixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(pixel.red, 159, accuracy: 4)
        XCTAssertEqual(pixel.green, 159, accuracy: 4)
        XCTAssertEqual(pixel.blue, 159, accuracy: 4)
    }

    func testLayerCompositeProgrammableBlendUsesPreparedLayerCanvas() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [64, 64, 64, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [64, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    programmableBlend: LayerProgrammableBlend(
                        functionName: "C7BlendColorAdd",
                        intensity: 1,
                        librarySource: .sourceFallback("layer-programmable-blend")
                    )
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let pixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(pixel.red, 128, accuracy: 3)
        XCTAssertEqual(pixel.green, 64, accuracy: 3)
        XCTAssertEqual(pixel.blue, 64, accuracy: 3)
        XCTAssertEqual(pixel.alpha, 255, accuracy: 2)
    }

    func testLayerCompositeProgrammableBlendPreservesLayerMaskCoverageAcrossPixels() throws {
        let background = try makeTexture(width: 2, height: 1, pixels: [[64, 64, 64, 255], [64, 64, 64, 255]])
        let layer = try makeTexture(width: 2, height: 1, pixels: [[64, 0, 0, 255], [64, 0, 0, 255]])
        let mask = try makeTexture(width: 2, height: 1, pixels: [[255, 0, 0, 255], [0, 0, 0, 255]])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    mask: MaskDescriptor(texture: mask, component: .red),
                    programmableBlend: LayerProgrammableBlend(
                        functionName: "C7BlendColorAdd",
                        intensity: 1,
                        librarySource: .sourceFallback("layer-programmable-blend")
                    )
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let first = try pixel(in: output, x: 0, y: 0)
        let second = try pixel(in: output, x: 1, y: 0)

        XCTAssertEqual(first.red, 128, accuracy: 3)
        XCTAssertEqual(first.green, 64, accuracy: 3)
        XCTAssertEqual(first.blue, 64, accuracy: 3)
        XCTAssertEqual(first.alpha, 255, accuracy: 2)
        XCTAssertEqual(second.red, 64, accuracy: 3)
        XCTAssertEqual(second.green, 64, accuracy: 3)
        XCTAssertEqual(second.blue, 64, accuracy: 3)
        XCTAssertEqual(second.alpha, 255, accuracy: 2)
    }

    func testLayerCompositeProgrammableBlendPreservesLayerFrameCoverageAcrossPixels() throws {
        let background = try makeTexture(width: 2, height: 1, pixels: [[64, 64, 64, 255], [64, 64, 64, 255]])
        let layer = try makeTexture(width: 1, height: 1, pixel: [64, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1),
                    programmableBlend: LayerProgrammableBlend(
                        functionName: "C7BlendColorAdd",
                        intensity: 1,
                        librarySource: .sourceFallback("layer-programmable-blend")
                    )
                )
            ]
        )

        let output = try ImageNode.layerComposite(recipe).makeTexture()
        let first = try pixel(in: output, x: 0, y: 0)
        let second = try pixel(in: output, x: 1, y: 0)

        XCTAssertEqual(first.red, 128, accuracy: 3)
        XCTAssertEqual(first.green, 64, accuracy: 3)
        XCTAssertEqual(first.blue, 64, accuracy: 3)
        XCTAssertEqual(first.alpha, 255, accuracy: 2)
        XCTAssertEqual(second.red, 64, accuracy: 3)
        XCTAssertEqual(second.green, 64, accuracy: 3)
        XCTAssertEqual(second.blue, 64, accuracy: 3)
        XCTAssertEqual(second.alpha, 255, accuracy: 2)
    }

    func testLayerCompositeFingerprintTracksProgrammableBlendDescriptor() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let basicRecipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [ImageLayer(content: .texture(layer))]
        )
        let programmableRecipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    programmableBlend: LayerProgrammableBlend(
                        functionName: "C7BlendSourceOver",
                        intensity: 0.75,
                        librarySource: .sourceFallback("layer-programmable-blend"),
                        functionConstants: [
                            KernelFunctionConstantDescriptor(name: "useRightSample", index: 0, value: .bool(true))
                        ]
                    )
                )
            ]
        )

        XCTAssertNotEqual(basicRecipe.fingerprint, programmableRecipe.fingerprint)
    }

    func testLayerCompositeProgrammableBlendIsVisibleInRenderPlanDiagnostics() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [64, 64, 64, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [64, 0, 0, 255])
        let recipe = LayerCompositeRecipe(
            background: .texture(background),
            layers: [
                ImageLayer(
                    content: .texture(layer),
                    programmableBlend: LayerProgrammableBlend(
                        functionName: "C7BlendColorAdd",
                        intensity: 1,
                        librarySource: .sourceFallback("layer-programmable-blend"),
                        functionConstants: [
                            KernelFunctionConstantDescriptor(name: "useRightSample", index: 0, value: .bool(true))
                        ]
                    )
                )
            ]
        )

        let plan = try ImageNode.layerComposite(recipe).makeRenderPlan()
        let advancedMetalNode = try XCTUnwrap(
            plan.diagnostics.nodes.first(where: {
                $0.kind == .advancedMetal && $0.name.contains("C7ProgrammableBlend")
            })
        )

        XCTAssertEqual(plan.diagnostics.compilationSource, .layerComposite)
        XCTAssertTrue(plan.graph.nodes.contains(where: { $0.kind == .advancedMetal }))
        XCTAssertGreaterThanOrEqual(plan.diagnostics.stageCount, 2)
        XCTAssertEqual(advancedMetalNode.parameterSummary["functionName"], "C7BlendColorAdd")
        XCTAssertEqual(
            advancedMetalNode.parameterSummary["librarySource"],
            "library=sourceFallback:layer-programmable-blend"
        )
        XCTAssertTrue(
            advancedMetalNode.parameterSummary["functionConstants"]?.contains(
                "constant=useRightSample|index=0|value=bool:1"
            ) == true
        )
    }

    func testLayerCompositeFingerprintTracksLayerTransformAndFilterParameters() throws {
        let background = try makeTexture(width: 1, height: 1, pixel: [0, 0, 0, 255])
        let layer = try makeTexture(width: 1, height: 1, pixel: [255, 255, 255, 255])
        let identityLayer = ImageLayer(content: .texture(layer))
        let transformedLayer = ImageLayer(
            content: .texture(layer),
            transform: ImageTransformRecipe(rotationDegrees: 90)
        )
        let filteredLayer = ImageLayer(content: .texture(layer), filters: [C7Brightness(brightness: 0.2)])

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
        let recipeNode = ImageNode.recipe(source: .texture(from), recipe: EditRecipe(), mode: .preview)
            .applying(C7Brightness(brightness: 0.1))
        let transitionNode = ImageNode.transition(
            TransitionRecipe(from: .texture(from), to: .texture(to), kernel: .dissolve, progress: 0.5)
        )

        let recipeDiagnostics = try recipeNode.makeDiagnostics()
        let transitionDiagnostics = try transitionNode.makeDiagnostics()

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
            kCVPixelBufferIOSurfacePropertiesKey: [:],
        ]
        let creationStatus = CVPixelBufferCreate(
            kCFAllocatorDefault,
            4,
            4,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard creationStatus == kCVReturnSuccess else {
            throw XCTSkip("Failed to create bi-planar pixel buffer.")
        }
        guard let pixelBuffer else {
            throw XCTSkip("Failed to create bi-planar pixel buffer.")
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

    func testRenderOutputContractTracksWideGamutHighPrecisionAndHDROutputs() {
        let displayP3 = RenderOutputContract.displayP3Texture
        let highPrecision = RenderOutputContract.highPrecisionLinearTexture
        let linearDisplayP3 = RenderOutputContract.highPrecisionLinearDisplayP3Texture
        let hdrPQ = RenderOutputContract.hdrPQTexture
        let toneMapped = RenderOutputContract.toneMappedDisplayP3Texture

        XCTAssertTrue(displayP3.isWideGamutOutput)
        XCTAssertFalse(displayP3.isHighPrecisionOutput)
        XCTAssertTrue(displayP3.isHDRFriendlyOutput)
        XCTAssertEqual(displayP3.toneMappingPolicy, .preserveInput)
        XCTAssertEqual(displayP3.colorSpace.gamut, .displayP3)
        XCTAssertEqual(displayP3.colorSpace.transferFunction, .sRGB)
        XCTAssertEqual(displayP3.pixelFormat.precision, .unorm8)

        XCTAssertTrue(highPrecision.isWideGamutOutput)
        XCTAssertTrue(highPrecision.isHighPrecisionOutput)
        XCTAssertTrue(highPrecision.isHDRFriendlyOutput)
        XCTAssertEqual(highPrecision.toneMappingPolicy, .preserveInput)
        XCTAssertEqual(highPrecision.colorSpace.transferFunction, .linear)
        XCTAssertEqual(highPrecision.pixelFormat.precision, .float16)
        XCTAssertTrue(highPrecision.fingerprint.contains("gamut=extendedLinearSRGB"))
        XCTAssertTrue(highPrecision.fingerprint.contains("precision=float16"))

        XCTAssertTrue(linearDisplayP3.isWideGamutOutput)
        XCTAssertTrue(linearDisplayP3.isHighPrecisionOutput)
        XCTAssertTrue(linearDisplayP3.isHDRFriendlyOutput)
        XCTAssertEqual(linearDisplayP3.toneMappingPolicy, .preserveInput)
        XCTAssertEqual(linearDisplayP3.colorSpace.gamut, .displayP3)
        XCTAssertEqual(linearDisplayP3.colorSpace.transferFunction, .linear)
        XCTAssertEqual(linearDisplayP3.pixelFormat.precision, .float16)
        XCTAssertTrue(linearDisplayP3.fingerprint.contains("color=extendedLinearDisplayP3"))

        XCTAssertTrue(hdrPQ.isHDRFriendlyOutput)
        XCTAssertEqual(hdrPQ.toneMappingPolicy, .toneMapToHDR)
        XCTAssertEqual(hdrPQ.colorSpace.gamut, .ituR2020)
        XCTAssertEqual(hdrPQ.colorSpace.transferFunction, .perceptualQuantizer)
        XCTAssertEqual(hdrPQ.pixelFormat.precision, .float16)
        XCTAssertTrue(hdrPQ.fingerprint.contains("toneMap=toneMapToHDR"))

        XCTAssertTrue(toneMapped.isWideGamutOutput)
        XCTAssertEqual(toneMapped.toneMappingPolicy, .toneMapToSDR)
        XCTAssertEqual(toneMapped.colorSpace.gamut, .displayP3)
        XCTAssertEqual(toneMapped.pixelFormat.precision, .unorm8)
        XCTAssertTrue(toneMapped.fingerprint.contains("toneMap=toneMapToSDR"))
        XCTAssertEqual(toneMapped.quantization, .automatic)
        XCTAssertTrue(toneMapped.fingerprint.contains("dither=ordered4x4"))
    }

    func testOutputContractQuantizesAfterHighPrecisionRendering() throws {
        let source = try makeTexture(pixel: [120, 80, 40, 255])
        let highPrecision = try ImageNode.applyOutputContractIfNeeded(
            .highPrecisionLinearTexture,
            to: source,
            profile: .stablePreview
        )
        let contract = RenderOutputContract(
            pixelFormat: .rgba8Unorm,
            quantization: OutputQuantizationContract(bitDepth: 6, ditherPattern: .ordered4x4)
        )

        let output = try ImageNode.applyOutputContractIfNeeded(
            contract,
            to: highPrecision,
            profile: .stablePreview
        )
        let pixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertEqual(highPrecision.pixelFormat, .rgba16Float)
        XCTAssertEqual(output.pixelFormat, .rgba8Unorm)
        XCTAssertNotEqual(pixel.red, 120)
        XCTAssertEqual(pixel.alpha, 255)
    }

    func testHDRColorSpaceContractsExposeCoreGraphicsHDRSpaces() {
        XCTAssertEqual(ImageColorSpaceContract.hdrPQ.dynamicRange, .highDynamicRange)
        XCTAssertEqual(ImageColorSpaceContract.hdrHLG.dynamicRange, .highDynamicRange)

        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, *) {
            let pq = ImageColorSpaceContract.hdrPQ.cgColorSpace
            let hlg = ImageColorSpaceContract.hdrHLG.cgColorSpace

            XCTAssertEqual(pq, CGColorSpace(name: CGColorSpace.itur_2100_PQ))
            XCTAssertEqual(hlg, CGColorSpace(name: CGColorSpace.itur_2100_HLG))
            if let hlg { XCTAssertTrue(CGColorSpaceIsHLGBased(hlg)) }
        }
    }

    func testHDRToneMappingPolicyBuildsExpectedFilters() {
        let hdr = ImageColorSpaceContract.hdrPQ
        let sdr = ImageColorSpaceContract.displayP3

        let sdrFilters = ImageToneMappingPolicy.toneMapToSDR.makeToneMappingFilters(
            sourceColorSpace: hdr,
            targetColorSpace: sdr
        )
        let hdrFilters = ImageToneMappingPolicy.toneMapToHDR.makeToneMappingFilters(
            sourceColorSpace: hdr,
            targetColorSpace: hdr
        )

        XCTAssertEqual(sdrFilters.count, 2)
        XCTAssertTrue(sdrFilters[0] is C7HighlightShadowTone)
        XCTAssertTrue(sdrFilters[1] is C7Exposure)
        XCTAssertTrue(hdrFilters.isEmpty)
    }

    func testRenderOutputContractToneMapsHDRSourceIntoSDROutput() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [240, 180, 90, 255])
        let output = try ImageNode.applyOutputContractIfNeeded(
            .toneMappedDisplayP3Texture,
            to: input,
            sourceColorSpace: .hdrPQ,
            profile: .stablePreview
        )
        let outputPixel = try pixel(in: output, x: 0, y: 0)
        let inputPixel = try pixel(in: input, x: 0, y: 0)

        XCTAssertNotEqual(ObjectIdentifier(output), ObjectIdentifier(input))
        XCTAssertFalse(
            outputPixel.red == inputPixel.red && outputPixel.green == inputPixel.green
                && outputPixel.blue == inputPixel.blue
        )
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
        XCTAssertTrue(plan.diagnostics.summary.contains("toneMapping=preserveInput"))
        XCTAssertEqual(plan.diagnostics.outputColorSpace, .extendedLinearSRGB)
        XCTAssertEqual(plan.diagnostics.outputPixelFormat, .rgba16Float)
    }

    func testKernelNodeMaterializesPixelFormatOutputContract() throws {
        let input = try makeTexture(width: 2, height: 2, pixel: [120, 80, 40, 255])
        let descriptor = KernelDescriptor(
            filterName: "identityHighPrecision",
            functionIdentity: KernelFunctionIdentity(kind: .compute, primaryName: "C7Brightness"),
            pixelContract: C7Brightness(brightness: 0).kernelPixelContract,
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

    func testColorTransferConversionRunsOnlyForExplicitCompatibleContracts() throws {
        let linearITU2020 = ImageColorSpaceContract(
            name: "linearITU2020",
            preservesInput: false,
            gamut: .ituR2020,
            transferFunction: .linear
        )

        XCTAssertEqual(ImageColorSpaceContract.extendedLinearSRGB.transferConversionMode(from: .sRGB), .sRGBToLinear)
        XCTAssertEqual(
            ImageColorSpaceContract.extendedLinearDisplayP3.transferConversionMode(from: .displayP3),
            .sRGBToLinear
        )
        XCTAssertEqual(ImageColorSpaceContract.sRGB.transferConversionMode(from: .extendedLinearSRGB), .linearToSRGB)
        XCTAssertEqual(
            ImageColorSpaceContract.displayP3.transferConversionMode(from: .extendedLinearDisplayP3),
            .linearToSRGB
        )
        XCTAssertEqual(ImageColorSpaceContract.hdrPQ.transferConversionMode(from: linearITU2020), .linearToPQ)
        XCTAssertEqual(linearITU2020.transferConversionMode(from: ImageColorSpaceContract.hdrPQ), .pqToLinear)
        XCTAssertEqual(ImageColorSpaceContract.hdrHLG.transferConversionMode(from: linearITU2020), .linearToHLG)
        XCTAssertEqual(linearITU2020.transferConversionMode(from: ImageColorSpaceContract.hdrHLG), .hlgToLinear)
        XCTAssertNil(ImageColorSpaceContract.displayP3.transferConversionMode(from: .sRGB))
        XCTAssertNil(ImageColorSpaceContract.extendedLinearSRGB.transferConversionMode(from: .preserveInput))

        let input = try makeTexture(width: 1, height: 1, pixel: [128, 128, 128, 255])
        let output = try HarbethIO(element: input, filter: C7RGBTransferConversion(mode: .sRGBToLinear)).output()
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertLessThan(outputPixel.red, 80)
        XCTAssertGreaterThan(outputPixel.red, 40)
        XCTAssertEqual(outputPixel.red, outputPixel.green)
        XCTAssertEqual(outputPixel.green, outputPixel.blue)
        XCTAssertEqual(outputPixel.alpha, 255)
    }

    func testHDRColorSpaceConversionFiltersBridgeThroughLinearLight() {
        let filters = ImageColorSpaceContract.displayP3.makeColorConversionFilters(from: .hdrPQ)

        XCTAssertEqual(filters.count, 3)
        XCTAssertEqual((filters[0] as? C7RGBTransferConversion)?.mode, .pqToLinear)
        XCTAssertEqual((filters[1] as? C7RGBColorSpaceConversion)?.mode, .linearITU2020ToLinearDisplayP3)
        XCTAssertEqual((filters[2] as? C7RGBTransferConversion)?.mode, .linearToSRGB)
    }

    func testColorSpaceConversionSupportsDisplayP3AndHDRContracts() {
        XCTAssertEqual(
            ImageColorSpaceContract.displayP3.colorConversionMode(from: .sRGB),
            .linearSRGBToLinearDisplayP3
        )
        XCTAssertEqual(
            ImageColorSpaceContract.sRGB.colorConversionMode(from: .displayP3),
            .linearDisplayP3ToLinearSRGB
        )
        XCTAssertEqual(
            ImageColorSpaceContract.extendedLinearSRGB.colorConversionMode(from: .displayP3),
            .linearDisplayP3ToLinearSRGB
        )
        XCTAssertEqual(
            ImageColorSpaceContract.extendedLinearDisplayP3.colorConversionMode(from: .extendedLinearSRGB),
            .linearSRGBToLinearDisplayP3
        )
        XCTAssertEqual(
            ImageColorSpaceContract.extendedLinearSRGB.colorConversionMode(from: .extendedLinearDisplayP3),
            .linearDisplayP3ToLinearSRGB
        )
        XCTAssertEqual(
            ImageColorSpaceContract.displayP3.colorConversionMode(from: .extendedLinearSRGB),
            .linearSRGBToLinearDisplayP3
        )
        XCTAssertEqual(
            ImageColorSpaceContract.displayP3.colorConversionMode(from: ImageColorSpaceContract.hdrPQ),
            .linearITU2020ToLinearDisplayP3
        )
        XCTAssertEqual(
            ImageColorSpaceContract.hdrPQ.colorConversionMode(from: .displayP3),
            .linearDisplayP3ToLinearITU2020
        )
        XCTAssertEqual(
            ImageColorSpaceContract.extendedLinearSRGB.colorConversionMode(from: ImageColorSpaceContract.hdrPQ),
            .linearITU2020ToLinearSRGB
        )
        XCTAssertEqual(
            ImageColorSpaceContract.hdrPQ.colorConversionMode(from: .extendedLinearSRGB),
            .linearSRGBToLinearITU2020
        )
        XCTAssertEqual(
            ImageColorSpaceContract.sRGB.colorConversionMode(from: ImageColorSpaceContract.hdrPQ),
            .linearITU2020ToLinearSRGB
        )
        XCTAssertEqual(
            ImageColorSpaceContract.hdrPQ.colorConversionMode(from: .sRGB),
            .linearSRGBToLinearITU2020
        )
        XCTAssertNil(ImageColorSpaceContract.extendedLinearDisplayP3.colorConversionMode(from: .displayP3))
        XCTAssertNil(ImageColorSpaceContract.displayP3.colorConversionMode(from: .preserveInput))
        XCTAssertNil(ImageColorSpaceContract.sRGB.colorConversionMode(from: .sRGB))
    }

    func testExtendedLinearDisplayP3ContractResolvesCGColorSpace() throws {
        let colorSpace = try XCTUnwrap(ImageColorSpaceContract.extendedLinearDisplayP3.cgColorSpace)
        if #available(macOS 10.14.3, iOS 12.1, tvOS 12.1, *) {
            XCTAssertEqual(colorSpace.name as String?, CGColorSpace.extendedLinearDisplayP3 as String)
        } else {
            XCTAssertEqual(colorSpace.name as String?, CGColorSpace.displayP3 as String)
        }
    }

    func testRGBColorSpaceConversionRoundTripsSRGBAndDisplayP3() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [64, 128, 192, 255])
        let displayP3 = try HarbethIO(
            element: input,
            filters: [
                C7RGBTransferConversion(mode: .sRGBToLinear),
                C7RGBColorSpaceConversion(mode: .linearSRGBToLinearDisplayP3),
                C7RGBTransferConversion(mode: .linearToSRGB),
            ]
        ).output()
        let restored = try HarbethIO(
            element: displayP3,
            filters: [
                C7RGBTransferConversion(mode: .sRGBToLinear),
                C7RGBColorSpaceConversion(mode: .linearDisplayP3ToLinearSRGB),
                C7RGBTransferConversion(mode: .linearToSRGB),
            ]
        ).output()
        let restoredPixel = try pixel(in: restored, x: 0, y: 0)

        XCTAssertEqual(restoredPixel.red, 64, accuracy: 3)
        XCTAssertEqual(restoredPixel.green, 128, accuracy: 3)
        XCTAssertEqual(restoredPixel.blue, 192, accuracy: 3)
        XCTAssertEqual(restoredPixel.alpha, 255)
    }

    func testKernelNodeExecutesExplicitColorTransferOutputContract() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [128, 128, 128, 255])
        let descriptor = KernelDescriptor(
            filterName: "identityLinearOutput",
            functionIdentity: KernelFunctionIdentity(kind: .compute, primaryName: "C7Brightness"),
            pixelContract: C7Brightness(brightness: 0).kernelPixelContract,
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

    func testKernelNodeExecutesDisplayP3OutputContract() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [64, 128, 192, 255])
        let descriptor = KernelDescriptor(
            filterName: "identityDisplayP3Output",
            functionIdentity: KernelFunctionIdentity(kind: .compute, primaryName: "C7Brightness"),
            pixelContract: C7Brightness(brightness: 0).kernelPixelContract,
            inputColorSpace: .sRGB,
            outputContract: RenderOutputContract(colorSpace: .displayP3)
        )
        let node = ImageNode.kernel(
            input: .source(.texture(input)),
            descriptor: descriptor,
            filter: C7Brightness(brightness: 0)
        )

        let output = try node.makeTexture(profile: .stablePreview)
        let manual = try HarbethIO(
            element: input,
            filters: [
                C7RGBTransferConversion(mode: .sRGBToLinear),
                C7RGBColorSpaceConversion(mode: .linearSRGBToLinearDisplayP3),
                C7RGBTransferConversion(mode: .linearToSRGB),
            ]
        ).output()
        let outputPixel = try pixel(in: output, x: 0, y: 0)
        let manualPixel = try pixel(in: manual, x: 0, y: 0)

        XCTAssertEqual(outputPixel.red, manualPixel.red, accuracy: 2)
        XCTAssertEqual(outputPixel.green, manualPixel.green, accuracy: 2)
        XCTAssertEqual(outputPixel.blue, manualPixel.blue, accuracy: 2)
        XCTAssertEqual(outputPixel.alpha, 255)
    }

    func testKernelNodeExecutesExtendedLinearDisplayP3OutputContract() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [64, 128, 192, 255])
        let descriptor = KernelDescriptor(
            filterName: "identityExtendedLinearDisplayP3Output",
            functionIdentity: KernelFunctionIdentity(kind: .compute, primaryName: "C7Brightness"),
            pixelContract: C7Brightness(brightness: 0).kernelPixelContract,
            inputColorSpace: .sRGB,
            outputContract: RenderOutputContract(colorSpace: .extendedLinearDisplayP3)
        )
        let node = ImageNode.kernel(
            input: .source(.texture(input)),
            descriptor: descriptor,
            filter: C7Brightness(brightness: 0)
        )

        let output = try node.makeTexture(profile: .stablePreview)
        let manual = try HarbethIO(
            element: input,
            filters: [
                C7RGBTransferConversion(mode: .sRGBToLinear),
                C7RGBColorSpaceConversion(mode: .linearSRGBToLinearDisplayP3),
            ]
        ).output()
        let outputPixel = try pixel(in: output, x: 0, y: 0)
        let manualPixel = try pixel(in: manual, x: 0, y: 0)

        XCTAssertEqual(outputPixel.red, manualPixel.red, accuracy: 2)
        XCTAssertEqual(outputPixel.green, manualPixel.green, accuracy: 2)
        XCTAssertEqual(outputPixel.blue, manualPixel.blue, accuracy: 2)
        XCTAssertEqual(outputPixel.alpha, 255)
    }

    func testApplyOutputContractSkipsRedundantPremultiplyPass() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [64, 32, 16, 128])

        let output = try ImageNode.applyOutputContractIfNeeded(
            RenderOutputContract(alpha: .premultiplied),
            to: input,
            sourceAlphaType: .premultiplied,
            profile: .stablePreview
        )

        XCTAssertEqual(ObjectIdentifier(output), ObjectIdentifier(input))
    }

    func testApplyOutputContractSkipsRedundantUnpremultiplyPass() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [64, 32, 16, 128])

        let output = try ImageNode.applyOutputContractIfNeeded(
            RenderOutputContract(alpha: .nonPremultiplied),
            to: input,
            sourceAlphaType: .nonPremultiplied,
            profile: .stablePreview
        )

        XCTAssertEqual(ObjectIdentifier(output), ObjectIdentifier(input))
    }

    func testApplyOutputContractSkipsRedundantOpaquePass() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [64, 32, 16, 255])

        let output = try ImageNode.applyOutputContractIfNeeded(
            RenderOutputContract(alpha: .opaque),
            to: input,
            sourceAlphaType: .alphaIsOne,
            profile: .stablePreview
        )

        XCTAssertEqual(ObjectIdentifier(output), ObjectIdentifier(input))
    }

    func testApplyOutputContractMaterializesAlphaPassWhenSourceAlphaDiffers() throws {
        let input = try makeTexture(width: 1, height: 1, pixel: [128, 64, 32, 128])

        let output = try ImageNode.applyOutputContractIfNeeded(
            RenderOutputContract(alpha: .premultiplied),
            to: input,
            sourceAlphaType: .nonPremultiplied,
            profile: .stablePreview
        )
        let outputPixel = try pixel(in: output, x: 0, y: 0)

        XCTAssertNotEqual(ObjectIdentifier(output), ObjectIdentifier(input))
        XCTAssertLessThan(outputPixel.red, 128)
        XCTAssertEqual(outputPixel.alpha, 128, accuracy: 1)
    }

    func testRenderOutputContractDecodesOlderColorAndPixelFormatPayloads() throws {
        let colorData = Data(
            """
            {"name":"sRGB","preservesInput":false}
            """.utf8
        )
        let pixelData = Data(
            """
            {"name":"rgba8Unorm","preservesInput":false}
            """.utf8
        )

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
        let coverage = RenderOutputAttachmentContract.coverage(index: 6, pixelFormat: .r16Float)
        let luminance = RenderOutputAttachmentContract.luminance(index: 3)
        let analysis = RenderOutputAttachmentContract.analysis(index: 4)
        let histogram = RenderOutputAttachmentContract.histogram(index: 5)

        XCTAssertEqual(auxiliary.semantic, .auxiliaryColor)
        XCTAssertEqual(auxiliary.colorSpace.gamut, .displayP3)
        XCTAssertEqual(mask.semantic, .maskCoverage)
        XCTAssertEqual(mask.alpha, .opaque)
        XCTAssertEqual(coverage.semantic, .coverage)
        XCTAssertEqual(coverage.pixelFormat, .r16Float)
        XCTAssertEqual(coverage.debugPolicy.label, "coverage")
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
        let data = Data(
            """
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
            """.utf8
        )

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

    private func makePixelBuffer(width: Int, height: Int, pixel: [UInt8]) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
        ]
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32BGRA,
                attributes as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        guard let pixelBuffer else {
            throw HarbethError.texture2Image
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw HarbethError.texture2Image
        }
        let byteCount = CVPixelBufferGetDataSize(pixelBuffer)
        let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for index in stride(from: 0, to: byteCount, by: 4) {
            pointer[index] = pixel[2]
            pointer[index + 1] = pixel[1]
            pointer[index + 2] = pixel[0]
            pointer[index + 3] = pixel[3]
        }
        return pixelBuffer
    }

    private func makeSampleBuffer(width: Int, height: Int, pixel: [UInt8]) throws -> CMSampleBuffer {
        let pixelBuffer = try makePixelBuffer(width: width, height: height, pixel: pixel)
        guard let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            throw HarbethError.texture2Image
        }
        return sampleBuffer
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
        texture.getBytes(&bytes, bytesPerRow: 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }
}

private struct SamplerProbeFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    func resize(input size: C7Size) -> C7Size {
        C7Size(width: 1, height: 1)
    }

    func setupVertices(inputSize: C7Size) -> [Float]? {
        [
            -1.0, -1.0, 0.375, 0.5,
             1.0, -1.0, 0.375, 0.5,
            -1.0,  1.0, 0.375, 0.5,
             1.0,  1.0, 0.375, 0.5
        ]
    }
}
