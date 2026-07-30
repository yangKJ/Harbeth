import Harbeth
import Metal
import XCTest

final class SceneRelightPublicAPITests: XCTestCase {
    func testSceneRelightSurfaceCompilesForDirectAndDeferredExecution() throws {
        let light = C7SceneLightDescriptor(
            kind: .spot,
            position: SIMD3<Float>(0.3, 0.2, 1.4),
            direction: SIMD3<Float>(0.2, 0.3, -1),
            color: SIMD3<Float>(1, 0.8, 0.6),
            intensity: 1.2,
            radius: 0.8,
            softness: 0.6,
            coneAngleDegrees: 50,
            falloff: 1.1
        )
        let descriptor = try C7SceneRelightDescriptor(
            lights: [light],
            ambient: 0.3,
            originalLight: 0.65,
            normalStrength: 1.2,
            depthScale: 0.5,
            highlightRolloff: 1.5,
            confidenceFloor: 0.1
        )
        let direct: (MTLTexture, MTLTexture?) -> C7SceneRelight = { depth, confidence in
            C7SceneRelight(
                descriptor: descriptor,
                depthTexture: depth,
                confidenceTexture: confidence
            )
        }
        let deferred = C7SceneRelight.deferred(descriptor)

        XCTAssertTrue(deferred.requiresDeferredDepthBinding)
        XCTAssertEqual(C7SceneRelight.requiredDeferredAuxiliaryTextureCount, 2)
        _ = direct
    }
}
