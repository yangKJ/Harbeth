//
//  MaskRecipeTests.swift
//  Harbeth
//

import XCTest
import Metal
@testable import Harbeth

final class MaskRecipeTests: XCTestCase {

    func testLinearGradientMaskRecipeBuildsExpectedCoverageRamp() throws {
        let recipe = MaskGradientRecipe(
            size: C7Size(width: 3, height: 1),
            kind: .linear(
                startPoint: CGPoint(x: 0, y: 0.5),
                endPoint: CGPoint(x: 1, y: 0.5)
            )
        )

        let texture = try recipe.makeTexture()
        let bytes = try MaskTestHelpers.bytes(in: texture)

        XCTAssertEqual(texture.width, 3)
        XCTAssertEqual(
            recipe.fingerprintFields.first(where: { $0.0 == "kind" })?.1,
            "linear"
        )
        XCTAssertEqual(bytes[0], 42, accuracy: 6)
        XCTAssertEqual(bytes[4], 128, accuracy: 6)
        XCTAssertEqual(bytes[8], 213, accuracy: 6)
    }

    func testRadialGradientMaskRecipeBuildsCenteredCoverageFalloff() throws {
        let recipe = MaskGradientRecipe(
            size: C7Size(width: 3, height: 3),
            kind: .radial(
                center: CGPoint(x: 0.5, y: 0.5),
                startRadius: 0.0,
                endRadius: 0.5
            )
        )

        let texture = try recipe.makeTexture()
        let bytes = try MaskTestHelpers.bytes(in: texture)

        XCTAssertEqual(
            recipe.fingerprintFields.first(where: { $0.0 == "kind" })?.1,
            "radial"
        )
        XCTAssertLessThan(bytes[0], 10)
        XCTAssertEqual(bytes[16], 255, accuracy: 2)
    }

    func testGradientMaskDescriptorCanDriveLocalEffectBlend() throws {
        let base = try MaskTestHelpers.makeTexture(width: 3, height: 1, red: 255, green: 0, blue: 0, alpha: 255)
        let effect = try MaskTestHelpers.makeTexture(width: 3, height: 1, red: 0, green: 0, blue: 255, alpha: 255)
        let descriptor = try MaskGradientRecipe(
            size: C7Size(width: 3, height: 1),
            kind: .linear(
                startPoint: CGPoint(x: 0, y: 0.5),
                endPoint: CGPoint(x: 1, y: 0.5)
            )
        )
        .makeMaskDescriptor(component: .red)

        let output = try MaskTestHelpers
            .maskedBlend(background: base, foreground: effect, mask: descriptor)
            .output()
        let bytes = try MaskTestHelpers.bytes(in: output)

        XCTAssertGreaterThan(bytes[2], 20)
        XCTAssertGreaterThan(bytes[6], bytes[2])
        XCTAssertGreaterThan(bytes[10], bytes[6])
        XCTAssertLessThan(bytes[0], 240)
        XCTAssertLessThan(bytes[4], bytes[0])
        XCTAssertLessThan(bytes[8], bytes[4])
    }

    func testRectangleShapeMaskRecipeBuildsExpectedCoverage() throws {
        let recipe = MaskShapeRecipe(
            size: C7Size(width: 3, height: 1),
            kind: .rectangle(rect: CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1))
        )

        let texture = try recipe.makeTexture()
        let bytes = try MaskTestHelpers.bytes(in: texture)

        XCTAssertEqual(recipe.shapeDescriptor.kind, "rectangle")
        XCTAssertLessThan(bytes[0], 10)
        XCTAssertGreaterThan(bytes[4], 240)
        XCTAssertLessThan(bytes[8], 10)
    }

    func testEllipseShapeMaskRecipeBuildsCenteredCoverage() throws {
        let recipe = MaskShapeRecipe(
            size: C7Size(width: 3, height: 3),
            kind: .ellipse(rect: CGRect(x: 1.0 / 6.0, y: 1.0 / 6.0, width: 2.0 / 3.0, height: 2.0 / 3.0))
        )

        let texture = try recipe.makeTexture()
        let bytes = try MaskTestHelpers.bytes(in: texture)

        XCTAssertEqual(recipe.shapeDescriptor.kind, "ellipse")
        XCTAssertLessThan(bytes[0], 40)
        XCTAssertGreaterThan(bytes[16], 240)
    }

    func testShapeMaskDescriptorCanDriveLocalEffectBlend() throws {
        let base = try MaskTestHelpers.makeTexture(width: 3, height: 1, red: 255, green: 0, blue: 0, alpha: 255)
        let effect = try MaskTestHelpers.makeTexture(width: 3, height: 1, red: 0, green: 0, blue: 255, alpha: 255)
        let descriptor = try MaskShapeRecipe(
            size: C7Size(width: 3, height: 1),
            kind: .rectangle(rect: CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1))
        )
        .makeMaskDescriptor(component: .red)

        let output = try MaskTestHelpers
            .maskedBlend(background: base, foreground: effect, mask: descriptor)
            .output()
        let bytes = try MaskTestHelpers.bytes(in: output)

        XCTAssertGreaterThan(bytes[0], 240)
        XCTAssertLessThan(bytes[4], 20)
        XCTAssertGreaterThan(bytes[8], 240)
        XCTAssertGreaterThan(bytes[6], 240)
    }

    func testPathMaskRecipeBuildsExpectedPolygonCoverage() throws {
        let recipe = MaskPathRecipe(
            size: C7Size(width: 5, height: 5),
            subpaths: [
                .polygon([
                    CGPoint(x: 0.2, y: 0.2),
                    CGPoint(x: 0.8, y: 0.2),
                    CGPoint(x: 0.8, y: 0.8),
                    CGPoint(x: 0.2, y: 0.8)
                ])
            ],
            fillRule: .nonZero
        )

        let texture = try recipe.makeTexture()
        let bytes = try MaskTestHelpers.bytes(in: texture)

        XCTAssertEqual(texture.width, 5)
        XCTAssertEqual(texture.height, 5)
        XCTAssertEqual(recipe.pathDescriptor.pointCount, 5)
        XCTAssertGreaterThan(bytes[(2 * 5 + 2) * 4], 240)
        XCTAssertLessThan(bytes[0], 10)
    }

    func testPathMaskRecipeSpatialFeatherProducesIntermediateCoverage() throws {
        let points = [
            CGPoint(x: 0.2, y: 0.2),
            CGPoint(x: 0.8, y: 0.2),
            CGPoint(x: 0.8, y: 0.8),
            CGPoint(x: 0.2, y: 0.8)
        ]
        let hard = MaskPathRecipe(
            size: C7Size(width: 24, height: 24),
            subpaths: [.polygon(points)]
        )
        let soft = MaskPathRecipe(
            size: C7Size(width: 24, height: 24),
            subpaths: [.polygon(points)],
            feather: 0.16
        )

        let hardBytes = try MaskTestHelpers.bytes(in: hard.makeTexture())
        let hardCoverage = stride(from: 0, to: hardBytes.count, by: 4).map { hardBytes[$0] }
        let softBytes = try MaskTestHelpers.bytes(in: soft.makeTexture())
        let softCoverage = stride(from: 0, to: softBytes.count, by: 4).map { softBytes[$0] }

        XCTAssertFalse(hardCoverage.contains { $0 > 0 && $0 < 255 })
        XCTAssertTrue(softCoverage.contains { $0 > 0 && $0 < 255 })
        XCTAssertTrue(soft.pathDescriptor.parameterValues.contains("feather=0.160000"))
        XCTAssertEqual(try soft.makeMaskDescriptor().featherPolicy, .none)
    }

    func testPathMaskRecipeRebasePreservesSpatialFeatherWidth() {
        let recipe = MaskPathRecipe(
            size: C7Size(width: 400, height: 200),
            subpaths: [.polygon([
                CGPoint(x: 0.2, y: 0.2),
                CGPoint(x: 0.8, y: 0.2),
                CGPoint(x: 0.8, y: 0.8),
                CGPoint(x: 0.2, y: 0.8)
            ])],
            feather: 0.1
        )

        let rebased = recipe.rebased(
            sourceRect: CGRect(x: 100, y: 50, width: 100, height: 100),
            logicalSize: recipe.size,
            tileInputSize: C7Size(width: 100, height: 100)
        )

        XCTAssertEqual(rebased.feather, 0.2, accuracy: 0.0001)
        XCTAssertTrue(rebased.fingerprint.contains("feather=0.200000"))
    }

    func testPathMaskRecipeRebaseDoesNotClampWideLogicalFeatherToTileBounds() {
        let recipe = MaskPathRecipe(
            size: C7Size(width: 4_000, height: 3_000),
            subpaths: [
                .polygon([
                    CGPoint(x: 0.2, y: 0.2),
                    CGPoint(x: 0.8, y: 0.2),
                    CGPoint(x: 0.8, y: 0.8),
                    CGPoint(x: 0.2, y: 0.8)
                ])
            ],
            feather: 0.8
        )

        let rebased = recipe.rebased(
            sourceRect: CGRect(x: 0, y: 0, width: 256, height: 256),
            logicalSize: C7Size(width: 4_000, height: 3_000),
            tileInputSize: C7Size(width: 256, height: 256)
        )

        XCTAssertEqual(rebased.feather, 9.375, accuracy: 0.0001)
        XCTAssertTrue(rebased.fingerprint.contains("feather=9.375000"))
    }

    func testPathMaskRecipeRebasePreservesFeatherCoverageOnWideCanvas() throws {
        let logicalSize = C7Size(width: 400, height: 200)
        let rectangle = MaskPathRecipe(
            size: logicalSize,
            subpaths: [
                .polygon([
                    CGPoint(x: 0.25, y: 0.25),
                    CGPoint(x: 0.75, y: 0.25),
                    CGPoint(x: 0.75, y: 0.75),
                    CGPoint(x: 0.25, y: 0.75)
                ])
            ],
            feather: 0.1
        )
        let fullRectangle = try MaskTestHelpers.bytes(in: rectangle.makeTexture())

        func coverage(_ bytes: [UInt8], width: Int, x: Int, y: Int) -> UInt8 {
            bytes[(y * width + x) * 4]
        }

        let verticalTile = rectangle.rebased(
            sourceRect: CGRect(x: 80, y: 0, width: 100, height: 100),
            logicalSize: logicalSize,
            tileInputSize: C7Size(width: 100, height: 100)
        )
        let verticalBytes = try MaskTestHelpers.bytes(in: verticalTile.makeTexture())
        XCTAssertEqual(
            coverage(fullRectangle, width: 400, x: 90, y: 75),
            coverage(verticalBytes, width: 100, x: 10, y: 75),
            accuracy: 2
        )

        let horizontalTile = rectangle.rebased(
            sourceRect: CGRect(x: 50, y: 30, width: 100, height: 100),
            logicalSize: logicalSize,
            tileInputSize: C7Size(width: 100, height: 100)
        )
        let horizontalBytes = try MaskTestHelpers.bytes(in: horizontalTile.makeTexture())
        XCTAssertEqual(
            coverage(fullRectangle, width: 400, x: 125, y: 40),
            coverage(horizontalBytes, width: 100, x: 75, y: 10),
            accuracy: 2
        )

        let diagonal = MaskPathRecipe(
            size: logicalSize,
            subpaths: [
                .polygon([
                    CGPoint(x: 0.25, y: 0.25),
                    CGPoint(x: 0.75, y: 0.75),
                    CGPoint(x: 0.25, y: 0.75)
                ])
            ],
            feather: 0.1
        )
        let fullDiagonal = try MaskTestHelpers.bytes(in: diagonal.makeTexture())
        let diagonalTile = diagonal.rebased(
            sourceRect: CGRect(x: 150, y: 50, width: 100, height: 100),
            logicalSize: logicalSize,
            tileInputSize: C7Size(width: 100, height: 100)
        )
        let diagonalBytes = try MaskTestHelpers.bytes(in: diagonalTile.makeTexture())
        XCTAssertEqual(
            coverage(fullDiagonal, width: 400, x: 200, y: 90),
            coverage(diagonalBytes, width: 100, x: 50, y: 40),
            accuracy: 2
        )
    }

    func testPathMaskRecipeKeepsTransformedVerticesOutsideCanvas() {
        let recipe = MaskPathRecipe(
            size: C7Size(width: 100, height: 100),
            subpaths: [
                .polygon([
                    CGPoint(x: 0.1, y: 0.1),
                    CGPoint(x: 0.9, y: 0.1),
                    CGPoint(x: 0.9, y: 0.9),
                    CGPoint(x: 0.1, y: 0.9)
                ])
            ],
            transform: MaskPathTransform(
                translation: CGPoint(x: 0.35, y: 0),
                rotationRadians: .pi / 4
            )
        )

        let encoded = recipe.encodedPath()

        XCTAssertTrue(encoded.points.contains { $0.x > 1 || $0.y > 1 })
        XCTAssertTrue(encoded.points.contains { $0.x < 0 || $0.y < 0 })
    }

    func testPathRotationUsesPixelSpaceOnWideCanvas() {
        let recipe = MaskPathRecipe(
            size: C7Size(width: 200, height: 100),
            subpaths: [
                .polygon([
                    CGPoint(x: 0.25, y: 0.25),
                    CGPoint(x: 0.75, y: 0.25),
                    CGPoint(x: 0.75, y: 0.75),
                    CGPoint(x: 0.25, y: 0.75)
                ])
            ],
            transform: MaskPathTransform(
                rotationRadians: .pi / 2,
                rotationAspectRatio: 2
            )
        )

        let encoded = recipe.encodedPath().points
        let pixelWidth = (encoded.map(\.x).max()! - encoded.map(\.x).min()!) * 200
        let pixelHeight = (encoded.map(\.y).max()! - encoded.map(\.y).min()!) * 100

        XCTAssertEqual(pixelWidth, 50, accuracy: 0.001)
        XCTAssertEqual(pixelHeight, 100, accuracy: 0.001)
    }

    func testShapeRotationUsesPixelSpaceOnWideCanvas() throws {
        let recipe = MaskShapeRecipe.rectangle(
            size: C7Size(width: 40, height: 20),
            rect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            transform: MaskPathTransform(
                rotationRadians: .pi / 2,
                rotationAspectRatio: 2
            )
        )

        let bytes = try MaskTestHelpers.bytes(in: recipe.makeTexture())
        let covered = { (x: Int, y: Int) in bytes[(y * 40 + x) * 4] }

        XCTAssertGreaterThan(covered(24, 10), 240)
        XCTAssertLessThan(covered(27, 10), 10)
    }

    func testPathMaskRecipeSupportsEvenOddHoles() throws {
        let recipe = MaskPathRecipe(
            size: C7Size(width: 5, height: 5),
            subpaths: [
                .polygon([
                    CGPoint(x: 0.1, y: 0.1),
                    CGPoint(x: 0.9, y: 0.1),
                    CGPoint(x: 0.9, y: 0.9),
                    CGPoint(x: 0.1, y: 0.9)
                ]),
                .polygon([
                    CGPoint(x: 0.3, y: 0.3),
                    CGPoint(x: 0.7, y: 0.3),
                    CGPoint(x: 0.7, y: 0.7),
                    CGPoint(x: 0.3, y: 0.7)
                ])
            ],
            fillRule: .evenOdd
        )

        let texture = try recipe.makeTexture()
        let bytes = try MaskTestHelpers.bytes(in: texture)
        let coveredPixels = stride(from: 0, to: bytes.count, by: 4).map { bytes[$0] }

        XCTAssertEqual(recipe.pathDescriptor.fillRule, "evenOdd")
        XCTAssertLessThan(bytes[(2 * 5 + 2) * 4], 10)
        XCTAssertTrue(coveredPixels.contains(where: { $0 > 240 }))
    }

    func testShapeRecipeShapeFactoriesBuildCoverage() throws {
        let canvas = C7Size(width: 8, height: 8)
        let rect = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        let recipes: [MaskShapeRecipe] = [
            MaskShapeRecipe.rectangle(size: canvas, rect: rect),
            MaskShapeRecipe.ellipse(size: canvas, rect: rect),
            MaskShapeRecipe.roundedRect(size: canvas, rect: rect, cornerRadius: 0.1),
            MaskShapeRecipe.triangle(size: canvas, rect: rect),
            MaskShapeRecipe.regularPolygon(size: canvas, rect: rect, sides: 5),
            MaskShapeRecipe.star(size: canvas, rect: rect)
        ]

        for recipe in recipes {
            let texture = try recipe.makeTexture()
            let bytes = try MaskTestHelpers.bytes(in: texture)
            XCTAssertTrue(bytes.contains { $0 > 0 }, "shape recipe should produce non-empty coverage")
            XCTAssertFalse(recipe.fingerprint.isEmpty, "shape recipe should expose a fingerprint")
            XCTAssertEqual(recipe.graphDescriptor.kind, "maskShapeRecipe")
        }
    }

    func testShapeRecipeFingerprintAndDescriptorIncludeTransform() throws {
        let transform = MaskPathTransform(
            translation: CGPoint(x: 0.1, y: -0.05),
            scale: CGPoint(x: 1.2, y: 0.8),
            rotationRadians: .pi / 4,
            anchor: CGPoint(x: 0.4, y: 0.6)
        )
        let recipe = MaskShapeRecipe.rectangle(
            size: C7Size(width: 8, height: 8),
            rect: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
            transform: transform
        )

        XCTAssertTrue(recipe.fingerprint.contains("transform={"))
        XCTAssertTrue(recipe.shapeDescriptor.parameterValues.contains { $0.hasPrefix("transform=") })
    }

    func testParametricShapeDescriptorCapturesPolygonAndStarMetadata() {
        let polygon = MaskShapeRecipe.regularPolygon(
            size: C7Size(width: 8, height: 8),
            rect: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
            sides: 6,
            feather: 0.15
        )
        let star = MaskShapeRecipe.star(
            size: C7Size(width: 8, height: 8),
            rect: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
            points: 7,
            innerRadiusRatio: 0.3,
            feather: 0.2
        )

        XCTAssertEqual(polygon.shapeDescriptor.kind, "regularPolygon")
        XCTAssertTrue(polygon.shapeDescriptor.parameterValues.contains("sides=6"))
        XCTAssertTrue(polygon.shapeDescriptor.parameterValues.contains("feather=0.150000"))
        XCTAssertEqual(star.shapeDescriptor.kind, "star")
        XCTAssertTrue(star.shapeDescriptor.parameterValues.contains("points=7"))
        XCTAssertTrue(star.shapeDescriptor.parameterValues.contains("innerRadiusRatio=0.300000"))
    }

    func testTriangleShapeRecipeMatchesPathRegularPolygonCoverageAtCoreSample() throws {
        let canvas = C7Size(width: 16, height: 16)
        let rect = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        let shapeTexture = try MaskShapeRecipe.triangle(size: canvas, rect: rect).makeTexture()
        let pathTexture = try MaskPathRecipe.regularPolygon(size: canvas, rect: rect, sides: 3).makeTexture()
        let shapeBytes = try MaskTestHelpers.bytes(in: shapeTexture)
        let pathBytes = try MaskTestHelpers.bytes(in: pathTexture)

        XCTAssertLessThanOrEqual(abs(Int(shapeBytes[(8 * 16 + 8) * 4]) - Int(pathBytes[(8 * 16 + 8) * 4])), 2)
        XCTAssertLessThanOrEqual(abs(Int(shapeBytes[(2 * 16 + 2) * 4]) - Int(pathBytes[(2 * 16 + 2) * 4])), 2)
    }

    func testParametricShapeFeatherSurvivesPathLowering() throws {
        let canvas = C7Size(width: 24, height: 24)
        let rect = CGRect(x: 0.15, y: 0.15, width: 0.7, height: 0.7)

        let hardPolygon = try MaskShapeRecipe
            .regularPolygon(size: canvas, rect: rect, sides: 6, feather: 0)
            .makeTexture()
        let softPolygon = try MaskShapeRecipe
            .regularPolygon(size: canvas, rect: rect, sides: 6, feather: 0.2)
            .makeTexture()
        let hardStar = try MaskShapeRecipe
            .star(size: canvas, rect: rect, points: 5, innerRadiusRatio: 0.44, feather: 0)
            .makeTexture()
        let softStar = try MaskShapeRecipe
            .star(size: canvas, rect: rect, points: 5, innerRadiusRatio: 0.44, feather: 0.2)
            .makeTexture()

        let hardPolygonBytes = try MaskTestHelpers.bytes(in: hardPolygon)
        let softPolygonBytes = try MaskTestHelpers.bytes(in: softPolygon)
        let hardStarBytes = try MaskTestHelpers.bytes(in: hardStar)
        let softStarBytes = try MaskTestHelpers.bytes(in: softStar)

        XCTAssertFalse(
            hardPolygonBytes.contains(where: { $0 > 0 && $0 < 255 }),
            "无 feather 的 polygon 当前应保持二值 coverage"
        )
        XCTAssertTrue(
            softPolygonBytes.contains(where: { $0 > 0 && $0 < 255 }),
            "lower 到 path 的 polygon 仍应保留 feather 中间 coverage"
        )
        XCTAssertFalse(
            hardStarBytes.contains(where: { $0 > 0 && $0 < 255 }),
            "无 feather 的 star 当前应保持二值 coverage"
        )
        XCTAssertTrue(
            softStarBytes.contains(where: { $0 > 0 && $0 < 255 }),
            "lower 到 path 的 star 仍应保留 feather 中间 coverage"
        )
    }

    func testPathVectorShapeFactoriesBuildCoverage() throws {
        let canvas = C7Size(width: 8, height: 8)
        let rect = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        let recipes: [MaskPathRecipe] = [
            MaskPathRecipe.star(size: canvas, rect: rect),
            MaskPathRecipe.heart(size: canvas, rect: rect)
        ]

        for recipe in recipes {
            let texture = try recipe.makeTexture()
            let bytes = try MaskTestHelpers.bytes(in: texture)
            XCTAssertTrue(bytes.contains { $0 > 0 }, "path vector shape should produce non-empty coverage")
            XCTAssertEqual(recipe.pathDescriptor.subpathCount, 1)
        }
    }
}
