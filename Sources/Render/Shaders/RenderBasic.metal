#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
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

fragment float4 basicFragment(VertexOut vertexOut [[stage_in]],
                              texture2d<float, access::sample> inputTexture [[texture(0)]],
                              sampler textureSampler [[sampler(0)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float4 color = inputTexture.sample(s, vertexOut.textureCoordinate);
    return color;
}

fragment float4 grayscaleFragment(VertexOut vertexOut [[stage_in]],
                                  texture2d<float, access::sample> inputTexture [[texture(0)]],
                                  sampler textureSampler [[sampler(0)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float4 color = inputTexture.sample(s, vertexOut.textureCoordinate);
    float gray = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    return float4(gray, gray, gray, color.a);
}

fragment float4 sepiaFragment(VertexOut vertexOut [[stage_in]],
                              texture2d<float, access::sample> inputTexture [[texture(0)]],
                              sampler textureSampler [[sampler(0)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float4 color = inputTexture.sample(s, vertexOut.textureCoordinate);
    float gray = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float4 sepiaColor = float4(gray * 0.9, gray * 0.7, gray * 0.4, color.a);
    return sepiaColor;
}
