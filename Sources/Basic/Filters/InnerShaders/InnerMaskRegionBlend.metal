#include <metal_stdlib>
using namespace metal;

static inline half mask_component_value(half4 color, int component) {
    switch (component) {
        case 0: return color.a;
        case 1: return color.r;
        case 2: return color.g;
        case 3: return color.b;
        case 4: return dot(color.rgb, half3(0.299h, 0.587h, 0.114h));
        default: return color.a;
    }
}

kernel void InnerMaskRegionBlend(texture2d<half, access::write> outputTexture [[texture(0)]],
                                 texture2d<half, access::read> inputTexture [[texture(1)]],
                                 texture2d<half, access::read> effectTexture [[texture(2)]],
                                 texture2d<half, access::read> maskTexture [[texture(3)]],
                                 constant float *opacityPointer [[buffer(0)]],
                                 constant float *invertPointer [[buffer(1)]],
                                 constant float *componentPointer [[buffer(2)]],
                                 constant float *blendModePointer [[buffer(3)]],
                                 constant float *featherPointer [[buffer(4)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    const half4 base = inputTexture.read(gid);
    const half4 effect = effectTexture.read(gid);
    const half4 maskColor = maskTexture.read(gid);

    half mask = mask_component_value(maskColor, int(*componentPointer));
    if (*invertPointer > 0.5f) {
        mask = 1.0h - mask;
    }
    const half feather = half(*featherPointer);
    if (feather > 0.0h) {
        const half low = max(0.0h, 0.5h - feather * 0.5h);
        const half high = min(1.0h, 0.5h + feather * 0.5h);
        mask = smoothstep(low, high, mask);
    }
    mask *= half(*opacityPointer);

    half4 output = mix(base, effect, mask);
    switch (int(*blendModePointer)) {
        case 1:
            output = base * (1.0h - mask) + effect * mask;
            break;
        case 2:
            output = base + effect * mask;
            break;
        case 3:
            output = base * mix(half4(1.0h), effect, mask);
            break;
        case 4:
            output = mix(base, max(base - effect, half4(0.0h)), mask);
            break;
        default:
            break;
    }
    outputTexture.write(output, gid);
}
