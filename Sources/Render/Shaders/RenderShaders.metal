#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

struct QuadTransformUniforms {
    float3x3 inverseHomography;
    float2 viewportOrigin;
    float2 viewportSize;
    uint samplingMode;
    uint edgeMode;
    uint2 padding;
};

vertex VertexOut basicVertex(uint vertexID [[vertex_id]], constant float *vertices [[buffer(0)]]) {
    VertexOut vertexOut;

    float x = vertices[vertexID * 4 + 0];
    float y = vertices[vertexID * 4 + 1];
    float u = vertices[vertexID * 4 + 2];
    float v = vertices[vertexID * 4 + 3];

    vertexOut.position = float4(x, y, 0.0, 1.0);
    vertexOut.textureCoordinate = float2(u, v);
    return vertexOut;
}

vertex VertexOut projectiveVertex(uint vertexID [[vertex_id]], constant float *vertices [[buffer(0)]]) {
    VertexOut vertexOut;

    float x = vertices[vertexID * 5 + 0];
    float y = vertices[vertexID * 5 + 1];
    float w = vertices[vertexID * 5 + 2];
    float u = vertices[vertexID * 5 + 3];
    float v = vertices[vertexID * 5 + 4];

    vertexOut.position = float4(x, y, 0.0, w);
    vertexOut.textureCoordinate = float2(u, v);
    return vertexOut;
}

// 线性到sRGB转换
float3 linearToSRGB(float3 color) {
    return float3(color.r < 0.0031308 ? 12.92 * color.r : 1.055 * pow(color.r, 1.0/2.4) - 0.055,
                  color.g < 0.0031308 ? 12.92 * color.g : 1.055 * pow(color.g, 1.0/2.4) - 0.055,
                  color.b < 0.0031308 ? 12.92 * color.b : 1.055 * pow(color.b, 1.0/2.4) - 0.055);
}

fragment float4 basicFragment(VertexOut vertexOut [[stage_in]],
                              texture2d<float, access::sample> inputTexture [[texture(0)]],
                              sampler textureSampler [[sampler(0)]]) {
    float4 color = inputTexture.sample(textureSampler, vertexOut.textureCoordinate);
    return color;
}

struct DualOutputLuminanceFragmentOut {
    float4 primaryColor [[color(0)]];
    float4 luminanceColor [[color(1)]];
};

static inline float maskComponentValue(float4 color, int component) {
    switch (component) {
        case 0: return color.a;
        case 1: return color.r;
        case 2: return color.g;
        case 3: return color.b;
        case 4: return dot(color.rgb, float3(0.299, 0.587, 0.114));
        default: return color.a;
    }
}

fragment DualOutputLuminanceFragmentOut dualOutputLuminanceFragment(
    VertexOut vertexOut [[stage_in]],
    texture2d<float, access::sample> inputTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    float4 color = inputTexture.sample(textureSampler, vertexOut.textureCoordinate);
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));

    DualOutputLuminanceFragmentOut output;
    output.primaryColor = color;
    output.luminanceColor = float4(luminance, luminance, luminance, 1.0);
    return output;
}

struct DualOutputMaskCoverageFragmentOut {
    float4 primaryColor [[color(0)]];
    float4 maskCoverageColor [[color(1)]];
};

struct DualOutputHighlightClippingFragmentOut {
    float4 primaryColor [[color(0)]];
    float4 analysisColor [[color(1)]];
};

struct DualOutputShadowClippingFragmentOut {
    float4 primaryColor [[color(0)]];
    float4 analysisColor [[color(1)]];
};

struct DualOutputFalseColorExposureFragmentOut {
    float4 primaryColor [[color(0)]];
    float4 analysisColor [[color(1)]];
};

fragment DualOutputMaskCoverageFragmentOut dualOutputMaskCoverageFragment(
    VertexOut vertexOut [[stage_in]],
    texture2d<float, access::sample> inputTexture [[texture(0)]],
    texture2d<float, access::sample> maskTexture [[texture(1)]],
    constant float *maskParameters [[buffer(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    float4 color = inputTexture.sample(textureSampler, vertexOut.textureCoordinate);
    float4 maskColor = maskTexture.sample(textureSampler, vertexOut.textureCoordinate);

    float opacity = clamp(maskParameters[0], 0.0, 1.0);
    bool invert = maskParameters[1] > 0.5;
    int component = int(maskParameters[2]);
    float feather = clamp(maskParameters[3], 0.0, 1.0);

    float mask = maskComponentValue(maskColor, component);
    if (invert) {
        mask = 1.0 - mask;
    }
    if (feather > 0.0) {
        float low = max(0.0, 0.5 - feather * 0.5);
        float high = min(1.0, 0.5 + feather * 0.5);
        mask = smoothstep(low, high, mask);
    }
    mask *= opacity;

    DualOutputMaskCoverageFragmentOut output;
    output.primaryColor = color;
    output.maskCoverageColor = float4(mask, mask, mask, 1.0);
    return output;
}

fragment DualOutputHighlightClippingFragmentOut dualOutputHighlightClippingFragment(
    VertexOut vertexOut [[stage_in]],
    texture2d<float, access::sample> inputTexture [[texture(0)]],
    constant float *analysisParameters [[buffer(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    float4 color = inputTexture.sample(textureSampler, vertexOut.textureCoordinate);

    float threshold = clamp(analysisParameters[0], 0.0, 1.0);
    float softness = clamp(analysisParameters[1], 0.0, 1.0);
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float low = max(0.0, threshold - softness);
    float high = min(1.0, threshold + max(softness, 0.0001));
    float clipped = softness > 0.0 ? smoothstep(low, high, luminance) : step(threshold, luminance);

    DualOutputHighlightClippingFragmentOut output;
    output.primaryColor = color;
    output.analysisColor = float4(clipped, 0.0, 0.0, 1.0);
    return output;
}

fragment DualOutputShadowClippingFragmentOut dualOutputShadowClippingFragment(
    VertexOut vertexOut [[stage_in]],
    texture2d<float, access::sample> inputTexture [[texture(0)]],
    constant float *analysisParameters [[buffer(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    float4 color = inputTexture.sample(textureSampler, vertexOut.textureCoordinate);

    float threshold = clamp(analysisParameters[0], 0.0, 1.0);
    float softness = clamp(analysisParameters[1], 0.0, 1.0);
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float low = max(0.0, threshold - max(softness, 0.0001));
    float high = min(1.0, threshold + softness);
    float clipped = softness > 0.0 ? 1.0 - smoothstep(low, high, luminance) : 1.0 - step(threshold, luminance);

    DualOutputShadowClippingFragmentOut output;
    output.primaryColor = color;
    output.analysisColor = float4(clipped, 0.0, 0.0, 1.0);
    return output;
}

fragment DualOutputFalseColorExposureFragmentOut dualOutputFalseColorExposureFragment(
    VertexOut vertexOut [[stage_in]],
    texture2d<float, access::sample> inputTexture [[texture(0)]],
    constant float *analysisParameters [[buffer(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    float4 color = inputTexture.sample(textureSampler, vertexOut.textureCoordinate);
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));

    float shadowThreshold = clamp(analysisParameters[0], 0.0, 1.0);
    float lowMidThreshold = clamp(max(analysisParameters[1], shadowThreshold), 0.0, 1.0);
    float highMidThreshold = clamp(max(analysisParameters[2], lowMidThreshold), 0.0, 1.0);
    float highlightThreshold = clamp(max(analysisParameters[3], highMidThreshold), 0.0, 1.0);

    float3 analysisColor;
    if (luminance <= shadowThreshold) {
        analysisColor = float3(0.0, 0.0, 1.0);
    } else if (luminance <= lowMidThreshold) {
        analysisColor = float3(0.0, 1.0, 1.0);
    } else if (luminance <= highMidThreshold) {
        analysisColor = float3(0.0, 1.0, 0.0);
    } else if (luminance <= highlightThreshold) {
        analysisColor = float3(1.0, 1.0, 0.0);
    } else {
        analysisColor = float3(1.0, 0.0, 0.0);
    }

    DualOutputFalseColorExposureFragmentOut output;
    output.primaryColor = color;
    output.analysisColor = float4(analysisColor, 1.0);
    return output;
}

fragment float4 quadTransformFragment(VertexOut vertexOut [[stage_in]],
                                      texture2d<float, access::sample> inputTexture [[texture(0)]],
                                      constant QuadTransformUniforms &uniforms [[buffer(0)]],
                                      sampler textureSampler [[sampler(0)]]) {
    constexpr sampler nearestTransparent(coord::normalized, address::clamp_to_zero, filter::nearest);
    constexpr sampler linearTransparent(coord::normalized, address::clamp_to_zero, filter::linear);
    constexpr sampler nearestClamp(coord::normalized, address::clamp_to_edge, filter::nearest);
    constexpr sampler linearClamp(coord::normalized, address::clamp_to_edge, filter::linear);
    constexpr sampler nearestRepeat(coord::normalized, address::repeat, filter::nearest);
    constexpr sampler linearRepeat(coord::normalized, address::repeat, filter::linear);
    constexpr sampler nearestMirror(coord::normalized, address::mirrored_repeat, filter::nearest);
    constexpr sampler linearMirror(coord::normalized, address::mirrored_repeat, filter::linear);
#if defined(__HAVE_BICUBIC_FILTERING__)
    constexpr sampler bicubicTransparent(coord::normalized, address::clamp_to_zero, filter::bicubic);
    constexpr sampler bicubicClamp(coord::normalized, address::clamp_to_edge, filter::bicubic);
    constexpr sampler bicubicRepeat(coord::normalized, address::repeat, filter::bicubic);
    constexpr sampler bicubicMirror(coord::normalized, address::mirrored_repeat, filter::bicubic);
#endif

    float2 destinationPoint = uniforms.viewportOrigin + vertexOut.textureCoordinate * uniforms.viewportSize;
    float3 sourcePoint = uniforms.inverseHomography * float3(destinationPoint, 1.0);
    sourcePoint /= sourcePoint.z;

    float2 uv = float2(
        (sourcePoint.x + inputTexture.get_width() * 0.5) / inputTexture.get_width(),
        (sourcePoint.y + inputTexture.get_height() * 0.5) / inputTexture.get_height()
    );

    const bool useNearest = uniforms.samplingMode == 0;
#if defined(__HAVE_BICUBIC_FILTERING__)
    const bool preferBicubic = uniforms.samplingMode == 2;
#else
    const bool preferBicubic = false;
#endif

    float4 color;
    if (useNearest) {
        switch (uniforms.edgeMode) {
            case 1: color = inputTexture.sample(nearestClamp, uv); break;
            case 2: color = inputTexture.sample(nearestRepeat, uv); break;
            case 3: color = inputTexture.sample(nearestMirror, uv); break;
            default: color = inputTexture.sample(nearestTransparent, uv); break;
        }
    } else if (preferBicubic) {
#if defined(__HAVE_BICUBIC_FILTERING__)
        switch (uniforms.edgeMode) {
            case 1: color = inputTexture.sample(bicubicClamp, uv); break;
            case 2: color = inputTexture.sample(bicubicRepeat, uv); break;
            case 3: color = inputTexture.sample(bicubicMirror, uv); break;
            default: color = inputTexture.sample(bicubicTransparent, uv); break;
        }
#else
        switch (uniforms.edgeMode) {
            case 1: color = inputTexture.sample(linearClamp, uv); break;
            case 2: color = inputTexture.sample(linearRepeat, uv); break;
            case 3: color = inputTexture.sample(linearMirror, uv); break;
            default: color = inputTexture.sample(linearTransparent, uv); break;
        }
#endif
    } else {
        switch (uniforms.edgeMode) {
            case 1: color = inputTexture.sample(linearClamp, uv); break;
            case 2: color = inputTexture.sample(linearRepeat, uv); break;
            case 3: color = inputTexture.sample(linearMirror, uv); break;
            default: color = inputTexture.sample(linearTransparent, uv); break;
        }
    }

    return color;
}

fragment float4 grayscaleFragment(VertexOut vertexOut [[stage_in]],
                                  texture2d<float, access::sample> inputTexture [[texture(0)]],
                                  sampler textureSampler [[sampler(0)]]) {
    float4 color = inputTexture.sample(textureSampler, vertexOut.textureCoordinate);
    float gray = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    return float4(gray, gray, gray, color.a);
}

fragment float4 sepiaFragment(VertexOut vertexOut [[stage_in]],
                              texture2d<float, access::sample> inputTexture [[texture(0)]],
                              sampler textureSampler [[sampler(0)]]) {
    float4 color = inputTexture.sample(textureSampler, vertexOut.textureCoordinate);
    float gray = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float4 sepiaColor = float4(gray * 0.9, gray * 0.7, gray * 0.4, color.a);
    return sepiaColor;
}

struct HistogramPreviewParameters {
    uint histogramOffset;
    uint histogramCount;
    uint textureHeight;
    uint peakCount;
};

kernel void histogramPreviewKernel(
    device const uint *histogramBuffer [[buffer(0)]],
    constant HistogramPreviewParameters &params [[buffer(1)]],
    constant float4 &barColor [[buffer(2)]],
    texture2d<float, access::write> outputTexture [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    uint index = min(gid.x, max(params.histogramCount, 1u) - 1u);
    uint count = histogramBuffer[params.histogramOffset + index];
    float normalized = params.peakCount > 0 ? float(count) / float(params.peakCount) : 0.0;
    uint filledHeight = uint(ceil(normalized * float(params.textureHeight)));
    uint thresholdRow = params.textureHeight > filledHeight ? (params.textureHeight - filledHeight) : 0u;

    float4 value = gid.y >= thresholdRow ? barColor : float4(0.0, 0.0, 0.0, 1.0);
    outputTexture.write(value, gid);
}
