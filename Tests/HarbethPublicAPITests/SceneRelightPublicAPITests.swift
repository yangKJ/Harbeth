import Harbeth
import Metal
import XCTest

final class SceneRelightPublicAPITests: XCTestCase {
    func testSceneRelightNewDescriptorFieldsRoundTripAndLegacyDefaults() throws {
        let descriptor = try SceneRelightDescriptor(
            lights: [SceneLightDescriptor(depthRange: SIMD2<Float>(0.2, 0.8), depthFeather: 0.35)],
            nearExposureEV: 0.7,
            farExposureEV: -0.4,
            depthSplit: 0.6,
            depthFeather: 0.3,
            edgeProtection: 0.8
        )
        let encoded = try JSONEncoder().encode(descriptor)
        XCTAssertEqual(try JSONDecoder().decode(SceneRelightDescriptor.self, from: encoded), descriptor)

        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        payload.removeValue(forKey: "edgeProtection")
        var lights = try XCTUnwrap(payload["lights"] as? [[String: Any]])
        lights[0].removeValue(forKey: "depthRange")
        lights[0].removeValue(forKey: "depthFeather")
        payload["lights"] = lights
        let legacy = try JSONDecoder().decode(
            SceneRelightDescriptor.self,
            from: JSONSerialization.data(withJSONObject: payload)
        )
        XCTAssertEqual(legacy.edgeProtection, 0)
        XCTAssertEqual(legacy.lights.first?.depthRange, SIMD2<Float>(0, 1))
        XCTAssertEqual(legacy.lights.first?.depthFeather, 0.1)
    }

    func testSceneRelightSurfaceCompilesForDirectAndDeferredExecution() throws {
        let light = SceneLightDescriptor(
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
        let descriptor = try SceneRelightDescriptor(
            lights: [light],
            ambient: 0.3,
            originalLight: 0.65,
            normalStrength: 1.2,
            depthScale: 0.5,
            highlightRolloff: 1.5,
            confidenceFloor: 0.1,
            nearExposureEV: 0.7,
            farExposureEV: -0.4,
            depthSplit: 0.6,
            depthFeather: 0.3
        )
        let direct: (MTLTexture, MTLTexture?) -> C7SceneRelight = { depth, confidence in
            C7SceneRelight(
                descriptor: descriptor,
                depthTexture: depth,
                confidenceTexture: confidence
            )
        }
        let deferred = C7SceneRelight.deferred(descriptor)

        XCTAssertEqual(deferred.descriptor.nearExposureEV, 0.7)
        XCTAssertEqual(deferred.descriptor.farExposureEV, -0.4)
        XCTAssertTrue(deferred.requiresDeferredDepthBinding)
        XCTAssertEqual(C7SceneRelight.requiredDeferredAuxiliaryTextureCount, 2)
        _ = direct
    }
}
