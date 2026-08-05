import XCTest
import CoreGraphics
@testable import Harbeth

final class KernelExecutionPlanTests: XCTestCase {

    func testComputeFilterExportsStableExecutionPlan() {
        let filter = C7Brightness(brightness: 0.2)
        let plan = filter.makeKernelExecutionPlan(inputSize: C7Size(width: 8, height: 6))

        XCTAssertEqual(plan.kind, .compute)
        XCTAssertEqual(plan.inputTextureCount, 1)
        XCTAssertEqual(plan.passes.count, 1)
        XCTAssertEqual(plan.passes.first?.kind, .compute)
        XCTAssertEqual(plan.pixelContract.samplingFootprint, .point)
        XCTAssertEqual(plan.pixelContract.dynamicRangeBehavior, .unspecified)
        XCTAssertTrue(plan.pixelContract.canAutoTile)
        XCTAssertTrue(plan.pixelContract.isPointwiseFusionEligible)
        XCTAssertFalse(plan.fingerprint.isEmpty)
    }

    func testExplicitPixelContractFlowsThroughDescriptorAndExecutionPlan() {
        let filter = KernelPixelContractTestFilter()
        let descriptor = filter.kernelDescriptor(inputSize: C7Size(width: 8, height: 6))
        let plan = filter.makeKernelExecutionPlan(inputSize: C7Size(width: 8, height: 6))

        XCTAssertEqual(descriptor.pixelContract, filter.kernelPixelContract)
        XCTAssertEqual(plan.pixelContract, filter.kernelPixelContract)
        XCTAssertTrue(plan.pixelContract.dynamicRangeBehavior.isExtendedRangeSafe)
        XCTAssertTrue(plan.pixelContract.isPointwiseFusionEligible)
        XCTAssertTrue(plan.fingerprint.contains("dynamicRange=preservesExtendedRange"))
    }

    func testPixelContractParticipatesInInvocationCompatibility() {
        let filter = KernelPixelContractTestFilter()
        let descriptor = KernelDescriptor(
            filterName: "KernelPixelContractTestFilter",
            functionIdentity: KernelFunctionIdentity(kind: .compute, primaryName: "C7Brightness"),
            pixelContract: .conservative(samplingFootprint: .dynamic)
        )

        XCTAssertEqual(
            descriptor.compatibilitySummary(with: filter, inputSize: C7Size(width: 4, height: 4)),
            "pixelContractMismatch"
        )
    }

    func testInvocationCarriesExecutionPlanAndCompatibilitySummary() {
        let filter = C7Brightness(brightness: 0.1)
        let descriptor = filter.kernelDescriptor(inputSize: C7Size(width: 4, height: 4))
        let invocation = descriptor.makeInvocation(filter: filter, inputSize: C7Size(width: 4, height: 4))

        XCTAssertEqual(invocation.kernelExecutionPlan.compatibilitySummary, "compatible")
        XCTAssertEqual(invocation.kernelExecutionPlan.passes.first?.functionIdentity.primaryName, "C7Brightness")
        XCTAssertTrue(invocation.fingerprint.contains(invocation.kernelExecutionPlan.fingerprint))
    }

    func testRenderFilterExecutionPlanTracksRenderPassKind() {
        let filter = RenderBasicFilter()
        let plan = filter.makeKernelExecutionPlan(inputSize: C7Size(width: 16, height: 12))

        XCTAssertEqual(plan.kind, .render)
        XCTAssertEqual(plan.passes.first?.kind, .render)
        XCTAssertEqual(plan.passes.first?.output.outputSize, C7Size(width: 16, height: 12))
        XCTAssertEqual(plan.passes.first?.drawCallCount, 1)
    }

    func testRenderExecutionPlanTracksMultiAttachmentOutputContract() {
        let filter = KernelExecutionMultiAttachmentRenderFilter()
        let plan = filter.makeKernelExecutionPlan(inputSize: C7Size(width: 16, height: 12))

        XCTAssertEqual(plan.kind, .render)
        XCTAssertEqual(plan.outputAttachmentCount, 2)
        XCTAssertEqual(plan.outputAttachmentSemantics, ["primaryColor", "analysis"])
        XCTAssertEqual(plan.outputAttachmentPixelFormats, ["rgba16Float", "rgba8Unorm"])
        XCTAssertEqual(plan.passes.first?.outputContract.attachmentCount, 2)
        XCTAssertTrue(plan.fingerprint.contains("outputAttachments=2"))
        XCTAssertTrue(plan.fingerprint.contains("outputAttachmentSemantics=primaryColor,analysis"))
        XCTAssertTrue(plan.fingerprint.contains("outputAttachmentPixels=rgba16Float,rgba8Unorm"))
    }

    func testKernelExecutionPlanIncludesExplicitParameterBindings() {
        let filter = KernelBindingComputeTestFilter()
        let descriptor = filter.kernelDescriptor(inputSize: C7Size(width: 8, height: 6))
        let plan = filter.makeKernelExecutionPlan(inputSize: C7Size(width: 8, height: 6))

        XCTAssertEqual(descriptor.parameterBindings.count, 2)
        XCTAssertTrue(descriptor.arguments.contains(where: { $0.name == "toneMatrix" && $0.dataType == .matrix3x3 }))
        XCTAssertTrue(descriptor.arguments.contains(where: { $0.name == "toneOffset" && $0.dataType == .float3 }))
        XCTAssertTrue(descriptor.fingerprint.contains("bindings=binding=toneMatrix"))
        XCTAssertTrue(plan.passes.first?.parameterFingerprint.contains("binding=toneMatrix") == true)
        XCTAssertTrue(plan.passes.first?.parameterFingerprint.contains("binding=toneOffset") == true)
    }

    func testExplicitParameterBindingFiltersDoNotMixLegacyFactors() throws {
        let texture = try MaskTestHelpers.makeTexture(pixel: [255, 255, 255, 255])
        let filters: [(name: String, filter: C7FilterProtocol, expectedBindingCount: Int)] = [
            ("C7FalseColor", C7FalseColor(fristColor: .black, secondColor: .white), 2),
            ("C7Levels", C7Levels(), 5),
            ("C7HighlightShadowTint", C7HighlightShadowTint(), 4),
            ("C7Transform", C7Transform(transform: .identity), 5),
            ("C7ChromaKey", C7ChromaKey(), 4),
            ("C7BlendChromaKey", C7BlendChromaKey(), 3),
            ("C7SolidColor", C7SolidColor(), 1),
            ("C7ColorVector4", C7ColorVector4(vector: .zero), 2),
            ("C7ColorMatrix4x4", C7ColorMatrix4x4(matrix: .Color.identity), 3),
            ("C7ConvolutionMatrix3x3", C7ConvolutionMatrix3x3(matrix: .Kernel.identity), 3),
            ("C7ColorMatrix4x5", C7ColorMatrix4x5(matrix: Matrix4x5(values: [
                1, 0, 0, 0, 0,
                0, 1, 0, 0, 0,
                0, 0, 1, 0, 0,
                0, 0, 0, 1, 0
            ])), 3),
            ("C7Vignette", C7Vignette(), 5),
            ("C7VignetteBlend", C7VignetteBlend(), 4),
            ("C7ColorRGBA", C7ColorRGBA(), 2),
            ("C7Curves", C7Curves(), 5),
            ("C7ColorBalanceEnhanced", C7ColorBalanceEnhanced(), 4),
            ("C7SelectiveHSL", C7SelectiveHSL(), 1),
            ("C7ColorGrading", C7ColorGrading(), 6),
            ("C7ToneMapping", C7ToneMapping(
                inputNitsPerUnit: 1_000,
                sourcePeakNits: 1_000,
                targetReferenceWhiteNits: 100,
                targetPeakNits: 100
            ), 3),
            ("C7ChromaticAberrationCorrection", C7ChromaticAberrationCorrection(), 4),
            ("C7LensDistortionCorrection", C7LensDistortionCorrection(), 5),
            ("C7SharpnessFalloffCorrection", C7SharpnessFalloffCorrection(), 4),
            ("C7ColorCube", C7ColorCube(cubeResource: nil), 4),
            ("C7DisplacementMap", C7DisplacementMap(displacementTexture: texture), 6),
            ("C7EdgeGlow", C7EdgeGlow(), 3),
            ("C7StickerOutline", C7StickerOutline(), 3)
        ]

        for filter in filters {
            let descriptor = filter.filter.kernelDescriptor(inputSize: C7Size(width: 4, height: 4))
            XCTAssertEqual(
                descriptor.parameterBindings.count,
                filter.expectedBindingCount,
                "\(filter.name) should expose a complete explicit parameter binding route."
            )
            XCTAssertTrue(filter.filter.factors.isEmpty, "\(filter.name) should not mix factors with kernelParameterBindings.")
            XCTAssertEqual(descriptor.parameters["factors"], .floatArray([]), "\(filter.name) should keep descriptor factors empty when bindings are present.")
        }
    }

    func testProfessionalColorPrimitivesExposeStablePointSamplingContracts() {
        let selective = C7SelectiveHSL(adjustments: [SIMD3<Float>(2, -2, 0.4)])
        let grading = C7ColorGrading(
            shadows: SIMD3<Float>(240, 0.4, -0.2),
            balance: 2,
            blending: -1
        )
        let whitesBlacks = C7WhitesBlacks(whites: 2, blacks: -2)

        XCTAssertEqual(selective.memoryAccessPattern, .point)
        XCTAssertEqual(C7SharpenDetail(sharpen: 0.2).memoryAccessPattern, .neighborhood)
        XCTAssertEqual(selective.kernelParameterBindings.first?.value, .floatArray([
            1, -1, 0.4,
            0, 0, 0,
            0, 0, 0,
            0, 0, 0,
            0, 0, 0,
            0, 0, 0,
            0, 0, 0,
            0, 0, 0
        ]))
        XCTAssertEqual(grading.balance, 1)
        XCTAssertEqual(grading.blending, 0)
        XCTAssertEqual(
            grading.kernelParameterBindings.first?.value,
            .float3(SIMD3<Float>(240, 0.4, -0.2))
        )
        XCTAssertEqual(whitesBlacks.factors, [1, -1])
    }

    func testPublicLongParameterFiltersUseReducedSemanticBindings() {
        assertGroupedParameters(
            C7BlendChromaKey(),
            expectedNames: ["keying", "keyColor", "intensity"],
            legacySlotCount: 6
        )
        assertGroupedParameters(
            C7ChromaticAberrationCorrection(),
            expectedNames: ["center", "channelShifts", "samplingMode", "edgeMode"],
            legacySlotCount: 6
        )
        assertGroupedParameters(
            C7LensDistortionCorrection(),
            expectedNames: ["center", "distortionCoefficients", "scale", "samplingMode", "edgeMode"],
            legacySlotCount: 7
        )
        assertGroupedParameters(
            C7SharpnessFalloffCorrection(),
            expectedNames: ["center", "falloff", "amount", "edgeThreshold"],
            legacySlotCount: 6
        )
        assertGroupedParameters(
            C7ColorCube(cubeResource: nil),
            expectedNames: ["intensity", "interpolation", "domainMinimum", "domainMaximum"],
            legacySlotCount: 8
        )
        assertGroupedParameters(
            C7Curves(),
            expectedNames: ["pointCounts", "rgbPoints", "redPoints", "greenPoints", "bluePoints"],
            legacySlotCount: 8
        )
        assertGroupedParameters(
            C7ColorMatrix4x4(matrix: .Color.identity),
            expectedNames: ["intensity", "offset", "matrix"],
            legacySlotCount: 6
        )
        assertGroupedParameters(
            C7ToneMapping(
                inputNitsPerUnit: 1_000,
                sourcePeakNits: 1_000,
                targetReferenceWhiteNits: 100,
                targetPeakNits: 100
            ),
            expectedNames: ["sourceLuminance", "targetLuminance", "appearance"],
            legacySlotCount: 6
        )
        assertGroupedParameters(
            C7VignetteBlend(),
            expectedNames: ["center", "range", "blendMode", "color"],
            legacySlotCount: 6
        )
    }

    func testLongParameterFilterKeepsFactorsWhenSemanticGroupingWouldNotHelp() {
        let filter = C7DefringeCorrection()

        XCTAssertEqual(filter.factors.count, 8)
        XCTAssertTrue(filter.kernelParameterBindings.isEmpty)
    }

    func testCriticalColorAndAlphaFiltersDeclareDynamicRangeBehavior() {
        XCTAssertEqual(
            C7RGBColorSpaceConversion(mode: .linearDisplayP3ToLinearSRGB)
                .kernelPixelContract.dynamicRangeBehavior,
            .preservesExtendedRange
        )
        XCTAssertEqual(
            C7RGBTransferConversion(mode: .linearToSRGB)
                .kernelPixelContract.dynamicRangeBehavior,
            .preservesExtendedRange
        )
        XCTAssertEqual(C7ColorCube(cubeResource: nil).kernelPixelContract.dynamicRangeBehavior, .unspecified)
        XCTAssertEqual(
            C7ToneMapping(
                inputNitsPerUnit: 1_000,
                sourcePeakNits: 1_000,
                targetReferenceWhiteNits: 100,
                targetPeakNits: 100
            ).kernelPixelContract.dynamicRangeBehavior,
            .toneMapsToSDR
        )
        XCTAssertEqual(
            C7ToneMapping(
                inputNitsPerUnit: 1_000,
                sourcePeakNits: 1_000,
                targetReferenceWhiteNits: 203,
                targetPeakNits: 400
            ).kernelPixelContract.dynamicRangeBehavior,
            .toneMapsToEDR
        )
        XCTAssertEqual(C7Deband(radius: 3.2).kernelPixelContract.samplingFootprint, .neighborhood(radius: 4))
        XCTAssertEqual(C7PremultiplyAlpha().kernelPixelContract.outputAlpha, .premultiplied)
        XCTAssertEqual(C7UnpremultiplyAlpha().kernelPixelContract.dynamicRangeBehavior, .preservesExtendedRange)
    }

    func testLongBasicFiltersExposeReducedSemanticBindingGroups() throws {
        let texture = try MaskTestHelpers.makeTexture(pixel: [255, 255, 255, 255])
        let mask = MaskDescriptor(texture: texture, component: .red, blendMode: .multiply, opacity: 0.75)

        assertGroupedParameters(
            ShapeMask(kind: .rectangle(rect: CGRect(x: 0.1, y: 0.2, width: 0.7, height: 0.6), feather: 0.3)),
            expectedNames: ["kind", "frame", "appearance", "translation", "scale", "rotation", "anchor"],
            legacySlotCount: 15
        )
        assertGroupedParameters(
            MaskCoverageBlend(mask: mask),
            expectedNames: ["baseMask", "overlayMask", "overlayFeather"],
            legacySlotCount: 9
        )
        assertGroupedParameters(
            MaskCoverageBlendBatch(masks: [mask]),
            expectedNames: ["baseMask", "maskCount", "mask0", "mask1", "mask2", "mask3"],
            legacySlotCount: 25
        )
        assertGroupedParameters(
            MaskAuxiliaryRangeFilter(
                confidenceTexture: texture,
                component: 0,
                lowerBound: 0.2,
                upperBound: 0.8,
                softness: 0.1,
                invert: false,
                usesConfidence: true
            ),
            expectedNames: ["component", "range", "flags"],
            legacySlotCount: 6
        )
        let layer = LayerComposite(
            layerTexture: texture,
            normalizedFrame: CGRect(x: 0.1, y: 0.2, width: 0.7, height: 0.6)
        )
        assertGroupedParameters(
            layer,
            expectedNames: [
                "normalizedFrame", "contentRegion", "layerOptions", "maskOptions", "maskCoverage",
                "compositingMaskOptions", "compositingMaskCoverage", "tintColor", "hasTint"
            ],
            legacySlotCount: 29
        )
        XCTAssertEqual(layer.kernelParameterBindings.first?.value, .float4(SIMD4<Float>(0.1, 0.2, 0.7, 0.6)))
    }

    func testGradientMaskKeepsOneSlotAndOnlyUploadsRequiredPayload() {
        let linear = GradientMask(
            kind: .linear(startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1))
        )
        let multiStop = GradientMask(
            kind: .multiStopLinear(
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 1, y: 1),
                stops: [
                    MaskGradientStop(location: 0, coverage: 0),
                    MaskGradientStop(location: 0.5, coverage: 0.8),
                    MaskGradientStop(location: 1, coverage: 1)
                ],
                curve: .smooth
            )
        )

        XCTAssertEqual(linear.kernelParameterBindings.map(\.name), ["gradientParameters"])
        guard case .floatArray(let linearValues) = linear.kernelParameterBindings.first?.value,
              case .floatArray(let multiStopValues) = multiStop.kernelParameterBindings.first?.value else {
            return XCTFail("渐变参数应保持单个 Float 数组绑定。")
        }
        XCTAssertEqual(linearValues.count, 8)
        XCTAssertEqual(multiStopValues.count, 16)
    }

    func testShortBasicFiltersKeepLightweightFactorsRoute() throws {
        let texture = try MaskTestHelpers.makeTexture(pixel: [255, 255, 255, 255])
        let descriptor = MaskDescriptor(texture: texture)
        let regionBlend = MaskRegionBlend(effectTexture: texture, mask: descriptor)
        let transition = DirectionalWipeTransition(toTexture: texture, progress: 0.5)

        XCTAssertEqual(regionBlend.factors.count, 5)
        XCTAssertTrue(regionBlend.kernelParameterBindings.isEmpty)
        XCTAssertEqual(transition.factors.count, 3)
        XCTAssertTrue(transition.kernelParameterBindings.isEmpty)
    }

    private func assertGroupedParameters<Filter: C7FilterProtocol>(
        _ filter: Filter,
        expectedNames: [String],
        legacySlotCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(filter.factors.isEmpty, file: file, line: line)
        let bindings = filter.kernelParameterBindings
        XCTAssertEqual(bindings.map(\.name), expectedNames, file: file, line: line)
        XCTAssertEqual(bindings.map(\.index), Array(expectedNames.indices), file: file, line: line)
        XCTAssertTrue(bindings.allSatisfy { $0.stage == .compute }, file: file, line: line)
        XCTAssertLessThan(bindings.count, legacySlotCount, file: file, line: line)
    }
}

private struct KernelBindingComputeTestFilter: C7FilterProtocol {
    var modifier: ModifierEnum {
        .compute(kernel: "C7Brightness")
    }

    var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(
                name: "toneMatrix",
                index: 0,
                stage: .compute,
                value: .matrix3x3(.Kernel.identity)
            ),
            KernelParameterBinding(
                name: "toneOffset",
                index: 1,
                stage: .compute,
                value: .float3(SIMD3<Float>(0.1, 0.2, 0.3))
            )
        ]
    }
}

private struct KernelPixelContractTestFilter: C7FilterProtocol {
    var modifier: ModifierEnum {
        .compute(kernel: "C7Brightness")
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .point
    }

    var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            workingColorSpace: .extendedLinearDisplayP3,
            precision: .float16,
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .point,
            fusionPolicy: .pointwise
        )
    }
}

private struct KernelExecutionMultiAttachmentRenderFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    var renderSamplerConsumption: RenderSamplerConsumption { .runtimeBound }

    var renderOutputContract: RenderOutputContract {
        RenderOutputContract(
            colorSpace: .extendedLinearSRGB,
            pixelFormat: .rgba16Float,
            additionalAttachments: [
                RenderOutputAttachmentContract(
                    index: 1,
                    semantic: .analysis,
                    alpha: .opaque,
                    colorSpace: .sRGB,
                    pixelFormat: .rgba8Unorm
                )
            ]
        )
    }
}
