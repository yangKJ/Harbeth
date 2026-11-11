import XCTest
import CoreVideo
@testable import Harbeth

final class FrameProcessingCapabilityTests: XCTestCase {
    func testHDRBufferPlanningUsesDecodedAndConcreteFloatPrecision() throws {
        for format in [kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, kCVPixelFormatType_64RGBAHalf] {
            var raw: CVPixelBuffer?
            CVPixelBufferCreate(nil, 16, 16, format,
                [kCVPixelBufferMetalCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &raw)
            let buffer = try XCTUnwrap(raw)
            CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_2020, .shouldPropagate)
            CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_2100_HLG, .shouldPropagate)
            CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_2020, .shouldPropagate)
            let node = ImageNode.pixelBuffer(buffer).applying(C7Brightness(brightness: 0.05))
            let diagnostics = try node.makeDiagnostics(profile: .exportQuality)
            XCTAssertEqual(diagnostics.inputPixelFormat.precision, .float16)
            XCTAssertEqual(diagnostics.outputPixelFormat.precision, .float16)
            XCTAssertTrue(diagnostics.frameProcessingCapability(for: .extendedRangeDynamicFrame).isSupported)
        }
    }

    func testStrictDynamicFrameRejectsLegacyFallbackContract() {
        let diagnostics = GraphCompiler.compile(
            filters: [FrameCapabilityLegacyFilter()],
            inputSize: C7Size(width: 16, height: 12),
            profile: .stablePreview
        ).diagnostics

        let capability = diagnostics.frameProcessingCapability()

        XCTAssertFalse(capability.isSupported)
        XCTAssertEqual(capability.blockers, [.kernelContractEvidenceMissing])
        XCTAssertEqual(diagnostics.fallbackKernelPixelContractCount, 1)
    }

    func testExplicitSDRContractSupportsDynamicFrame() {
        let filter = FrameCapabilityTestFilter(
            contract: KernelPixelContract(
                dynamicRangeBehavior: .preservesExtendedRange,
                samplingFootprint: .point
            )
        )
        let diagnostics = GraphCompiler.compile(
            filters: [filter],
            inputSize: C7Size(width: 16, height: 12),
            profile: .stablePreview
        ).diagnostics

        XCTAssertTrue(diagnostics.frameProcessingCapability().isSupported)
    }

    func testStrictCapabilityReportsExecutionBlockersInStableOrder() {
        let filter = FrameCapabilityTestFilter(
            contract: KernelPixelContract(
                dynamicRangeBehavior: .preservesExtendedRange,
                samplingFootprint: .point,
                globalDependency: .imageStatistics,
                isDeterministic: false,
                requiresCPUReadback: true
            )
        )
        let diagnostics = GraphCompiler.compile(
            filters: [filter],
            inputSize: C7Size(width: 16, height: 12),
            profile: .stablePreview
        ).diagnostics

        XCTAssertEqual(
            diagnostics.frameProcessingCapability().blockers,
            [.cpuReadbackRequired, .globalDependencyPresent, .nonDeterministicKernelPresent]
        )
    }

    func testExtendedRangeRequirementRejectsClampingKernel() {
        let diagnostics = GraphCompiler.compile(
            filters: [C7Deband(radius: 2)],
            inputSize: C7Size(width: 16, height: 12),
            profile: .stablePreview
        ).diagnostics

        let capability = diagnostics.frameProcessingCapability(for: .extendedRangeDynamicFrame)

        XCTAssertFalse(capability.isSupported)
        XCTAssertTrue(capability.blockers.contains(.extendedRangePreservationUnproven))
    }

    func testCustomSamplerMustBeAppliedByTheExecutionPlan() {
        let descriptor = ImageSamplerDescriptor(
            minFilter: .nearest,
            magFilter: .linear,
            sAddressMode: .clampToEdge,
            tAddressMode: .repeat
        )
        let diagnostics = GraphCompiler.compile(
            filters: [FrameCapabilityMetadataOnlySamplerFilter()],
            inputSize: C7Size(width: 16, height: 12),
            profile: .stablePreview,
            samplerDescriptor: descriptor
        ).diagnostics

        XCTAssertEqual(
            diagnostics.frameProcessingCapability().blockers,
            [.samplerDescriptorNotApplied]
        )
    }

    func testExternalPluginBoundaryFailsClosedWithoutPixelContract() {
        let size = C7Size(width: 16, height: 12)
        let graph = RenderGraph(nodes: [
            RenderNode(
                kind: .boundary,
                filter: nil,
                boundary: FrameCapabilityPluginBoundary(capability: .cpu),
                outputSize: size,
                breaksFusion: true
            )
        ])
        let node = RenderNodeDiagnostic(
            index: 0,
            name: "PluginBoundary",
            kind: .boundary,
            inputSize: size,
            outputSize: size,
            breaksFusion: true,
            parameterSummary: [:]
        )
        let plan = RenderPlan(
            graph: graph,
            profile: .stablePreview,
            derivative: RenderProfile.stablePreview.defaultDerivativeSpec,
            inputSize: size,
            outputSize: size,
            nodeDiagnostics: [node],
            compilationSource: .nodeGraph
        )

        XCTAssertEqual(
            plan.diagnostics.frameProcessingCapability().blockers,
            [.externalBoundaryContractUnproven]
        )
    }

    func testKernelPixelContractCurrentSchemaPreservesEvidence() throws {
        let declared = KernelPixelContract(
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .point
        )
        let inferred = KernelPixelContract.conservative(samplingFootprint: .neighborhood(radius: 1))

        let decodedDeclared = try JSONDecoder().decode(
            KernelPixelContract.self,
            from: JSONEncoder().encode(declared)
        )
        let decodedInferred = try JSONDecoder().decode(
            KernelPixelContract.self,
            from: JSONEncoder().encode(inferred)
        )

        XCTAssertEqual(decodedDeclared.evidence, .declared)
        XCTAssertEqual(decodedInferred.evidence, .conservativeFallback)
    }

    func testKernelPixelContractRejectsPayloadWithoutEvidence() throws {
        let contract = KernelPixelContract(
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .point
        )
        let data = try JSONEncoder().encode(contract)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "evidence")
        let incompleteData = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try JSONDecoder().decode(KernelPixelContract.self, from: incompleteData))
    }
}

private struct FrameCapabilityTestFilter: C7FilterProtocol {
    let contract: KernelPixelContract

    var modifier: ModifierEnum { .compute(kernel: "C7Brightness") }
    var memoryAccessPattern: MemoryAccessPattern { .point }
    var kernelPixelContract: KernelPixelContract { contract }
}

private struct FrameCapabilityLegacyFilter: C7FilterProtocol {
    var modifier: ModifierEnum { .compute(kernel: "C7Gamma") }
    var factors: [Float] { [1.1] }
    var memoryAccessPattern: MemoryAccessPattern { .point }
}

private struct FrameCapabilityMetadataOnlySamplerFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    var renderSamplerConsumption: RenderSamplerConsumption { .shaderDefined }
    var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(
            dynamicRangeBehavior: .preservesExtendedRange,
            samplingFootprint: .point
        )
    }
}

private struct FrameCapabilityPluginBoundary: PluginBoundaryAdapter {
    let capability: PluginCapability

    func render(input: RenderedFrame, context: PluginContext) throws -> RenderedFrame {
        input
    }
}
