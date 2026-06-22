#include <metal_stdlib>
using namespace metal;

static inline half4 safe_read(texture2d<half, access::read> texture, uint2 gid) {
    uint x = min(gid.x, texture.get_width() - 1);
    uint y = min(gid.y, texture.get_height() - 1);
    return texture.read(uint2(x, y));
}

kernel void C7DissolveTransition(texture2d<half, access::write> outputTexture [[texture(0)]],
                                 texture2d<half, access::read> fromTexture [[texture(1)]],
                                 texture2d<half, access::read> toTexture [[texture(2)]],
                                 constant float *progressPointer [[buffer(0)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    const half progress = half(clamp(*progressPointer, 0.0f, 1.0f));
    const half4 from = safe_read(fromTexture, gid);
    const half4 to = safe_read(toTexture, gid);
    outputTexture.write(mix(from, to, progress), gid);
}

kernel void C7DirectionalWipeTransition(texture2d<half, access::write> outputTexture [[texture(0)]],
                                        texture2d<half, access::read> fromTexture [[texture(1)]],
                                        texture2d<half, access::read> toTexture [[texture(2)]],
                                        constant float *progressPointer [[buffer(0)]],
                                        constant float *anglePointer [[buffer(1)]],
                                        constant float *softnessPointer [[buffer(2)]],
                                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    const float progressValue = clamp(*progressPointer, 0.0f, 1.0f);
    if (progressValue <= 0.0f) {
        outputTexture.write(safe_read(fromTexture, gid), gid);
        return;
    }
    if (progressValue >= 1.0f) {
        outputTexture.write(safe_read(toTexture, gid), gid);
        return;
    }
    const half2 uv = half2(float(gid.x) / max(float(outputTexture.get_width() - 1), 1.0f),
                           float(gid.y) / max(float(outputTexture.get_height() - 1), 1.0f));
    const half2 direction = normalize(half2(cos(*anglePointer), sin(*anglePointer)));
    const half projection = dot(uv - 0.5h, direction) + 0.5h;
    const half softness = half(max(*softnessPointer, 0.0001f));
    const half progress = half(progressValue);
    const half mixFactor = smoothstep(progress - softness, progress + softness, projection);
    const half4 from = safe_read(fromTexture, gid);
    const half4 to = safe_read(toTexture, gid);
    outputTexture.write(mix(from, to, mixFactor), gid);
}

kernel void C7LumaWipeTransition(texture2d<half, access::write> outputTexture [[texture(0)]],
                                 texture2d<half, access::read> fromTexture [[texture(1)]],
                                 texture2d<half, access::read> toTexture [[texture(2)]],
                                 texture2d<half, access::read> lumaTexture [[texture(3)]],
                                 constant float *progressPointer [[buffer(0)]],
                                 constant float *softnessPointer [[buffer(1)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    const float progressValue = clamp(*progressPointer, 0.0f, 1.0f);
    if (progressValue <= 0.0f) {
        outputTexture.write(safe_read(fromTexture, gid), gid);
        return;
    }
    if (progressValue >= 1.0f) {
        outputTexture.write(safe_read(toTexture, gid), gid);
        return;
    }
    const half4 lumaSample = safe_read(lumaTexture, gid);
    const half luma = dot(lumaSample.rgb, half3(0.299h, 0.587h, 0.114h));
    const half softness = half(max(*softnessPointer, 0.0001f));
    const half progress = half(progressValue);
    const half mixFactor = smoothstep(progress - softness, progress + softness, luma);
    const half4 from = safe_read(fromTexture, gid);
    const half4 to = safe_read(toTexture, gid);
    outputTexture.write(mix(from, to, mixFactor), gid);
}

kernel void C7DisplacementTransition(texture2d<half, access::write> outputTexture [[texture(0)]],
                                     texture2d<half, access::read> fromTexture [[texture(1)]],
                                     texture2d<half, access::read> toTexture [[texture(2)]],
                                     texture2d<half, access::read> displacementTexture [[texture(3)]],
                                     constant float *progressPointer [[buffer(0)]],
                                     constant float *scalePointer [[buffer(1)]],
                                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    const float progressValue = clamp(*progressPointer, 0.0f, 1.0f);
    if (progressValue <= 0.0f) {
        outputTexture.write(safe_read(fromTexture, gid), gid);
        return;
    }
    if (progressValue >= 1.0f) {
        outputTexture.write(safe_read(toTexture, gid), gid);
        return;
    }
    const half4 displacementSample = safe_read(displacementTexture, gid);
    const half progress = half(progressValue);
    const half2 offset = (displacementSample.rg - 0.5h) * half(*scalePointer) * half(1.0f - progressValue) * half2(outputTexture.get_width(), outputTexture.get_height());
    const int2 displaced = int2(clamp(int(gid.x) + int(offset.x), 0, int(outputTexture.get_width() - 1)),
                                clamp(int(gid.y) + int(offset.y), 0, int(outputTexture.get_height() - 1)));
    const half4 from = fromTexture.read(uint2(displaced));
    const half4 to = safe_read(toTexture, gid);
    outputTexture.write(mix(from, to, progress), gid);
}
