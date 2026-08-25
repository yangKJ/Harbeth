import XCTest
import Metal
@testable import Harbeth

final class DeviceLibraryTests: XCTestCase {

    func testSwiftPackageCanLoadHarbethMetalLibrary() throws {
        let device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal device is unavailable in this environment.")

        let library = Device.makeFrameworkLibrary(device!, for: "Harbeth")

        XCTAssertNotNil(library)
    }

    func testRegisterExternalLibraryProviderIsIdempotent() throws {
        HarbethContext.shared.recoverExecution()
        let baseline = Device.externalLibraryProviderIdentifiers()
        let provider = MockExternalLibraryProvider(identifier: "tests.mock.provider")

        XCTAssertTrue(Device.registerExternalLibraryProvider(provider))
        XCTAssertFalse(Device.registerExternalLibraryProvider(provider))

        let identifiers = Device.externalLibraryProviderIdentifiers()
        XCTAssertEqual(identifiers.filter { $0 == provider.providerIdentifier }.count, 1)
        XCTAssertEqual(identifiers.count, baseline.count + 1)
        XCTAssertTrue(Device.externalLibraryRegistryDebugDescription().contains(provider.providerIdentifier))
    }

    func testContextResetKeepsExternalLibraryProviders() {
        let context = HarbethContext.shared
        let provider = MockExternalLibraryProvider(identifier: "tests.reset.provider.\(UUID().uuidString)")

        XCTAssertTrue(context.registerExternalLibraryProvider(provider))
        context.resetCaches()

        XCTAssertTrue(context.externalLibraryProviderIdentifiers.contains(provider.providerIdentifier))
    }

    func testReadFrameworkBundleFallsBackToHarbethHostBundle() {
        let bundle = R.readFrameworkBundle(with: "Harbeth")
        XCTAssertNotNil(bundle)
        XCTAssertNotNil(R.cacheBundles["Harbeth"])
    }

    func testContextRuntimeSurfacesResolveToOneDefaultOwner() {
        let context = HarbethContext.shared
        let owner = context.runtimeDevice
        let textureCache = context.cvMetalTextureCache

        XCTAssertTrue(context.device === owner.device)
        XCTAssertEqual(context.colorSpace, owner.colorSpace)
        XCTAssertEqual(context.debugCacheSnapshot().hasCVMetalTextureCache, textureCache != nil)
    }

    func testLookupAndCubeKeepResourceOwnerMetadataWhenResourcesAreMissing() {
        let lookup = C7LookupTable(name: "missing_lookup", forResource: "Harbeth", intensity: 0.42)
        let cube = C7ColorCube(cubeName: "missing_cube", forResource: "Harbeth", intensity: 0.73)
        let multiZone = C7MultiZoneLookup(
            shadowThreshold: 0.25,
            highlightThreshold: 0.75,
            transitionWidth: 0.12,
            shadowLookupName: "shadow",
            midtoneLookupName: "midtone",
            highlightLookupName: "highlight",
            forResource: "Harbeth"
        )

        XCTAssertEqual(lookup.resourceName, "missing_lookup")
        XCTAssertEqual(lookup.resourceBundleName, "Harbeth")
        XCTAssertEqual(lookup.otherInputTextures.count, 0)

        XCTAssertEqual(cube.resourceName, "missing_cube")
        XCTAssertEqual(cube.resourceBundleName, "Harbeth")
        XCTAssertEqual(cube.otherInputTextures.count, 0)

        XCTAssertEqual(multiZone.resourceBundleName, "Harbeth")
        XCTAssertEqual(multiZone.otherInputTextures.count, 0)
    }

    func testMetalFunctionLookupFailureDescriptionIncludesCandidateSources() {
        let description = Device.metalFunctionLookupFailureDescription("missing_kernel")
        XCTAssertTrue(description.contains("missing_kernel"))
        XCTAssertTrue(description.contains("Default Library"))
        XCTAssertTrue(description.contains("External Registry"))
    }

    func testReadMetalFunctionByKernelIdentityUsesLibrarySource() throws {
        let identity = KernelFunctionIdentity(kind: .compute, primaryName: "C7Brightness", librarySource: .automatic)

        let function = try Device.readMTLFunction(identity)
        let description = Device.metalFunctionLookupFailureDescription(identity)

        XCTAssertEqual(function.name, "C7Brightness")
        XCTAssertTrue(description.contains("C7Brightness"))
        XCTAssertTrue(description.contains("library=automatic"))
    }

    func testMissingMetalFunctionThrowsInDebugAndRelease() {
        let identity = KernelFunctionIdentity(
            kind: .compute,
            primaryName: "__harbeth_missing_kernel_for_test__",
            librarySource: .defaultLibrary
        )

        XCTAssertThrowsError(try Device.readMTLFunction(identity)) { error in
            guard case HarbethError.readFunction(let name) = error else {
                return XCTFail("Expected readFunction, received \(error)")
            }
            XCTAssertEqual(name, identity.primaryName)
        }
    }

    func testHeapTexturePoolCapabilityReportUsesStablePlatformContract() {
        let report = Device.metalCapabilityReport(.heapTexturePool)

        XCTAssertEqual(report.capability, .heapTexturePool)
        XCTAssertTrue(report.minimumPlatform.contains("iOS 13"))
        XCTAssertTrue(report.minimumPlatform.contains("macOS 10.15"))
        XCTAssertTrue(report.minimumPlatform.contains("tvOS 13"))
        XCTAssertFalse(report.reason.isEmpty)
    }
}

private final class MockExternalLibraryProvider: ExternalMTLLibraryProvider {
    let providerIdentifier: String

    init(identifier: String) { self.providerIdentifier = identifier }

    func provideLibrary(for device: MTLDevice) -> MTLLibrary? { nil }
}
