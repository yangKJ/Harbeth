#include <metal_stdlib>
using namespace metal;

struct MeshWarpVertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex MeshWarpVertexOut meshWarpVertex(
    uint vertexID [[vertex_id]],
    constant float *vertices [[buffer(0)]]) {
    const uint offset = vertexID * 4;
    MeshWarpVertexOut vertexOut;
    vertexOut.position = float4(vertices[offset], vertices[offset + 1], 0.0, 1.0);
    vertexOut.textureCoordinate = float2(vertices[offset + 2], vertices[offset + 3]);
    return vertexOut;
}

fragment float4 meshWarpFragment(
    MeshWarpVertexOut vertexOut [[stage_in]],
    texture2d<float, access::sample> inputTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]) {
    return inputTexture.sample(textureSampler, vertexOut.textureCoordinate);
}
