#include <metal_stdlib>
using namespace metal;

static inline half coverage_mask_component_value(half4 color, int component) {
    switch (component) {
        case 0: return color.a;
        case 1: return color.r;
        case 2: return color.g;
        case 3: return color.b;
        case 4: return dot(color.rgb, half3(0.299h, 0.587h, 0.114h));
        default: return color.a;
    }
}

static inline half normalized_mask_value(half4 color,
                                         int component,
                                         bool invert,
                                         half opacity,
                                         half feather) {
    half value = coverage_mask_component_value(color, component);
    if (invert) {
        value = 1.0h - value;
    }
    if (feather > 0.0h) {
        const half low = max(0.0h, 0.5h - feather * 0.5h);
        const half high = min(1.0h, 0.5h + feather * 0.5h);
        value = smoothstep(low, high, value);
    }
    return clamp(value * opacity, 0.0h, 1.0h);
}

static inline half combine_coverage(half baseCoverage, half maskCoverage, int blendMode) {
    switch (blendMode) {
        case 2:
            return clamp(baseCoverage + maskCoverage, 0.0h, 1.0h);
        case 3:
            return clamp(baseCoverage * maskCoverage, 0.0h, 1.0h);
        case 4:
            return clamp(baseCoverage * (1.0h - maskCoverage), 0.0h, 1.0h);
        case 1:
        case 0:
        default:
            return maskCoverage;
    }
}

kernel void C7MaskCoverageBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                                texture2d<half, access::read> baseTexture [[texture(1)]],
                                texture2d<half, access::read> maskTexture [[texture(2)]],
                                constant float *baseOpacityPointer [[buffer(0)]],
                                constant float *baseInvertPointer [[buffer(1)]],
                                constant float *baseComponentPointer [[buffer(2)]],
                                constant float *baseFeatherPointer [[buffer(3)]],
                                constant float *maskOpacityPointer [[buffer(4)]],
                                constant float *maskInvertPointer [[buffer(5)]],
                                constant float *maskComponentPointer [[buffer(6)]],
                                constant float *maskBlendModePointer [[buffer(7)]],
                                constant float *maskFeatherPointer [[buffer(8)]],
                                uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    const half4 baseColor = baseTexture.read(gid);
    const half4 maskColor = maskTexture.read(gid);
    const half baseCoverage = normalized_mask_value(
        baseColor,
        int(*baseComponentPointer),
        *baseInvertPointer > 0.5f,
        half(*baseOpacityPointer),
        half(*baseFeatherPointer)
    );
    const half maskCoverage = normalized_mask_value(
        maskColor,
        int(*maskComponentPointer),
        *maskInvertPointer > 0.5f,
        half(*maskOpacityPointer),
        half(*maskFeatherPointer)
    );
    const half combinedCoverage = combine_coverage(baseCoverage, maskCoverage, int(*maskBlendModePointer));
    const half4 output = half4(combinedCoverage, combinedCoverage, combinedCoverage, 1.0h);
    outputTexture.write(output, gid);
}
