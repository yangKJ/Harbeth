// Created by Condy on 2026/11/16.
import XCTest
import Metal
import QuartzCore
@testable import Harbeth

/// 冻结改动前的二维算法，仅用于同设备配对测量，不进入生产回退路径。
final class AlgorithmBenefitBenchmarkTests: XCTestCase {
    func testPairedAlgorithmBenefits() throws {
        guard ProcessInfo.processInfo.environment["HARBETH_ALGORITHM_BENCHMARKS"] == "1" else { throw XCTSkip("按需运行算法收益基准") }
        #if DEBUG
        throw XCTSkip("性能对照使用 Release 构建")
        #else
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let library = try device.makeLibrary(source: Self.referenceSource, options: nil)
        HarbethContext.shared.registerExternalLibraryProvider(BenefitReferenceLibrary(library: library))
        var rows: [[String: Any]] = []
        let source = try texture(device: device, width: 1024, height: 1024)
        for (name, baseline, current): (String, any C7FilterProtocol, any C7FilterProtocol) in [
            ("localBlur", OriginalLocalBlur(radius: 10), C7LocalBlur(radius: 10)),
            ("tiltShift", OriginalTiltShift(), C7TiltShift())
        ] {
            let before: MTLTexture = try HarbethIO(element: source, filter: baseline).output()
            let after: MTLTexture = try HarbethIO(element: source, filter: current).output()
            let a = try XCTUnwrap(before.c7.rawBytes(maximumBytes: 1024 * 1024 * 8))
            let b = try XCTUnwrap(after.c7.rawBytes(maximumBytes: 1024 * 1024 * 8))
            let error = a.withUnsafeBytes { left in b.withUnsafeBytes { right in
                zip(left.bindMemory(to: UInt16.self), right.bindMemory(to: UInt16.self)).map {
                    abs(Float(Float16(bitPattern: $0)) - Float(Float16(bitPattern: $1)))
                }.max() ?? 0
            } }
            XCTAssertLessThan(error, 0.003)
            rows.append(try paired(name, metadata: ["width": 1024, "height": 1024, "maximumAbsoluteError": error],
                before: { let _: MTLTexture = try HarbethIO(element: source, filter: baseline).output() },
                after: { let _: MTLTexture = try HarbethIO(element: source, filter: current).output() }))
        }
        rows.append(try paired("bilateralRangeLookup", metadata: ["width": 1024, "height": 1024],
            before: { let _: MTLTexture = try HarbethIO(element: source, filter: C7BilateralBlur()).output() },
            after: { let _: MTLTexture = try HarbethIO(element: source, filter: ApproximateBilateralReference(base: C7BilateralBlur())).output() }))
        let large = try texture(device: device, width: 3840, height: 2160)
        rows.append(try paired("statistics4K", metadata: ["cpuReadbackBeforeBytes": 3840 * 2160 * 8, "cpuReadbackAfterBytes": 48],
            before: {
                let readback = try XCTUnwrap(TextureAnalysisReadback(texture: large))
                _ = try XCTUnwrap(large.c7.makeStatistics(readback: readback, region: nil, maskSample: nil,
                    luminanceRange: nil, colorRange: nil, coverageThreshold: 0.5))
            }, after: { _ = try XCTUnwrap(GPUTextureAnalysis.statistics(large, scope: TextureAnalysisScope())) }))
        let report: [String: Any] = ["device": device.name, "configuration": "release",
            "measurement": "同步离屏端到端墙钟；每条路线预热3次，交替顺序9对样本；不含drawable呈现", "rows": rows]
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("HarbethAlgorithmBenefits-20261116.json")
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url)
        print("[算法收益报告] \(url.path)")
        #endif
    }

    private func paired(_ name: String, metadata: [String: Any], before: () throws -> Void, after: () throws -> Void) throws -> [String: Any] {
        for _ in 0..<3 { try before(); try after() }
        func time(_ operation: () throws -> Void) throws -> Double {
            let start = CACurrentMediaTime(); try autoreleasepool(invoking: operation); return (CACurrentMediaTime() - start) * 1000
        }
        var old: [Double] = [], new: [Double] = []
        for index in 0..<9 {
            if index.isMultiple(of: 2) { old.append(try time(before)); new.append(try time(after)) }
            else { new.append(try time(after)); old.append(try time(before)) }
        }
        old.sort(); new.sort()
        var row = metadata
        row["name"] = name; row["baselineP50Ms"] = old[4]; row["currentP50Ms"] = new[4]
        row["baselineP95Ms"] = old[8]; row["currentP95Ms"] = new[8]
        print("[算法收益] \(name)：\(old[4]) → \(new[4]) ms")
        return row
    }

    private func texture(device: MTLDevice, width: Int, height: Int) throws -> MTLTexture {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        d.storageMode = .shared; d.usage = [.shaderRead, .shaderWrite]
        let result = try XCTUnwrap(device.makeTexture(descriptor: d))
        var pixels = [Float16](repeating: 1, count: width * height * 4)
        for index in 0..<(width * height) {
            pixels[index * 4] = Float16(Float(index % width) / Float(width))
            pixels[index * 4 + 1] = Float16(Float(index / width) / Float(height))
            pixels[index * 4 + 2] = 0.25
        }
        pixels.withUnsafeBytes { result.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
            withBytes: $0.baseAddress!, bytesPerRow: width * 8) }
        return result
    }
    private static let referenceSource = #"""
//
//  C7LocalBlur.metal
//  Harbeth
//
//  Created by Condy on 2026/3/7.
//

#include <metal_stdlib>
using namespace metal;

kernel void AuditLocalBlurReference(texture2d<half, access::write> outputTexture [[texture(0)]],
                        texture2d<half, access::read> inputTexture [[texture(1)]],
                        constant float *radius [[buffer(0)]],
                        constant float *centerX [[buffer(1)]],
                        constant float *centerY [[buffer(2)]],
                        constant float *size [[buffer(3)]],
                        constant float *softness [[buffer(4)]],
                        uint2 grid [[thread_position_in_grid]]) {
    const int width = inputTexture.get_width();
    const int height = inputTexture.get_height();
    const int x = int(grid.x);
    const int y = int(grid.y);

    // Calculate pixel distance from center
    float2 pixelPos = float2(float(x) / float(width), float(y) / float(height));
    float2 centerPos = float2(*centerX, *centerY);
    float distance = length(pixelPos - centerPos);

    // Calculate blur strength based on distance
    float blurSize = *size * 0.5; // Normalize size
    float blurSoftness = *softness;
    float blurStrength = smoothstep(blurSize, blurSize - blurSoftness, distance);
    blurStrength = clamp(blurStrength, 0.0, 1.0);

    if (blurStrength < 0.01) {
        // No blur, just copy the original pixel
        outputTexture.write(inputTexture.read(grid), grid);
        return;
    }

    // Calculate Gaussian blur
    int kernelSize = int(ceil(*radius) * 2 + 1);
    int kernelRadius = kernelSize / 2;
    float sigma = *radius / 3.0;
    float sigma2 = sigma * sigma;

    float4 blurredColor = float4(0.0);
    float weightSum = 0.0;

    for (int i = -kernelRadius; i <= kernelRadius; i++) {
        for (int j = -kernelRadius; j <= kernelRadius; j++) {
            int pixelX = clamp(x + i, 0, width - 1);
            int pixelY = clamp(y + j, 0, height - 1);

            // Calculate Gaussian weight
            float distance2 = float(i * i + j * j);
            float weight = exp(-distance2 / (2.0 * sigma2));

            blurredColor += float4(inputTexture.read(uint2(pixelX, pixelY))) * weight;
            weightSum += weight;
        }
    }

    blurredColor /= weightSum;

    // Get original color
    float4 originalColor = float4(inputTexture.read(grid));

    // Mix original and blurred color based on blur strength
    float4 finalColor = mix(originalColor, blurredColor, blurStrength);

    outputTexture.write(half4(finalColor), grid);
}

//
//  C7TiltShift.metal
//  Harbeth
//
//  Created by Condy on 2026/3/13.
//

#include <metal_stdlib>
using namespace metal;

// 高斯模糊函数
float4 auditGaussianBlur(texture2d<half, access::read> texture, int2 position, float blurRadius, int2 size) {
    float4 color = float4(0.0);
    float totalWeight = 0.0;

    // 计算高斯核大小
    int kernelSize = int(ceil(blurRadius * 10.0));

    for (int x = -kernelSize; x <= kernelSize; x++) {
        for (int y = -kernelSize; y <= kernelSize; y++) {
            // 计算高斯权重
            float distance = sqrt(float(x * x + y * y));
            float weight = exp(-(distance * distance) / (2.0 * blurRadius * blurRadius));

            // 计算采样位置
            const int2 samplePos = clamp(position + int2(x, y), int2(0), size - 1);
            color += float4(texture.read(uint2(samplePos))) * weight;
            totalWeight += weight;
        }
    }

    return color / totalWeight;
}

kernel void AuditTiltShiftReference(texture2d<half, access::write> outputTexture [[texture(0)]],
                      texture2d<half, access::read> inputTexture [[texture(1)]],
                      constant float *blurRadius [[buffer(0)]],
                      constant float *center [[buffer(1)]],
                      constant float *size [[buffer(2)]],
                      constant float *transition [[buffer(3)]],
                      constant float *isLinear [[buffer(4)]],
                      constant float4 *regionContext [[buffer(30)]],
                      uint2 grid [[thread_position_in_grid]]) {

    const float4 inColor = float4(inputTexture.read(grid));
    const int2 textureSize = int2(inputTexture.get_width(), inputTexture.get_height());
    const float4 outputRegion = regionContext[1];
    const float2 globalPixel = float2(grid) + outputRegion.xy;
    const float2 logicalSize = max(outputRegion.zw, float2(1.0));

    float blurAmount = *blurRadius;
    float centerPoint = *center;
    float clearSize = *size;
    float transitionSize = *transition;
    bool linearMode = *isLinear > 0.5;

    // 计算像素到清晰区域的距离
    float distance = 0.0;

    if (linearMode) {
        // 线性模式：计算垂直距离
        float pixelY = globalPixel.y / logicalSize.y;
        distance = abs(pixelY - centerPoint);
    } else {
        // 径向模式：计算到中心点的距离
        float2 centerCoord = float2(logicalSize.x * 0.5, logicalSize.y * centerPoint);
        float2 pixelCoord = globalPixel;
        float2 delta = pixelCoord - centerCoord;
        distance = length(delta) / length(logicalSize * 0.5);
    }

    // 计算模糊强度
    float blurStrength = 0.0;
    float clearHalfSize = clearSize * 0.5;

    if (distance > clearHalfSize) {
        float transitionStart = clearHalfSize;
        float transitionEnd = clearHalfSize + transitionSize;

        if (distance > transitionEnd) {
            blurStrength = 1.0;
        } else if (distance > transitionStart) {
            // 平滑过渡
            blurStrength = (distance - transitionStart) / (transitionEnd - transitionStart);
        }
    }

    // 应用模糊
    float4 blurredColor = auditGaussianBlur(inputTexture, int2(grid), blurAmount * 10.0, textureSize);
    float4 finalColor = mix(inColor, blurredColor, blurStrength * blurAmount);

    outputTexture.write(half4(finalColor), grid);
}

//
//  C7BilateralBlur.metal
//  Harbeth
//
//  Created by Condy on 2022/3/2.
//

#include <metal_stdlib>
using namespace metal;

kernel void AuditBilateralLookup(texture2d<float, access::write> outputTexture [[texture(0)]],
                            texture2d<float, access::read> inputTexture [[texture(1)]],
                            constant float *sigmaSpace [[buffer(0)]],
                            constant float *sigmaColor [[buffer(1)]],
                            constant float *blurRadius [[buffer(2)]],
                            constant float *spatialWeights [[buffer(3)]],
                            constant float &usesSpatialWeights [[buffer(4)]],
                            constant float *rangeWeights [[buffer(5)]],
                            constant float &usesRangeWeights [[buffer(6)]],
                            uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) return;
    const float x = float(grid.x);
    const float y = float(grid.y);
    const float width = float(inputTexture.get_width());
    const float height = float(inputTexture.get_height());

    uint2 centralPixel = uint2(x, y);
    float4 centralColor = inputTexture.read(centralPixel);

    if (!isfinite(*sigmaSpace) || !isfinite(*sigmaColor) || *sigmaSpace <= 0.0f || *sigmaColor <= 0.0f || !isfinite(*blurRadius) || *blurRadius <= 0.0f) {
        outputTexture.write(centralColor, grid);
        return;
    }

    int radius = int(*blurRadius);
    if (radius < 1) radius = 1;

    float4 sum = float4(0.0);
    float weightSum = 0.0;

    float sigmaSpaceSquared = *sigmaSpace * *sigmaSpace;
    float sigmaColorSquared = *sigmaColor * *sigmaColor;

    for (int i = -radius; i <= radius; i++) {
        for (int j = -radius; j <= radius; j++) {
            int2 offset = int2(i, j);
            uint2 currentPixel = uint2(clamp(int(x) + offset.x, 0, int(width) - 1),
                                       clamp(int(y) + offset.y, 0, int(height) - 1));
            float4 currentColor = inputTexture.read(currentPixel);
            float spatialDistanceSquared = float(i * i + j * j);
            float3 colorDiff = currentColor.rgb - centralColor.rgb;
            float colorDistanceSquared = dot(float3(colorDiff), float3(colorDiff));
            float spatialWeight = usesSpatialWeights > 0.5f ? spatialWeights[i + radius] * spatialWeights[j + radius]
                : exp(-(spatialDistanceSquared) / (2.0 * sigmaSpaceSquared));
            float exponent = colorDistanceSquared == 0 ? 0 : colorDistanceSquared / (2.0 * sigmaColorSquared);
            float colorWeight;
            if (usesRangeWeights > 0.5f) {
                float position = clamp(exponent, 0.0f, 16.0f) * 16;
                uint lower = min(uint(position), 255u);
                colorWeight = exponent >= 16 ? 0 : mix(rangeWeights[lower], rangeWeights[lower + 1], position - float(lower));
            } else {
                colorWeight = exp(-exponent);
            }
            float weight = spatialWeight * colorWeight;
            sum += float4(currentColor) * weight;
            weightSum += weight;
        }
    }
    float4 outColor = float4(sum / max(weightSum, 1e-20f));

    outputTexture.write(outColor, grid);
}

"""#
}
private struct BenefitReferenceFilter: C7FilterProtocol {
    let kernel: String
    let factors: [Float]
    var modifier: ModifierEnum { .compute(kernel: kernel) }
    var computeKernelLibrarySource: KernelLibrarySource { .externalProvider("algorithm-benefit") }
    var memoryAccessPattern: MemoryAccessPattern { .neighborhood }
}
private struct BenefitReferenceLibrary: ExternalMTLLibraryProvider {
    let library: MTLLibrary
    var providerIdentifier: String { "algorithm-benefit" }
    func provideLibrary(for device: MTLDevice) -> MTLLibrary? { library }
}

/// 查表近似保留在实验基准中；当前设备上没有性能收益，不进入生产 API。
private struct ApproximateBilateralReference: C7FilterProtocol {
    let base: C7BilateralBlur
    private static let rangeWeights = (0...256).map { exp(-Float($0) / 16) }
    var modifier: ModifierEnum { .compute(kernel: "AuditBilateralLookup") }
    var computeKernelLibrarySource: KernelLibrarySource { .externalProvider("algorithm-benefit") }
    var memoryAccessPattern: MemoryAccessPattern { .neighborhood }
    var kernelParameterBindings: [KernelParameterBinding] {
        base.kernelParameterBindings + [
            .init(name: "rangeWeights", index: 5, stage: .compute, value: .floatArray(Self.rangeWeights)),
            .init(name: "lookup", index: 6, stage: .compute, value: .float(1))
        ]
    }
}

private struct OriginalLocalBlur: C7FilterProtocol {

    /// Blur radius, from 0.0 to 100.0, default 10.0
    var radius: Float = 10.0

    /// Blur center, normalized coordinates (0.0-1.0), default center
    var center: C7Point2D = C7Point2D.center

    /// Blur size, normalized (0.0-1.0), default 0.5
    @ZeroOneRange var size: Float = 0.5

    /// Blur softness, from 0.0 to 1.0, default 0.3
    @ZeroOneRange var softness: Float = 0.3

    var computeKernelLibrarySource: KernelLibrarySource { .externalProvider("algorithm-benefit") }
    var modifier: ModifierEnum {
        return .compute(kernel: "AuditLocalBlurReference")
    }

    var factors: [Float] {
        return [radius, center.x, center.y, size, softness]
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    init(radius: Float = 10.0, center: C7Point2D = C7Point2D.center, size: Float = 0.5, softness: Float = 0.3) {
        self.radius = radius
        self.center = center
        self.size = size
        self.softness = softness
    }
}

private struct OriginalTiltShift: C7FilterProtocol {

    enum TiltShiftMode {
        case linear
        case radial
    }

    static let range: ParameterRange<Float, Self> = .init(min: 0.0, max: 1.0, value: 0.2)

    /// 模糊半径，0.0 到 1.0，默认 0.2
    @Clamping(range.min...range.max) var blurRadius: Float = range.value

    /// 清晰区域中心，0.0 到 1.0，默认 0.5
    @ZeroOneRange var center: Float = 0.5

    /// 清晰区域大小，0.0 到 1.0，默认 0.3
    @ZeroOneRange var size: Float = 0.3

    /// 过渡区域大小，0.0 到 1.0，默认 0.1
    @ZeroOneRange var transition: Float = 0.1

    /// 移轴模式，线性或径向
    var mode: TiltShiftMode = .linear

    var computeKernelLibrarySource: KernelLibrarySource { .externalProvider("algorithm-benefit") }
    var modifier: ModifierEnum {
        return .compute(kernel: "AuditTiltShiftReference")
    }

    var factors: [Float] {
        return [blurRadius, center, size, transition, mode == .linear ? 1.0 : 0.0]
    }

    var memoryAccessPattern: MemoryAccessPattern {
        .neighborhood
    }

    init(blurRadius: Float = range.value, center: Float = 0.5, size: Float = 0.3, transition: Float = 0.1, mode: TiltShiftMode = .linear) {
        self.blurRadius = blurRadius
        self.center = center
        self.size = size
        self.transition = transition
        self.mode = mode
    }
}
