//
//  InnerYCbCrPlaneDecode.metal
//  Harbeth
//
//  Created by Condy on 2026/6/23.
//

#include <metal_stdlib>
using namespace metal;

static inline uint2 InnerYCbCrScaleCoordinate(uint2 outputCoordinate,
                                              texture2d<half, access::read> planeTexture,
                                              texture2d<half, access::write> outputTexture) {
    uint planeWidth = max(planeTexture.get_width(), 1u);
    uint planeHeight = max(planeTexture.get_height(), 1u);
    uint outputWidth = max(outputTexture.get_width(), 1u);
    uint outputHeight = max(outputTexture.get_height(), 1u);
    return uint2(
        min((outputCoordinate.x * planeWidth) / outputWidth, planeWidth - 1),
        min((outputCoordinate.y * planeHeight) / outputHeight, planeHeight - 1)
    );
}

static inline half4 InnerYCbCrConvertToRGBA(float3x3 conversionMatrix,
                                            float3 conversionOffset,
                                            half y,
                                            half u,
                                            half v) {
    float3 yuv = float3(float(y), float(u), float(v)) + conversionOffset;
    float3 rgb = conversionMatrix * yuv;
    rgb = clamp(rgb, float3(0.0f), float3(1.0f));
    return half4(half3(rgb), 1.0h);
}

kernel void InnerYCbCrBiPlanarToRGBA(texture2d<half, access::write> outputTexture [[texture(0)]],
                                     texture2d<half, access::read> lumaTexture [[texture(1)]],
                                     texture2d<half, access::read> chromaTexture [[texture(2)]],
                                     constant float3x3 &conversionMatrix [[buffer(0)]],
                                     constant float3 &conversionOffset [[buffer(1)]],
                                     uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    uint2 lumaCoordinate = InnerYCbCrScaleCoordinate(grid, lumaTexture, outputTexture);
    uint2 chromaCoordinate = InnerYCbCrScaleCoordinate(grid, chromaTexture, outputTexture);
    half y = lumaTexture.read(lumaCoordinate).r;
    half2 uv = chromaTexture.read(chromaCoordinate).rg;
    outputTexture.write(
        InnerYCbCrConvertToRGBA(conversionMatrix, conversionOffset, y, uv.x, uv.y),
        grid
    );
}

kernel void InnerYCbCrTriPlanarToRGBA(texture2d<half, access::write> outputTexture [[texture(0)]],
                                      texture2d<half, access::read> lumaTexture [[texture(1)]],
                                      texture2d<half, access::read> chromaUTexture [[texture(2)]],
                                      texture2d<half, access::read> chromaVTexture [[texture(3)]],
                                      constant float3x3 &conversionMatrix [[buffer(0)]],
                                      constant float3 &conversionOffset [[buffer(1)]],
                                      uint2 grid [[thread_position_in_grid]]) {
    if (grid.x >= outputTexture.get_width() || grid.y >= outputTexture.get_height()) {
        return;
    }
    uint2 lumaCoordinate = InnerYCbCrScaleCoordinate(grid, lumaTexture, outputTexture);
    uint2 uCoordinate = InnerYCbCrScaleCoordinate(grid, chromaUTexture, outputTexture);
    uint2 vCoordinate = InnerYCbCrScaleCoordinate(grid, chromaVTexture, outputTexture);
    half y = lumaTexture.read(lumaCoordinate).r;
    half u = chromaUTexture.read(uCoordinate).r;
    half v = chromaVTexture.read(vCoordinate).r;
    outputTexture.write(
        InnerYCbCrConvertToRGBA(conversionMatrix, conversionOffset, y, u, v),
        grid
    );
}
