import Harbeth
import Metal
import XCTest

final class SamplerPublicAPITests: XCTestCase {
    func testPartialSamplerAdaptationIsPubliclyExpressible() {
        let adaptation: SamplerAdaptation = .partial(C7Brightness(brightness: 0))

        guard case .partial = adaptation else {
            return XCTFail("Expected partial sampler adaptation.")
        }
    }

    func testCustomRenderFilterCanDeclareRuntimeSamplerConsumption() {
        let filter: any RenderProtocol = RuntimeSamplerProbeFilter()

        XCTAssertEqual(filter.modifier, .render(vertex: "basicVertex", fragment: "basicFragment"))
        XCTAssertEqual(filter.renderSamplerConsumption, .runtimeBound)
    }
}

private struct RuntimeSamplerProbeFilter: RenderProtocol {
    var modifier: ModifierEnum {
        .render(vertex: "basicVertex", fragment: "basicFragment")
    }

    var renderSamplerConsumption: RenderSamplerConsumption { .runtimeBound }
}
