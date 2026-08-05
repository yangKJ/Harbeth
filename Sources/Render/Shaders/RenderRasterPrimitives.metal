//
//  RenderRasterPrimitives.metal
//  Harbeth
//
//  Created by Condy on 2026/8/5.
//

#include <metal_stdlib>
using namespace metal;

struct RasterPrimitiveVertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex RasterPrimitiveVertexOut renderLayerCompositeVertex(
    uint vertexID [[vertex_id]],
    constant float *vertices [[buffer(0)]]) {
    const uint offset = vertexID * 4;
    RasterPrimitiveVertexOut output;
    output.position = float4(vertices[offset], vertices[offset + 1], 0.0, 1.0);
    output.textureCoordinate = float2(vertices[offset + 2], vertices[offset + 3]);
    return output;
}

fragment float4 renderLayerCompositeFragment(
    RasterPrimitiveVertexOut input [[stage_in]],
    texture2d<float, access::sample> backgroundTexture [[texture(0)]],
    texture2d<float, access::sample> layerTexture [[texture(1)]],
    sampler textureSampler [[sampler(0)]],
    constant float *opacity [[buffer(0)]]) {
    (void)backgroundTexture;
    const float4 layer = layerTexture.sample(textureSampler, input.textureCoordinate);
    return layer * clamp(*opacity, 0.0f, 1.0f);
}

vertex RasterPrimitiveVertexOut renderVectorMaskVertex(
    uint vertexID [[vertex_id]],
    constant float *vertices [[buffer(0)]]) {
    const uint offset = vertexID * 4;
    RasterPrimitiveVertexOut output;
    output.position = float4(vertices[offset], vertices[offset + 1], 0.0, 1.0);
    output.textureCoordinate = float2(0.0);
    return output;
}

fragment float4 renderVectorMaskFragment(RasterPrimitiveVertexOut input [[stage_in]]) {
    (void)input;
    return float4(1.0);
}
