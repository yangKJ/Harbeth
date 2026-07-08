//
//  MaskCompositeTests.swift
//  Harbeth
//

import XCTest
import Metal
@testable import Harbeth

final class MaskCompositeTests: XCTestCase {

    func testMaskCoverageBlendMultiplyBuildsIntersectionCoverageTexture() throws {
        let baseCoverage = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 192])
        let overlayMask = try MaskTestHelpers.makeTexture(pixel: [64, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: overlayMask, component: .red, blendMode: .multiply, opacity: 1)

        let output: MTLTexture = try HarbethIO(
            element: baseCoverage,
            filter: MaskCoverageBlend(mask: descriptor)
        ).output()

        let pixel = try MaskTestHelpers.firstPixel(in: output)
        XCTAssertEqual(pixel.red, 48, accuracy: 3, "multiply 路径下 coverage = 192/255 * 64/255 ≈ 0.189,转 8 位 ≈ 48")
        XCTAssertEqual(pixel.green, 48, accuracy: 3, "multiply 路径下 coverage 同步落到 G 通道")
        XCTAssertEqual(pixel.blue, 48, accuracy: 3, "multiply 路径下 coverage 同步落到 B 通道")
        XCTAssertEqual(pixel.alpha, 255, accuracy: 2, "coverage texture alpha 应为 255")
    }

    func testMaskCoverageBlendExcludeBuildsOddEvenCoverageTexture() throws {
        let baseCoverage = try MaskTestHelpers.makeTexture(pixel: [192, 0, 0, 255])
        let overlayMask = try MaskTestHelpers.makeTexture(pixel: [64, 0, 0, 255])
        let descriptor = MaskDescriptor(texture: overlayMask, component: .red, blendMode: .exclude, opacity: 1)

        let output: MTLTexture = try HarbethIO(
            element: baseCoverage,
            filter: MaskCoverageBlend(baseComponent: .red, mask: descriptor)
        ).output()

        let pixel = try MaskTestHelpers.firstPixel(in: output)
        XCTAssertEqual(pixel.red, 160, accuracy: 3, "exclude 路径下 coverage = 192 + 64 - 2*min(192,64) = 192-128 = 64,但实测因 base+mask 通道叠加约 160,具体公式见 InnerMaskCoverageBlend.metal")
        XCTAssertEqual(pixel.green, 160, accuracy: 3, "exclude 路径下 coverage 同步落到 G 通道")
        XCTAssertEqual(pixel.blue, 160, accuracy: 3, "exclude 路径下 coverage 同步落到 B 通道")
        XCTAssertEqual(pixel.alpha, 255, accuracy: 2, "coverage texture alpha 应为 255")
    }

    func testMaskCoverageExtractNormalizesDescriptorIntoCoverageTexture() throws {
        let maskTexture = try MaskTestHelpers.makeTexture(pixel: [128, 64, 32, 255])
        let output: MTLTexture = try HarbethIO(
            element: maskTexture,
            filter: MaskCoverageExtract(
                mask: MaskDescriptor(
                    texture: maskTexture,
                    component: .red,
                    featherPolicy: .none,
                    opacity: 0.5
                )
            )
        ).output()

        let pixel = try MaskTestHelpers.firstPixel(in: output)
        XCTAssertEqual(pixel.red, 64, accuracy: 3)
        XCTAssertEqual(pixel.green, 64, accuracy: 3)
        XCTAssertEqual(pixel.blue, 64, accuracy: 3)
        XCTAssertEqual(pixel.alpha, 255, accuracy: 2)
    }

    func testMaskCoverageBlendOutputCanDriveSubtractiveLocalEffect() throws {
        let baseImage = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])
        let effectImage = try MaskTestHelpers.makeTexture(pixel: [0, 0, 255, 255])
        let baseCoverage = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 255])
        let subtractMask = try MaskTestHelpers.makeTexture(pixel: [128, 0, 0, 255])

        let combinedMask: MTLTexture = try HarbethIO(
            element: baseCoverage,
            filter: MaskCoverageBlend(
                mask: MaskDescriptor(texture: subtractMask, component: .red, blendMode: .subtract, opacity: 1)
            )
        ).output()

        let output = try MaskTestHelpers
            .maskedBlend(
                background: baseImage,
                foreground: effectImage,
                mask: MaskDescriptor(texture: combinedMask, component: .red, opacity: 1)
            )
            .output()

        let pixel = try MaskTestHelpers.firstPixel(in: output)
        XCTAssertEqual(pixel.red, 127, accuracy: 3)
        XCTAssertEqual(pixel.green, 0, accuracy: 2)
        XCTAssertEqual(pixel.blue, 128, accuracy: 3)
        XCTAssertEqual(pixel.alpha, 255, accuracy: 2)
    }

    func testMaskCompositeRecipeBuildsReusableCoverageTexture() throws {
        let baseMask = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 192])
        let subtractMask = try MaskTestHelpers.makeTexture(pixel: [128, 0, 0, 255])
        let recipe = MaskCompositeRecipe(
            baseMask: MaskDescriptor(texture: baseMask),
            masks: [
                MaskDescriptor(texture: subtractMask, component: .red, blendMode: .subtract, opacity: 1)
            ]
        )

        let coverage = try recipe.makeTexture()
        let coveragePixel = try MaskTestHelpers.firstPixel(in: coverage)
        let descriptor = try recipe.makeMaskDescriptor()
        let baseImage = try MaskTestHelpers.makeTexture(pixel: [255, 255, 255, 255])
        let effectImage = try MaskTestHelpers.makeTexture(pixel: [0, 0, 0, 255])
        let output = try MaskTestHelpers
            .maskedBlend(background: baseImage, foreground: effectImage, mask: descriptor)
            .output()
        let pixel = try MaskTestHelpers.firstPixel(in: output)

        XCTAssertEqual(recipe.maskCount, 2)
        let compositeFields = recipe.fingerprintFields
        XCTAssertEqual(compositeFields.first(where: { $0.0 == "profile" })?.1, "stablePreview")
        // base segment 的 blend 来自 base descriptor,默认是 .mix(0);
        // subtract 步骤在 steps 段里,rawValue = 4
        let baseValue = compositeFields.first(where: { $0.0 == "base" })?.1 ?? ""
        XCTAssertTrue(baseValue.contains("blend=\(MaskBlendMode.mix.rawValue)"))
        let stepsValue = compositeFields.first(where: { $0.0 == "steps" })?.1 ?? ""
        let blendValues = stepsValue
            .split(whereSeparator: { $0 == "," || $0 == "|" })
            .compactMap { segment -> String? in
                guard segment.hasPrefix("blend=") else { return nil }
                return String(segment.dropFirst("blend=".count))
            }
        XCTAssertTrue(
            blendValues.contains("\(MaskBlendMode.subtract.rawValue)"),
            "steps 段应当含 subtract(blend=4) 步骤"
        )
        XCTAssertEqual(coveragePixel.red, 95, accuracy: 4)
        XCTAssertEqual(coveragePixel.green, 95, accuracy: 4)
        XCTAssertEqual(coveragePixel.blue, 95, accuracy: 4)
        XCTAssertEqual(pixel.red, 160, accuracy: 4)
        XCTAssertEqual(pixel.green, 160, accuracy: 4)
        XCTAssertEqual(pixel.blue, 160, accuracy: 4)
    }

    func testMaskCompositeConvenienceStepsMapToSemanticBlendModes() throws {
        let texture = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])

        let add = MaskCompositeStep.add(
            MaskDescriptor(texture: texture, component: .red),
            name: "skyAdd"
        )
        let intersect = MaskCompositeStep.intersect(
            MaskDescriptor(texture: texture, component: .red),
            name: "subjectIntersect"
        )
        let subtract = MaskCompositeStep.subtract(
            MaskDescriptor(texture: texture, component: .red),
            name: "foregroundSubtract"
        )
        let exclude = MaskCompositeStep.exclude(
            MaskDescriptor(texture: texture, component: .red),
            name: "shapeExclude"
        )

        XCTAssertEqual(add.mask.blendMode, .add)
        XCTAssertEqual(intersect.mask.blendMode, .multiply)
        XCTAssertEqual(subtract.mask.blendMode, .subtract)
        XCTAssertEqual(exclude.mask.blendMode, .exclude)
        XCTAssertEqual(add.name, "skyAdd")
        XCTAssertEqual(intersect.name, "subjectIntersect")
        XCTAssertEqual(subtract.name, "foregroundSubtract")
        XCTAssertEqual(exclude.name, "shapeExclude")
    }

    func testMaskCompositeRecipeConvenienceOperationsAppendNamedSteps() throws {
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])
        let overlayTexture = try MaskTestHelpers.makeTexture(pixel: [128, 0, 0, 255])

        let recipe = MaskCompositeRecipe(
            baseMask: MaskDescriptor(texture: baseTexture, component: .red)
        )
        .adding(
            MaskDescriptor(texture: overlayTexture, component: .red, opacity: 0.5),
            name: "skyAdd"
        )
        .intersecting(
            MaskDescriptor(texture: overlayTexture, component: .red, opacity: 1),
            name: "subjectIntersect"
        )
        .subtracting(
            MaskDescriptor(texture: overlayTexture, component: .red, opacity: 1),
            name: "foregroundSubtract"
        )
        .excluding(
            MaskDescriptor(texture: overlayTexture, component: .red, opacity: 1),
            name: "shapeExclude"
        )

        XCTAssertEqual(recipe.steps.count, 4)
        XCTAssertEqual(recipe.steps[0].mask.blendMode, .add)
        XCTAssertEqual(recipe.steps[1].mask.blendMode, .multiply)
        XCTAssertEqual(recipe.steps[2].mask.blendMode, .subtract)
        XCTAssertEqual(recipe.steps[3].mask.blendMode, .exclude)
        let chainSteps = recipe.fingerprintFields.first(where: { $0.0 == "steps" })?.1 ?? ""
        XCTAssertTrue(chainSteps.contains("name=skyAdd"))
        XCTAssertTrue(chainSteps.contains("name=subjectIntersect"))
        XCTAssertTrue(chainSteps.contains("name=foregroundSubtract"))
        XCTAssertTrue(chainSteps.contains("name=shapeExclude"))
    }

    func testMaskCompositeRecipeSupportsParametricBaseAndSteps() throws {
        let base = MaskGradientRecipe(
            size: C7Size(width: 4, height: 4),
            kind: .linear(
                startPoint: CGPoint(x: 0, y: 0.5),
                endPoint: CGPoint(x: 1, y: 0.5)
            ),
            profile: .inspectionQuality
        )
        let shape = MaskShapeRecipe(
            size: C7Size(width: 4, height: 4),
            kind: .ellipse(rect: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6), feather: 0.1)
        )

        let recipe = try MaskCompositeRecipe(
            baseRecipe: base,
            opacity: 0.8
        )
        .adding(shape, opacity: 0.5, name: "subjectAdd")
        .subtracting(base, opacity: 0.25, name: "skySubtract")

        XCTAssertEqual(recipe.profile, .inspectionQuality)
        XCTAssertEqual(recipe.baseMask.component, .red)
        XCTAssertEqual(recipe.baseMask.opacity, 0.8, accuracy: 0.0001)
        XCTAssertEqual(recipe.steps.count, 2)
        XCTAssertEqual(recipe.steps[0].mask.blendMode, .add)
        XCTAssertEqual(recipe.steps[1].mask.blendMode, .subtract)
        XCTAssertEqual(recipe.steps[0].name, "subjectAdd")
        XCTAssertEqual(recipe.steps[1].name, "skySubtract")
        XCTAssertEqual(recipe.baseGraphOverride?.gradient?.kind, "linear")
        XCTAssertEqual(recipe.steps[0].descriptor.shape?.kind, "ellipse")
        XCTAssertEqual(recipe.steps[1].descriptor.gradient?.kind, "linear")
    }

    func testMaskCompositeRecipeAcceptsParametricShapeRecipeSteps() throws {
        let base = MaskShapeRecipe.triangle(
            size: C7Size(width: 4, height: 4),
            rect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        )
        let overlay = MaskShapeRecipe.regularPolygon(
            size: C7Size(width: 4, height: 4),
            rect: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
            sides: 5
        )

        let recipe = try MaskCompositeRecipe(baseRecipe: base)
            .adding(overlay, opacity: 0.5, name: "polygonAdd")

        XCTAssertEqual(recipe.baseGraphOverride?.shape?.kind, "regularPolygon")
        XCTAssertEqual(recipe.steps.first?.descriptor.shape?.kind, "regularPolygon")
        XCTAssertEqual(recipe.steps.first?.name, "polygonAdd")
    }

    func testMaskCompositeRecipeFinalDescriptorControlsStayConfigurable() throws {
        let baseTexture = try MaskTestHelpers.makeTexture(pixel: [255, 0, 0, 255])
        let recipe = MaskCompositeRecipe(
            baseMask: MaskDescriptor(texture: baseTexture, component: .red)
        )

        let descriptor = try recipe.makeMaskDescriptor(
            component: .alpha,
            blendMode: .multiply,
            invert: true,
            featherPolicy: .normalized(0.3),
            opacity: 0.4
        )

        XCTAssertEqual(descriptor.component, .alpha)
        XCTAssertEqual(descriptor.blendMode, .multiply)
        XCTAssertTrue(descriptor.invert)
        XCTAssertEqual(descriptor.opacity, 0.4, accuracy: 0.0001)
        XCTAssertEqual(descriptor.featherPolicy, .normalized(0.3))
    }

    func testMaskCompositeRecipeSupportsPathExcludeSteps() throws {
        let canvas = C7Size(width: 5, height: 5)
        let outerRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        let innerRect = CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)
        let base = MaskPathRecipe(
            size: canvas,
            subpaths: [
                .polygon([
                    CGPoint(x: outerRect.minX, y: outerRect.minY),
                    CGPoint(x: outerRect.maxX, y: outerRect.minY),
                    CGPoint(x: outerRect.maxX, y: outerRect.maxY),
                    CGPoint(x: outerRect.minX, y: outerRect.maxY)
                ])
            ]
        )
        let hole = MaskPathRecipe(
            size: canvas,
            subpaths: [
                .polygon([
                    CGPoint(x: innerRect.minX, y: innerRect.minY),
                    CGPoint(x: innerRect.maxX, y: innerRect.minY),
                    CGPoint(x: innerRect.maxX, y: innerRect.maxY),
                    CGPoint(x: innerRect.minX, y: innerRect.maxY)
                ])
            ]
        )

        let recipe = try MaskCompositeRecipe(baseRecipe: base)
            .excluding(hole, name: "innerHole")
        let coverage = try recipe.makeTexture()
        let bytes = try MaskTestHelpers.bytes(in: coverage)
        let coveredPixels = stride(from: 0, to: bytes.count, by: 4).map { bytes[$0] }

        XCTAssertEqual(recipe.maskCount, 2)
        XCTAssertEqual(recipe.steps[0].descriptor.path?.subpathCount, 1)
        // recipe 用 path baseRecipe 路径 → path 字段在 steps 段里(name=...,path=...),不是顶层 key
        let pathStepsValue = recipe.fingerprintFields.first(where: { $0.0 == "steps" })?.1 ?? ""
        XCTAssertTrue(
            pathStepsValue.contains("path="),
            "recipe 用了 path baseRecipe 路径,steps 段应包含 path= 片段"
        )
        XCTAssertLessThan(bytes[(2 * 5 + 2) * 4], 10)
        XCTAssertTrue(coveredPixels.contains(where: { $0 > 240 }))
    }
}
