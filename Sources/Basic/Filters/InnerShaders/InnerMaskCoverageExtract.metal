#include <metal_stdlib>
using namespace metal;

static inline half extract_mask_component_value(half4 color, int component) {
    switch (component) {
        case 0: return color.a;
        case 1: return color.r;
        case 2: return color.g;
        case 3: return color.b;
        case 4: return dot(color.rgb, half3(0.299h, 0.587h, 0.114h));
        default: return color.a;
    }
}

kernel void InnerMaskCoverageExtract(texture2d<half, access::write> outputTexture [[texture(0)]],
                                     texture2d<half, access::read> inputTexture [[texture(1)]],
                                     constant float *opacityPointer [[buffer(0)]],
                                     constant float *invertPointer [[buffer(1)]],
                                     constant float *componentPointer [[buffer(2)]],
                                     constant float *featherPointer [[buffer(3)]],
                                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    const half4 input = inputTexture.read(gid);
    half coverage = extract_mask_component_value(input, int(*componentPointer));
    if (*invertPointer > 0.5f) {
        coverage = 1.0h - coverage;
    }
    const half feather = half(*featherPointer);
    if (feather > 0.0h) {
        const half low = max(0.0h, 0.5h - feather * 0.5h);
        const half high = min(1.0h, 0.5h + feather * 0.5h);
        coverage = smoothstep(low, high, coverage);
    }
    coverage = clamp(coverage * half(*opacityPointer), 0.0h, 1.0h);
    outputTexture.write(half4(coverage, coverage, coverage, 1.0h), gid);
}
